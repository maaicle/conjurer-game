extends RefCounted
class_name GridHighlighter

const GENERIC_HIGHLIGHT_TEXTURE := preload("res://assets/generic_highlight.png")

var ground_layer: TileMapLayer
var parent_node: Node

func _init(layer: TileMapLayer, parent: Node) -> void:
	ground_layer = layer
	parent_node = parent

func create_highlight(cell: Vector2i, color: Color) -> Sprite2D:
	var highlight := Sprite2D.new()
	highlight.texture = GENERIC_HIGHLIGHT_TEXTURE
	highlight.modulate = color
	highlight.position = ground_layer.map_to_local(cell)
	parent_node.add_child(highlight)
	return highlight
