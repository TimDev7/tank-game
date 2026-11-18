class_name Levels
extends RefCounted
## Уровни арены как данные. Поле 32x18 клеток по 40 px (1280x720), рамка по периметру добавляется сама.
## Каждый уровень — прямоугольники препятствий [x, y, w, h] в клетках ДЛЯ ЛЕВОЙ ПОЛОВИНЫ;
## зеркало по горизонтали добавляется автоматически (честно для обоих игроков).
## Точки появления — всегда (2.5, 9) и (29.5, 9) клеток: вокруг них по ~3 клетки свободного места
## (стволу нужно место), проходы между препятствиями ≥ 3 клеток (иначе ИИ с запасом 1 клетка не пройдёт).
## Проверка уровней: tools/check_levels.gd.

const COLS := 32
const ROWS := 18

const LIST := [
	{
		"name": "Classic",
		"rects": [[6, 4, 4, 1], [6, 13, 4, 1], [10, 7, 1, 4], [6, 8, 1, 2], [15, 6, 2, 6]],
	},
	{
		"name": "Pillars",
		"rects": [[5, 3, 2, 2], [5, 13, 2, 2], [10, 5, 2, 2], [10, 11, 2, 2], [15, 8, 2, 2]],
	},
	{
		"name": "Lanes",
		"rects": [[7, 1, 1, 6], [7, 11, 1, 6], [12, 5, 1, 8]],
	},
	{
		"name": "Fortress",
		"rects": [[12, 5, 8, 1], [12, 12, 8, 1], [12, 5, 1, 2], [12, 11, 1, 2], [6, 4, 1, 3], [6, 11, 1, 3]],
	},
	{
		"name": "Zigzag",
		"rects": [[5, 1, 1, 10], [9, 7, 1, 10], [13, 1, 1, 10]],
	},
]


static func count() -> int:
	return LIST.size()


static func level_name(index: int) -> String:
	return LIST[posmod(index, LIST.size())].name


## Все клетки стен уровня: рамка + препятствия + зеркальная половина.
static func cells(index: int) -> Array[Vector2i]:
	var set := {}
	for x in COLS:
		set[Vector2i(x, 0)] = true
		set[Vector2i(x, ROWS - 1)] = true
	for y in ROWS:
		set[Vector2i(0, y)] = true
		set[Vector2i(COLS - 1, y)] = true
	for rect in LIST[posmod(index, LIST.size())].rects:
		var x: int = rect[0]
		var y: int = rect[1]
		var w: int = rect[2]
		var h: int = rect[3]
		for dx in w:
			for dy in h:
				set[Vector2i(x + dx, y + dy)] = true
				set[Vector2i(COLS - 1 - (x + dx), y + dy)] = true
	var result: Array[Vector2i] = []
	for c in set:
		result.append(c)
	return result
