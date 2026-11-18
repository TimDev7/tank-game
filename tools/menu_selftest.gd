extends Node
## Автотест главного меню в реальном проекте. Запуск:
##   Godot_console.exe --headless --path . res://tools/menu_selftest.tscn

var _ok := true


func _ready() -> void:
	var menu: MainMenu = (load("res://game/menu/main_menu.tscn") as PackedScene).instantiate()
	menu.auto_start = false  # не менять сцену — иначе потеряем сам тест
	add_child(menu)
	_run.call_deferred(menu)


func _run(menu: MainMenu) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_check(menu.play_ai_button != null and menu.play_pvp_button != null, "две кнопки режимов созданы")
	_check(menu.play_ai_button.has_focus(), "фокус по умолчанию на «Play vs Computer»")
	_check(menu.play_ai_button.get_child_count() > 0 and menu.play_ai_button.get_child(0) is JuicyButtonComponent,
		"кнопка использует JuicyButtonComponent из шаблона")

	var got := []
	menu.start_requested.connect(func(vs_ai: bool): got.append(vs_ai))
	menu.play_ai_button.pressed.emit()
	await get_tree().process_frame
	_check(got == [true] and MatchConfig.vs_ai, "клик по «vs Computer» -> vs_ai=true (один клик до игры)")

	# повторный клик не запускает матч второй раз
	menu.play_pvp_button.pressed.emit()
	await get_tree().process_frame
	_check(got == [true], "повторный старт игнорируется")

	# второй экземпляр меню: режим PvP
	var menu2: MainMenu = (load("res://game/menu/main_menu.tscn") as PackedScene).instantiate()
	menu2.auto_start = false
	add_child(menu2)
	await get_tree().process_frame
	var got2 := []
	menu2.start_requested.connect(func(vs_ai: bool): got2.append(vs_ai))
	menu2.play_pvp_button.pressed.emit()
	await get_tree().process_frame
	_check(got2 == [false] and not MatchConfig.vs_ai, "клик по «2 Players» -> vs_ai=false")

	# матч, запущенный из меню с vs_ai=true, создаёт ИИ
	MatchConfig.vs_ai = true
	var m: Node = (load("res://game/match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var mgr: RoundManager = m.get_node("RoundManager")
	_check(mgr.vs_ai and (mgr.tanks[2] as Tank).brain != null, "match.tscn берёт режим из MatchConfig (красный = ИИ)")
	MatchConfig.vs_ai = false

	print("ALL OK" if _ok else "FAILED")
	get_tree().quit(0 if _ok else 1)


func _check(cond: bool, label: String) -> void:
	print("%s %s" % ["OK  " if cond else "FAIL", label])
	_ok = _ok and cond
