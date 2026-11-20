class_name Hud
extends CanvasLayer
## Интерфейс матча, строится кодом: счёт, сообщение по центру, подсказка, оверлей паузы.
## Все строки английские (правило CrazyGames), через tr() для будущих переводов.

## Игрок выбрал уровень в меню паузы (индекс 0..Levels.count()-1).
signal level_selected(index: int)

const BLUE := Color(0.45, 0.7, 1.0)
const RED := Color(1.0, 0.45, 0.4)
const LEVEL_CARD := preload("res://game/match/level_card.gd")

var level_cards: Array[Button] = []

var _blue_label: Label
var _red_label: Label
var _message: Label
var _hint: Label
var _level_label: Label
var _pause_overlay: Control
var _current_level: int = 0
var _message_tween: Tween
var _last_scores := Vector2i.ZERO


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS  # обновляется и на паузе
	_build()


func set_scores(blue: int, red: int) -> void:
	_blue_label.text = "%s  %d" % [tr("BLUE"), blue]
	_red_label.text = "%d  %s" % [red, tr("RED")]
	if blue > _last_scores.x:
		_pop(_blue_label)
	if red > _last_scores.y:
		_pop(_red_label)
	_last_scores = Vector2i(blue, red)


func _pop(label: Label) -> void:
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(1.5, 1.5)
	create_tween().tween_property(label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_message(text: String) -> void:
	if _message_tween:
		_message_tween.kill()
	_message.modulate = Color.WHITE
	_message.scale = Vector2.ONE
	_message.text = text
	_message.visible = not text.is_empty()


## Короткая надпись «FIGHT!»: выпрыгивает, держится и гаснет сама.
func flash_message(text: String) -> void:
	show_message(text)
	_message.pivot_offset = _message.size / 2.0
	_message.scale = Vector2(0.4, 0.4)
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_message_tween.tween_interval(0.35)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.3)
	_message_tween.tween_callback(func(): _message.visible = false)


func set_level(number: int, total: int, level_name: String) -> void:
	_level_label.text = "%s %d/%d  -  %s" % [tr("LEVEL"), number, total, tr(level_name)]
	_current_level = number - 1
	for card in level_cards:
		card.call("set_current", card.get("level_index") == _current_level)


func set_hint(text: String) -> void:
	_hint.text = text


func show_pause(on: bool) -> void:
	_pause_overlay.visible = on
	if on and _current_level < level_cards.size():
		level_cards[_current_level].grab_focus()  # стрелки/Enter работают сразу
	elif not on:
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()  # чтобы Enter/пробел (стрельба) не нажимали скрытую кнопку


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# виньетка: затемнение к краям экрана
	var vignette := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.55))
	grad.set_offset(0, 0.55)
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 144
	vignette.texture = gtex
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)

	# счёт сверху по центру
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 46.0
	box.add_theme_constant_override("separation", 28)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	_blue_label = _make_label(34, BLUE)
	_red_label = _make_label(34, RED)
	var dash := _make_label(34, Color(0.85, 0.85, 0.85))
	dash.text = "-"
	box.add_child(_blue_label)
	box.add_child(dash)
	box.add_child(_red_label)

	# номер и название уровня — слева сверху, внутри рамки арены
	_level_label = _make_label(18, Color(0.8, 0.82, 0.8, 0.85))
	_level_label.position = Vector2(54, 50)
	root.add_child(_level_label)

	# сообщение по центру
	_message = _make_label(54, Color.WHITE)
	_message.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.visible = false
	root.add_child(_message)

	# подсказка снизу (внутри рамки арены, нижняя стена 40 px)
	_hint = _make_label(16, Color(0.8, 0.8, 0.8, 0.9))
	_hint.text = tr("Blue: WASD + Space   |   Red: Arrows + /   |   Esc - pause   |   R - restart round")
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_top = -34.0
	_hint.offset_bottom = -8.0
	root.add_child(_hint)

	# пауза
	_pause_overlay = ColorRect.new()
	(_pause_overlay as ColorRect).color = Color(0, 0, 0, 0.78)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # клики не проваливаются в игру
	_pause_overlay.visible = false
	root.add_child(_pause_overlay)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(column)

	var paused_label := _make_label(64, Color.WHITE)
	paused_label.text = tr("PAUSED")
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(paused_label)
	var select_label := _make_label(30, Color(0.85, 0.87, 0.85))
	select_label.text = tr("SELECT LEVEL")
	select_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(select_label)

	var grid := GridContainer.new()  # 30 уровней: сетка 10 x 3
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(grid)
	for i in Levels.count():
		var card: Button = LEVEL_CARD.new()
		card.call("setup", i, i == _current_level)
		card.pressed.connect(func(): level_selected.emit(i))
		grid.add_child(card)
		level_cards.append(card)

	var keys_label := _make_label(22, Color(0.8, 0.82, 0.8))
	keys_label.text = tr("Esc / P - resume   |   Arrows + Enter or click - level   |   M - menu")
	keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(keys_label)

	set_scores(0, 0)


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", maxi(4, size / 6))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
