extends RefCounted
class_name BasePlacementController

const BASE_SCENE := preload("res://scenes/Base.tscn")
const AVATAR_SCENE := preload("res://scenes/Avatar.tscn")

var tile_grid: TileGrid
var highlighter: GridHighlighter
var parent_node: Node
var on_avatar_placed: Callable
var on_state_changed: Callable

var base_placed := false
var base_position: Vector2i
var current_base: Base = null

var in_avatar_placement_mode := false
var avatar_valid_cells: Array[Vector2i] = []
var avatar_highlight_nodes: Array[Sprite2D] = []

func _init(grid: TileGrid, grid_highlighter: GridHighlighter, root: Node, avatar_placed_callback: Callable, state_changed_callback: Callable) -> void:
	tile_grid = grid
	highlighter = grid_highlighter
	parent_node = root
	on_avatar_placed = avatar_placed_callback
	on_state_changed = state_changed_callback

func try_place_base(cell: Vector2i) -> void:
	if not tile_grid.is_passable(cell):
		print("Cannot place base — tile is not passable or doesn't exist.")
		return

	var base: Base = BASE_SCENE.instantiate()
	base.position = tile_grid.ground_layer.map_to_local(cell)
	base.grid_position = cell
	parent_node.add_child(base)
	current_base = base
	base_position = cell

	avatar_valid_cells = compute_avatar_area(cell)
	if avatar_valid_cells.is_empty():
		print("Cannot place base here — no valid tile for the avatar.")
		parent_node.remove_child(base)
		base.queue_free()
		current_base = null
		return

	enter_avatar_placement_mode()

func compute_avatar_area(base_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in tile_grid.compute_flood_area(base_cell, 1):
		if tile_grid.is_passable(cell):
			cells.append(cell)
	return cells

func enter_avatar_placement_mode() -> void:
	in_avatar_placement_mode = true
	for cell in avatar_valid_cells:
		avatar_highlight_nodes.append(highlighter.create_highlight(cell, Color(0.6, 0.4, 1.0)))
	on_state_changed.call()

func exit_avatar_placement_mode() -> void:
	in_avatar_placement_mode = false
	avatar_valid_cells = []
	for node in avatar_highlight_nodes:
		node.queue_free()
	avatar_highlight_nodes = []
	on_state_changed.call()

func cancel_base_placement() -> void:
	exit_avatar_placement_mode()
	parent_node.remove_child(current_base)
	current_base.queue_free()
	current_base = null

func place_avatar(cell: Vector2i) -> void:
	var avatar: Avatar = AVATAR_SCENE.instantiate()
	avatar.position = tile_grid.ground_layer.map_to_local(cell)
	avatar.grid_position = cell
	parent_node.add_child(avatar)

	exit_avatar_placement_mode()
	base_placed = true
	print("Base placed at ", base_position, ", avatar placed at ", cell)
	on_avatar_placed.call()
