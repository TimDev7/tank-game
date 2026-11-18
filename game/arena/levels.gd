class_name Levels
extends RefCounted
## Уровни арены как данные. Поле 32x18 клеток по 40 px (1280x720), рамка по периметру добавляется сама.
##
## "rects" — препятствия [x, y, w, h] в клетках. Всегда рисуется ЛЕВАЯ половина, зеркало по горизонтали
## добавляется автоматически (честно для обоих игроков). Если "vmirror": true — рисуется только ВЕРХНЯЯ
## четверть (ряды 1..8), отражение по вертикали тоже автоматическое.
## "crates" — ящики [x, y, вид] (0 дерево, 1 металл, 2 армейский, 3 «опасность») тоже зеркалятся;
## если ключа нет — ящики расставляются автоматически (детерминированно по индексу уровня).
## Тема оформления (стены, пол, декор) = индекс уровня % Arena.THEME_COUNT.
##
## Точки появления — всегда (2.5, 9) и (29.5, 9) клеток: вокруг них нужно свободное место для корпуса
## и ствола, проходы между препятствиями на основных путях ≥ 3 клеток (иначе ИИ с запасом в 1 клетку
## не пройдёт). Проверка всех уровней: tools/check_levels.gd.

const COLS := 32
const ROWS := 18

const LIST := [
	# --- 1-5: исходные ---
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
	# --- 6-30: новые (верхняя четверть, vmirror) ---
	{"name": "Ice Fields", "vmirror": true, "rects": [[6, 2, 2, 1], [10, 5, 1, 2], [14, 2, 2, 1], [14, 7, 1, 2]]},
	{"name": "Magma Stairs", "vmirror": true, "rects": [[10, 1, 2, 2], [12, 3, 2, 2], [14, 5, 2, 2]]},
	{"name": "Neon Grid", "vmirror": true, "rects": [[7, 3, 1, 1], [11, 3, 1, 1], [15, 3, 1, 1], [9, 6, 1, 1], [13, 6, 1, 1]]},
	{"name": "Twin Bunkers", "vmirror": true, "rects": [[9, 5, 5, 1], [9, 5, 1, 2]]},
	{"name": "Dunes", "vmirror": true, "rects": [[6, 3, 4, 1], [12, 5, 4, 1]]},
	{"name": "Overgrown", "vmirror": true, "rects": [[6, 3, 2, 2], [10, 5, 2, 2], [14, 2, 2, 2]]},
	{"name": "Steel Mill", "vmirror": true, "rects": [[8, 4, 8, 1], [12, 7, 2, 2]]},
	{"name": "Brick Alley", "vmirror": true, "rects": [[8, 1, 1, 5], [12, 4, 1, 5]]},
	{"name": "Ice Maze", "vmirror": true, "rects": [[7, 3, 3, 1], [7, 3, 1, 3], [11, 2, 1, 4], [11, 6, 3, 1], [14, 4, 1, 3]]},
	{"name": "Lava Pools", "vmirror": true, "rects": [[6, 3, 3, 2], [12, 7, 2, 2]]},
	{"name": "Neon Diamond", "vmirror": true, "rects": [[15, 2, 1, 1], [14, 3, 1, 1], [13, 4, 1, 1], [12, 5, 1, 1], [11, 6, 1, 1], [7, 3, 2, 2]]},
	{"name": "Concrete Rings", "vmirror": true, "rects": [[6, 3, 3, 1], [6, 3, 1, 3], [8, 3, 1, 3], [13, 6, 2, 2]]},
	{"name": "Sandstone Ruins", "vmirror": true, "rects": [[6, 2, 1, 3], [10, 3, 3, 1], [14, 2, 1, 3]]},
	{"name": "Moss Logs", "vmirror": true, "rects": [[7, 2, 1, 3], [11, 5, 4, 1], [15, 2, 2, 2]]},
	{"name": "Crossfire", "vmirror": true, "rects": [[9, 3, 1, 1], [10, 4, 1, 1], [11, 5, 1, 1], [12, 6, 1, 1]]},
	{"name": "Brick Castle", "vmirror": true, "rects": [[11, 3, 5, 1], [10, 2, 2, 2], [14, 6, 2, 1]]},
	{"name": "Ice Cross", "vmirror": true, "rects": [[15, 2, 2, 3], [11, 8, 5, 1]]},
	{"name": "Lava Maze", "vmirror": true, "rects": [[7, 1, 1, 4], [11, 4, 1, 4], [15, 1, 1, 4]]},
	{"name": "Neon Lanes", "vmirror": true, "rects": [[6, 3, 5, 1], [12, 6, 4, 1]]},
	{"name": "Checkerboard", "vmirror": true, "rects": [[7, 3, 1, 1], [12, 2, 1, 1], [9, 6, 1, 1], [14, 5, 1, 1]]},
	{"name": "Pinwheel", "vmirror": true, "rects": [[9, 2, 1, 3], [9, 5, 4, 1], [13, 2, 1, 4]]},
	{"name": "Barricades", "vmirror": true, "rects": [[6, 3, 1, 2], [10, 6, 1, 2], [14, 3, 1, 2], [15, 8, 2, 1]]},
	{"name": "Chambers", "vmirror": true, "rects": [[8, 2, 4, 1], [8, 2, 1, 3], [11, 2, 1, 3], [14, 6, 2, 1]]},
	{"name": "Hooks", "vmirror": true, "rects": [[9, 3, 7, 1], [9, 3, 1, 4]]},
	{"name": "Gauntlet", "vmirror": true, "rects": [[6, 1, 1, 6], [10, 4, 1, 5], [14, 1, 1, 6]]},
]

