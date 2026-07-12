extends Node2D
class_name Unit

enum TurnState { READY, WAITING, DONE }

const SELECTED_RING_TEXTURE := preload("res://assets/selected_ring.png")

var grid_position: Vector2i
var movement_range: int = 1
var turn_state: TurnState = TurnState.READY
var has_moved: bool = false
var has_acted: bool = false
var action_range: int = 1
var collection_range: int = 1
var selection_ring: Sprite2D

func get_available_actions() -> Array[String]:
	return []

func can_move() -> bool:
	return not has_moved and turn_state != TurnState.DONE

func can_act() -> bool:
	return turn_state != TurnState.DONE

func use_movement() -> void:
	has_moved = true
	_check_done()

func use_action() -> void:
	has_moved = true
	has_acted = true
	_check_done()

func skip() -> void:
	if turn_state == TurnState.DONE:
		return
	turn_state = TurnState.WAITING

func _check_done() -> void:
	if has_moved and has_acted:
		turn_state = TurnState.DONE

func reset_for_new_turn() -> void:
	turn_state = TurnState.READY
	has_moved = false
	has_acted = false

func _ready() -> void:
	selection_ring = Sprite2D.new()
	selection_ring.texture = SELECTED_RING_TEXTURE
	selection_ring.visible = false
	selection_ring.z_index = -1
	add_child(selection_ring)

func set_selected(is_selected: bool) -> void:
	selection_ring.visible = is_selected
