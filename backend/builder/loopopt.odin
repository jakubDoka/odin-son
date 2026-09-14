package builder

import backend ".."
import "../../vendored/gam/util/arna"
import "../../vendored/gam/util/bit_arr"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"

loopopt :: proc(graph: ^backend.Graph) -> (optimized: bool) {
	context.allocator, _ = arna.scrath()

	if .Loop_Opt not_in graph.opt_flags do return

	defer graph.peeped &= !optimized

	Ctx :: struct {
		using graph:  ^backend.Graph,
		sched:        backend.Graph_Schedule,
		cloned_up:    []Node_ID,
		cloned_down:  []Node_ID,
		node_blocks:  []^backend.Graph_Basic_Block,
		instrs:       []Node_ID,
		current_loop: Node_ID,
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.cloned_up = make([]Node_ID, graph.gvn * 2)
	ctx.cloned_down = make([]Node_ID, graph.gvn * 2)
	ctx.node_blocks = make(type_of(ctx.node_blocks), graph.gvn * 2)
	backend.graph_schedule(graph, &ctx.sched, .for_loopopt)

	reserve(&ctx.sched.bbs, len(ctx.sched.bbs) * 2)
	ctx.sched.bbs.allocator = {}

	for &bb in ctx.sched.bbs {
		hnode := graph_get(ctx.graph, bb.head)
		ctx.node_blocks[hnode.gvn] = &bb
		for instr in bb.instrs {
			if backend.graph_has_flag(
				ctx.graph,
				instr,
				.Is_Basic_Block_Start,
			) {continue}
			inode := graph_get(ctx.graph, instr)
			ctx.node_blocks[inode.gvn] = &bb
		}
	}

	rotated := false

	rotate: for &bb, i in ctx.sched.bbs {
		if graph_get(ctx, bb.head).rtype == backend.DEAD_NODE_KIND {
			continue
		}

		hnode := backend.graph_expand(ctx, bb.head)
		if hnode.itype != .Loop do continue

		bnd := graph_expand(ctx, hnode.inps[1])

		// NOTE: this should mean rotation does noting/already rotated
		if bnd.itype == .If do continue
		if len(block_of(ctx, hnode.inps[1]).instrs) == 1 &&
		   (bnd.itype == .Else || bnd.itype == .Then) &&
		   graph_get(ctx, bnd.inps[0]).itype == .If &&
		   block_of(ctx, bnd.inps[0]).loop_tree == bb.loop_tree {

			already_latch := false
			for out in backend.graph_outs(ctx, bnd.inps[0]) {
				if graph_get(ctx, out.id).itype == .Loop {
					already_latch = true
				}
			}

			if !already_latch {
				backend.graph_subsume(ctx, bnd.inps[0], hnode.inps[1])
				continue
			}
		}

		next_ctrl := bb.instrs[len(bb.instrs) - 1]

		nnode := backend.graph_expand(ctx, next_ctrl)
		// TODO: we could do better then this and actually clone calls as well
		if nnode.itype != .If do continue

		then_else_bb: [2]^backend.Graph_Basic_Block
		then_else := [?]Node_ID{nnode.outs[0].id, nnode.outs[1].id}
		break_branch: ^backend.Graph_Basic_Block
		continue_branch: ^backend.Graph_Basic_Block

		for &n, i in then_else_bb {
			n = block_of(ctx, then_else[i])
			if n.loop_tree != bb.loop_tree {
				break_branch = n
			} else {
				continue_branch = n
			}
		}

		// NOTE: this if actually does not break out of the loop
		if break_branch == nil do continue

		fmt.assertf(
			continue_branch != nil,
			"%#v %v\n%v\n%v",
			then_else_bb,
			bb.loop_tree,
			hnode,
			nnode,
		)

		assert(
			graph_get(ctx, break_branch.head).rtype != backend.DEAD_NODE_KIND,
		)

		cond_is_inverted := then_else_bb[0] == break_branch

		ctx.current_loop = bb.head
		ctx.instrs = bb.instrs[:]

		to_clone: [dynamic]Node_ID
		append(&to_clone, nnode.inps[1])

		#reverse for instr in bb.instrs[:len(bb.instrs) - 1] {
			nd := graph_expand(ctx, instr)
			for out in nd.outs {
				blk := block_of(ctx, out.id)
				if !in_loop(bb.loop_tree, blk.loop_tree) {
					append(&to_clone, instr)
					break
				}
			}
		}

		for node in to_clone {
			if !check_valid_ops(ctx, node) do continue rotate
		}

		rotated = true

		entry_blk := block_of(ctx, hnode.inps[0])
		exit_blk := block_of(ctx, hnode.inps[1])

		guard_cond := clone_by(ctx, nnode.inps[1], 1, entry_blk)

		guard := backend.graph_add_if(ctx, "urlg", hnode.inps[0], guard_cond)
		ctx.node_blocks[graph_get(ctx, guard).gvn] = entry_blk

		guard_loop := backend.graph_add_then(ctx, "urltn", guard)
		wire_up_new_block(&ctx, guard_loop, bb.loop_tree.parent)
		guard_skip := backend.graph_add_else(ctx, "urles", guard)
		wire_up_new_block(&ctx, guard_skip, bb.loop_tree.parent)

		back_cond := clone_by(ctx, nnode.inps[1], 2, exit_blk)

		backend.graph_set_input(ctx, next_ctrl, 1, back_cond)
		ctx.node_blocks[graph_get(ctx, next_ctrl).gvn] = exit_blk

		if cond_is_inverted do guard_loop, guard_skip = guard_skip, guard_loop

		backend.graph_set_input(ctx, bb.head, 0, guard_loop)

		join := backend.graph_add_region(
			ctx,
			"urljn",
			{guard_skip, break_branch.head, graph.start},
		)
		join_bb := wire_up_new_block(&ctx, join, bb.loop_tree.parent)

		wire_up_new_block :: proc(
			ctx: ^Ctx,
			node: Node_ID,
			ltree: ^backend.Loop_Tree,
		) -> ^backend.Graph_Basic_Block {
			append(
				&ctx.sched.bbs,
				backend.Graph_Basic_Block{head = node, loop_tree = ltree},
			)
			join_bb := &ctx.sched.bbs[len(ctx.sched.bbs) - 1]
			ctx.node_blocks[graph_get(ctx, node).gvn] = join_bb
			return join_bb
		}

		bouts := backend.graph_outs(ctx, break_branch.head)
		#reverse for out in bouts[:len(bouts) - 1] {
			backend.graph_set_input(ctx, out.id, out.idx, join)
		}

		for instr in break_branch.instrs {
			if !backend.graph_has_flag(ctx, instr, .Is_Basic_Block_Start) {
				ctx.node_blocks[graph_get(ctx, instr).gvn] = join_bb
			}
		}

		if !ODIN_DISABLE_ASSERT {
			for &bb in ctx.sched.bbs {
				if graph_get(ctx, bb.head).rtype == backend.DEAD_NODE_KIND do continue
				assert(block_of(ctx, bb.head) == &bb)
			}
		}

		hnode = graph_expand(ctx, bb.head)

		#reverse for to_clone in to_clone[1:] {
			init := clone_by(ctx, to_clone, 1, entry_blk)
			back := clone_by(ctx, to_clone, 2, exit_blk)

			tcnode := graph_expand(ctx, to_clone)
			join_phi := backend.graph_add_phi(
				ctx,
				"urlph",
				tcnode.dt,
				join,
				init,
				back,
			)
			ctx.node_blocks[graph_get(ctx, join_phi).gvn] = join_bb

			oouts: []backend.Node_Output = backend.graph_outs(ctx, to_clone)

			#reverse for tcout in oouts {
				tco_blk := block_of(ctx, tcout.id)
				ponode := graph_get(ctx, tcout.id)

				if in_loop(bb.loop_tree, tco_blk.loop_tree) {
					continue
				}

				dblk := tco_blk.head
				if ponode.itype == .Phi {
					dblk = backend.graph_inps(ctx, dblk)[tcout.idx - 1]
					if graph_get(ctx, dblk).itype == .If {
						dblk = backend.graph_inps(ctx, dblk)[0]
					}
					fmt.assertf(
						backend.graph_has_flag(
							ctx,
							dblk,
							.Is_Basic_Block_Start,
						),
						"%v",
						graph_get(ctx, dblk),
					)
				}

				res := walk_use_blocks(
					ctx,
					dblk,
					join,
					to_clone,
					join_phi,
					bb.loop_tree,
				)

				backend.graph_set_input(ctx, tcout.id, tcout.idx, res)
			}
		}

		backend.graph_pin(ctx, continue_branch.head)
		couts := backend.graph_outs(ctx, continue_branch.head)
		for out in couts[:len(couts) - 1] {
			backend.graph_set_input(ctx, out.id, out.idx, bb.head)
		}

		backend.graph_set_input(ctx, next_ctrl, 0, hnode.inps[1])
		backend.graph_set_input(ctx, bb.head, 1, next_ctrl)

		backend.graph_unpin(ctx, continue_branch.head)
	}

	optimized |= rotated

	if rotated {
		backend.graph_invalidate_idepth(graph)
		backend.graph_schedule(ctx, &ctx.sched, .for_loopopt)
	}

	if !ODIN_DISABLE_ASSERT {
		backend.graph_schedule(ctx, &ctx.sched, .for_loopopt)
	}

	for &bb in ctx.sched.bbs {
		head := graph_expand(ctx, bb.head)
		if head.itype != .Loop do continue

		bedge := graph_expand(ctx, head.inps[1])
		if bedge.itype != .If do continue
		if bedge.inps[0] != bb.head do continue

		inverted := bedge.outs[0].id != bb.head
		cond := graph_expand(ctx, bedge.inps[1])

		@(rodata, static)
		CMP_OP_REVERSE :=
			#partial [backend.Ideal_Node_Type]backend.Ideal_Node_Type {
				.Eq = .Ne,
				.Ne = .Eq,
				.Lt = .Ge,
				.Le = .Gt,
				.Gt = .Le,
				.Ge = .Lt,
			}

		@(rodata, static)
		CMP_OP_FLIP :=
			#partial [backend.Ideal_Node_Type]backend.Ideal_Node_Type {
				.Eq = .Eq,
				.Ne = .Ne,
				.Lt = .Gt,
				.Le = .Ge,
				.Gt = .Lt,
				.Ge = .Le,
			}

		effective_op := cond.itype
		if CMP_OP_REVERSE[effective_op] == {} do continue
		if inverted do effective_op = CMP_OP_REVERSE[effective_op]

		Inductor :: struct {
			phy:       Node_ID,
			stride:    Node_ID,
			bound:     Node_ID,
			stride_vl: i64,
		}

		inductors: [dynamic]Inductor
		terminates := false

		for out in head.outs {
			onode := graph_expand(ctx, out.id)
			if onode.itype != .Phi do continue

			init := graph_expand(ctx, onode.inps[1])
			bvl := graph_expand(ctx, onode.inps[2])

			if bvl.itype != .Add do continue
			if bvl.inps[0] != out.id do continue
			if slice.contains(bb.instrs[:], bvl.inps[1]) do continue

			stride := backend.graph_extra(ctx, bvl.inps[1], backend.CInt)
			stride_vl: i64
			if stride != nil {
				stride_vl = stride.value
			}

			bound: Node_ID
			slcs := [][]backend.Node_Output{bvl.outs, onode.outs}
			find_bound: for slc in slcs {
				for bout in slc {
					bonode := graph_expand(ctx, bout.id)
					if bout.id == bedge.inps[1] {
						bound = cond.inps[1 - bout.idx]
						break find_bound
					}
				}
			}

			if slice.contains(bb.instrs[:], bound) do bound = 0
			terminates |= bound != 0

			append(&inductors, Inductor{out.id, bvl.inps[1], bound, stride_vl})
		}

		for ind in inductors {
			phy := graph_expand(ctx, ind.phy)

			Op :: struct {
				node:   Node_ID,
				base:   Node_ID,
				stride: i64,
			}

			Indexing :: struct {
				base:       Node_ID,
				stride:     Node_ID,
				to_subsume: Node_ID,
			}

			// candidate for memset or memcpy
			stores: #soa[dynamic]Op
			loads: #soa[dynamic]Op
			indexings: [dynamic]Indexing
			for out in phy.outs {
				out := out
				onode := graph_expand(ctx, out.id)
				if out.id == phy.inps[2] do continue

				stride_node: Node_ID
				if onode.itype == .Mul {
					stride_node = onode.inps[1 - out.idx]
					otnode := graph_expand(ctx, stride_node)
					if slice.contains(bb.instrs[:], stride_node) {
						continue
					}

					for oout in onode.outs {
						oonode := graph_expand(ctx, oout.id)
						if oonode.itype == .Add {
							out = oout
							onode = oonode
							break
						}
					}
				}

				if onode.itype == .Add {
					base := onode.inps[1 - out.idx]
					otnode := graph_expand(ctx, base)

					if slice.contains(bb.instrs[:], base) do continue

					stride: i64
					stride_vl: ^backend.CInt

					if stride_node != 0 {
						stride_vl = backend.graph_extra(
							ctx,
							stride_node,
							backend.CInt,
						)
					} else {
						stride_vl = &CInt{value = 1}
					}
					if stride_vl != nil do stride = stride_vl.value

					if stride_vl != nil {
						for otout in onode.outs {
							otonode := graph_expand(ctx, otout.id)

							if otonode.itype == .Store {
								append(&stores, Op{otout.id, base, stride})
							}
							if otonode.itype == .Load {
								append(&loads, Op{otout.id, base, stride})
							}
						}
					}

					stride_is_pow2 := math.is_power_of_two(int(stride))
					if stride_node != 0 && (!stride_is_pow2 || stride > 8) {
						append(
							&indexings,
							Indexing {
								base,
								stride_node,
								backend.graph_id(ctx, onode),
							},
						)
					}
				}
			}

			for idx in indexings {
				if true do break
				fmt.assertf(
					!slice.contains(bb.instrs[:], idx.base),
					"%v",
					graph_get(ctx, idx.base),
				)
				fmt.assertf(
					!slice.contains(bb.instrs[:], idx.stride),
					"%v",
					graph_get(ctx, idx.stride),
				)

				graph_dyn_index_offset :: proc(
					ctx: ^Graph,
					base, idx, stride: Node_ID,
				) -> Node_ID {
					index := idx

					index = backend.graph_add_bin_op(
						ctx,
						"snoff",
						.Mul,
						.I64,
						index,
						stride,
					)
					index = backend.graph_peep(ctx, index)

					return backend.graph_add_bin_op(
						ctx,
						"snd",
						.Add,
						.I64,
						base,
						index,
					)
				}

				init := graph_dyn_index_offset(
					ctx,
					idx.base,
					phy.inps[1],
					idx.stride,
				)

				nphy := graph_add_lazy_phi(ctx, "srdph", phy.dt, bb.head, init)
				next := backend.graph_add_bin_op(
					ctx,
					"srdnt",
					.Add,
					phy.dt,
					nphy,
					idx.stride,
				)
				backend.graph_connect(ctx, nphy, next)
				graph_get(ctx, nphy).itype = .Phi
				nphy = backend.graph_intern(ctx, nphy)

				backend.graph_subsume(ctx, nphy, idx.to_subsume)

				if ind.bound != 0 && effective_op == .Lt {
					new_bound := graph_dyn_index_offset(
						ctx,
						idx.base,
						ind.bound,
						idx.stride,
					)
					ncmp := backend.graph_add_bin_op(
						ctx,
						"srdcp",
						Bin_Op(cond.itype),
						.I8,
						next,
						new_bound,
					)
					backend.graph_subsume(ctx, ncmp, bedge.inps[1])
				}
			}

			for store, i in stores {
				snode := graph_expand(ctx, store.node)
				vl := graph_expand(ctx, snode.inps[3])

				mem := graph_expand(ctx, snode.inps[1])
				if mem.itype != .Phi || mem.inps[0] != bb.head do continue

				for out in snode.outs {
					if graph_get(ctx, out.id).itype != .Phi &&
					   slice.contains(bb.instrs[:], out.id) {
						// NOTE: the loop has other garbage, we cant decide no yet
						continue
					}
				}

				stride := ind.stride_vl * store.stride

				continuous: if backend.DT_SIZE[vl.dt] == int(stride) &&
				   effective_op == .Lt &&
				   ind.bound != 0 {

					can_memset :=
						!slice.contains(bb.instrs[:], snode.inps[3]) &&
						stride == 1

					lidx, lok := slice.linear_search(
						loads.node[:len(loads)],
						snode.inps[3],
					)
					can_memcpy :=
						lok &&
						vl.inps[1] == snode.inps[1] &&
						loads[lidx].stride == store.stride
					optimized |= can_memset | can_memcpy

					size, dst, cpy: Node_ID

					if can_memset || can_memcpy {
						size = backend.graph_add_bin_op(
							ctx,
							"lnscl",
							.Mul,
							.I64,
							backend.graph_add_bin_op(
								ctx,
								"ln",
								.Sub,
								.I64,
								ind.bound,
								phy.inps[1],
							),
							backend.graph_add_c_int(
								ctx,
								"scl",
								.I64,
								store.stride,
							),
						)
						dst = graph_index_offset(
							ctx,
							store.base,
							phy.inps[1],
							stride,
						)
					}

					if can_memset {
						cpy = backend.graph_add_set(
							graph,
							"mstf",
							head.inps[0],
							mem.inps[1],
							dst,
							snode.inps[3],
							size,
						)
					}

					if can_memcpy {
						cpy = backend.graph_add_copy(
							graph,
							"mcpf",
							head.inps[0],
							mem.inps[1],
							dst,
							graph_index_offset(
								ctx,
								loads[lidx].base,
								phy.inps[1],
								stride,
							),
							size,
						)
					}

					if cpy != 0 {
						backend.graph_set_input(graph, snode.inps[1], 1, cpy)
						backend.graph_subsume(graph, snode.inps[1], store.node)
						continue
					}
				}
			}
		}

		for ind in inductors {
			phy := graph_expand(ctx, ind.phy)
			next := graph_expand(ctx, phy.inps[2])
			if len(phy.outs) > 1 do continue
			if len(next.outs) > 1 do continue

			backend.graph_subsume(ctx, phy.inps[1], ind.phy)
		}

		head = graph_expand(ctx, bb.head)
		keep := 0
		for instr in bb.instrs {
			if graph_get(ctx, instr).rtype != backend.DEAD_NODE_KIND {
				bb.instrs[keep] = instr
				keep += 1
			}
		}
		resize(&bb.instrs, keep)

		eliminate: if terminates {
			req_sched := bit_arr.init(len(bb.instrs))
			for {
				changed := false

				#reverse for instr, i in bb.instrs {
					inode := graph_expand(ctx, instr)
					if inode.inps[0] == bb.head {
						changed |= bit_arr.set(req_sched, i)
						continue
					}
					if bit_arr.contains(req_sched, i) do continue
					for out in inode.outs {
						onode := graph_expand(ctx, out.id)
						if onode.itype == .Phi && onode.inps[0] == bb.head {
							changed |= bit_arr.set(req_sched, i)
							break
						}

						idx := slice.linear_search(
							bb.instrs[:],
							out.id,
						) or_continue

						if bit_arr.contains(req_sched, idx) {
							ok := bit_arr.set(req_sched, i)
							assert(ok)
							changed = true
							break
						}
					}
				}

				if !changed do break
			}

			for it := bit_arr.iter(req_sched); i in bit_arr.iter_next(&it) {
				instr := bb.instrs[i]
				inode := graph_expand(ctx, instr)

				if backend.is_cfg(ctx, instr) {
					continue
				}

				if inode.itype == .Phi && inode.inps[2] == instr {
					// phy is essentially dead
					continue
				}

				for out in inode.outs {
					idx, ok := slice.linear_search(bb.instrs[:], out.id)
					if !ok || !bit_arr.contains(req_sched, idx) {
						break eliminate
					}
				}
			}

			assert(graph_get(ctx, head.inps[1]).itype == .If)

			backend.graph_set_input(
				ctx,
				head.inps[1],
				1,
				backend.graph_add_c_int(ctx, "ulfld", .I8, i64(inverted)),
			)

			optimized = true
		}
	}

	return

	block_of :: proc(
		ctx: Ctx,
		node: Node_ID,
	) -> (
		v: ^backend.Graph_Basic_Block,
	) {
		defer fmt.assertf(v != nil, "%v", graph_get(ctx, node))
		return ctx.node_blocks[graph_get(ctx, node).gvn]
	}

	walk_use_blocks :: proc(
		ctx: Ctx,
		root: Node_ID,
		guard: Node_ID,
		out: Node_ID,
		nphy: Node_ID,
		to_loop: ^backend.Loop_Tree,
	) -> Node_ID {
		node := graph_expand(ctx, root)
		if root == guard do return nphy

		if in_loop(to_loop, block_of(ctx, root).loop_tree) {
			return out
		}

		loop_or_region := node.itype == .Loop || node.itype == .Region
		edges: [dynamic]Node_ID
		for inp in node.inps[:len(node.inps) - int(loop_or_region)] {
			if backend.is_cfg(ctx, inp) {
				vl := walk_use_blocks(ctx, inp, guard, out, nphy, to_loop)
				append(&edges, vl)
			}
		}

		ref := edges[0]
		for oth in edges[1:] {
			if oth != ref {
				inject_at(&edges, 0, root)
				ref = backend.graph_add_raw(
					ctx,
					"urlj",
					u16(backend.Ideal_Node_Type.Phi),
					graph_get(ctx, ref).dt,
					edges[:],
				)
				break
			}
		}

		return ref
	}

	in_loop :: proc(
		this: ^backend.Loop_Tree,
		tested: ^backend.Loop_Tree,
	) -> bool {
		assert(tested != nil)
		assert(this != nil)
		for cursor := tested; cursor != nil; cursor = cursor.parent {
			if cursor == this {
				return true
			}
		}

		return false
	}

	check_valid_ops :: proc(ctx: Ctx, root: Node_ID) -> bool {
		if !slice.contains(ctx.instrs, root) do return true

		PROHIBITED_OPS :: bit_set[backend.Ideal_Node_Type]{.Copy, .Set, .Store}
		rnode := graph_expand(ctx, root)
		// TODO: we could clone the stores too, but that requires more
		// complex fixups of memory threads
		if rnode.itype in PROHIBITED_OPS do return false

		if rnode.itype != .Phi {
			for inp in rnode.inps {
				if !check_valid_ops(ctx, inp) do return false
			}
		}

		return true
	}

	clone_by :: proc(
		ctx: Ctx,
		root: Node_ID,
		phy_idx: int,
		ctrl: ^backend.Graph_Basic_Block,
	) -> Node_ID {
		if root == ctx.current_loop {
			return ctrl.head
		}

		if !slice.contains(ctx.instrs, root) do return root

		cloned := ctx.cloned_down
		if phy_idx == 1 {
			cloned = ctx.cloned_up
		} else {
			assert(phy_idx == 2)
		}

		node := graph_expand(ctx, root)
		if cloned[node.gvn] == 0 {
			if node.itype == .Phi && node.inps[0] == ctx.current_loop {
				cloned[node.gvn] = node.inps[phy_idx]
			} else {
				graph := ctx.graph
				PRECISION :: backend.PRECISION

				prev := graph.mem.pos

				inps := make([]Node_ID, len(node.inps))

				for &inp, i in inps {
					inp = clone_by(ctx, node.inps[i], phy_idx, ctrl)
				}

				new_node, id := backend.graph_shallow_clone(graph, node)
				backend.graph_init_counts(graph, new_node)

				new_node.input_idx = u32(graph.mem.pos / backend.PRECISION)
				_ = arna.clone(graph.mem, inps)
				new_node.input_cap = new_node.input_count

				// This should be fine since we kind of reserver memory for
				// dependants, even if we overallocate its a good estimate
				new_node.output_idx = u32(graph.mem.pos / backend.PRECISION)
				_ = arna.alloc(
					graph.mem,
					uint(node.output_cap * backend.PRECISION),
					backend.PRECISION,
				)
				new_node.output_count = 0
				new_node.output_cap = node.output_cap

				interned := backend.graph_intern(graph, id)
				if interned != id {
					graph.mem.pos = prev
					id = interned
					graph.gvn -= 1
					cloned[node.gvn] = id
				} else {
					ctx.node_blocks[new_node.gvn] = ctrl
					append(&ctrl.instrs, id)
					cloned[node.gvn] = id
					for inp, i in inps {
						backend.graph_add_output(ctx, inp, cloned[node.gvn], i)
					}
					// NOTE: no need to clone the debug info
				}
			}
		}

		return cloned[node.gvn]
	}
}
