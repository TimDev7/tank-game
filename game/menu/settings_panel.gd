extends Control
## Окно настроек поверх главного меню: переключатели музыки и звуковых эффектов.
## Строится кодом (как всё меню). Значения хранятся в Game.game_data.sounds (сохраняются SaveManager),
## применяются через Game.sound_manager. Закрывается кнопкой Back, Esc или щелчком по затемнению.
## Скрипт без class_name - подключается через preload (см. main_menu.gd).

signal closed

const GOLD := Color(1.0, 0.78, 0.22)
const GREEN := Color(0.45, 0.85, 0.5)
const OFF_COLOR := Color(0.55, 0.58, 0.58)
const TEXT_COLOR := Color(0.93, 0.95, 0.93)

var music_button: Button
var sfx_button: Button
var back_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # клики не проваливаются в меню под окном
	_build()
	_refresh()
	music_button.grab_focus()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.09, 0.08, 0.97), GOLD, 3, 6))
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var title := _label(tr("SETTINGS"), 56, Color.WHITE)
	column.add_child(title)
	var line := ColorRect.new()
	line.color = Color(GOLD, 0.8)
	line.custom_minimum_size = Vector2(0, 3)
	column.add_child(line)

	music_button = _toggle_button()
	music_button.pressed.connect(_on_music_pressed)
	column.add_child(music_button)
	sfx_button = _toggle_button()
	sfx_button.pressed.connect(_on_sfx_pressed)
	column.add_child(sfx_button)

	back_button = _toggle_button()
	back_button.text = tr("BACK")
	back_button.custom_minimum_size = Vector2(420, 56)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.add_theme_color_override("font_color", TEXT_COLOR)
	back_button.pressed.connect(close)
	column.add_child(back_button)

	var hint := _label(tr("Esc - back"), 18, Color(0.75, 0.78, 0.75))
	column.add_child(hint)

	# фокус ходит по кругу внутри окна и не уходит в меню под ним
	var order: Array[Button] = [music_button, sfx_button, back_button]
	for i in order.size():
		var button := order[i]
		button.focus_neighbor_top = order[(i - 1 + order.size()) % order.size()].get_path()
		button.focus_neighbor_bottom = order[(i + 1) % order.size()].get_path()
		button.focus_neighbor_left = button.get_path()
		button.focus_neighbor_right = button.get_path()
		button.focus_previous = button.focus_neighbor_top
		button.focus_next = button.focus_neighbor_bottom


func _toggle_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(420, 64)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_stylebox_override("normal", _style(Color(0.10, 0.13, 0.11, 0.95), GOLD.darkened(0.45), 3, 10))
	button.add_theme_stylebox_override("hover", _style(Color(0.16, 0.20, 0.17, 0.97), GOLD, 3, 10))
	button.add_theme_stylebox_override("pressed", _style(Color(0.05, 0.07, 0.06, 0.97), GOLD, 3, 10))
	button.add_theme_stylebox_override("focus", _style(Color(0.16, 0.20, 0.17, 0.97), GOLD.lightened(0.5), 4, 10))
	return button


func _style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", maxi(4, size / 7))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _sounds() -> Sounds:
	return Game.game_data.sounds


func _refresh() -> void:
	_set_toggle_text(music_button, tr("MUSIC"), not _sounds().music_mute)
	_set_toggle_text(sfx_button, tr("SOUND EFFECTS"), not _sounds().sfx_mute)


func _set_toggle_text(button: Button, title: String, enabled: bool) -> void:
	button.text = "%s:  %s" % [title, tr("ON") if enabled else tr("OFF")]
	button.add_theme_color_override("font_color", GREEN if enabled else OFF_COLOR)


func _on_music_pressed() -> void:
	Game.sound_manager.set_music_mute(not _sounds().music_mute)
	_save_and_refresh()


func _on_sfx_pressed() -> void:
	Game.sound_manager.set_sfx_mute(not _sounds().sfx_mute)
	_save_and_refresh()
	GameAudio.sfx("ui_click", 0.6)  # при включении сразу слышно, что звук вернулся (при выключении - тишина)


func _save_and_refresh() -> void:
	_refresh()
	Core.save_manager.save_data()


func close() -> void:
	closed.emit()
	queue_free()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()
