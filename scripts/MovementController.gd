extends RefCounted
class_name MovementController

var tile_grid: TileGrid
var turn_manager: TurnManager
var base_placement: BasePlacementController
var parent_node: Node
var on_state_changed: Callable
var highlighter: GridHighlighter

var in_move_mode := false
var reachable_cells: Array[Vector2i] = []
var move_highlight_nodes: Array[Sprite2D] = []

func _init(grid: TileGrid, tm: TurnManager, placement: BasePlacementController, grid_highlighter: GridHighlighter, root: Node, state_changed_callback: Callable) -> void:
	tile_grid = grid
	turn_manager = tm
	base_placement = placement
	highlighter = grid_highlighter
	parent_node = root
	on_state_changed = state_changed_callback

func compute_reachable_tiles(start: Vector2i, points: int) -> Array[Vector2i]:
	var flood := tile_grid.compute_flood_area(start, points, tile_grid.is_passable)
	var reachable: Array[Vector2i] = []
	for cell in flood:
		if cell != base_placement.base_position and turn_manager.get_unit_at(cell) == null:
			reachable.append(cell)
	return reachable

func enter_move_mode() -> void:
	highlighter.clear(move_highlight_nodes)
	in_move_mode = false
	reachable_cells = []

	var selected_unit := turn_manager.selected_unit
	if selected_unit == null or not selected_unit.can_move():
		on_state_changed.call()
		return

	in_move_mode = true
	reachable_cells = compute_reachable_tiles(selected_unit.grid_position, selected_unit.movement_range)
	for cell in reachable_cells:
		move_highlight_nodes.append(highlighter.create_highlight(cell, Color(0.47, 0.86, 0.55)))
	on_state_changed.call()

func exit_move_mode() -> void:
	highlighter.clear(move_highlight_nodes)
	in_move_mode = false
	reachable_cells = []
	on_state_changed.call()

func perform_move(cell: Vector2i) -> void:
	var selected_unit := turn_manager.selected_unit
	selected_unit.grid_position = cell
	selected_unit.position = tile_grid.ground_layer.map_to_local(cell)
	selected_unit.use_movement()
	exit_move_mode()
