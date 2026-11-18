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

## "crates" — ящики [x, y, вид] (клетка левой половины; вид 0 дерево, 1 металл, 2 армейский, 3 «опасность»),
## тоже зеркалятся. Не ставить в зонах спавна (столбцы 1-4 и 27-30, ряды 7-10) — проверяет check_levels.
## Тема оформления уровня (стены/пол/декор) = индекс уровня, см. Arena.

const LIST := [
	{
		"name": "Classic",
		"rects": [[6, 4, 4, 1], [6, 13, 4, 1], [10, 7, 1, 4], [6, 8, 1, 2], [15, 6, 2, 6]],
		"crates": [[3, 4, 0], [3, 13, 1], [8, 2, 2], [8, 15, 3], [8, 8, 0], [13, 3, 1], [13, 14, 2], [12, 8, 3]],
	},
	{
		"name": "Pillars",
		"rects": [[5, 3, 2, 2], [5, 13, 2, 2], [10, 5, 2, 2], [10, 11, 2, 2], [15, 8, 2, 2]],
		"crates": [[8, 8, 0], [8, 4, 1], [8, 13, 2], [13, 3, 3], [13, 14, 0], [13, 8, 1], [3, 4, 2], [3, 14, 3]],
	},
	{
		"name": "Lanes",
		"rects": [[7, 1, 1, 6], [7, 11, 1, 6], [12, 5, 1, 8]],
		"crates": [[4, 4, 0], [4, 13, 1], [9, 3, 2], [9, 14, 3], [10, 8, 0], [14, 5, 1], [14, 12, 2], [15, 8, 3]],
	},
	{
		"name": "Fortress",
		"rects": [[12, 5, 8, 1], [12, 12, 8, 1], [12, 5, 1, 2], [12, 11, 1, 2], [6, 4, 1, 3], [6, 11, 1, 3]],
		"crates": [[14, 7, 0], [14, 10, 1], [9, 8, 2], [4, 3, 3], [4, 14, 0], [9, 3, 1], [9, 14, 2]],
	},
	{
		"name": "Zigzag",
		"rects": [[6, 1, 1, 10], [10, 7, 1, 10], [15, 1, 2, 8]],
		"crates": [[3, 4, 0], [3, 14, 1], [8, 3, 2], [8, 12, 3], [13, 12, 0], [13, 3, 1], [12, 8, 2], [8, 8, 3]],
	},
]


static func count() -> int:
	return LIST.size()


static func level_name(index: int) -> String:
	return LIST[posmod(index, LIST.size())].name


## Ящики уровня как Vector3i(x, y, вид): левая половина + зеркальная.
static func crates(index: int) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for c in LIST[posmod(index, LIST.size())].crates:
		result.append(Vector3i(c[0], c[1], c[2]))
		result.append(Vector3i(COLS - 1 - c[0], c[1], c[2]))
	return result


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
