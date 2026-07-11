extends Unit
class_name Avatar

func _ready() -> void:
	movement_range = 2

func get_available_actions() -> Array[String]:
	return ["Spawn Soldier"]
