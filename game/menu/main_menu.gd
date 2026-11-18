class_name MainMenu
extends Control
## Главное меню. Строится кодом (как Hud).
## Страница 1: «PLAY VS COMPUTER» (ведёт на выбор уровня 1-5) и «2 PLAYERS» (сразу в матч).
## Страница 2: выбор уровня — кнопки 1-5 с миниатюрами (клавиши 1-5 тоже работают), «BACK» (Backspace).
## Все строки английские через tr(). Название — рабочее, заменить на финальное.
##
## CrazyGames: для Full Launch «сразу в игру или максимум один клик». Выбор уровня — второй клик
## для режима против компьютера; отключается флагом show_level_select (тогда играется ротация уровней).

signal start_requested(vs_ai: bool, level: int)

const MATCH_SCENE := "res://game/match/match.tscn"
const JUICY := preload("res://template/ui/components/juicy_button_component.tscn")
const THUMB := preload("res://game/menu/level_thumb.gd")
const HULLS := {
	1: preload("res://game/tanks/art/tank_blue_hull.png"),
	2: preload("res://game/tanks/art/tank_red_hull.png"),
}
const TURRETS := {
	1: preload("res://game/tanks/art/tank_blue_turret.png"),
	2: preload("res://game/tanks/art/tank_red_turret.png"),
}
const BLUE := Color(0.45, 0.7, 1.0)
const RED := Color(1.0, 0.45, 0.4)
const NUMBER_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]

@export var game_title: String = "RICOCHET TANKS"
## false — только сообщить сигналом (для автотеста), не менять сцену.
@export var auto_start: bool = true
## true — против компьютера сначала выбор уровня; false — сразу в матч (ротация уровней).
@export var show_level_select: bool = true

var play_ai_button: Button
var play_pvp_button: Button
var back_button: Button
var level_buttons: Array[Button] = []
var main_page: Control
var level_page: Control

var _tanks: Array[Node2D] = []
var _starting := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	show_main_page()


func show_main_page() -> void:
	main_page.visible = true
	level_page.visible = false
	for tank in _tanks:
		tank.visible = true
	play_ai_button.grab_focus()


func show_level_page() -> void:
	main_page.visible = false
	level_page.visible = true
	for tank in _tanks:
		tank.visible = false
	level_buttons[0].grab_focus()


## level: индекс 0..4 — играть только его; -1 — ротация уровней каждый раунд.
func start(vs_ai: bool, level: int = -1) -> void:
	if _starting:
		return
	_starting = true
	MatchConfig.vs_ai = vs_ai
	MatchConfig.level = level
	start_requested.emit(vs_ai, level)
	if auto_start:
		get_tree().change_scene_to_file(MATCH_SCENE)


func _on_play_vs_computer() -> void:
	if show_level_select:
		show_level_page()
	else:
		start(true)


func _unhandled_input(event: InputEvent) -> void:
	if not level_page.visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = (event as InputEventKey).physical_keycode
	if key == KEY_BACKSPACE:
		get_viewport().set_input_as_handled()
		show_main_page()
	elif NUMBER_KEYS.has(key):
		get_viewport().set_input_as_handled()
		start(true, NUMBER_KEYS.find(key))


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.13, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# два танка друг против друга по бокам (абсолютные позиции под 1280x720)
	_add_tank(1, Vector2(210, 470), 0.0)
	_add_tank(2, Vector2(1070, 470), PI)

	# шапка — на обеих страницах одинаковая
	var header := VBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 64.0
	header.offset_bottom = 250.0
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_label(game_title, 92, Color.WHITE))
	header.add_child(_label(tr("Bank your shots off the walls"), 26, Color(0.75, 0.78, 0.75)))
	add_child(header)

	# область страниц под шапкой
	var pages := Control.new()
	pages.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.offset_top = 270.0
	pages.offset_bottom = -64.0
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pages)

	main_page = _page(pages)
	main_page.add_theme_constant_override("separation", 22)
	play_ai_button = _button(tr("PLAY VS COMPUTER"), BLUE, Vector2(440, 76))
	play_ai_button.pressed.connect(_on_play_vs_computer)
	main_page.add_child(play_ai_button)
	play_pvp_button = _button(tr("2 PLAYERS"), RED, Vector2(440, 76))
	play_pvp_button.pressed.connect(start.bind(false, -1))
	main_page.add_child(play_pvp_button)
	# фокус по кругу
	play_ai_button.focus_neighbor_top = play_pvp_button.get_path()
	play_pvp_button.focus_neighbor_bottom = play_ai_button.get_path()

	level_page = _page(pages)
	level_page.add_theme_constant_override("separation", 18)
	level_page.add_child(_label(tr("SELECT LEVEL"), 36, Color.WHITE))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_page.add_child(row)
	for i in Levels.count():
		var button := _level_button(i)
		button.pressed.connect(start.bind(true, i))
		row.add_child(button)
		level_buttons.append(button)
	back_button = _button(tr("BACK"), Color(0.7, 0.72, 0.7), Vector2(240, 56))
	back_button.add_theme_font_size_override("font_size", 26)
	back_button.pressed.connect(show_main_page)
	level_page.add_child(back_button)

	var hint := _label(tr("Blue: WASD + Space   |   Red: Arrows + Enter   |   P - pause"), 18, Color(0.7, 0.72, 0.7, 0.9))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -56.0
	hint.offset_bottom = -26.0
	add_child(hint)


func _page(parent: Control) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(page)
	return page


func _add_tank(player: int, pos: Vector2, rot: float) -> void:
	var holder := Node2D.new()
	holder.position = pos
	holder.rotation = rot
	holder.scale = Vector2(1.7, 1.7)
	for tex in [HULLS[player], TURRETS[player]]:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		holder.add_child(sprite)
	add_child(holder)
	_tanks.append(holder)
	# лёгкое «покачивание», чтобы меню не было мёртвым
	var tween := create_tween().set_loops()
	tween.tween_property(holder, "rotation", rot + 0.05, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(holder, "rotation", rot - 0.05, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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


func _button(text: String, accent: Color, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(button, accent)
	button.add_theme_font_size_override("font_size", 32)
	button.add_child(JUICY.instantiate())
	return button


## Кнопка уровня: номер, миниатюра, название.
func _level_button(index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(204, 196)
	_style_button(button, BLUE if index % 2 == 0 else RED)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label(str(index + 1), 40, Color.WHITE))
	var thumb: Control = THUMB.new()
	thumb.set("level_index", index)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(thumb)
	box.add_child(_label(tr(Levels.level_name(index)), 20, Color(0.85, 0.87, 0.85)))
	button.add_child(box)
	button.add_child(JUICY.instantiate())
	return button


func _style_button(button: Button, accent: Color) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(Color(0.17, 0.2, 0.17), accent.darkened(0.35), 3))
	button.add_theme_stylebox_override("hover", _style(Color(0.22, 0.26, 0.22), accent, 4))
	button.add_theme_stylebox_override("pressed", _style(Color(0.13, 0.15, 0.13), accent, 4))
	button.add_theme_stylebox_override("focus", _style(Color(0.22, 0.26, 0.22), accent.lightened(0.5), 5))


func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(14)
	return style
