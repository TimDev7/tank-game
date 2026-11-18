class_name MainMenu
extends Control
## Главное меню. Строится кодом (как Hud).
## Живой фон (menu_background.gd) + логотип + две кнопки, любая ведёт сразу в матч за один клик/Enter —
## правило CrazyGames «сразу в игру или максимум один клик». Выбор уровня 1-5 — в меню паузы (Esc).
## Все строки английские через tr(). Название — рабочее, заменить на финальное.

signal start_requested(vs_ai: bool)

const MATCH_SCENE := "res://game/match/match.tscn"
const JUICY := preload("res://template/ui/components/juicy_button_component.tscn")
const BACKGROUND := preload("res://game/menu/menu_background.gd")
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
const GOLD := Color(1.0, 0.78, 0.22)
const MENU_FONT_COLOR := Color(0.93, 0.95, 0.93)

@export var game_title: String = "RICOCHET TANKS"
## false — только сообщить сигналом (для автотеста), не менять сцену.
@export var auto_start: bool = true

var play_ai_button: Button
var play_pvp_button: Button

var _starting := false
var _header: Control
var _buttons_box: Control
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	play_ai_button.grab_focus()
	_play_intro()


func start(vs_ai: bool) -> void:
	if _starting:
		return
	_starting = true
	MatchConfig.vs_ai = vs_ai
	MatchConfig.level = -1  # уровни меняются каждый раунд; зафиксировать можно в меню паузы
	start_requested.emit(vs_ai)
	if auto_start:
		get_tree().change_scene_to_file(MATCH_SCENE)


func _build() -> void:
	add_child(BACKGROUND.new())

	# --- логотип: две строки с тенью + «гусеничная» полоса ---
	var words := game_title.split(" ", false, 1)
	var top_word := words[0]
	var bottom_word := words[1] if words.size() > 1 else ""
	_header = VBoxContainer.new()
	_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_header.offset_top = 22.0
	_header.offset_bottom = 340.0
	_header.add_theme_constant_override("separation", -8)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	_header.add_child(_title_line(top_word, 108, Color.WHITE, Color(0.10, 0.12, 0.16)))
	_header.add_child(_title_line(bottom_word, 138, GOLD, Color(0.36, 0.2, 0.04)))
	var strip := TrackStrip.new()
	strip.custom_minimum_size = Vector2(640, 22)
	strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_header.add_child(strip)

	# --- кнопки ---
	_buttons_box = VBoxContainer.new()
	_buttons_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_buttons_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_buttons_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_buttons_box.offset_bottom = -92.0
	_buttons_box.add_theme_constant_override("separation", 20)
	_buttons_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buttons_box)
	play_ai_button = _mode_button(tr("PLAY VS COMPUTER"), tr("Solo  -  30 levels, crates and ricochets"), BLUE, [1], "AI")
	play_ai_button.pressed.connect(start.bind(true))
	_buttons_box.add_child(play_ai_button)
	play_pvp_button = _mode_button(tr("2 PLAYERS"), tr("Same keyboard  -  WASD vs Arrows"), RED, [1, 2], "")
	play_pvp_button.pressed.connect(start.bind(false))
	_buttons_box.add_child(play_pvp_button)

	# фокус вверх/вниз по кругу
	play_ai_button.focus_neighbor_top = play_pvp_button.get_path()
	play_pvp_button.focus_neighbor_bottom = play_ai_button.get_path()

	# --- подсказка ---
	_hint = _label(tr("Blue: WASD + Space   |   Red: Arrows + Enter   |   Esc - pause / levels"), 18, Color(0.82, 0.85, 0.82, 0.95))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -52.0
	_hint.offset_bottom = -22.0
	add_child(_hint)


