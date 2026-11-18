@tool
class_name SpawnPoint
extends Marker2D
## Точка появления игрока на арене. Поворот узла = направление, куда смотрит танк при старте.
## Ставится в сцене арены как дочерний узел "SpawnPoints" (по одному на игрока).

@export_range(1, 2) var player_index: int = 1:
	set(value):
		player_index = value
		queue_redraw()

const COLORS := {1: Color(0.3, 0.6, 1.0), 2: Color(1.0, 0.4, 0.3)}


func _ready() -> void:
	add_to_group(&"spawn_points")


## Подсказка в редакторе: цветной круг и стрелка направления. В игре не рисуется.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color: Color = COLORS.get(player_index, Color.WHITE)
	draw_circle(Vector2.ZERO, 14.0, Color(color, 0.35))
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, color, 2.0)
	draw_line(Vector2.ZERO, Vector2(24, 0), color, 3.0)
