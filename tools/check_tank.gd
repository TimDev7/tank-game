extends SceneTree
## Проверка заглушки танка на арене. Запуск:
##   Godot_console.exe --headless --path . --script res://tools/check_tank.gd

var _ok := true


func _init() -> void:
	TankInput.register_actions()  # автозагрузка Game в режиме --script не стартует
	var arena: Arena = (load("res://game/arena/arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	var tank_scene: PackedScene = load("res://game/tanks/tank.tscn")
	var t1: Tank = tank_scene.instantiate()
	var t2: Tank = tank_scene.instantiate()
	t1.player_index = 1
	t2.player_index = 2
	arena.add_child(t1)
	arena.add_child(t2)
	await process_frame  # в режиме --script дерево оживает только после первого кадра
	arena.place_tank(t1, 1)
	arena.place_tank(t2, 2)
	await physics_frame

	# 1) вперёд: перед спавном P1 стоит блок (x=240), танк должен упереться, передний край <= 240
	var x0 := t1.global_position.x
	Input.action_press("p1_up")
	await _frames(60)
	Input.action_release("p1_up")
	_check(t1.global_position.x > x0 + 5.0 and t1.global_position.x + 44.0 <= 241.0,
		"P1 едет вперёд и упирается в блок (x %.0f -> %.0f, передний край %.0f <= 240)" % [x0, t1.global_position.x, t1.global_position.x + 44.0])

	# 2) поворот: right -> rotation растёт (~1.4 рад за 30 кадров)
	var r0 := t1.rotation
	Input.action_press("p1_right")
	await _frames(30)
	Input.action_release("p1_right")
	_check(t1.rotation > r0 + 1.0, "P1 поворачивает (%.2f -> %.2f)" % [r0, t1.rotation])

	# 2b) после поворота (~вниз) едет свободно
	var y0 := t1.global_position.y
	Input.action_press("p1_up")
	await _frames(30)
	Input.action_release("p1_up")
	_check(t1.global_position.y > y0 + 60.0, "P1 едет после поворота (y %.0f -> %.0f)" % [y0, t1.global_position.y])

	# 3) стена: игрок 2 смотрит влево (rotation PI) у правой стены? Едем P2 назад в правую стену
	var wall_inner_x := 1280.0 - 40.0
	Input.action_press("p2_down")  # назад = вправо при rotation PI
	await _frames(120)
	Input.action_release("p2_down")
	var max_x := t2.global_position.x + 44.0
	_check(max_x <= wall_inner_x + 2.0, "P2 упёрся в правую стену (задний край %.1f <= %.1f)" % [max_x, wall_inner_x])

	# 4) выстрел: сигнал fired и кулдаун
	var shots := [0]
	t1.fired.connect(func(_t, _p, _d): shots[0] += 1)
	Input.action_press("p1_fire")
	await _frames(10)
	_check(shots[0] == 1, "один выстрел за 10 кадров из-за кулдауна (shots=%d)" % shots[0])
	Input.action_release("p1_fire")

	# 5) смерть блокирует управление, respawn возвращает
	t1.die()
	var px := t1.global_position.x
	Input.action_press("p1_up")
	await _frames(10)
	Input.action_release("p1_up")
	_check(not t1.alive and is_equal_approx(t1.global_position.x, px), "мёртвый танк не двигается")
	t1.respawn(arena.get_spawn_transform(1))
	await physics_frame
	_check(t1.alive and t1.global_position.is_equal_approx(arena.get_spawn(1).global_position), "respawn на точку появления")

	print("ALL OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(cond: bool, label: String) -> void:
	print("%s %s" % ["OK  " if cond else "FAIL", label])
	_ok = _ok and cond