## Плавное появление: фон уже живёт, логотип выезжает сверху, кнопки проявляются по очереди.
func _play_intro() -> void:
	_header.modulate.a = 0.0
	var header_y := _header.position.y
	_header.position.y = header_y - 40.0
	play_ai_button.modulate.a = 0.0
	play_pvp_button.modulate.a = 0.0
	_hint.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_header, "modulate:a", 1.0, 0.5)
	tween.tween_property(_header, "position:y", header_y, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(play_ai_button, "modulate:a", 1.0, 0.4).set_delay(0.35)
	tween.tween_property(play_pvp_button, "modulate:a", 1.0, 0.4).set_delay(0.5)
	tween.tween_property(_hint, "modulate:a", 1.0, 0.4).set_delay(0.7)


func _title_line(text: String, size: int, color: Color, shadow: Color) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, size + 40)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for layer in [[Vector2(0, 8), shadow, 0], [Vector2.ZERO, color, 14]]:  # тень, затем сам текст
		var label := _label(text, size, layer[1])
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_top = layer[0].y
		label.offset_bottom = layer[0].y
		if layer[2] > 0:
			label.add_theme_constant_override("outline_size", layer[2])
			label.add_theme_color_override("font_outline_color", shadow.darkened(0.4))
		else:
			label.add_theme_constant_override("outline_size", 14)
			label.add_theme_color_override("font_outline_color", shadow)
		holder.add_child(label)
	return holder


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


## Кнопка режима: мини-танки слева, название и подпись справа.
func _mode_button(title: String, subtitle: String, accent: Color, tank_players: Array, badge: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(620, 96)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", _style(Color(0.08, 0.10, 0.09, 0.82), accent.darkened(0.3), 3, accent, 12))
	button.add_theme_stylebox_override("hover", _style(Color(0.14, 0.18, 0.15, 0.92), accent, 4, accent, 14))
	button.add_theme_stylebox_override("pressed", _style(Color(0.05, 0.07, 0.06, 0.95), accent, 4, accent, 14))
	button.add_theme_stylebox_override("focus", _style(Color(0.14, 0.18, 0.15, 0.92), accent.lightened(0.55), 5, accent.lightened(0.2), 14))
	button.add_child(JUICY.instantiate())  # анимация нажатия из шаблона (первый ребёнок)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	row.offset_left = 30.0
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_tank_icon(tank_players, badge))
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label(title, 34, MENU_FONT_COLOR)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(name_label)
	var sub_label := _label(subtitle, 17, Color(0.72, 0.76, 0.72))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(sub_label)
	row.add_child(texts)
	button.add_child(row)
	return button


## Мини-танки: [1] — синий (+ бейдж «AI»), [1, 2] — синий и красный лицом друг к другу.
func _tank_icon(players: Array, badge: String) -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(132, 52)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := 0.38  # масштаб мини-танка
	for i in players.size():
		var player: int = players[i]
		var cx := 34.0 + i * 64.0
		for pair in [[HULLS[player], Vector2(96, 64)], [TURRETS[player], Vector2(160, 64)]]:
			var rect := TextureRect.new()
			rect.texture = pair[0]
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.size = pair[1] * k
			rect.position = Vector2(cx, 26.0) - rect.size / 2.0
			rect.pivot_offset = rect.size / 2.0
			rect.rotation = 0.0 if i == 0 else PI
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(rect)
	if not badge.is_empty():
		var tag := _label(badge, 20, Color(1.0, 0.85, 0.4))
		tag.add_theme_stylebox_override("normal", _style(Color(0.2, 0.16, 0.05, 0.9), Color(1.0, 0.78, 0.22), 2, Color.TRANSPARENT, 0))
		tag.position = Vector2(84, 10)
		tag.size = Vector2(44, 32)
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_child(tag)
	return icon


## accent_bar — толщина цветной планки слева (0 — без неё).
func _style(fill: Color, border: Color, width: int, accent_bar_color: Color, accent_bar: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	if accent_bar > 0:
		style.border_width_left = accent_bar
		style.border_color = accent_bar_color if accent_bar_color.a > 0.0 else border
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


## Декоративная «гусеничная» полоса под логотипом.
class TrackStrip extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.07, 0.08, 0.08, 0.95))
		draw_rect(Rect2(0, 0, w, h), Color(1.0, 0.78, 0.22, 0.9), false, 2.0)
		var x := 8.0
		while x < w - 8.0:
			draw_rect(Rect2(x, 4.0, 10.0, h - 8.0), Color(0.3, 0.32, 0.34, 0.95))
			draw_rect(Rect2(x, 4.0, 10.0, 2.0), Color(0.55, 0.58, 0.6, 0.9))
			x += 16.0
