package backend
// NOTE: this file is generated: odin run meta

graph_remove_output :: proc{graph_remove_output_node, graph_remove_output_node_id}
graph_remove_output_node_id :: #force_inline proc(
	graph: ^Graph,
	id: Node_ID,
	out: Node_Output,
	no_delete := false,
) {
	graph_remove_output_node(graph, graph_get(graph, id), out, no_delete)
}
graph_node_hash :: proc{graph_node_hash_node, graph_node_hash_node_id}
graph_node_hash_node_id :: #force_inline proc(graph: ^Graph, id: Node_ID) -> u8 {
	return graph_node_hash_node(graph, graph_get(graph, id))
}
graph_delete :: proc{graph_delete_node, graph_delete_node_id}
graph_delete_node_id :: #force_inline proc(graph: ^Graph, id: Node_ID, indirect := false) {
	graph_delete_node(graph, graph_get(graph, id), indirect)
}
graph_extra_dwords :: proc{graph_extra_dwords_node, graph_extra_dwords_node_id}
graph_extra_dwords_node_id :: #force_inline proc(graph: ^Graph, id: Node_ID) -> []u32 {
	return graph_extra_dwords_node(graph, graph_get(graph, id))
}
graph_inps :: proc{graph_inps_node, graph_inps_node_id}
graph_inps_node_id :: #force_inline proc(
	graph: ^Graph,
	id: Node_ID,
) -> []Node_ID {
	return graph_inps_node(graph, graph_get(graph, id))
}
graph_outs :: proc{graph_outs_node, graph_outs_node_id}
graph_outs_node_id :: #force_inline proc(
	graph: ^Graph,
	id: Node_ID,
) -> []Node_Output {
	return graph_outs_node(graph, graph_get(graph, id))
}
graph_add_input :: proc{graph_add_input_node, graph_add_input_node_id}
graph_add_input_node_id :: #force_inline proc(
	graph: ^Graph,
	id: Node_ID,
	inp: Node_ID,
	max_growth: u16 = 1024,
) -> int {
	return graph_add_input_node(graph, graph_get(graph, id), inp, max_growth)
}
graph_add_extra_input :: proc{graph_add_extra_input_node, graph_add_extra_input_node_id}
graph_add_extra_input_node_id :: #force_inline proc(graph: ^Graph, id: Node_ID, inp: Node_ID) {
	graph_add_extra_input_node(graph, graph_get(graph, id), inp)
}
graph_add_output :: proc{graph_add_output_node, graph_add_output_node_id}
graph_add_output_node_id :: #force_inline proc(
	graph: ^Graph,
	id: Node_ID,
	out: Node_ID,
	#any_int i: int,
) {
	graph_add_output_node(graph, graph_get(graph, id), out, i)
}
graph_get_static_extra :: proc{graph_get_static_extra_node, graph_get_static_extra_node_id}
graph_get_static_extra_node_id :: #force_inline proc(
	graph: ^Graph,
	id: Node_ID,
	$T: typeid,
) -> ^T {
	return graph_get_static_extra_node(graph, graph_get(graph, id), T)
}
graph_get_any_extra :: proc{graph_get_any_extra_node, graph_get_any_extra_node_id}
graph_get_any_extra_node_id :: #force_inline proc(
	graph: ^Graph,
	id: Node_ID,
) -> any {
	return graph_get_any_extra_node(graph, graph_get(graph, id))
}
graph_has_flag :: proc{graph_has_flag_node, graph_has_flag_node_id}
graph_has_flag_node_id :: #force_inline proc(
	graph: ^Graph,
	id: Node_ID,
	flag: Class_Flag,
) -> bool {
	return graph_has_flag_node(graph, graph_get(graph, id), flag)
}
graph_idom :: proc{graph_idom_node, graph_idom_node_id}
graph_idom_node_id :: #force_inline proc(graph: ^Graph, id: Node_ID) -> Node_ID {
	return graph_idom_node(graph, graph_get(graph, id))
}
graph_idepth :: proc{graph_idepth_node, graph_idepth_node_id}
graph_idepth_node_id :: #force_inline proc(graph: ^Graph, id: Node_ID) -> u32 {
	return graph_idepth_node(graph, graph_get(graph, id))
}
