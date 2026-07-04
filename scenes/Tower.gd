extends Node2D
class_name Tower


enum TowerState { PENDING, ACTIVE }

var grid_position: Vector2i
var owner_id: int = 1
var armor: int = 1
var damage: int = 1
var range_stat: int = 1
var state: TowerState = TowerState.PENDING
