extends RefCounted
class_name TileGrid

enum ResourceType { EMPTY, ROCK, TREE, ORE, BERRIES, WATER }

const TILE_ATLAS_COORDS := {
	Vector2i(0, 0): ResourceType.EMPTY,
	Vector2i(1, 0): ResourceType.ROCK,
	Vector2i(2, 0): ResourceType.TREE,
	Vector2i(3, 0): ResourceType.ORE,
	Vector2i(4, 0): ResourceType.BERRIES,
	Vector2i(5, 0): ResourceType.WATER,
}

var ground_layer: TileMapLayer

func _init(layer: TileMapLayer) -> void:
	ground_layer = layer

func is_valid_ground(cell: Vector2i) -> bool:
	return ground_layer.get_cell_source_id(cell) != -1

func get_resource_at(cell: Vector2i) -> ResourceType:
	var atlas_coords := ground_layer.get_cell_atlas_coords(cell)
	if atlas_coords in TILE_ATLAS_COORDS:
		return TILE_ATLAS_COORDS[atlas_coords]
	return ResourceType.EMPTY

func grid_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func is_passable(cell: Vector2i) -> bool:
	var data := ground_layer.get_cell_tile_data(cell)
	if data == null:
		return false
	return data.get_custom_data("passable")

func compute_flood_area(start: Vector2i, points: int, can_traverse: Callable = Callable()) -> Array[Vector2i]:
	var visited := {start: 0}
	var frontier: Array[Vector2i] = [start]
	var directions: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var result: Array[Vector2i] = []

	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		var current_cost: int = visited[current]
		if current_cost >= points:
			continue
		for dir in directions:
			var neighbor := current + dir
			if visited.has(neighbor):
				continue
			if can_traverse.is_valid() and not can_traverse.call(neighbor):
				continue
			visited[neighbor] = current_cost + 1
			frontier.append(neighbor)
			result.append(neighbor)
	return result
