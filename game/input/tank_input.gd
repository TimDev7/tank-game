class_name TankInput
extends RefCounted
## Раскладки двух игроков + общие действия. Действия регистрируются кодом при старте
## (не в project.godot), чтобы не конфликтовать с открытым редактором.
##
## Правила CrazyGames (docs/crazygames-requirements.md):
## - Используем physical_keycode: WASD остаётся в тех же физических позициях на AZERTY/QWERTZ (там это ZQSD/WASD).
## - Esc НЕ используем: он выходит из fullscreen. Пауза — P.
## - Fullscreen-кнопок своих нет: его даёт платформа.
##
## Имена действий: "p1_up", "p1_down", "p1_left", "p1_right", "p1_fire" (то же для p2_*),
## а также "pause" и "restart_round".

const PLAYER_COUNT := 2
const MOVES := ["up", "down", "left", "right"]

const LAYOUTS := {
	1: {
		"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
		"fire": KEY_SPACE,
	},
	2: {
		"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
		"fire": KEY_ENTER,
	},
}

const SHARED := {
	"pause": KEY_P,
	"restart_round": KEY_R,
	"menu": KEY_M,  # в главное меню: только из паузы или после конца матча
}


static func action(player: int, name: String) -> StringName:
	return StringName("p%d_%s" % [player, name])


## Идемпотентно: можно вызывать повторно.
static func register_actions() -> void:
	for player in LAYOUTS:
		for name in LAYOUTS[player]:
			_bind(action(player, name), LAYOUTS[player][name])
	for name in SHARED:
		_bind(StringName(name), SHARED[name])


## Вектор движения игрока: x — поворот (-1 влево, 1 вправо), y — газ (-1 вперёд/up, 1 назад/down).
static func move_vector(player: int) -> Vector2:
	return Input.get_vector(
		action(player, "left"), action(player, "right"),
		action(player, "up"), action(player, "down"))


static func _bind(action_name: StringName, physical_key: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and existing.physical_keycode == physical_key:
			return
	var event := InputEventKey.new()
	event.physical_keycode = physical_key
	InputMap.action_add_event(action_name, event)
