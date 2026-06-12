package backend
// NOTE: this file is generated: odin run meta

graph_idom :: proc{graph_idom_node, graph_idom_node_id}
graph_idom_node_id :: #force_inline proc(graph: ^Graph, id: Node_ID) -> Node_ID {
	return graph_idom_node(graph, graph_get(graph, id))
}
graph_inputs :: proc{graph_inputs_node, graph_inputs_node_id}
graph_inputs_node_id :: #force_inline proc(
	graph: ^Graph,
	id: Node_ID,
) -> []Node_ID {
	return graph_inputs_node(graph, graph_get(graph, id))
}
graph_outputs :: proc{graph_outputs_node, graph_outputs_node_id}
graph_outputs_node_id :: #force_inline proc(
	graph: ^Graph,
	id: Node_ID,
) -> []Node_Output {
	return graph_outputs_node(graph, graph_get(graph, id))
}
graph_add_output :: proc{graph_add_output_node, graph_add_output_node_id}
graph_add_output_node_id :: #force_inline proc(
	graph: ^Graph,
	id: Node_ID,
	out: Node_ID,
	i: int,
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
