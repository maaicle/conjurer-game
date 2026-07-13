extends RefCounted
class_name ToolbarUI

var on_action_pressed: Callable

var skip_btn: Button
var end_turn_btn: Button
var next_unit_btn: Button
var action_buttons_container: Control

func _init(toolbar_root: Control, action_callback: Callable) -> void:
	on_action_pressed = action_callback
	skip_btn = toolbar_root.get_node("HBox/SkipButton")
	end_turn_btn = toolbar_root.get_node("HBox/EndTurnButton")
	next_unit_btn = toolbar_root.get_node("HBox/NextUnitButton")
	action_buttons_container = toolbar_root.get_node("HBox/ActionButtons")

func update(selected_unit: Unit, mode_active: bool, all_finished: bool) -> void:
	if selected_unit == null:
		skip_btn.disabled = true
		end_turn_btn.disabled = true
		next_unit_btn.disabled = true
		clear_action_buttons()
		return

	if mode_active:
		skip_btn.disabled = true
		end_turn_btn.disabled = true
		next_unit_btn.disabled = true
		for child in action_buttons_container.get_children():
			if child is Button:
				child.disabled = true
		return

	skip_btn.disabled = selected_unit.turn_state != Unit.TurnState.READY
	end_turn_btn.disabled = not all_finished
	next_unit_btn.disabled = all_finished

	clear_action_buttons()
	for action_name in selected_unit.get_available_actions():
		var btn := Button.new()
		btn.text = action_name
		btn.disabled = not selected_unit.can_act()
		btn.pressed.connect(on_action_pressed.bind(action_name))
		action_buttons_container.add_child(btn)

func clear_action_buttons() -> void:
	for child in action_buttons_container.get_children():
		child.queue_free()
