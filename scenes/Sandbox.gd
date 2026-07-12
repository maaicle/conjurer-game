extends Node2D

#Declarations-------------------------------------------

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
const SOLDIER_SCENE := preload("res://scenes/Soldier.tscn")
const MOVE_HIGHLIGHT_TEXTURE := preload("res://assets/move_highlight.png")
const GENERIC_HIGHLIGHT_TEXTURE := preload("res://assets/generic_highlight.png")


var base_placed := false
var selected_unit: Unit = null
var turn_number: int = 1
var base_position: Vector2i
var in_move_mode := false
var reachable_cells: Array[Vector2i] = []
var move_highlight_nodes: Array[Sprite2D] = []
var in_spawn_mode := false
var spawn_valid_cells: Array[Vector2i] = []
var spawn_highlight_nodes: Array[Sprite2D] = []
var in_consume_mode := false
var consume_valid_cells: Array[Vector2i] = []
var consume_highlight_nodes: Array[Sprite2D] = []
var pending_soldier: Soldier = null
var current_base: Base = null
var in_avatar_placement_mode := false
var avatar_valid_cells: Array[Vector2i] = []
var avatar_highlight_nodes: Array[Sprite2D] = []

#Scene setup ----------------------------------------------------

func _ready() -> void:
	draw_grid_labels()
	fit_camera_to_map()
	update_toolbar()

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

#Map functions ----------------------------------------------------

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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if not (in_spawn_mode or in_consume_mode or in_avatar_placement_mode):
			_on_skip_button_pressed()
		return

	if not (event is InputEventMouseButton and event.pressed):
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if in_consume_mode:
			exit_consume_mode(true)
		elif in_spawn_mode:
			exit_spawn_mode()
		elif in_avatar_placement_mode:
			cancel_base_placement()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var mouse_pos := get_global_mouse_position()
	var cell := ground_layer.local_to_map(mouse_pos)

	if in_avatar_placement_mode:
		if cell in avatar_valid_cells:
			place_avatar(cell)
		return

	if not base_placed:
		try_place_base(cell)
		return

	if in_consume_mode:
		if cell in consume_valid_cells:
			consume_resource(cell)
		return

	if in_spawn_mode:
		if cell in spawn_valid_cells:
			place_soldier(cell)
		return

	if in_move_mode and cell in reachable_cells:
		perform_move(cell)
		return

	try_select_unit_at(cell)

#Base placement -----------------------------------------------------

func try_place_base(cell: Vector2i) -> void:
	if not is_passable(cell):
		print("Cannot place base — tile is not passable or doesn't exist.")
		return

	var base: Base = BASE_SCENE.instantiate()
	base.position = ground_layer.map_to_local(cell)
	base.grid_position = cell
	add_child(base)
	current_base = base
	base_position = cell

	avatar_valid_cells = compute_avatar_area(cell)
	if avatar_valid_cells.is_empty():
		print("Cannot place base here — no valid tile for the avatar.")
		remove_child(base)
		base.queue_free()
		current_base = null
		return

	enter_avatar_placement_mode()

