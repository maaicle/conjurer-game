extends Node2D

@onready var ground_layer: TileMapLayer = $GroundLayer

enum ResourceType { EMPTY, ROCK, TREE, ORE }

const TILE_ATLAS_COORDS := {
	Vector2i(0, 0): ResourceType.EMPTY,
	Vector2i(1, 0): ResourceType.ROCK,
	Vector2i(2, 0): ResourceType.TREE,
	Vector2i(3, 0): ResourceType.ORE,
}

const TOWER_SCENE := preload("res://scenes/Tower.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_global_mouse_position()
		var cell := ground_layer.local_to_map(mouse_pos)
		place_tower(cell)

func place_tower(cell: Vector2i) -> void:
	var tower := TOWER_SCENE.instantiate()
	tower.position = ground_layer.map_to_local(cell)
	tower.grid_position = cell
	add_child(tower)
	
	var found := scan_proximity(cell, 1)
	var stats := compute_stats(found)
	print("Tower at ", cell, " stats: ", stats)
	
func get_resource_at(cell: Vector2i) -> ResourceType:
	var atlas_coords := ground_layer.get_cell_atlas_coords(cell)
	if atlas_coords in TILE_ATLAS_COORDS:
		return TILE_ATLAS_COORDS[atlas_coords]
	return ResourceType.EMPTY
	
func scan_proximity(center: Vector2i, radius: int) -> Dictionary:
	var found := {
		ResourceType.ROCK: false,
		ResourceType.TREE: false,
		ResourceType.ORE: false,
	}
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var cell := center + Vector2i(x, y)
			var resource := get_resource_at(cell)
			if resource != ResourceType.EMPTY:
				found[resource] = true
	return found
	
func compute_stats(found: Dictionary) -> Dictionary:
	var stats := {"armor": 1, "damage": 1, "range": 1}
	if found[ResourceType.ROCK]:
		stats["armor"] = 3
	if found[ResourceType.TREE]:
		stats["range"] = 3
	if found[ResourceType.ORE]:
		stats["damage"] = 3
	return stats
