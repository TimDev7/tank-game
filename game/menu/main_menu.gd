class_name MainMenu
extends Control
## Главное меню. Строится кодом (как Hud). Правило CrazyGames «сразу в игру или максимум один клик»:
## на экране только две кнопки режима, любая ведёт прямо в матч за один клик/Enter.
## Все строки английские через tr(). Название — рабочее, заменить на финальное.

signal start_requested(vs_ai: bool)

const MATCH_SCENE := "res://game/match/match.tscn"
const JUICY := preload("res://template/ui/components/juicy_button_component.tscn")
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

@export var game_title: String = "RICOCHET TANKS"
## false — только сообщить сигналом (для автотеста), не менять сцену.
@export var auto_start: bool = true

var play_ai_button: Button
var play_pvp_button: Button
var _starting := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	play_ai_button.grab_focus()


func start(vs_ai: bool) -> void:
	if _starting:
		return
	_starting = true
	MatchConfig.vs_ai = vs_ai
	start_requested.emit(vs_ai)
	if auto_start:
		get_tree().change_scene_to_file(MATCH_SCENE)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.13, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# рамка из тайлов арены не нужна — простой тёмный фон и два танка друг против друга
	_add_tank(1, Vector2(210, 430), 0.0)
	_add_tank(2, Vector2(1070, 430), PI)

	var title := _label(game_title, 92, Color.WHITE)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 90.0
	add_child(title)

	var subtitle := _label(tr("Bank your shots off the walls"), 26, Color(0.75, 0.78, 0.75))
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	subtitle.offset_top = 205.0
	add_child(subtitle)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.offset_top = 40.0
	box.add_theme_constant_override("separation", 22)
	add_child(box)

	play_ai_button = _button(tr("PLAY VS COMPUTER"), BLUE)
	play_ai_button.pressed.connect(start.bind(true))
	box.add_child(play_ai_button)
	play_pvp_button = _button(tr("2 PLAYERS"), RED)
	play_pvp_button.pressed.connect(start.bind(false))
	box.add_child(play_pvp_button)

	# фокус: вверх/вниз между кнопками, замыкаем по кругу
	play_ai_button.focus_neighbor_top = play_pvp_button.get_path()
	play_pvp_button.focus_neighbor_bottom = play_ai_button.get_path()

	var hint := _label(tr("Blue: WASD + Space   |   Red: Arrows + Enter   |   P - pause"), 18, Color(0.7, 0.72, 0.7, 0.9))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_bottom = -26.0
	add_child(hint)


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


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(440, 76)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(Color(0.17, 0.2, 0.17), accent.darkened(0.35), 3))
	button.add_theme_stylebox_override("hover", _style(Color(0.22, 0.26, 0.22), accent, 4))
	button.add_theme_stylebox_override("pressed", _style(Color(0.13, 0.15, 0.13), accent, 4))
	button.add_theme_stylebox_override("focus", _style(Color(0.22, 0.26, 0.22), accent.lightened(0.5), 5))
	button.add_child(JUICY.instantiate())
	return button


func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(14)
	return style
