extends Node
## Запись превью-видео для портала: два танка под управлением ИИ играют на нескольких уровнях,
## без HUD и подсказок (CrazyGames: без промо-текста). Запуск (с окном, НЕ --headless):
##   Godot_console.exe --path . --resolution 1920x1080 --write-movie C:/out/preview.avi --fixed-fps 60 --quit-after 1050 res://tools/record_preview.tscn
## Дальше монтаж: tools/make_preview_video.py (нужен ffmpeg).

const LEVELS := [0, 5, 10, 16]  ## Classic, Ice Fields, Overgrown, Neon Diamond
const SECONDS_PER_LEVEL := 4.35

var _mgr: Node  ## RoundManager (без типа: скрипт собирается в --script без автозагрузок)
var _time := 0.0
var _slot := -1


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	MatchConfig.vs_ai = true
	_setup.call_deferred()


func _setup() -> void:
	var m: Node = (load("res://game/match/match_ai.tscn") as PackedScene).instantiate()
	add_child(m)
	for i in 3:
		await get_tree().process_frame
	_mgr = m.get_node("RoundManager")
	(m.get_node("Hud") as CanvasLayer).visible = false
	# синий тоже под ИИ: охотится на красного
	var brain = load("res://game/tanks/tank_brain.gd").new()
	brain.setup(m.get_node("Arena"), _mgr.tanks[2], m.get_node("Bullets"))
	_mgr.tanks[1].brain = brain


func _physics_process(delta: float) -> void:
	if _mgr == null:
		return
	_time += delta
	var slot := int(_time / SECONDS_PER_LEVEL)
	if slot != _slot and slot < LEVELS.size():
		_slot = slot
		_mgr.level = LEVELS[slot]
		_mgr.start_round()
	# если кого-то подстрелили раньше времени — сразу новый розыгрыш на том же уровне
	if _mgr.state != 0 and _slot >= 0:  # 0 = State.PLAYING
		_mgr.start_round()
