extends Node2D

#Declarations-------------------------------------------

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var camera: Camera2D = $Camera2D

var tile_grid: TileGrid
var toolbar_ui: ToolbarUI
var turn_manager: TurnManager
var grid_highlighter: GridHighlighter
var base_placement: BasePlacementController
var movement: MovementController
var spawn_controller: SpawnController

#Scene setup ----------------------------------------------------

func _ready() -> void:
	tile_grid = TileGrid.new(ground_layer)
	toolbar_ui = ToolbarUI.new($UI/Toolbar, _on_action_button_pressed)
	turn_manager = TurnManager.new(self, _on_unit_selection_changed)
	grid_highlighter = GridHighlighter.new(ground_layer, self)
	base_placement = BasePlacementController.new(tile_grid, grid_highlighter, self, _on_avatar_placed, update_toolbar)
	movement = MovementController.new(tile_grid, turn_manager, base_placement,grid_highlighter, self, update_toolbar)
	spawn_controller = SpawnController.new(tile_grid, turn_manager, base_placement, grid_highlighter, self, update_toolbar, movement.exit_move_mode, movement.enter_move_mode)
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if not (spawn_controller.in_spawn_mode or spawn_controller.in_consume_mode or base_placement.in_avatar_placement_mode):
			_on_skip_button_pressed()
		return

	if not (event is InputEventMouseButton and event.pressed):
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if spawn_controller.in_consume_mode:
			spawn_controller.exit_consume_mode(true)
		elif spawn_controller.in_spawn_mode:
			spawn_controller.exit_spawn_mode()
		elif base_placement.in_avatar_placement_mode:
			base_placement.cancel_base_placement()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var mouse_pos := get_global_mouse_position()
	var cell := ground_layer.local_to_map(mouse_pos)

	if base_placement.in_avatar_placement_mode:
		if cell in base_placement.avatar_valid_cells:
			base_placement.place_avatar(cell)
		return

	if not base_placement.base_placed:
		base_placement.try_place_base(cell)
		return

	if spawn_controller.in_consume_mode:
		if cell in spawn_controller.consume_valid_cells:
			spawn_controller.consume_resource(cell)
		return

	if spawn_controller.in_spawn_mode:
		if cell in spawn_controller.spawn_valid_cells:
			spawn_controller.place_soldier(cell)
		return

	if movement.in_move_mode and cell in movement.reachable_cells:
		movement.perform_move(cell)
		return

	turn_manager.try_select_unit_at(cell)

#Base placement -----------------------------------------------------

func _on_avatar_placed() -> void:
	turn_manager.begin_turn_planning()

#Unit Selection Tracking -------------------------------------------

func _on_unit_selection_changed() -> void:
	movement.enter_move_mode()

#Toolbar Update------------------------------------------------------

func update_toolbar() -> void:
	var mode_active := spawn_controller.in_spawn_mode or spawn_controller.in_consume_mode or base_placement.in_avatar_placement_mode
	toolbar_ui.update(turn_manager.selected_unit, mode_active, turn_manager.all_units_finished())

#Button functions-----------------------------------------------

func _on_skip_button_pressed() -> void:
	if turn_manager.selected_unit == null:
		return
	turn_manager.selected_unit.skip()
	print("Unit at ", turn_manager.selected_unit.grid_position, " is now waiting")
	movement.exit_move_mode()
	update_toolbar()

func _on_action_button_pressed(action_name: String) -> void:
	if action_name == "Spawn Soldier":
		spawn_controller.enter_spawn_mode()

func _on_end_turn_button_pressed() -> void:
	turn_manager.end_turn()
	update_toolbar()

func _on_next_unit_button_pressed() -> void:
	turn_manager.select_next_unit()
