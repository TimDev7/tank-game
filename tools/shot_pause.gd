extends Node
## Снимки: пауза с сеткой уровней и несколько арен. Запуск (с окном):
##   Godot_console.exe --path . --resolution 1280x720 res://tools/shot_pause.tscn -- C:/out_dir

func _ready() -> void:
	TankInput.register_actions()
	_run.call_deferred()

func _run() -> void:
	var dir := OS.get_cmdline_user_args()[0]
	MatchConfig.vs_ai = false
	var m: Node = (load("res://game/match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	for i in 4: await get_tree().process_frame
	var mgr: RoundManager = m.get_node("RoundManager")
	for lv in [5, 8, 15, 22]:
		mgr.select_level(lv) if false else null
		mgr.level = lv
		mgr.start_round()
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("%s/lvl_%d.png" % [dir, lv + 1])
	var ev := InputEventAction.new()
	ev.action = "pause"; ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png("%s/pause.png" % dir)
	get_tree().quit()
