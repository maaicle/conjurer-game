extends RefCounted
class_name SpawnController

signal state_changed
signal spawn_started
signal action_completed

const SOLDIER_SCENE := preload("res://scenes/Soldier.tscn")

var tile_grid: TileGrid
var turn_manager: TurnManager
var base_placement: BasePlacementController
var highlighter: GridHighlighter
var parent_node: Node

var in_spawn_mode := false
var spawn_valid_cells: Array[Vector2i] = []
var spawn_highlight_nodes: Array[Sprite2D] = []

var in_consume_mode := false
var consume_valid_cells: Array[Vector2i] = []
var consume_highlight_nodes: Array[Sprite2D] = []
var pending_soldier: Soldier = null

const RESOURCE_BONUSES := {
	TileGrid.ResourceType.ROCK: {"stat": "armor", "amount": 1},
	TileGrid.ResourceType.TREE: {"stat": "attack_range", "amount": 1},
	TileGrid.ResourceType.ORE: {"stat": "damage", "amount": 1},
	TileGrid.ResourceType.BERRIES: {"stat": "movement_range", "amount": 1},
	TileGrid.ResourceType.WATER: {"stat": "armor_regen", "amount": 1},
}

func _init(grid: TileGrid, tm: TurnManager, placement: BasePlacementController, grid_highlighter: GridHighlighter, root: Node) -> void:
	tile_grid = grid
	turn_manager = tm
	base_placement = placement
	highlighter = grid_highlighter
	parent_node = root

func compute_spawn_area(center: Vector2i, range_points: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in tile_grid.compute_flood_area(center, range_points):
		if not tile_grid.is_passable(cell):
			continue
		if cell == base_placement.base_position:
			continue
		if turn_manager.get_unit_at(cell) != null:
			continue
		cells.append(cell)
	return cells

func compute_resource_area(center: Vector2i, range_points: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if tile_grid.get_resource_at(center) != TileGrid.ResourceType.EMPTY:
		cells.append(center)
	for cell in tile_grid.compute_flood_area(center, range_points):
		if tile_grid.get_resource_at(cell) != TileGrid.ResourceType.EMPTY:
			cells.append(cell)
	return cells

func enter_spawn_mode() -> void:
	spawn_started.emit() # ensures move mode is cleared first
	var selected_unit := turn_manager.selected_unit
	if selected_unit == null or not selected_unit.can_act():
		return
	in_spawn_mode = true
	spawn_valid_cells = compute_spawn_area(selected_unit.grid_position, selected_unit.action_range)
	for cell in spawn_valid_cells:
		spawn_highlight_nodes.append(highlighter.create_highlight(cell, Color(0.4, 0.6, 1.0)))
	state_changed.emit()

func place_soldier(cell: Vector2i) -> void:
	var soldier: Soldier = SOLDIER_SCENE.instantiate()
	soldier.grid_position = cell
	soldier.position = tile_grid.ground_layer.map_to_local(cell)
	soldier.turn_state = Unit.TurnState.DONE
	soldier.has_moved = true
	soldier.has_acted = true
	parent_node.add_child(soldier)
	pending_soldier = soldier

	clear_spawn_highlights()
	enter_consume_mode()

func clear_spawn_highlights() -> void:
	in_spawn_mode = false
	spawn_valid_cells = []
	highlighter.clear(spawn_highlight_nodes)
	spawn_highlight_nodes = []

func exit_spawn_mode() -> void:
	clear_spawn_highlights()
	action_completed.emit()
	state_changed.emit()

func enter_consume_mode() -> void:
	in_consume_mode = true
	consume_valid_cells = compute_resource_area(pending_soldier.grid_position, pending_soldier.collection_range)
	for cell in consume_valid_cells:
		consume_highlight_nodes.append(highlighter.create_highlight(cell, Color(1.0, 0.65, 0.2)))
	state_changed.emit()

func exit_consume_mode(cancelled: bool) -> void:
	in_consume_mode = false
	consume_valid_cells = []
	highlighter.clear(consume_highlight_nodes)
	consume_highlight_nodes = []
	if cancelled:
		NodeUtils.free_node(parent_node, pending_soldier)
		pending_soldier = null
		enter_spawn_mode()
	else:
		action_completed.emit()
	state_changed.emit()

func consume_resource(cell: Vector2i) -> void:
	var resource := tile_grid.get_resource_at(cell)
	apply_resource_bonus(pending_soldier, resource)
	tile_grid.ground_layer.set_cell(cell, 0, Vector2i(0, 0))
	print("Soldier gained bonus from ", TileGrid.ResourceType.keys()[resource])
	pending_soldier = null
	turn_manager.selected_unit.use_action()
	exit_consume_mode(false)

func apply_resource_bonus(soldier: Soldier, resource: TileGrid.ResourceType) -> void:
	if not RESOURCE_BONUSES.has(resource):
		return
	var bonus: Dictionary = RESOURCE_BONUSES[resource]
	var stat_name: String = bonus["stat"]
	var amount: int = bonus["amount"]
	soldier.set(stat_name, soldier.get(stat_name) + amount)
