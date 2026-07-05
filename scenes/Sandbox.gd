extends Node2D

@onready var ground_layer: TileMapLayer = $GroundLayer

enum ResourceType { EMPTY, ROCK, TREE, ORE }
enum Phase { PLACEMENT, ATTACK, ACTIVATION }

const TILE_ATLAS_COORDS := {
	Vector2i(0, 0): ResourceType.EMPTY,
	Vector2i(1, 0): ResourceType.ROCK,
	Vector2i(2, 0): ResourceType.TREE,
	Vector2i(3, 0): ResourceType.ORE,
}
const TOWER_SCENE := preload("res://scenes/Tower.tscn")

var player_scores := {1: 0, 2: 0}
var current_phase: Phase = Phase.PLACEMENT
var attack_queue: Array[Tower] = []
var current_player: int = 1
var turn_number: int = 1
var current_attacker: Tower = null
var current_targets: Array[Tower] = []

func _ready() -> void:
	print("[Phase] PLACEMENT — Player ", current_player)
	draw_grid_labels()
	update_score_ui()
	
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

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
		
	if current_phase == Phase.PLACEMENT:
		var mouse_pos := get_global_mouse_position()
		var cell := ground_layer.local_to_map(mouse_pos)
		if is_valid_ground(cell):
			place_tower(cell)
	elif current_phase == Phase.ATTACK and current_attacker != null:
		var mouse_pos := get_global_mouse_position()
		var clicked_cell := ground_layer.local_to_map(mouse_pos)
		for t in current_targets:
			if is_instance_valid(t) and t.grid_position == clicked_cell:
				resolve_attack(t)
				return
				
func is_valid_ground(cell: Vector2i) -> bool:
	return ground_layer.get_cell_source_id(cell) != -1

func place_tower(cell: Vector2i) -> void:
	var tower := TOWER_SCENE.instantiate()
	tower.position = ground_layer.map_to_local(cell)
	tower.grid_position = cell
	tower.owner_id = current_player
	tower.owner_id = current_player
	tower.apply_owner_color()

	var counts := scan_proximity(cell, 1)
	var stats := compute_stats(counts)
	tower.armor = stats["armor"]
	tower.damage = stats["damage"]
	tower.range_stat = stats["range"]

	add_child(tower)
	print("Player ", current_player, " placed tower at ", cell, " — armor:", tower.armor, " damage:", tower.damage, " range:", tower.range_stat)

	start_attack_phase()

func start_attack_phase() -> void:
	current_phase = Phase.ATTACK
	print("[Phase] ATTACK — Player ", current_player)

	attack_queue.clear()
	for tower in get_children():
		if tower is Tower and tower.owner_id == current_player and tower.state == Tower.TowerState.ACTIVE:
			attack_queue.append(tower)

	print("  Attack queue: ", attack_queue.size(), " tower(s)")
	process_next_attacker()
	
func process_next_attacker() -> void:
	if attack_queue.is_empty():
		print("  Attack phase complete")
		current_attacker = null
		current_targets = []
		start_activation_phase()
		return

	current_attacker = attack_queue.pop_front()
	current_targets = find_targets_in_range(current_attacker)

	current_attacker.set_highlight(Color.YELLOW)
	for t in current_targets:
		t.set_highlight(Color.RED)

	print("  Tower at ", current_attacker.grid_position, " is up — ", current_targets.size(), " target(s) in range")
	print("  Click a highlighted target, or press Skip/Rest.")
	# Execution pauses here — waiting for input. No more self-call.
	
func find_targets_in_range(attacker: Tower) -> Array[Tower]:
	var targets: Array[Tower] = []
	for tower in get_children():
		if tower is Tower and tower.owner_id != attacker.owner_id and tower.state == Tower.TowerState.ACTIVE:
			var distance := grid_distance(attacker.grid_position, tower.grid_position)
			if distance <= attacker.range_stat:
				targets.append(tower)
	return targets
	
func resolve_attack(target: Tower) -> void:
	print("  Tower at ", current_attacker.grid_position, " attacks tower at ", target.grid_position, " for ", current_attacker.damage, " damage")
	target.armor -= current_attacker.damage
	print("    Target armor now: ", target.armor)

	if target.armor <= 0:
		print("    Tower at ", target.grid_position, " destroyed!")
		player_scores[current_attacker.owner_id] += 1
		remove_child(target)
		target.queue_free()
	
	update_score_ui()
	check_win_condition(current_player)
	finish_current_attacker()

func skip_attack() -> void:
	print("  Tower at ", current_attacker.grid_position, " skips/rests")
	finish_current_attacker()

func finish_current_attacker() -> void:
	current_attacker.clear_highlight()
	for t in current_targets:
		if is_instance_valid(t):
			t.clear_highlight()
	process_next_attacker()
	
func _on_skip_button_pressed() -> void:
	if current_phase == Phase.ATTACK and current_attacker != null:
		skip_attack()

func start_activation_phase() -> void:
	current_phase = Phase.ACTIVATION
	print("[Phase] ACTIVATION — Player ", current_player)
	for tower in get_children():
		if tower is Tower and tower.owner_id == current_player and tower.state == Tower.TowerState.PENDING:
			tower.state = Tower.TowerState.ACTIVE
			print("  Tower at ", tower.grid_position, " activated")
	end_turn()

func end_turn() -> void:
	print("[Phase] End of turn ", turn_number, " (Player ", current_player, ")")
	current_player = 2 if current_player == 1 else 1
	turn_number += 1
	current_phase = Phase.PLACEMENT
	print("[Phase] PLACEMENT — Player ", current_player)
	update_score_ui()
	
func get_resource_at(cell: Vector2i) -> ResourceType:
	var atlas_coords := ground_layer.get_cell_atlas_coords(cell)
	if atlas_coords in TILE_ATLAS_COORDS:
		return TILE_ATLAS_COORDS[atlas_coords]
	return ResourceType.EMPTY
	
func scan_proximity(center: Vector2i, radius: int) -> Dictionary:
	var counts := {
		ResourceType.ROCK: 0,
		ResourceType.TREE: 0,
		ResourceType.ORE: 0,
	}
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var cell := center + Vector2i(x, y)
			var resource := get_resource_at(cell)
			if resource != ResourceType.EMPTY:
				counts[resource] += 1
	return counts
	
func compute_stats(counts: Dictionary) -> Dictionary:
	return {
		"armor": 1 + counts[ResourceType.ROCK],
		"damage": 1 + counts[ResourceType.ORE],
		"range": 1 + counts[ResourceType.TREE],
	}
	
func grid_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func update_score_ui() -> void:
	$UI/P1Container/Player1Label.text = "Player 1 — Score: " + str(player_scores[1])
	$UI/P2Container/Player2Label.text = "Player 2 — Score: " + str(player_scores[2])

	if current_player == 1:
		$UI/P1Container/Player1Label.modulate = Color.YELLOW
		$UI/P2Container/Player2Label.modulate = Color.WHITE
	else:
		$UI/P2Container/Player2Label.modulate = Color.YELLOW
		$UI/P1Container/Player1Label.modulate = Color.WHITE
		
func check_win_condition(player: int) -> bool:
	if player_scores[player] >= 5:
		$UI/WinLabel.text = "Player " + str(player) + " Wins!"
		$UI/WinLabel.visible = true
		get_tree().paused = true
		return true
	return false
