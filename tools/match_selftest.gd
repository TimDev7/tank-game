extends Node
## Автотест матча в реальном проекте (с автозагрузками). Запуск:
##   Godot_console.exe --headless --path . res://tools/match_selftest.tscn
## Выходит с кодом 0 при успехе.

var _ok := true
var _mgr: RoundManager
var _match: Node


func _ready() -> void:
	TankInput.register_actions()
	_match = (load("res://game/match/match.tscn") as PackedScene).instantiate()
	add_child(_match)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame  # отложенный старт матча
	_mgr = _match.get_node("RoundManager")
	var arena: Arena = _match.get_node("Arena")
	var t1: Tank = _mgr.tanks[1]
	var t2: Tank = _mgr.tanks[2]
	_mgr.level = 0  # тесты ниже рассчитаны на раскладку Classic; без этого уровень случайный
	_mgr.start_round()
	await get_tree().physics_frame
	await get_tree().physics_frame

	_check(_mgr.state == RoundManager.State.PLAYING and t1.alive and t2.alive, "матч стартует: раунд идёт, оба танка живы")
	_check(t1.global_position.is_equal_approx(arena.get_spawn(1).global_position)
		and t2.global_position.is_equal_approx(arena.get_spawn(2).global_position), "танки на точках появления")

	# рикошет от нижней стены (внутренний край y=680)
	var bullets: Node2D = _match.get_node("Bullets")
	var b := Bullet.new()
	bullets.add_child(b)
	b.launch(t1, Vector2(640, 600), Vector2.DOWN)
	await _frames(25)
	_check(is_instance_valid(b) and b.direction.y < 0.0 and b.bounces >= 1 and b.global_position.y < 680.0,
		"пуля отражается от стены (dir.y=%.2f, bounces=%d, y=%.0f)" % [b.direction.y if is_instance_valid(b) else 0.0, b.bounces if is_instance_valid(b) else -1, b.global_position.y if is_instance_valid(b) else 0.0])
	b.queue_free()

	# попадание в красный танк -> очко синему
	var hit := Bullet.new()
	bullets.add_child(hit)
	hit.launch(t1, Vector2(1090, 360), Vector2.RIGHT)
	await _frames(20)
	_check(not t2.alive, "пуля убивает красный танк")
	_check(_mgr.scores[1] == 1 and _mgr.scores[2] == 0 and _mgr.state == RoundManager.State.ROUND_OVER,
		"очко синему, раунд окончен (scores=%s)" % [_mgr.scores])
	_check(not t1.controls_enabled, "управление выключено до нового раунда")

	# автоматический следующий раунд — на новом уровне
	var level_before := _mgr.level
	await get_tree().create_timer(RoundManager.ROUND_END_DELAY + 1.0).timeout
	_check(_mgr.state == RoundManager.State.PLAYING and t1.alive and t2.alive and t1.controls_enabled, "следующий раунд стартует сам")
	_check(_mgr.level == (level_before + 1) % Levels.count() and arena.level_index == _mgr.level,
		"следующий раунд идёт на следующем уровне (%d -> %d)" % [level_before, _mgr.level])
	var lvl := _mgr.level
	_press("restart_round")
	await _frames(2)
	_check(_mgr.level == lvl, "R перезапускает раунд на том же уровне")

	# ничья: оба танка гибнут в одном кадре
	t1.die()
	t2.die()
	await _frames(3)
	_check(_mgr.scores[1] == 1 and _mgr.scores[2] == 0 and _mgr.state == RoundManager.State.ROUND_OVER, "двойное попадание = ничья, счёт не растёт")

	# ручной рестарт раунда (R) до таймера
	_press("restart_round")
	await _frames(2)
	_check(_mgr.state == RoundManager.State.PLAYING and t1.alive and t2.alive, "R перезапускает раунд, счёт сохранён")

	# матч до 5 побед
	for i in range(4):
		t2.die()
		await _frames(2)
		if _mgr.state == RoundManager.State.ROUND_OVER:
			_press("restart_round")
			await _frames(2)
	_check(_mgr.state == RoundManager.State.MATCH_OVER and _mgr.scores[1] == 5, "5 побед = конец матча (scores=%s)" % [_mgr.scores])
	_press("restart_round")
	await _frames(2)
	_check(_mgr.state == RoundManager.State.PLAYING and _mgr.scores[1] == 0, "R после конца матча начинает новый матч")

	# пауза
	_press("pause")
	await _frames(2)
	var paused_on := get_tree().paused
	var x := t1.global_position
	Input.action_press("p1_up")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("p1_up")
	_check(paused_on and t1.global_position == x, "P ставит игру на паузу, танк стоит")
	_press("pause")
	await _frames(2)
	_check(not get_tree().paused, "второе нажатие P снимает паузу")

	# возврат в меню по M: только из паузы или после конца матча
	var menu_hits := [0]
	_mgr.auto_change_scene = false
	_mgr.menu_requested.connect(func(): menu_hits[0] += 1)
	_press("menu")
	await _frames(2)
	_check(menu_hits[0] == 0, "M во время игры ничего не делает")
	_press("pause")
	await _frames(2)
	_press("menu")
	await _frames(2)
	_check(menu_hits[0] == 1 and not get_tree().paused, "M из паузы -> меню, пауза снята")

	print("ALL OK" if _ok else "FAILED")
	get_tree().quit(0 if _ok else 1)


func _press(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, label: String) -> void:
	print("%s %s" % ["OK  " if cond else "FAIL", label])
	_ok = _ok and cond
