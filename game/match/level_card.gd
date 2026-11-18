extends Button
## Компактная карточка уровня для меню паузы (30 штук в сетке): номер, миниатюра карты, название.
## Подключается через preload (без class_name): LevelCard = preload("res://game/match/level_card.gd").

const JUICY := preload("res://template/ui/components/juicy_button_component.tscn")
const THUMB := preload("res://game/menu/level_thumb.gd")
const BLUE := Color(0.45, 0.7, 1.0)
const RED := Color(1.0, 0.45, 0.4)
const CARD_SIZE := Vector2(112, 100)
const THUMB_SIZE := Vector2(96, 54)

var level_index: int = 0
var _accent: Color


func setup(index: int, current: bool = false) -> void:
	level_index = index
	_accent = BLUE if index % 2 == 0 else RED
	custom_minimum_size = CARD_SIZE
	focus_mode = Control.FOCUS_ALL
	process_mode = Node.PROCESS_MODE_ALWAYS  # работает на паузе
	tooltip_text = "%d - %s" % [index + 1, tr(Levels.level_name(index))]

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label(str(index + 1), 22, false))
	var thumb: Control = THUMB.new()
	thumb.set("level_index", index)
	thumb.custom_minimum_size = THUMB_SIZE
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(thumb)
	box.add_child(_label(tr(Levels.level_name(index)), 12, true))
	add_child(box)
	add_child(JUICY.instantiate())
	set_current(current)


## Подсветка уровня, на котором идёт игра.
func set_current(on: bool) -> void:
	var fill := Color(0.20, 0.25, 0.20) if on else Color(0.17, 0.2, 0.17)
	var border := _accent.lightened(0.25) if on else _accent.darkened(0.35)
	add_theme_stylebox_override("normal", _style(fill, border, 4 if on else 2))
	add_theme_stylebox_override("hover", _style(Color(0.22, 0.26, 0.22), _accent, 3))
	add_theme_stylebox_override("pressed", _style(Color(0.13, 0.15, 0.13), _accent, 3))
	add_theme_stylebox_override("focus", _style(Color(0.22, 0.26, 0.22), _accent.lightened(0.5), 4))


func _label(text: String, size: int, trim: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if trim:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size = Vector2(CARD_SIZE.x - 8, 0)
	return label


func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	return style
