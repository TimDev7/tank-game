class_name Fx
extends RefCounted
## Визуальные эффекты на частицах (CPUParticles2D — работают и в Web-сборке без проблем).
## Все функции статические: создают одноразовый узел в parent и сами его удаляют.


## Корень для эффектов (создаёт RoundManager, группа "fx_root"); без него — запасной узел.
## Отдельно от Bullets: RoundManager считает детей Bullets пулями.
static func root(from: Node, fallback: Node = null) -> Node:
	var found := from.get_tree().get_first_node_in_group(&"fx_root") if from.is_inside_tree() else null
	return found if found != null else fallback


static func _burst(parent: Node, pos: Vector2, amount: int, life: float, speed_min: float, speed_max: float,
		size_min: float, size_max: float, color: Color, spread: float = 180.0, direction: Vector2 = Vector2.RIGHT,
		damping: float = 0.0) -> CPUParticles2D:
	var fx := CPUParticles2D.new()
	fx.position = pos
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.amount = amount
	fx.lifetime = life
	fx.direction = direction
	fx.spread = spread
	fx.gravity = Vector2.ZERO
	fx.initial_velocity_min = speed_min
	fx.initial_velocity_max = speed_max
	fx.damping_min = damping
	fx.damping_max = damping * 1.4
	fx.scale_amount_min = size_min / 16.0
	fx.scale_amount_max = size_max / 16.0
	fx.color = color
	fx.texture = GameAtlas.tex("fx_puff")  # пиксельный «пух» из единого атласа; размер частицы задаём масштабом
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fx.color_ramp = fade
	parent.add_child(fx)
	fx.emitting = true
	fx.finished.connect(fx.queue_free)
	return fx


static func muzzle_flash(parent: Node, pos: Vector2, dir: Vector2, color: Color) -> void:
	_burst(parent, pos, 8, 0.18, 90.0, 240.0, 2.0, 4.5, Color(1.0, 0.9, 0.55), 28.0, dir, 60.0)
	_burst(parent, pos, 4, 0.12, 20.0, 70.0, 5.0, 8.0, color.lerp(Color.WHITE, 0.5), 40.0, dir, 40.0)


static func spark(parent: Node, pos: Vector2, normal: Vector2) -> void:
	_burst(parent, pos, 7, 0.22, 70.0, 200.0, 1.6, 3.0, Color(1.0, 0.93, 0.65), 55.0, normal, 40.0)


static func dust(parent: Node, pos: Vector2, color: Color) -> void:
	_burst(parent, pos, 2, 0.45, 6.0, 22.0, 2.5, 4.5, color, 180.0, Vector2.RIGHT, 20.0)


static func explosion(parent: Node, pos: Vector2, team_color: Color) -> void:
	_burst(parent, pos, 26, 0.7, 60.0, 280.0, 3.5, 8.0, Color(1.0, 0.55, 0.12), 180.0, Vector2.RIGHT, 90.0)
	_burst(parent, pos, 16, 0.5, 40.0, 200.0, 2.5, 6.0, Color(1.0, 0.9, 0.5), 180.0, Vector2.RIGHT, 80.0)
	_burst(parent, pos, 14, 1.1, 15.0, 90.0, 7.0, 13.0, Color(0.16, 0.16, 0.18, 0.8), 180.0, Vector2.RIGHT, 35.0)
	_burst(parent, pos, 12, 0.9, 80.0, 230.0, 2.0, 4.5, team_color, 180.0, Vector2.RIGHT, 70.0)
	var ring := _Ring.new()
	ring.position = pos
	parent.add_child(ring)
	var scorch := _Scorch.new()
	scorch.position = pos
	scorch.z_index = -1
	parent.add_child(scorch)


## Расходящееся кольцо ударной волны.
class _Ring extends Node2D:
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta / 0.35
		if _t >= 1.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 8.0 + 52.0 * k, 0.0, TAU, 40, Color(1.0, 0.85, 0.5, 1.0 - k), 4.0 * (1.0 - k) + 1.0)
		draw_circle(Vector2.ZERO, 22.0 * (1.0 - k), Color(1, 1, 1, 0.8 * (1.0 - k)))


## Закопчённое пятно на месте подбитого танка; тает к концу раунда.
class _Scorch extends Node2D:
	func _ready() -> void:
		var tween := create_tween()
		tween.tween_interval(2.5)
		tween.tween_property(self, "modulate:a", 0.0, 2.0)
		tween.tween_callback(queue_free)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.28))
		draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.32))
