class_name Tank
extends CharacterBody2D
## ЗАГЛУШКА танка для PvP-прототипа (позже заменяется танком Тимура с тем же контрактом).
##
## Управление «как в Tank Trouble»: влево/вправо — поворот корпуса, вверх/вниз — вперёд/назад.
## Башня пока жёстко смотрит по корпусу (независимый поворот башни — задача Тимура).
##
## Контракт для остального кода (менеджер раунда, пули, ИИ):
##   var player_index: int       1 — синий (наш), 2 — красный (враг)
##   var alive: bool
##   var controls_enabled: bool  false между раундами/на паузе
##   signal fired(tank, muzzle_position, direction)   — пули создаёт тот, кто слушает сигнал
##   signal died(tank)
##   func die() / func respawn(at: Transform2D)
## Физика — только в _physics_process (одинаково на 60/144 Гц, правила CrazyGames).

signal fired(tank: Tank, muzzle_position: Vector2, direction: Vector2)
signal died(tank: Tank)

const HULL_REGIONS := {1: "tank_blue_hull", 2: "tank_red_hull"}
const TURRET_REGIONS := {1: "tank_blue_turret", 2: "tank_red_turret"}

@export_range(1, 2) var player_index: int = 1:
	set(value):
		player_index = value
		_apply_skin()
## Арт танка рисован 88x58; в игре уменьшается до размера ящика (~40 px в длину).
const BODY_SCALE := 0.45

@export var move_speed: float = 240.0
@export var reverse_speed_factor: float = 0.6
@export var turn_speed: float = 4.2  ## рад/с
@export var fire_cooldown: float = 0.45

var alive: bool = true
var controls_enabled: bool = true
var brain: TankBrain  ## null — управляет человек (TankInput); иначе ИИ

var _cooldown_left: float = 0.0
var _engine: AudioStreamPlayer
var _dust_timer: float = 0.0

const DUST_COLORS := {1: Color(0.75, 0.82, 0.9, 0.5), 2: Color(0.9, 0.78, 0.74, 0.5)}

@onready var _hull: Sprite2D = $Hull
@onready var _turret: Sprite2D = $Turret
@onready var _muzzle: Marker2D = $Muzzle
@onready var _body: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = 1 << (PhysicsLayers.TANK - 1)
	collision_mask = (1 << (PhysicsLayers.WALL - 1)) | (1 << (PhysicsLayers.TANK - 1)) | (1 << (PhysicsLayers.CRATE - 1))
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_apply_body_scale()
	_apply_skin()
	var arena := get_parent() as Arena
	if arena:
		arena.get_shadow_layer().track(_hull, ShadowLayer.HULL_OFFSET)
		arena.get_shadow_layer().track(_turret, ShadowLayer.TURRET_OFFSET)
	var engine_stream := GameAudio.stream("engine")
	if engine_stream:
		_engine = AudioStreamPlayer.new()
		_engine.stream = engine_stream
		_engine.bus = &"SFX"
		_engine.volume_db = -80.0
		add_child(_engine)
		_engine.play()


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if not alive or not controls_enabled:
		velocity = Vector2.ZERO
		_update_engine(0.0, 0.0, delta)
		return

	var cmd := _read_command(delta)
	rotation += float(cmd.turn) * turn_speed * delta
	var throttle: float = cmd.throttle
	var speed := move_speed * (reverse_speed_factor if throttle < 0.0 else 1.0)
	velocity = Vector2.RIGHT.rotated(rotation) * throttle * speed
	var intended := velocity
	move_and_slide()
	_push_crates(intended)
	_update_engine(absf(throttle), absf(float(cmd.turn)), delta)

	if cmd.fire and _cooldown_left <= 0.0:
		_cooldown_left = fire_cooldown
		fired.emit(self, _muzzle.global_position, Vector2.RIGHT.rotated(_turret.global_rotation))


## Гул двигателя (громче и выше при езде) и пыль из-под гусениц.
func _update_engine(throttle: float, turning: float, delta: float) -> void:
	var load_amount := clampf(throttle + turning * 0.5, 0.0, 1.0)
	if _engine:
		var target_db := lerpf(-34.0, -17.0, load_amount) if alive else -80.0
		_engine.volume_db = lerpf(_engine.volume_db, target_db, minf(1.0, delta * 8.0))
		_engine.pitch_scale = lerpf(_engine.pitch_scale, 0.85 + load_amount * 0.5 + (0.08 if player_index == 2 else 0.0), minf(1.0, delta * 6.0))
	_dust_timer -= delta
	var fx_root := Fx.root(self) if throttle > 0.1 and _dust_timer <= 0.0 else null
	if fx_root:
		_dust_timer = 0.07
		var back := -Vector2.RIGHT.rotated(rotation) * 14.0
		Fx.dust(fx_root, global_position + back, DUST_COLORS[player_index])


## Ящик, в который упёрлись, едет в сторону давления (составляющая скорости в ящик); вдоль грани танк скользит.
func _push_crates(intended: Vector2) -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var crate := hit.get_collider() as Crate
		if crate == null:
			continue
		var into := -hit.get_normal()
		var speed := intended.dot(into)
		if speed > 1.0:
			crate.push(into * speed)


## Команда кадра: turn (-1..1, + вправо), throttle (-1..1, + вперёд), fire.
func _read_command(delta: float) -> Dictionary:
	if brain != null:
		return brain.think(self, delta)
	var input := TankInput.move_vector(player_index)  # x: поворот, y: -1 вперёд / +1 назад
	return {
		"turn": input.x,
		"throttle": -input.y,
		"fire": Input.is_action_pressed(TankInput.action(player_index, "fire")),
	}


func die() -> void:
	if not alive:
		return
	alive = false
	visible = false
	if _engine:
		_engine.volume_db = -80.0
	_body.set_deferred("disabled", true)
	died.emit(self)


## Ставит танк в точку (позиция + поворот), оживляет и сбрасывает кулдаун.
func respawn(at: Transform2D) -> void:
	global_transform = at
	velocity = Vector2.ZERO
	alive = true
	visible = true
	_cooldown_left = 0.0
	_body.set_deferred("disabled", false)
	if brain != null:
		brain.reset()


func _apply_body_scale() -> void:
	_hull.scale = Vector2.ONE * BODY_SCALE
	_turret.scale = Vector2.ONE * BODY_SCALE
	_muzzle.position *= BODY_SCALE
	var rect := RectangleShape2D.new()
	rect.size = (_body.shape as RectangleShape2D).size * BODY_SCALE
	_body.shape = rect


func _apply_skin() -> void:
	if not is_node_ready():
		return
	_hull.texture = GameAtlas.tex(HULL_REGIONS[player_index])
	_turret.texture = GameAtlas.tex(TURRET_REGIONS[player_index])
