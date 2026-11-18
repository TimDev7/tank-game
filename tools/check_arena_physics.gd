extends SceneTree
## Проверка: стены блокируют на слое wall, пустое поле и спавны свободны.
## Запуск: Godot_console.exe --headless --path . --script res://tools/check_arena_physics.gd

func _init() -> void:
	var arena: Arena = (load("res://game/arena/arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var space := arena.get_world_2d().direct_space_state
	var ok := true
	ok = _check(space, Vector2(20, 20), true, "угол рамки") and ok
	ok = _check(space, Vector2(640, 300), true, "центральный столб") and ok
	ok = _check(space, Vector2(640, 40 * 15), false, "пустое место") and ok
	ok = _check(space, arena.get_spawn(1).global_position, false, "спавн игрока 1") and ok
	ok = _check(space, arena.get_spawn(2).global_position, false, "спавн игрока 2") and ok
	print("playfield: ", arena.get_playfield_rect())
	print("ALL OK" if ok else "FAILED")
	quit(0 if ok else 1)


func _check(space: PhysicsDirectSpaceState2D, pos: Vector2, expect_hit: bool, label: String) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = 1 << (PhysicsLayers.WALL - 1)
	var hit := not space.intersect_point(q).is_empty()
	print("%s %s: hit=%s expected=%s" % ["OK  " if hit == expect_hit else "FAIL", label, hit, expect_hit])
	return hit == expect_hit
