extends SceneTree
## Печатает ASCII-карты уровней для отладки проходимости ИИ.
##   Godot_console.exe --headless --path . --script res://tools/dump_levels.gd -- 5 7 9   (номера с 1; без аргументов — все)
## Обозначения: # стена, + клетка у стены (ИИ не ездит: запас 1 клетка), . достижимо из спавна 1, x недостижимо, S спавн.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var wanted: Array[int] = []
	for a in args:
		wanted.append(int(a) - 1)
	if wanted.is_empty():
		for i in Levels.count():
			wanted.append(i)
	for i in wanted:
		_dump(i)
	quit()


func _dump(index: int) -> void:
	var walls := {}
	for c in Levels.cells(index):
		walls[c] = true
	var blocked := {}
	for c in walls:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				blocked[Vector2i(c.x + dx, c.y + dy)] = true
	# заливка по 8 соседям, как AStarGrid2D с DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES (диагональ — только если оба ортогональных свободны)
	var start := Vector2i(2, 8)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var n: Vector2i = cur + d
			if n.x < 0 or n.y < 0 or n.x >= Levels.COLS or n.y >= Levels.ROWS or blocked.has(n) or seen.has(n):
				continue
			if d.x != 0 and d.y != 0 and (blocked.has(cur + Vector2i(d.x, 0)) or blocked.has(cur + Vector2i(0, d.y))):
				continue
			seen[n] = true
			queue.append(n)
	var ok := seen.has(Vector2i(Levels.COLS - 3, 8))
	print("=== %d %s  (путь %s) ===" % [index + 1, Levels.level_name(index), "ЕСТЬ" if ok else "НЕТ"])
	for y in Levels.ROWS:
		var line := ""
		for x in Levels.COLS:
			var c := Vector2i(x, y)
			if (x == 2 or x == Levels.COLS - 3) and (y == 8 or y == 9):
				line += "S"
			elif walls.has(c):
				line += "#"
			elif blocked.has(c):
				line += "+"
			elif seen.has(c):
				line += "."
			else:
				line += "x"
		print(line)
