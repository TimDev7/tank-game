extends BaseGame

## Шрифт игры = шрифт логотипа (assets/store/logo.png). Ставится как шрифт темы по умолчанию:
## так он применяется ко всем Control без правки сцен и project.godot.
const GAME_FONT := preload("res://assets/font/marimpa.regular.ttf")


func _ready() -> void:
	ThemeDB.fallback_font = GAME_FONT
	ThemeDB.get_default_theme().default_font = GAME_FONT
	TankInput.register_actions()
	super()
