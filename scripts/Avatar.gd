extends Unit
class_name Avatar

func _ready() -> void:
	super._ready()
	movement_range = 2

func get_available_actions() -> Array[String]:
	return ["Spawn Soldier"]
