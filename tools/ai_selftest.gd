extends Node
## Автотест ИИ в реальном проекте на нескольких разных уровнях. Запуск:
##   Godot_console.exe --headless --path . res://tools/ai_selftest.tscn
## Идёт в реальном времени (до ~60 с на уровень). Код выхода 0 — успех.

const MAX_SECONDS := 60.0
## 0 Classic, 6 Magma Stairs, 11 Steel Mill (с ящиками на пути), 17 Concrete Rings, 24 Checkerboard, 29 Gauntlet (длинный проход)
const TEST_LEVELS := [0, 6, 11, 17, 24, 29]

var _ok := true


func _ready() -> void:
	TankInput.register_actions()
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	for level in TEST_LEVELS:
		await _test_level(level)
	print("ALL OK" if _ok else "FAILED")
	get_tree().quit(0 if _ok else 1)


func _test_level(level: int) -> void:
	MatchConfig.vs_ai = true
	MatchConfig.level = level  # фиксируем уровень, ротация не мешает
	var m: Node = (load("res://game/match/match_ai.tscn") as PackedScene).instantiate()
	add_child(m)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var mgr: RoundManager = m.get_node("RoundManager")
	var arena: Arena = m.get_node("Arena")
	var blue: Tank = mgr.tanks[1]
	var red: Tank = mgr.tanks[2]
	var tag := "[%d %s]" % [level + 1, arena.get_level_name()]

	_check(mgr.vs_ai and red.brain != null and blue.brain == null and mgr.level == level,
		"%s красный под управлением ИИ, уровень выбран" % tag)

	# путь: красный спавн -> синий спавн, ни одной точки в стене
	var path := red.brain.plan_path(red.global_position, blue.global_position)
	var space := arena.get_world_2d().direct_space_state
	var in_wall := 0
	for p in path:
		var q := PhysicsPointQueryParameters2D.new()
		q.position = p
		q.collision_mask = 1 << (PhysicsLayers.WALL - 1)
		if not space.intersect_point(q).is_empty():
			in_wall += 1
	_check(path.size() >= 5 and in_wall == 0, "%s путь найден (%d точек), в стенах: %d" % [tag, path.size(), in_wall])

	# симуляция: синий стоит на месте, ИИ должен найти и подстрелить его (ящики на пути ИИ тоже может разбить)
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
	_check(mgr.scores[2] >= 1, "%s ИИ выигрывает раунд против неподвижной цели за %.1f с (выстрелов %d, проехал %.0f px)"
		% [tag, secs, shots[0], travelled])

	m.queue_free()
	await get_tree().process_frame
	MatchConfig.vs_ai = false
	MatchConfig.level = -1


func _check(cond: bool, label: String) -> void:
	print("%s %s" % ["OK  " if cond else "FAIL", label])
	_ok = _ok and cond
