package builder

import bac ".."
import "../../vendored/gam/util/arna"
import "../../vendored/gam/util/bit_arr"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"

loopopt :: proc(graph: ^bac.Proc) -> (optimized: bool) {
	context.allocator, _ = arna.scrath()

	if .Loop_Opt not_in graph.opt_flags do return

	defer graph.peeped &= !optimized

	Ctx :: struct {
		using graph:  ^bac.Proc,
		sched:        bac.Schedule,
		cloned_up:    []Node_ID,
		cloned_down:  []Node_ID,
		node_blocks:  []^bac.Basic_Block,
		instrs:       []Node_ID,
		current_loop: Node_ID,
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.cloned_up = make([]Node_ID, graph.gvn * 2)
	ctx.cloned_down = make([]Node_ID, graph.gvn * 2)
	ctx.node_blocks = make(type_of(ctx.node_blocks), graph.gvn * 2)
	bac.schedule_graph(graph, &ctx.sched, .for_loopopt)

	reserve(&ctx.sched.bbs, len(ctx.sched.bbs) * 2)
	ctx.sched.bbs.allocator = {}

	for &bb in ctx.sched.bbs {
		hnode := get_node(ctx.graph, bb.head)
		ctx.node_blocks[hnode.gvn] = &bb
		for instr in bb.instrs {
			if bac.has_flag(ctx.graph, instr, .Is_Basic_Block_Start) {continue}
			inode := get_node(ctx.graph, instr)
			ctx.node_blocks[inode.gvn] = &bb
		}
	}

	rotated := false

	rotate: for &bb, i in ctx.sched.bbs {
		if get_node(ctx, bb.head).rtype == bac.DEAD_NODE_KIND {
			continue
		}

		hnode := bac.expand_node(ctx, bb.head)
		if hnode.itype != .Loop do continue

		bnd := expand_node(ctx, hnode.inps[1])

		// NOTE: this should mean rotation does noting/already rotated
		if bnd.itype == .If do continue
		if len(block_of(ctx, hnode.inps[1]).instrs) == 1 &&
		   (bnd.itype == .Else || bnd.itype == .Then) &&
		   get_node(ctx, bnd.inps[0]).itype == .If &&
		   block_of(ctx, bnd.inps[0]).loop_tree == bb.loop_tree {

			already_latch := false
			for out in bac.get_outputs(ctx, bnd.inps[0]) {
				if get_node(ctx, out.id).itype == .Loop {
					already_latch = true
				}
			}

			if !already_latch {
				bac.subsume(ctx, bnd.inps[0], hnode.inps[1])
				continue
			}
		}

		next_ctrl := bb.instrs[len(bb.instrs) - 1]

		nnode := bac.expand_node(ctx, next_ctrl)
		// TODO: we could do better then this and actually clone calls as well
		if nnode.itype != .If do continue

		then_else_bb: [2]^bac.Basic_Block
		then_else := [?]Node_ID{nnode.outs[0].id, nnode.outs[1].id}
		break_branch: ^bac.Basic_Block
		continue_branch: ^bac.Basic_Block

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

		assert(get_node(ctx, break_branch.head).rtype != bac.DEAD_NODE_KIND)

		cond_is_inverted := then_else_bb[0] == break_branch

		ctx.current_loop = bb.head
		ctx.instrs = bb.instrs[:]

		to_clone: [dynamic]Node_ID
		append(&to_clone, nnode.inps[1])

		#reverse for instr in bb.instrs[:len(bb.instrs) - 1] {
			nd := expand_node(ctx, instr)
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

		guard := bac.add_if(ctx, "urlg", hnode.inps[0], guard_cond)
		ctx.node_blocks[get_node(ctx, guard).gvn] = entry_blk

		guard_loop := bac.add_then(ctx, "urltn", guard)
		wire_up_new_block(&ctx, guard_loop, bb.loop_tree.parent)
		guard_skip := bac.add_else(ctx, "urles", guard)
		wire_up_new_block(&ctx, guard_skip, bb.loop_tree.parent)

		back_cond := clone_by(ctx, nnode.inps[1], 2, exit_blk)

		bac.set_input(ctx, next_ctrl, 1, back_cond)
		ctx.node_blocks[get_node(ctx, next_ctrl).gvn] = exit_blk

		if cond_is_inverted do guard_loop, guard_skip = guard_skip, guard_loop

		bac.set_input(ctx, bb.head, 0, guard_loop)

		join := bac.add_region(
			ctx,
			"urljn",
			{guard_skip, break_branch.head, graph.start},
		)
		join_bb := wire_up_new_block(&ctx, join, bb.loop_tree.parent)

		wire_up_new_block :: proc(
			ctx: ^Ctx,
			node: Node_ID,
			ltree: ^bac.Loop_Tree,
		) -> ^bac.Basic_Block {
			append(
				&ctx.sched.bbs,
				bac.Basic_Block{head = node, loop_tree = ltree},
			)
			join_bb := &ctx.sched.bbs[len(ctx.sched.bbs) - 1]
			ctx.node_blocks[get_node(ctx, node).gvn] = join_bb
			return join_bb
		}

		bouts := bac.get_outputs(ctx, break_branch.head)
		#reverse for out in bouts[:len(bouts) - 1] {
			bac.set_input(ctx, out.id, out.idx, join)
		}

		for instr in break_branch.instrs {
			if !bac.has_flag(ctx, instr, .Is_Basic_Block_Start) {
				ctx.node_blocks[get_node(ctx, instr).gvn] = join_bb
			}
		}

		if !ODIN_DISABLE_ASSERT {
			for &bb in ctx.sched.bbs {
				if get_node(ctx, bb.head).rtype == bac.DEAD_NODE_KIND do continue
				assert(block_of(ctx, bb.head) == &bb)
			}
		}

		hnode = expand_node(ctx, bb.head)

		#reverse for to_clone in to_clone[1:] {
			init := clone_by(ctx, to_clone, 1, entry_blk)
			back := clone_by(ctx, to_clone, 2, exit_blk)

			tcnode := expand_node(ctx, to_clone)
			join_phi := bac.add_phi(ctx, "urlph", tcnode.dt, join, init, back)
			ctx.node_blocks[get_node(ctx, join_phi).gvn] = join_bb

			oouts: []bac.Node_Output = bac.get_outputs(ctx, to_clone)

			#reverse for tcout in oouts {
				tco_blk := block_of(ctx, tcout.id)
				ponode := get_node(ctx, tcout.id)

				if in_loop(bb.loop_tree, tco_blk.loop_tree) {
					continue
				}

				dblk := tco_blk.head
				if ponode.itype == .Phi {
					dblk = bac.get_inputs(ctx, dblk)[tcout.idx - 1]
					if get_node(ctx, dblk).itype == .If {
						dblk = bac.get_inputs(ctx, dblk)[0]
					}
					fmt.assertf(
						bac.has_flag(ctx, dblk, .Is_Basic_Block_Start),
						"%v",
						get_node(ctx, dblk),
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

				bac.set_input(ctx, tcout.id, tcout.idx, res)
			}
		}

		bac.pin(ctx, continue_branch.head)
		couts := bac.get_outputs(ctx, continue_branch.head)
		for out in couts[:len(couts) - 1] {
			bac.set_input(ctx, out.id, out.idx, bb.head)
		}

		bac.set_input(ctx, next_ctrl, 0, hnode.inps[1])
		bac.set_input(ctx, bb.head, 1, next_ctrl)

		bac.unpin(ctx, continue_branch.head)
	}

	optimized |= rotated

	if rotated {
		bac.invalidate_idepth(graph)
		bac.schedule_graph(ctx, &ctx.sched, .for_loopopt)
	}

	if !ODIN_DISABLE_ASSERT {
		bac.schedule_graph(ctx, &ctx.sched, .for_loopopt)
	}

	for &bb in ctx.sched.bbs {
		head := expand_node(ctx, bb.head)
		if head.itype != .Loop do continue

		bedge := expand_node(ctx, head.inps[1])
		if bedge.itype != .If do continue
		if bedge.inps[0] != bb.head do continue

		inverted := bedge.outs[0].id != bb.head
		cond := expand_node(ctx, bedge.inps[1])

		@(rodata, static)
		CMP_OP_REVERSE := #partial [bac.Node_Type]bac.Node_Type {
			.Eq = .Ne,
			.Ne = .Eq,
			.Lt = .Ge,
			.Le = .Gt,
			.Gt = .Le,
			.Ge = .Lt,
		}

		@(rodata, static)
		CMP_OP_FLIP := #partial [bac.Node_Type]bac.Node_Type {
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
			onode := expand_node(ctx, out.id)
			if onode.itype != .Phi do continue

			init := expand_node(ctx, onode.inps[1])
			bvl := expand_node(ctx, onode.inps[2])

			if bvl.itype != .Add do continue
			if bvl.inps[0] != out.id do continue
			if slice.contains(bb.instrs[:], bvl.inps[1]) do continue

			stride := bac.get_extra(ctx, bvl.inps[1], bac.CInt)
			stride_vl: i64
			if stride != nil {
				stride_vl = stride.value
			}

			bound: Node_ID
			slcs := [][]bac.Node_Output{bvl.outs, onode.outs}
			find_bound: for slc in slcs {
				for bout in slc {
					bonode := expand_node(ctx, bout.id)
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
			phy := expand_node(ctx, ind.phy)

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
				onode := expand_node(ctx, out.id)
				if out.id == phy.inps[2] do continue

				stride_node: Node_ID
				if onode.itype == .Mul {
					stride_node = onode.inps[1 - out.idx]
					otnode := expand_node(ctx, stride_node)
					if slice.contains(bb.instrs[:], stride_node) {
						continue
					}

					for oout in onode.outs {
						oonode := expand_node(ctx, oout.id)
						if oonode.itype == .Add {
							out = oout
							onode = oonode
							break
						}
					}
				}

				if onode.itype == .Add {
					base := onode.inps[1 - out.idx]
					otnode := expand_node(ctx, base)

					if slice.contains(bb.instrs[:], base) do continue

					stride: i64
					stride_vl: ^bac.CInt

					if stride_node != 0 {
						stride_vl = bac.get_extra(ctx, stride_node, bac.CInt)
					} else {
						stride_vl = &CInt{value = 1}
					}
					if stride_vl != nil do stride = stride_vl.value

					if stride_vl != nil {
						for otout in onode.outs {
							otonode := expand_node(ctx, otout.id)

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
								bac.get_node_id(ctx, onode),
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
					get_node(ctx, idx.base),
				)
				fmt.assertf(
					!slice.contains(bb.instrs[:], idx.stride),
					"%v",
					get_node(ctx, idx.stride),
				)

				compute_dynamic_index_offset :: proc(
					ctx: ^Proc,
					base, idx, stride: Node_ID,
				) -> Node_ID {
					index := idx

					index = bac.add_bin_op(
						ctx,
						"snoff",
						.Mul,
						.I64,
						index,
						stride,
					)
					index = bac.apply_peep(ctx, index)

					return bac.add_bin_op(ctx, "snd", .Add, .I64, base, index)
				}

				init := compute_dynamic_index_offset(
					ctx,
					idx.base,
					phy.inps[1],
					idx.stride,
				)

				nphy := add_lazy_phi(ctx, "srdph", phy.dt, bb.head, init)
				next := bac.add_bin_op(
					ctx,
					"srdnt",
					.Add,
					phy.dt,
					nphy,
					idx.stride,
				)
				bac.connect(ctx, nphy, next)
				get_node(ctx, nphy).itype = .Phi
				nphy = bac.intern(ctx, nphy)

				bac.subsume(ctx, nphy, idx.to_subsume)

				if ind.bound != 0 && effective_op == .Lt {
					new_bound := compute_dynamic_index_offset(
						ctx,
						idx.base,
						ind.bound,
						idx.stride,
					)
					ncmp := bac.add_bin_op(
						ctx,
						"srdcp",
						Bin_Op(cond.itype),
						.I8,
						next,
						new_bound,
					)
					bac.subsume(ctx, ncmp, bedge.inps[1])
				}
			}

			for store, i in stores {
				snode := expand_node(ctx, store.node)
				vl := expand_node(ctx, snode.inps[3])

				mem := expand_node(ctx, snode.inps[1])
				if mem.itype != .Phi || mem.inps[0] != bb.head do continue

				for out in snode.outs {
					if get_node(ctx, out.id).itype != .Phi &&
					   slice.contains(bb.instrs[:], out.id) {
						// NOTE: the loop has other garbage, we cant decide no yet
						continue
					}
				}

				stride := ind.stride_vl * store.stride

				continuous: if bac.DT_SIZE[vl.dt] == int(stride) &&
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
						size = bac.add_bin_op(
							ctx,
							"lnscl",
							.Mul,
							.I64,
							bac.add_bin_op(
								ctx,
								"ln",
								.Sub,
								.I64,
								ind.bound,
								phy.inps[1],
							),
							bac.add_c_int(ctx, "scl", .I64, store.stride),
						)
						dst = compute_index_offset(
							ctx,
							store.base,
							phy.inps[1],
							stride,
						)
					}

					if can_memset {
						cpy = bac.add_set(
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
						cpy = bac.add_copy(
							graph,
							"mcpf",
							head.inps[0],
							mem.inps[1],
							dst,
							compute_index_offset(
								ctx,
								loads[lidx].base,
								phy.inps[1],
								stride,
							),
							size,
						)
					}

					if cpy != 0 {
						bac.set_input(graph, snode.inps[1], 1, cpy)
						bac.subsume(graph, snode.inps[1], store.node)
						continue
					}
				}
			}
		}

		for ind in inductors {
			phy := expand_node(ctx, ind.phy)
			next := expand_node(ctx, phy.inps[2])
			if len(phy.outs) > 1 do continue
			if len(next.outs) > 1 do continue

			bac.subsume(ctx, phy.inps[1], ind.phy)
		}

		head = expand_node(ctx, bb.head)
		keep := 0
		for instr in bb.instrs {
			if get_node(ctx, instr).rtype != bac.DEAD_NODE_KIND {
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
					inode := expand_node(ctx, instr)
					if inode.inps[0] == bb.head {
						changed |= bit_arr.set(req_sched, i)
						continue
					}
					if bit_arr.contains(req_sched, i) do continue
					for out in inode.outs {
						onode := expand_node(ctx, out.id)
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
				inode := expand_node(ctx, instr)

				if bac.is_cfg(ctx, instr) {
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

			assert(get_node(ctx, head.inps[1]).itype == .If)

			bac.set_input(
				ctx,
				head.inps[1],
				1,
				bac.add_c_int(ctx, "ulfld", .I8, i64(inverted)),
			)

			optimized = true
		}
	}

	return

	block_of :: proc(ctx: Ctx, node: Node_ID) -> (v: ^bac.Basic_Block) {
		defer fmt.assertf(v != nil, "%v %v", get_node(ctx, node), int(node))
		return ctx.node_blocks[get_node(ctx, node).gvn]
	}

	walk_use_blocks :: proc(
		ctx: Ctx,
		root: Node_ID,
		guard: Node_ID,
		out: Node_ID,
		nphy: Node_ID,
		to_loop: ^bac.Loop_Tree,
	) -> Node_ID {
		node := expand_node(ctx, root)
		if root == guard do return nphy

		if in_loop(to_loop, block_of(ctx, root).loop_tree) {
			return out
		}

		loop_or_region := node.itype == .Loop || node.itype == .Region
		edges: [dynamic]Node_ID
		for inp in node.inps[:len(node.inps) - int(loop_or_region)] {
			if bac.is_cfg(ctx, inp) {
				vl := walk_use_blocks(ctx, inp, guard, out, nphy, to_loop)
				append(&edges, vl)
			}
		}

		ref := edges[0]
		for oth in edges[1:] {
			if oth != ref {
				inject_at(&edges, 0, root)
				ref = bac.add_raw(
					ctx,
					"urlj",
					u16(bac.Node_Type.Phi),
					get_node(ctx, ref).dt,
					edges[:],
				)
				break
			}
		}

		return ref
	}

	in_loop :: proc(this: ^bac.Loop_Tree, tested: ^bac.Loop_Tree) -> bool {
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

		PROHIBITED_OPS :: bit_set[bac.Node_Type]{.Copy, .Set, .Store}
		rnode := expand_node(ctx, root)
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
		ctrl: ^bac.Basic_Block,
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

		node := expand_node(ctx, root)
		if cloned[node.gvn] == 0 {
			if node.itype == .Phi && node.inps[0] == ctx.current_loop {
				cloned[node.gvn] = node.inps[phy_idx]
			} else {
				graph := ctx.graph
				PRECISION :: bac.PRECISION

				prev := graph.mem.pos

				inps := make([]Node_ID, len(node.inps))

				for &inp, i in inps {
					inp = clone_by(ctx, node.inps[i], phy_idx, ctrl)
				}

				new_node, id := bac.shallow_clone(graph, node)
				bac.init_counts(graph, new_node)

				new_node.input_idx = u32(graph.mem.pos / bac.PRECISION)
				_ = arna.clone(graph.mem, inps)
				new_node.input_cap = new_node.input_count

				// This should be fine since we kind of reserver memory for
				// dependants, even if we overallocate its a good estimate
				new_node.output_idx = u32(graph.mem.pos / bac.PRECISION)
				_ = arna.alloc(
					graph.mem,
					uint(node.output_cap * bac.PRECISION),
					bac.PRECISION,
				)
				new_node.output_count = 0
				new_node.output_cap = node.output_cap

				interned := bac.intern(graph, id)
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
						bac.add_output(ctx, inp, cloned[node.gvn], i)
					}

					bac.on_node_creation(graph, new_node)
					// NOTE: no need to clone the debug info
				}
			}
		}

		return cloned[node.gvn]
	}
}
