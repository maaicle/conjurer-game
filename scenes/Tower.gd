extends Node2D
class_name Tower


enum TowerState { PENDING, ACTIVE }

var grid_position: Vector2i
var owner_id: int = 1
var armor: int = 1
var damage: int = 1
var range_stat: int = 1
var state: TowerState = TowerState.PENDING

func set_highlight(color: Color) -> void:
	$Sprite2D.modulate = color

func clear_highlight() -> void:
	$Sprite2D.modulate = Color.WHITE
	
func apply_owner_color() -> void:
	if owner_id == 1:
		$Sprite2D.self_modulate = Color(0.4, 0.6, 1.0)  # blue-ish
	else:
		$Sprite2D.self_modulate = Color(1.0, 0.5, 0.4)  # orange-ish
