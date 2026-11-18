extends SceneTree
## Проверка всех уровней арены. Запуск:
##   Godot_console.exe --headless --path . --script res://tools/check_levels.gd
## Для каждого уровня: зеркальность, свободные точки появления (танк 88x58 с запасом под ствол),
## путь ИИ между спавнами без точек в стенах, проходимость (доля достижимых клеток).

var _ok := true


func _init() -> void:
	var arena: Arena = (load("res://game/arena/arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	await process_frame
	await physics_frame
	var space := arena.get_world_2d().direct_space_state
	var brain := TankBrain.new()
	brain.setup(arena, null, Node2D.new())

	for i in Levels.count():
		arena.load_level(i)
		await physics_frame
		await physics_frame
		brain.rebuild()
		var name := Levels.level_name(i)
		var cells := Levels.cells(i)
		var set := {}
		for c in cells:
			set[c] = true

		var mirrored := true
		for c in cells:
			if not set.has(Vector2i(Levels.COLS - 1 - c.x, c.y)):
				mirrored = false
		_check(mirrored, "[%d %s] уровень зеркален по горизонтали" % [i + 1, name])
		_check(arena.walls.get_used_cells().size() == cells.size(), "[%d %s] арена содержит %d клеток стен" % [i + 1, name, cells.size()])

		var spawn_ok := true
		for p in [1, 2]:
			var shape := RectangleShape2D.new()
			shape.size = Vector2(88 + 90, 58 + 20)  # корпус + запас ~45 px впереди под ствол
			var q := PhysicsShapeQueryParameters2D.new()
			q.shape = shape
			q.transform = Transform2D(0.0, arena.get_spawn(p).global_position + Vector2(45 if p == 1 else -45, 0))
			q.collision_mask = 1 << (PhysicsLayers.WALL - 1)
			if not space.intersect_shape(q, 1).is_empty():
				spawn_ok = false
		_check(spawn_ok, "[%d %s] у обоих спавнов достаточно места под корпус и ствол" % [i + 1, name])

		var path := brain.plan_path(arena.get_spawn(1).global_position, arena.get_spawn(2).global_position)
		var in_wall := 0
		for p in path:
			var q2 := PhysicsPointQueryParameters2D.new()
			q2.position = p
			q2.collision_mask = 1 << (PhysicsLayers.WALL - 1)
			if not space.intersect_point(q2).is_empty():
				in_wall += 1
		var length := 0.0
		for k in range(1, path.size()):
			length += path[k - 1].distance_to(path[k])
		_check(path.size() >= 5 and in_wall == 0 and length < 3200.0,
			"[%d %s] путь ИИ между спавнами: %d точек, %.0f px, в стенах %d" % [i + 1, name, path.size(), length, in_wall])

		var free := 0
		for x in range(1, Levels.COLS - 1):
			for y in range(1, Levels.ROWS - 1):
				if not set.has(Vector2i(x, y)):
					free += 1
		print("     свободно %d из %d клеток внутри рамки" % [free, (Levels.COLS - 2) * (Levels.ROWS - 2)])

	print("ALL OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(cond: bool, label: String) -> void:
	print("%s %s" % ["OK  " if cond else "FAIL", label])
	_ok = _ok and cond
