extends Node
## Автотест главного меню и выбора уровня в меню паузы. Запуск (реальный проект, с автозагрузками):
##   Godot_console.exe --headless --path . res://tools/menu_selftest.tscn

var _ok := true


func _make_menu() -> MainMenu:
	var menu: MainMenu = (load("res://game/menu/main_menu.tscn") as PackedScene).instantiate()
	menu.auto_start = false  # не менять сцену — иначе потеряем сам тест
	add_child(menu)
	return menu


func _ready() -> void:
	TankInput.register_actions()
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var menu := _make_menu()
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
	_check(got == [true] and MatchConfig.vs_ai and MatchConfig.level == -1, "«Play vs Computer» — сразу в матч с ИИ, один клик")
	menu.play_pvp_button.pressed.emit()
	await get_tree().process_frame
	_check(got == [true], "повторный старт игнорируется")
	menu.queue_free()

	var menu2 := _make_menu()
	await get_tree().process_frame
	var got2 := []
	menu2.start_requested.connect(func(vs_ai: bool): got2.append(vs_ai))
	menu2.play_pvp_button.pressed.emit()
	await get_tree().process_frame
	_check(got2 == [false] and not MatchConfig.vs_ai, "«2 Players» — сразу в матч, без ИИ")
	menu2.queue_free()

	# матч против ИИ из меню: уровни ротируются
	MatchConfig.vs_ai = true
	MatchConfig.level = -1
	var m: Node = (load("res://game/match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var mgr: RoundManager = m.get_node("RoundManager")
	var arena: Arena = m.get_node("Arena")
	var hud: Hud = m.get_node("Hud")
	_check(mgr.vs_ai and (mgr.tanks[2] as Tank).brain != null, "match.tscn берёт режим из MatchConfig (красный = ИИ)")
	_check(hud.level_cards.size() == Levels.count(), "в меню паузы %d карточек уровней" % hud.level_cards.size())

	# пауза показывает выбор уровня и фокус на текущем
	await _action("pause")
	await get_tree().process_frame
	_check(get_tree().paused and hud._pause_overlay.visible, "P открывает паузу с выбором уровня")
	_check(hud.level_cards[mgr.level].has_focus(), "фокус на карточке текущего уровня")
	var scores_before := mgr.scores.duplicate()

	# выбор карточкой: уровень 3
	var target := (mgr.level + 2) % Levels.count()
	hud.level_cards[target].pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not get_tree().paused and not hud._pause_overlay.visible, "после выбора пауза снята")
	_check(mgr.level == target and arena.level_index == target and mgr.state == RoundManager.State.PLAYING,
		"выбран уровень %d (%s), раунд перезапущен" % [target + 1, arena.get_level_name()])
	_check(mgr.scores == scores_before, "счёт сохранён при смене уровня")

	# выбор клавишей 5 из паузы
	await _action("pause")
	await get_tree().process_frame
	await _key(KEY_5)
	await get_tree().process_frame
	_check(not get_tree().paused and mgr.level == 4 and arena.level_index == 4, "клавиша «5» в паузе выбирает уровень 5")

	# уровень зафиксирован: следующий раунд на том же
	(mgr.tanks[1] as Tank).die()
	await get_tree().create_timer(RoundManager.ROUND_END_DELAY + 1.0).timeout
	_check(mgr.state == RoundManager.State.PLAYING and mgr.level == 4, "выбранный уровень держится между раундами")

	# цифры вне паузы ничего не меняют
	await _key(KEY_2)
	await get_tree().process_frame
	_check(mgr.level == 4, "цифры вне паузы не меняют уровень")

	MatchConfig.vs_ai = false
	MatchConfig.level = -1
	print("ALL OK" if _ok else "FAILED")
	get_tree().quit(0 if _ok else 1)


func _action(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame


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
