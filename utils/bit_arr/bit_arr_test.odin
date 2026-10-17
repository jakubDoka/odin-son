#+build !wasm32
#+build !freestanding
package bit_arr

import "core:testing"

@(test)
iter_sanity :: proc(t: ^testing.T) {
	masks: [2]int
	st := init_from_masks(masks[:])

	set(st, 65)
	set(st, 125)

	it := iter(st)
	testing.expect_value(t, iter_next(&it) or_else panic(""), 65)
	testing.expect_value(t, iter_next(&it) or_else panic(""), 125)
	_, ok := iter_next(&it)
	testing.expect(t, !ok)
}

@(test)
dl_sanity :: proc(t: ^testing.T) {
	nodes: [3]DL_Node
	list: DL_List

	for &n in nodes {
		dl_push(&list, &n)
	}

	for &n in nodes {
		dl_remove(&n)
	}

	testing.expect_value(t, list.first, nil)

	for &n in nodes {
		dl_push(&list, &n)
	}

	dl_remove(&nodes[1])

	iter := dl_iter(&list)

	n, ok := dl_iter_next(&iter, DL_Node, 0)
	testing.expect(t, ok)
	testing.expect_value(t, n, &nodes[2])

	n, ok = dl_iter_next(&iter, DL_Node, 0)
	testing.expect(t, ok)
	testing.expect_value(t, n, &nodes[0])

	testing.expect_value(t, iter.cursor, iter.last)
}
