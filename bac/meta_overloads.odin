package bac
// NOTE: this file is generated: odin run meta

remove_output :: proc{remove_output_node, remove_output_node_id}
remove_output_node_id :: #force_inline proc(
	graph: ^Proc,
	id: Node_ID,
	out: Node_Output,
	no_delete := false,
) {
	remove_output_node(graph, get_node(graph, id), out, no_delete)
}
node_hash :: proc{node_hash_node, node_hash_node_id}
node_hash_node_id :: #force_inline proc(graph: ^Proc, id: Node_ID) -> u8 {
	return node_hash_node(graph, get_node(graph, id))
}
delete_node :: proc{delete_node_node, delete_node_node_id}
delete_node_node_id :: #force_inline proc(graph: ^Proc, id: Node_ID, indirect := false) {
	delete_node_node(graph, get_node(graph, id), indirect)
}
get_extra_dwords :: proc{get_extra_dwords_node, get_extra_dwords_node_id}
get_extra_dwords_node_id :: #force_inline proc(
	graph: ^Proc,
	id: Node_ID,
	consider_dbg := false,
) -> []u32 {
	return get_extra_dwords_node(graph, get_node(graph, id), consider_dbg)
}
get_inputs :: proc{get_inputs_node, get_inputs_node_id}
get_inputs_node_id :: #force_inline proc(graph: ^Proc, id: Node_ID) -> []Node_ID {
	return get_inputs_node(graph, get_node(graph, id))
}
get_outputs :: proc{get_outputs_node, get_outputs_node_id}
get_outputs_node_id :: #force_inline proc(
	graph: ^Proc,
	id: Node_ID,
) -> []Node_Output {
	return get_outputs_node(graph, get_node(graph, id))
}
add_input :: proc{add_input_node, add_input_node_id}
add_input_node_id :: #force_inline proc(graph: ^Proc, id: Node_ID, inp: Node_ID) -> int {
	return add_input_node(graph, get_node(graph, id), inp)
}
add_output :: proc{add_output_node, add_output_node_id}
add_output_node_id :: #force_inline proc(
	graph: ^Proc,
	id: Node_ID,
	out: Node_ID,
	#any_int i: int,
) {
	add_output_node(graph, get_node(graph, id), out, i)
}
get_static_extra :: proc{get_static_extra_node, get_static_extra_node_id}
get_static_extra_node_id :: #force_inline proc(
	graph: ^Proc,
	id: Node_ID,
	$T: typeid,
) -> ^T {
	return get_static_extra_node(graph, get_node(graph, id), T)
}
get_any_extra :: proc{get_any_extra_node, get_any_extra_node_id}
get_any_extra_node_id :: #force_inline proc(graph: ^Proc, id: Node_ID) -> any {
	return get_any_extra_node(graph, get_node(graph, id))
}
has_flag :: proc{has_flag_node, has_flag_node_id}
has_flag_node_id :: #force_inline proc(
	graph: ^Proc,
	id: Node_ID,
	flag: Class_Flag,
) -> bool {
	return has_flag_node(graph, get_node(graph, id), flag)
}
get_idom :: proc{get_idom_node, get_idom_node_id}
get_idom_node_id :: #force_inline proc(graph: ^Proc, id: Node_ID) -> Node_ID {
	return get_idom_node(graph, get_node(graph, id))
}
get_idepth :: proc{get_idepth_node, get_idepth_node_id}
get_idepth_node_id :: #force_inline proc(graph: ^Proc, id: Node_ID) -> u32 {
	return get_idepth_node(graph, get_node(graph, id))
}
