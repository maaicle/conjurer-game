extends RefCounted
class_name TurnManager

var units_root: Node
var on_selection_changed: Callable

var selected_unit: Unit = null
var turn_number: int = 1

func _init(root: Node, selection_changed_callback: Callable) -> void:
	units_root = root
	on_selection_changed = selection_changed_callback

func get_unit_at(cell: Vector2i) -> Unit:
	for unit in units_root.get_children():
		if unit is Unit and unit.grid_position == cell:
			return unit
	return null

func select_unit(unit: Unit) -> void:
	if selected_unit != null and is_instance_valid(selected_unit):
		selected_unit.set_selected(false)
	selected_unit = unit
	selected_unit.set_selected(true)
	print("Selected unit at ", unit.grid_position)
	on_selection_changed.call()

func try_select_unit_at(cell: Vector2i) -> bool:
	var clicked_unit := get_unit_at(cell)
	if clicked_unit != null:
		select_unit(clicked_unit)
		return true
	return false

func auto_select_unit() -> void:
	for unit in units_root.get_children():
		if unit is Unit and unit.turn_state == Unit.TurnState.READY:
			select_unit(unit)
			return
	if selected_unit != null and is_instance_valid(selected_unit):
		selected_unit.set_selected(false)
	selected_unit = null
	print("  No units available to auto-select.")
	on_selection_changed.call()

func select_next_unit() -> void:
	var units: Array[Unit] = []
	for child in units_root.get_children():
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

func all_units_finished() -> bool:
	for unit in units_root.get_children():
		if unit is Unit and unit.turn_state == Unit.TurnState.READY:
			return false
	return true

func begin_turn_planning() -> void:
	print("Turn ", turn_number, " begins. Entering planning mode.")
	auto_select_unit()

func end_turn() -> void:
	print("--- End of turn ", turn_number, " ---")
	for unit in units_root.get_children():
		if unit is Unit:
			unit.reset_for_new_turn()
	turn_number += 1
	begin_turn_planning()
