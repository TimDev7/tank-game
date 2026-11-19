class_name Crate
extends CharacterBody2D
## Ящик: танк двигает его, наезжая; упирается в стены, танки и другие ящики (цепочку ящиков можно толкать
## вместе); пуля разбивает ящик вдребезги, и он пропадает. Строится кодом (без .tscn).
##
## Виды (спрайты в art/crates.png): 0 дерево, 1 металл, 2 армейский, 3 «опасность».
## Физика только в _physics_process (одинаково на 60/144 Гц).

const ART_SIZE := 36.0  ## размер ячейки в спрайт-листе
const SIZE := 40.0  ## размер в игре = клетка арены = длина танка
const SHEET := preload("res://game/arena/art/crates.png")
const DEBRIS_COLORS := [
	Color(0.69, 0.49, 0.28), Color(0.62, 0.68, 0.76), Color(0.42, 0.52, 0.30), Color(0.92, 0.72, 0.14),
]
const MAX_PUSH_SPEED := 190.0
const FRICTION := 1100.0  ## px/с² — после отпускания ящик быстро останавливается

@export_range(0, 3) var variant: int = 0

var alive: bool = true

var _push_velocity := Vector2.ZERO
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1 << (PhysicsLayers.CRATE - 1)
	collision_mask = (1 << (PhysicsLayers.WALL - 1)) | (1 << (PhysicsLayers.TANK - 1)) | (1 << (PhysicsLayers.CRATE - 1))
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(&"crates")

	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(variant * ART_SIZE, 0, ART_SIZE, ART_SIZE)
	sprite.texture = atlas
	sprite.scale = Vector2.ONE * (SIZE / ART_SIZE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(SIZE, SIZE)
	_shape.shape = rect
	add_child(_shape)


## Толчок: ящик едет со скоростью толкающего, пока тот давит; потом тормозит сам.
func push(velocity_in: Vector2) -> void:
	if alive:
		_push_velocity = velocity_in.limit_length(MAX_PUSH_SPEED)


func _physics_process(delta: float) -> void:
	if not alive or _push_velocity == Vector2.ZERO:
		return
	var collision := move_and_collide(_push_velocity * delta)
	if collision:
		var other := collision.get_collider()
		if other is Crate:
			(other as Crate).push(_push_velocity)  # цепочка ящиков едет вместе
		_push_velocity = Vector2.ZERO
		return
	_push_velocity = _push_velocity.move_toward(Vector2.ZERO, FRICTION * delta)


## Разбить ящик (попадание пули): брызги обломков, и ящик исчезает.
func destroy() -> void:
	if not alive:
		return
	alive = false
	_shape.set_deferred("disabled", true)
	_spawn_debris()
	queue_free()


func _spawn_debris() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fx := CPUParticles2D.new()
	fx.position = position
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.amount = 14
	fx.lifetime = 0.6
	fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	fx.emission_sphere_radius = 9.0
	fx.spread = 180.0
	fx.gravity = Vector2.ZERO
	fx.initial_velocity_min = 80.0
	fx.initial_velocity_max = 200.0
	fx.damping_min = 90.0
	fx.damping_max = 140.0
	fx.scale_amount_min = 2.5
	fx.scale_amount_max = 5.5
	fx.angular_velocity_min = -540.0
	fx.angular_velocity_max = 540.0
	fx.color = DEBRIS_COLORS[variant]
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fx.color_ramp = fade
	parent.add_child(fx)
	fx.emitting = true
	fx.finished.connect(fx.queue_free)
