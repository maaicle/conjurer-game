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

var current_phase: Phase = Phase.PLACEMENT
var current_player: int = 1
var turn_number: int = 1

func _ready() -> void:
	print("[Phase] PLACEMENT — Player ", current_player)

func _unhandled_input(event: InputEvent) -> void:
	if current_phase != Phase.PLACEMENT:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_global_mouse_position()
		var cell := ground_layer.local_to_map(mouse_pos)
		place_tower(cell)

func place_tower(cell: Vector2i) -> void:
	var tower := TOWER_SCENE.instantiate()
	tower.position = ground_layer.map_to_local(cell)
	tower.grid_position = cell
	tower.owner_id = current_player

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
	# Batch C will fill this in with a real tower queue.
	# Stub for now: immediately move on.
	start_activation_phase()

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
