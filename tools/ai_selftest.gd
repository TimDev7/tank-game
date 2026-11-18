extends Node
## Автотест ИИ в реальном проекте. Запуск:
##   Godot_console.exe --headless --path . res://tools/ai_selftest.tscn
## Идёт в реальном времени (до ~60 с). Код выхода 0 — успех.

const MAX_SECONDS := 60.0

var _ok := true


func _ready() -> void:
	TankInput.register_actions()
	var m: Node = (load("res://game/match/match_ai.tscn") as PackedScene).instantiate()
	add_child(m)
	_run.call_deferred(m)


func _run(m: Node) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var mgr: RoundManager = m.get_node("RoundManager")
	var arena: Arena = m.get_node("Arena")
	var blue: Tank = mgr.tanks[1]
	var red: Tank = mgr.tanks[2]

	_check(mgr.vs_ai and red.brain != null and blue.brain == null, "красный под управлением ИИ, синий — человек")

	# путь: красный спавн -> синий спавн, ни одной точки в стене, длина разумная
	var path := red.brain.plan_path(red.global_position, blue.global_position)
	var space := arena.get_world_2d().direct_space_state
	var in_wall := 0
	for p in path:
		var q := PhysicsPointQueryParameters2D.new()
		q.position = p
		q.collision_mask = 1 << (PhysicsLayers.WALL - 1)
		if not space.intersect_point(q).is_empty():
			in_wall += 1
	_check(path.size() >= 5 and in_wall == 0, "путь найден (%d точек), в стенах: %d" % [path.size(), in_wall])
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	_check(length < 2600.0, "путь не безумно длинный (%.0f px)" % length)

	# симуляция: синий стоит на месте, ИИ должен найти и подстрелить его
	var shots := [0]
	red.fired.connect(func(_t, _p, _d): shots[0] += 1)
	var start := Time.get_ticks_msec()
	var travelled := 0.0
	var last := red.global_position
	while mgr.scores[2] < 1 and (Time.get_ticks_msec() - start) / 1000.0 < MAX_SECONDS:
		await get_tree().physics_frame
		travelled += red.global_position.distance_to(last)
		last = red.global_position
	var secs := (Time.get_ticks_msec() - start) / 1000.0
	_check(shots[0] > 0, "ИИ стреляет (выстрелов: %d)" % shots[0])
	_check(travelled > 300.0, "ИИ едет (проехал %.0f px)" % travelled)
	_check(mgr.scores[2] >= 1, "ИИ выигрывает раунд против неподвижной цели за %.1f с (счёт %s)" % [secs, mgr.scores])

	print("ALL OK" if _ok else "FAILED")
	get_tree().quit(0 if _ok else 1)


func _check(cond: bool, label: String) -> void:
	print("%s %s" % ["OK  " if cond else "FAIL", label])
	_ok = _ok and cond