const SPAWN_ROW := 8  ## ряды спавна 8-9 (центр поля по вертикали между ними)


static func count() -> int:
	return LIST.size()


static func level_name(index: int) -> String:
	return LIST[posmod(index, LIST.size())].name


static func is_vmirror(index: int) -> bool:
	return LIST[posmod(index, LIST.size())].get("vmirror", false)


## Ящики уровня как Vector3i(x, y, вид): авторские, если заданы, иначе автоматические.
static func crates(index: int) -> Array[Vector3i]:
	var entry: Dictionary = LIST[posmod(index, LIST.size())]
	var picks: Array = entry["crates"] if entry.has("crates") else _auto_crates(index)
	var vmirror := is_vmirror(index)
	var explicit: bool = entry.has("crates")
	var result: Array[Vector3i] = []
	for c in picks:
		var variants := [Vector2i(c[0], c[1]), Vector2i(COLS - 1 - c[0], c[1])]
		if vmirror and not explicit:  # авто-ящики выбираются в верхней четверти и отражаются вниз
			variants.append(Vector2i(c[0], ROWS - 1 - c[1]))
			variants.append(Vector2i(COLS - 1 - c[0], ROWS - 1 - c[1]))
		for cell in variants:
			result.append(Vector3i(cell.x, cell.y, c[2]))
	return result


## Все клетки стен уровня: рамка + препятствия + зеркальные копии.
static func cells(index: int) -> Array[Vector2i]:
	var set := {}
	for x in COLS:
		set[Vector2i(x, 0)] = true
		set[Vector2i(x, ROWS - 1)] = true
	for y in ROWS:
		set[Vector2i(0, y)] = true
		set[Vector2i(COLS - 1, y)] = true
	var vmirror := is_vmirror(index)
	for rect in LIST[posmod(index, LIST.size())].rects:
		var x: int = rect[0]
		var y: int = rect[1]
		var w: int = rect[2]
		var h: int = rect[3]
		for dx in w:
			for dy in h:
				var cx := x + dx
				var cy := y + dy
				set[Vector2i(cx, cy)] = true
				set[Vector2i(COLS - 1 - cx, cy)] = true
				if vmirror:
					set[Vector2i(cx, ROWS - 1 - cy)] = true
					set[Vector2i(COLS - 1 - cx, ROWS - 1 - cy)] = true
	var result: Array[Vector2i] = []
	for c in set:
		result.append(c)
	return result


## Автоматические ящики: клетки левой части (верхней четверти при vmirror), на расстоянии ≥ 2 клеток
## от стен (чтобы не заклинивали), вне зоны спавна и друг от друга ≥ 3 клеток; виды чередуются.
static func _auto_crates(index: int) -> Array:
	var walls := {}
	for c in cells(index):
		walls[c] = true
	var vmirror := is_vmirror(index)
	var max_y := 7 if vmirror else ROWS - 3
	var want := 4 if vmirror else 8
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337 + index * 101
	var candidates: Array[Vector2i] = []
	for x in range(2, 15):
		for y in range(2, max_y + 1):
			if x <= 5 and y >= 6 and y <= 11:
				continue  # зона спавна
			var clear := true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if walls.has(Vector2i(x + dx, y + dy)):
						clear = false
			if clear:
				candidates.append(Vector2i(x, y))
	for i in range(candidates.size() - 1, 0, -1):  # перемешать (Фишер-Йетс)
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var picks: Array = []
	for cell in candidates:
		var far_enough := true
		for p in picks:
			if maxi(absi(p[0] - cell.x), absi(p[1] - cell.y)) < 3:
				far_enough = false
		if far_enough:
			picks.append([cell.x, cell.y, (picks.size() + index) % 4])
		if picks.size() >= want:
			break
	return picks
