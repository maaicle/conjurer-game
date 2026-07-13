extends RefCounted
class_name NodeUtils

static func free_node(parent: Node, node: Node) -> void:
	parent.remove_child(node)
	node.queue_free()
