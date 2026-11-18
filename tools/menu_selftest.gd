extends Node
## Автотест главного меню в реальном проекте. Запуск:
##   Godot_console.exe --headless --path . res://tools/menu_selftest.tscn

var _ok := true


func _make_menu(select: bool = true) -> MainMenu:
	var menu: MainMenu = (load("res://game/menu/main_menu.tscn") as PackedScene).instantiate()
	menu.auto_start = false  # не менять сцену — иначе потеряем сам тест
	menu.show_level_select = select
	add_child(menu)
	return menu


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var menu := _make_menu()
	await get_tree().process_frame
	await get_tree().process_frame

	_check(menu.play_ai_button != null and menu.play_pvp_button != null, "две кнопки режимов созданы")
	_check(menu.main_page.visible and not menu.level_page.visible, "сначала видна главная страница")
	_check(menu.play_ai_button.has_focus(), "фокус по умолчанию на «Play vs Computer»")
	_check(menu.play_ai_button.get_child_count() > 0 and menu.play_ai_button.get_child(0) is JuicyButtonComponent,
		"кнопка использует JuicyButtonComponent из шаблона")

	var got := []
	menu.start_requested.connect(func(vs_ai: bool, level: int): got.append([vs_ai, level]))

	# «Play vs Computer» -> страница выбора уровня, игра ещё не стартовала
	menu.play_ai_button.pressed.emit()
	await get_tree().process_frame
	_check(menu.level_page.visible and not menu.main_page.visible and got.is_empty(), "«Play vs Computer» открывает выбор уровня")
	_check(menu.level_buttons.size() == Levels.count() and menu.level_buttons[0].has_focus(),
		"кнопок уровней: %d, фокус на первой" % menu.level_buttons.size())

	# Back возвращает
	menu.back_button.pressed.emit()
	await get_tree().process_frame
	_check(menu.main_page.visible and not menu.level_page.visible and menu.play_ai_button.has_focus(), "Back возвращает на главную страницу")

	# Backspace тоже
	menu.show_level_page()
	await _key(KEY_BACKSPACE)
	_check(menu.main_page.visible, "Backspace возвращает на главную страницу")

	# клик по кнопке уровня 3
	menu.show_level_page()
	menu.level_buttons[2].pressed.emit()
	await get_tree().process_frame
	_check(got == [[true, 2]] and MatchConfig.vs_ai and MatchConfig.level == 2, "кнопка «3» запускает матч с ИИ на уровне индекс 2")
	menu.play_pvp_button.pressed.emit()
	await get_tree().process_frame
	_check(got.size() == 1, "повторный старт игнорируется")
	menu.queue_free()

	# клавиша 4 на странице уровней
	var menu2 := _make_menu()
	await get_tree().process_frame
	var got2 := []
	menu2.start_requested.connect(func(vs_ai: bool, level: int): got2.append([vs_ai, level]))
	menu2.show_level_page()
	await _key(KEY_4)
	_check(got2 == [[true, 3]], "клавиша «4» запускает уровень 4")
	menu2.queue_free()

	# PvP: сразу в матч, ротация уровней
	var menu3 := _make_menu()
	await get_tree().process_frame
	var got3 := []
	menu3.start_requested.connect(func(vs_ai: bool, level: int): got3.append([vs_ai, level]))
	menu3.play_pvp_button.pressed.emit()
	await get_tree().process_frame
	_check(got3 == [[false, -1]] and not MatchConfig.vs_ai and MatchConfig.level == -1, "«2 Players» — сразу в матч, ротация уровней")
	menu3.queue_free()

	# без выбора уровня (флаг): vs Computer стартует сразу
	var menu4 := _make_menu(false)
	await get_tree().process_frame
	var got4 := []
	menu4.start_requested.connect(func(vs_ai: bool, level: int): got4.append([vs_ai, level]))
	menu4.play_ai_button.pressed.emit()
	await get_tree().process_frame
	_check(got4 == [[true, -1]], "show_level_select=false: vs Computer стартует сразу")
	menu4.queue_free()

	# матч с выбранным уровнем держит его между раундами
	MatchConfig.vs_ai = true
	MatchConfig.level = 3
	var m: Node = (load("res://game/match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var mgr: RoundManager = m.get_node("RoundManager")
	var arena: Arena = m.get_node("Arena")
	_check(mgr.vs_ai and (mgr.tanks[2] as Tank).brain != null, "match.tscn берёт режим из MatchConfig (красный = ИИ)")
	_check(mgr.level == 3 and arena.level_index == 3, "матч стартует на выбранном уровне 4 (%s)" % arena.get_level_name())
	(mgr.tanks[1] as Tank).die()
	await get_tree().create_timer(RoundManager.ROUND_END_DELAY + 1.0).timeout
	_check(mgr.state == RoundManager.State.PLAYING and mgr.level == 3 and arena.level_index == 3, "следующий раунд — на том же уровне")
	MatchConfig.vs_ai = false
	MatchConfig.level = -1

	print("ALL OK" if _ok else "FAILED")
	get_tree().quit(0 if _ok else 1)


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame


func _check(cond: bool, label: String) -> void:
	print("%s %s" % ["OK  " if cond else "FAIL", label])
	_ok = _ok and cond
