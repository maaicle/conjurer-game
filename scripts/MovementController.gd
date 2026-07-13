extends RefCounted
class_name MovementController

const MOVE_HIGHLIGHT_TEXTURE := preload("res://assets/move_highlight.png")

var tile_grid: TileGrid
var turn_manager: TurnManager
var base_placement: BasePlacementController
var parent_node: Node
var on_state_changed: Callable

var in_move_mode := false
var reachable_cells: Array[Vector2i] = []
var move_highlight_nodes: Array[Sprite2D] = []

func _init(grid: TileGrid, tm: TurnManager, placement: BasePlacementController, root: Node, state_changed_callback: Callable) -> void:
	tile_grid = grid
	turn_manager = tm
	base_placement = placement
	parent_node = root
	on_state_changed = state_changed_callback

func compute_reachable_tiles(start: Vector2i, points: int) -> Array[Vector2i]:
	var visited := {start: 0}
	var frontier: Array[Vector2i] = [start]
	var directions: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var reachable: Array[Vector2i] = []

	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		var current_cost: int = visited[current]
		if current_cost >= points:
			continue
		for dir in directions:
			var neighbor := current + dir
			if visited.has(neighbor):
				continue
			if not tile_grid.is_passable(neighbor):
				continue
			visited[neighbor] = current_cost + 1
			frontier.append(neighbor)
			if neighbor != base_placement.base_position and turn_manager.get_unit_at(neighbor) == null:
				reachable.append(neighbor)

	return reachable

func enter_move_mode() -> void:
	in_move_mode = false
	reachable_cells = []
	for node in move_highlight_nodes:
		node.queue_free()
	move_highlight_nodes = []

	var selected_unit := turn_manager.selected_unit
	if selected_unit == null or not selected_unit.can_move():
		on_state_changed.call()
		return

	in_move_mode = true
	reachable_cells = compute_reachable_tiles(selected_unit.grid_position, selected_unit.movement_range)
	for cell in reachable_cells:
		var highlight := Sprite2D.new()
		highlight.texture = MOVE_HIGHLIGHT_TEXTURE
		highlight.position = tile_grid.ground_layer.map_to_local(cell)
		parent_node.add_child(highlight)
		move_highlight_nodes.append(highlight)
	on_state_changed.call()

func exit_move_mode() -> void:
	in_move_mode = false
	reachable_cells = []
	for node in move_highlight_nodes:
		node.queue_free()
	move_highlight_nodes = []
	on_state_changed.call()

func perform_move(cell: Vector2i) -> void:
	var selected_unit := turn_manager.selected_unit
	selected_unit.grid_position = cell
	selected_unit.position = tile_grid.ground_layer.map_to_local(cell)
	selected_unit.use_movement()
	exit_move_mode()
