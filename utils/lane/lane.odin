package lane

import "base:intrinsics"
import "base:runtime"
import psync "core:sync"
import "core:thread"

Group :: struct {
	idx:     int,
	count:   int,
	barrier: ^psync.Barrier,
	slot:    ^u64,
}

Queue :: struct {
	pos, limit: int,
}

@(thread_local)
group: Group

idx :: proc "contextless" () -> int {
	return group.idx
}

alloc :: proc() -> bool {
	@(thread_local)
	cursor: int
	defer cursor += 1
	return cursor % count() == idx()
}

count :: proc "contextless" () -> int {
	// thread locals cant have initializers, zeroed group is single lane
	return max(group.count, 1)
}

sync :: proc "contextless" () {
	if count() == 1 do return
	psync.barrier_wait(group.barrier)
}

range :: proc "contextless" (#any_int item_count: int) -> (lo, hi: int) {
	base := item_count / count()
	rem := item_count % count()
	lo = group.idx * base + min(group.idx, rem)
	hi = lo + base + int(group.idx < rem)
	return
}

sync_value :: proc(
	value: ^$T,
	#any_int src: int = 0,
) where size_of(T) <=
	size_of(u64) {
	assert(0 <= src && src < count())
	if count() == 1 do return

	if group.idx == src {
		intrinsics.mem_copy_non_overlapping(
			group.slot,
			transmute(rawptr)value,
			size_of(T),
		)
	}
	sync()
	if group.idx != src {
		intrinsics.mem_copy_non_overlapping(
			value,
			transmute(rawptr)group.slot,
			size_of(T),
		)
	}
	sync()
}

set_group :: proc "contextless" (g: Group) {
	group = g
}

@(deferred_out = set_group)
single :: proc "contextless" () -> Group {
	prev := group
	group = {
		count = 1,
	}
	return prev
}

next :: proc "contextless" (q: ^Queue) -> (int, bool) {
	i := psync.atomic_add(&q.pos, 1)
	return i, i < q.limit
}

run :: proc {
	run_with_data,
	run_no_data,
}

run_no_data :: proc(#any_int lane_count: int, entry: proc()) {
	run_with_data(lane_count, entry, proc(entry: proc()) {entry()})
}

run_with_data :: proc(
	#any_int lane_count: int,
	data: $T,
	entry: proc(data: T),
) {
	assert(lane_count >= 1)

	Shared :: struct {
		barrier: psync.Barrier,
		slot:    u64,
		data:    T,
		entry:   proc(data: T),
	}

	shared := Shared {
		data  = data,
		entry = entry,
	}
	psync.barrier_init(&shared.barrier, lane_count)

	threads := make([]^thread.Thread, lane_count - 1)
	defer delete(threads)
	for &t, i in threads {
		t = thread.create_and_start_with_poly_data2(
			&shared,
			i + 1,
			lane_main,
			context,
		)
		assert(t != nil)
	}

	lane_main(&shared, 0)

	thread.join_multiple(..threads)
	for t in threads do thread.destroy(t)

	lane_main :: proc(shared: ^Shared, i: int) {
		prev := group
		defer group = prev
		group = {i, shared.barrier.thread_count, &shared.barrier, &shared.slot}

		shared.entry(shared.data)

		// thread.create_* skips destroying the thread's default temp allocator when given an init_context
		if i != 0 &&
		   context.temp_allocator.procedure ==
			   runtime.default_temp_allocator_proc {
			runtime.default_temp_allocator_destroy(
				auto_cast context.temp_allocator.data,
			)
		}
	}
}