func compute_avatar_area(base_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in compute_flood_area(base_cell, 1):
		if is_passable(cell):
			cells.append(cell)
	return cells

func find_valid_avatar_tile(base_cell: Vector2i) -> Vector2i:
	var directions: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for dir in directions:
		var candidate := base_cell + dir
		if is_passable(candidate):
			return candidate
	return Vector2i(-1, -1)

func enter_avatar_placement_mode() -> void:
	in_avatar_placement_mode = true
	for cell in avatar_valid_cells:
		avatar_highlight_nodes.append(create_highlight(cell, Color(0.6, 0.4, 1.0)))
	update_toolbar()

func exit_avatar_placement_mode() -> void:
	in_avatar_placement_mode = false
	avatar_valid_cells = []
	for node in avatar_highlight_nodes:
		node.queue_free()
	avatar_highlight_nodes = []
	update_toolbar()

func cancel_base_placement() -> void:
	exit_avatar_placement_mode()
	remove_child(current_base)
	current_base.queue_free()
	current_base = null

func place_avatar(cell: Vector2i) -> void:
	var avatar: Avatar = AVATAR_SCENE.instantiate()
	avatar.position = ground_layer.map_to_local(cell)
	avatar.grid_position = cell
	add_child(avatar)

	exit_avatar_placement_mode()
	base_placed = true
	print("Base placed at ", base_position, ", avatar placed at ", cell)
	begin_turn_planning()
	
#Unit Selection Tracking -------------------------------------------

func begin_turn_planning() -> void:
	print("Turn ", turn_number, " begins. Entering planning mode.")
	auto_select_unit()

func auto_select_unit() -> void:
	for unit in get_children():
		if unit is Unit and unit.turn_state == Unit.TurnState.READY:
			select_unit(unit)
			return
	if selected_unit != null and is_instance_valid(selected_unit):
		selected_unit.set_selected(false)
	selected_unit = null
	print("  No units available to auto-select.")
	update_toolbar()

func get_unit_at(cell: Vector2i) -> Unit:
	for unit in get_children():
		if unit is Unit and unit.grid_position == cell:
			return unit
	return null

func select_unit(unit: Unit) -> void:
	if selected_unit != null and is_instance_valid(selected_unit):
		selected_unit.set_selected(false)
	if in_move_mode:
		exit_move_mode()
	selected_unit = unit
	selected_unit.set_selected(true)
	print("Selected unit at ", unit.grid_position)
	enter_move_mode()
	update_toolbar()

func try_select_unit_at(cell: Vector2i) -> bool:
	var clicked_unit := get_unit_at(cell)
	if clicked_unit != null:
		select_unit(clicked_unit)
		return true
	return false

#Toolbar Update------------------------------------------------------
func update_toolbar() -> void:

	var skip_btn: Button = $UI/Toolbar/HBox/SkipButton
	var end_turn_btn: Button = $UI/Toolbar/HBox/EndTurnButton
	var next_unit_btn: Button = $UI/Toolbar/HBox/NextUnitButton

	if selected_unit == null:
		skip_btn.disabled = true
		end_turn_btn.disabled = true
		next_unit_btn.disabled = true
		clear_action_buttons()
		return
		
	var mode_active := in_spawn_mode or in_consume_mode or in_avatar_placement_mode
	if mode_active:
		skip_btn.disabled = true
		end_turn_btn.disabled = true
		next_unit_btn.disabled = true
		for child in $UI/Toolbar/HBox/ActionButtons.get_children():
			if child is Button:
				child.disabled = true
		return

	skip_btn.disabled = selected_unit.turn_state != Unit.TurnState.READY
	end_turn_btn.disabled = not all_units_finished()
	next_unit_btn.disabled = all_units_finished()


	clear_action_buttons()
	for action_name in selected_unit.get_available_actions():
		var btn := Button.new()
		btn.text = action_name
		btn.disabled = not selected_unit.can_act()
		btn.pressed.connect(_on_action_button_pressed.bind(action_name))
		$UI/Toolbar/HBox/ActionButtons.add_child(btn)

func clear_action_buttons() -> void:
	for child in $UI/Toolbar/HBox/ActionButtons.get_children():
		child.queue_free()
		
#Button functions-----------------------------------------------

func _on_skip_button_pressed() -> void:
	if selected_unit == null:
		return
	selected_unit.skip()
	print("Unit at ", selected_unit.grid_position, " is now waiting")
	exit_move_mode()
	update_toolbar()

func _on_action_button_pressed(action_name: String) -> void:
	if action_name == "Spawn Soldier":
		enter_spawn_mode()

func _on_end_turn_button_pressed() -> void:
	end_turn()
	update_toolbar()

func _on_next_unit_button_pressed() -> void:
	select_next_unit()


#Unit movement---------------------------------------------------

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
			if not is_passable(neighbor):
				continue
			visited[neighbor] = current_cost + 1
			frontier.append(neighbor)
			if neighbor != base_position and get_unit_at(neighbor) == null:
				reachable.append(neighbor)

	return reachable

func enter_move_mode() -> void:
	in_move_mode = false
	reachable_cells = []
	for node in move_highlight_nodes:
		node.queue_free()
	move_highlight_nodes = []

	if selected_unit == null or not selected_unit.can_move():
		update_toolbar()
		return

	in_move_mode = true
	reachable_cells = compute_reachable_tiles(selected_unit.grid_position, selected_unit.movement_range)
	for cell in reachable_cells:
		var highlight := Sprite2D.new()
		highlight.texture = MOVE_HIGHLIGHT_TEXTURE
		highlight.position = ground_layer.map_to_local(cell)
		add_child(highlight)
		move_highlight_nodes.append(highlight)
	update_toolbar()

func exit_move_mode() -> void:
	in_move_mode = false
	reachable_cells = []
	for node in move_highlight_nodes:
		node.queue_free()
	move_highlight_nodes = []
	update_toolbar()
	
func perform_move(cell: Vector2i) -> void:
	selected_unit.grid_position = cell
	selected_unit.position = ground_layer.map_to_local(cell)
	selected_unit.use_movement()
	exit_move_mode()
	update_toolbar()

#End Turn----------------------------------------------------------

func all_units_finished() -> bool:
	for unit in get_children():
		if unit is Unit and unit.turn_state == Unit.TurnState.READY:
			return false
	return true

func end_turn() -> void:
	print("--- End of turn ", turn_number, " ---")
	for unit in get_children():
		if unit is Unit:
			unit.reset_for_new_turn()
	turn_number += 1
	begin_turn_planning()

#Flood Area--------------------------------------------------------
func compute_flood_area(start: Vector2i, points: int) -> Array[Vector2i]:
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
			visited[neighbor] = current_cost + 1
			frontier.append(neighbor)
			result.append(neighbor)
	return result

func compute_spawn_area(center: Vector2i, range_points: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in compute_flood_area(center, range_points):
		if not is_passable(cell):
			continue
		if cell == base_position:
			continue
		if get_unit_at(cell) != null:
			continue
		cells.append(cell)
	return cells

func compute_resource_area(center: Vector2i, range_points: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if get_resource_at(center) != ResourceType.EMPTY:
		cells.append(center)
	for cell in compute_flood_area(center, range_points):
		if get_resource_at(cell) != ResourceType.EMPTY:
			cells.append(cell)
	return cells

#Consume Mode----------------------------------------------------------------
func enter_consume_mode() -> void:
	in_consume_mode = true
	consume_valid_cells = compute_resource_area(pending_soldier.grid_position, pending_soldier.collection_range)
	for cell in consume_valid_cells:
		consume_highlight_nodes.append(create_highlight(cell, Color(1.0, 0.65, 0.2)))
	update_toolbar()

func exit_consume_mode(cancelled: bool) -> void:
	in_consume_mode = false
	consume_valid_cells = []
	for node in consume_highlight_nodes:
		node.queue_free()
	consume_highlight_nodes = []
	if cancelled:
		remove_child(pending_soldier)
		pending_soldier.queue_free()
		pending_soldier = null
		enter_spawn_mode()
	else:
		enter_move_mode()
	update_toolbar()

func consume_resource(cell: Vector2i) -> void:
	var resource := get_resource_at(cell)
	apply_resource_bonus(pending_soldier, resource)
	ground_layer.set_cell(cell, 0, Vector2i(0, 0))
	print("Soldier gained bonus from ", ResourceType.keys()[resource])
	pending_soldier = null
	selected_unit.use_action()
	exit_consume_mode(false)
	update_toolbar()

func apply_resource_bonus(soldier: Soldier, resource: ResourceType) -> void:
	match resource:
		ResourceType.ROCK:
			soldier.armor += 1
		ResourceType.TREE:
			soldier.range_stat += 1
		ResourceType.ORE:
			soldier.damage += 1
		ResourceType.BERRIES:
			soldier.movement_range += 1
		ResourceType.WATER:
			soldier.armor_regen += 1

#Spawn Mode---------------------------------------------------------------------
func enter_spawn_mode() -> void:
	exit_move_mode()
	if selected_unit == null or not selected_unit.can_act():
		return
	in_spawn_mode = true
	spawn_valid_cells = compute_spawn_area(selected_unit.grid_position, selected_unit.action_range)
	for cell in spawn_valid_cells:
		spawn_highlight_nodes.append(create_highlight(cell, Color(0.4, 0.6, 1.0)))
	update_toolbar()

func place_soldier(cell: Vector2i) -> void:
	var soldier: Soldier = SOLDIER_SCENE.instantiate()
	soldier.grid_position = cell
	soldier.position = ground_layer.map_to_local(cell)
	soldier.turn_state = Unit.TurnState.DONE
	soldier.has_moved = true
	soldier.has_acted = true
	add_child(soldier)
	pending_soldier = soldier

	clear_spawn_highlights()
	enter_consume_mode()

func clear_spawn_highlights() -> void:
	in_spawn_mode = false
	spawn_valid_cells = []
	for node in spawn_highlight_nodes:
		node.queue_free()
	spawn_highlight_nodes = []

func exit_spawn_mode() -> void:
	clear_spawn_highlights()
	enter_move_mode()
	update_toolbar()

func create_highlight(cell: Vector2i, color: Color) -> Sprite2D:
	var highlight := Sprite2D.new()
	highlight.texture = GENERIC_HIGHLIGHT_TEXTURE
	highlight.modulate = color
	highlight.position = ground_layer.map_to_local(cell)
	add_child(highlight)
	return highlight

#Next Unit----------------------------------------------------------------------
func select_next_unit() -> void:
	var units: Array[Unit] = []
	for child in get_children():
		if child is Unit:
			units.append(child)
	if units.is_empty():
		return

	var start_index := units.find(selected_unit)
	if start_index == -1:
		start_index = 0

	for i in range(1, units.size() + 1):
		var idx := (start_index + i) % units.size()
		if units[idx].turn_state == Unit.TurnState.READY:
			select_unit(units[idx])
			return
