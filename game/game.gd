extends BaseGame

## Шрифт игры = шрифт логотипа (assets/store/logo.png). Ставится как шрифт темы по умолчанию:
## так он применяется ко всем Control без правки сцен и project.godot.
const GAME_FONT := preload("res://assets/font/marimpa.regular.ttf")


func _ready() -> void:
	ThemeDB.fallback_font = GAME_FONT
	ThemeDB.get_default_theme().default_font = GAME_FONT
	TankInput.register_actions()
	super()
	get_tree().node_added.connect(_on_node_added)


## Звуки интерфейса для ВСЕХ кнопок игры без правки сцен: ловим появление кнопок в дереве.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		button.pressed.connect(GameAudio.sfx.bind("ui_click", 0.6, 0.05))
		button.mouse_entered.connect(GameAudio.sfx.bind("ui_hover", 0.35, 0.05))
		button.focus_entered.connect(GameAudio.sfx.bind("ui_hover", 0.35, 0.05))
