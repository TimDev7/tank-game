class_name Hud
extends CanvasLayer
## Интерфейс матча, строится кодом: счёт, сообщение по центру, подсказка, оверлей паузы.
## Все строки английские (правило CrazyGames), через tr() для будущих переводов.

const BLUE := Color(0.45, 0.7, 1.0)
const RED := Color(1.0, 0.45, 0.4)

var _blue_label: Label
var _red_label: Label
var _message: Label
var _pause_overlay: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS  # обновляется и на паузе
	_build()


func set_scores(blue: int, red: int) -> void:
	_blue_label.text = "%s  %d" % [tr("BLUE"), blue]
	_red_label.text = "%d  %s" % [red, tr("RED")]


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = not text.is_empty()


func show_pause(on: bool) -> void:
	_pause_overlay.visible = on


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

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

	# сообщение по центру
	_message = _make_label(54, Color.WHITE)
	_message.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.visible = false
	root.add_child(_message)

	# подсказка снизу (внутри рамки арены, нижняя стена 40 px)
	var hint := _make_label(16, Color(0.8, 0.8, 0.8, 0.9))
	hint.text = tr("Blue: WASD + Space   |   Red: Arrows + Enter   |   P - pause   |   R - restart round")
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_top = -34.0
	hint.offset_bottom = -8.0
	root.add_child(hint)

	# пауза
	_pause_overlay = ColorRect.new()
	(_pause_overlay as ColorRect).color = Color(0, 0, 0, 0.6)
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.visible = false
	var paused_label := _make_label(64, Color.WHITE)
	paused_label.text = tr("PAUSED") + "\n" + tr("Press P to resume")
	paused_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paused_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_overlay.add_child(paused_label)
	root.add_child(_pause_overlay)

	set_scores(0, 0)


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", maxi(4, size / 6))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
