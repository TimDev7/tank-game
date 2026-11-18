class_name LevelThumb
extends Control
## Миниатюра уровня для меню выбора: стены в масштабе, синяя и красная точки появления.

const WALL := Color(0.45, 0.47, 0.50)
const FLOOR := Color(0.10, 0.12, 0.10)

var level_index: int = 0:
	set(value):
		level_index = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(160, 90)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var cell := Vector2(size.x / Levels.COLS, size.y / Levels.ROWS)
	draw_rect(Rect2(Vector2.ZERO, size), FLOOR)
	for c in Levels.cells(level_index):
		draw_rect(Rect2(Vector2(c) * cell, cell + Vector2(0.5, 0.5)), WALL)
	var row := Levels.ROWS / 2.0
	draw_circle(Vector2(2.5, row) * cell, cell.y * 0.9, Color(0.45, 0.7, 1.0))
	draw_circle(Vector2(Levels.COLS - 2.5, row) * cell, cell.y * 0.9, Color(1.0, 0.45, 0.4))
