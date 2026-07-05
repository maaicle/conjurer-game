extends Node2D

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var camera: Camera2D = $Camera2D

enum ResourceType { EMPTY, ROCK, TREE, ORE, BERRIES, WATER }

const TILE_ATLAS_COORDS := {
	Vector2i(0, 0): ResourceType.EMPTY,
	Vector2i(1, 0): ResourceType.ROCK,
	Vector2i(2, 0): ResourceType.TREE,
	Vector2i(3, 0): ResourceType.ORE,
	Vector2i(4, 0): ResourceType.BERRIES,
	Vector2i(5, 0): ResourceType.WATER,
}

const BASE_SCENE := preload("res://scenes/Base.tscn")
const AVATAR_SCENE := preload("res://scenes/Avatar.tscn")

var base_placed := false

func _ready() -> void:
	draw_grid_labels()
	fit_camera_to_map()

func draw_grid_labels() -> void:
	var used_rect := ground_layer.get_used_rect()
	var tile_size := ground_layer.tile_set.tile_size

	for x in range(used_rect.position.x, used_rect.end.x):
		var label := Label.new()
		label.text = str(x)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(tile_size.x, 0)
		var world_pos := ground_layer.map_to_local(Vector2i(x, used_rect.end.y))
		label.position = world_pos - Vector2(tile_size.x / 2.0, 14)
		add_child(label)

	for y in range(used_rect.position.y, used_rect.end.y):
		var label := Label.new()
		label.text = str(y)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(0, tile_size.y)
		var world_pos := ground_layer.map_to_local(Vector2i(used_rect.end.x, y))
		label.position = world_pos - Vector2(14, tile_size.y / 2.0)
		add_child(label)

func fit_camera_to_map() -> void:
	var used_rect := ground_layer.get_used_rect()
	var tile_size := ground_layer.tile_set.tile_size
	var map_pixel_size := Vector2(used_rect.size.x * tile_size.x, used_rect.size.y * tile_size.y)
	var viewport_size := get_viewport_rect().size

	var zoom_x := viewport_size.x / map_pixel_size.x
	var zoom_y := viewport_size.y / map_pixel_size.y
	var zoom: float = min(zoom_x, zoom_y) * 0.9  # 0.9 leaves a small margin so edges aren't flush against the window

	camera.zoom = Vector2(zoom, zoom)
	@warning_ignore("integer_division")
	camera.position = ground_layer.map_to_local(used_rect.position + used_rect.size / 2)

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

func _unhandled_input(event: InputEvent) -> void:
	if base_placed:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_global_mouse_position()
		var cell := ground_layer.local_to_map(mouse_pos)
		try_place_base(cell)

func try_place_base(cell: Vector2i) -> void:
	if not is_passable(cell):
		print("Cannot place base — tile is not passable or doesn't exist.")
		return

	var avatar_cell := find_valid_avatar_tile(cell)
	if avatar_cell == Vector2i(-1, -1):
		print("Cannot place base here — no valid adjacent tile for the avatar.")
		return

	var base := BASE_SCENE.instantiate()
	base.position = ground_layer.map_to_local(cell)
	base.grid_position = cell
	add_child(base)

	var avatar := AVATAR_SCENE.instantiate()
	avatar.position = ground_layer.map_to_local(avatar_cell)
	avatar.grid_position = avatar_cell
	add_child(avatar)

	base_placed = true
	print("Base placed at ", cell, ", avatar placed at ", avatar_cell)

func find_valid_avatar_tile(base_cell: Vector2i) -> Vector2i:
	var directions: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for dir in directions:
		var candidate := base_cell + dir
		if is_passable(candidate):
			return candidate
	return Vector2i(-1, -1)
