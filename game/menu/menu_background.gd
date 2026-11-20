extends Node2D
## Живой фон главного меню: стальной пол арены, рамка из тайлов, ящики по углам, декали, два танка,
## которые по очереди стреляют, и пули, рикошетящие по экрану со светящимся следом.
## Только оформление (подключается через preload, без class_name). Рисуется целиком в _draw.

const FLOOR_REGION := "floor_3"
const HULLS := {1: "tank_blue_hull", 2: "tank_red_hull"}  ## регионы единого атласа
const TURRETS := {1: "tank_blue_turret", 2: "tank_red_turret"}
const SIZE := Vector2(1280, 720)
const TILE := 40
const STEEL_THEME := 3
const BOUNDS := Rect2(52, 52, 1176, 616)  ## куда летят и где отскакивают пули (внутри рамки)
const BULLET_SPEED := 340.0
const TRAIL_POINTS := 26
const TANK_SCALE := 1.8
const FIRE_INTERVAL := 2.1
const SHOT_COLORS := {1: Color(0.55, 0.78, 1.0), 2: Color(1.0, 0.55, 0.45)}

var _shots: Array = []  # словари: pos, vel, trail, color, alive, life, bounces (без типа: filter() возвращает Array)
var _flashes: Array = []
var _tanks: Dictionary = {}
var _fire_timer: float = 1.0
var _next_shooter: int = 1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 424242
	_tanks[1] = _make_tank(1, Vector2(170, 470), 0.0)
	_tanks[2] = _make_tank(2, Vector2(1110, 470), PI)
	_add_vignette()


func _process(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = FIRE_INTERVAL
		_fire(_next_shooter)
		_next_shooter = 3 - _next_shooter
	for shot in _shots:
		_step_shot(shot, delta)
	_shots = _shots.filter(func(s): return not s.trail.is_empty())
	for flash in _flashes:
		flash.time -= delta
	_flashes = _flashes.filter(func(f): return f.time > 0.0)
	queue_redraw()


func _draw() -> void:
	# пол + затемнение
	draw_texture_rect(GameAtlas.standalone(FLOOR_REGION), Rect2(Vector2.ZERO, SIZE), true)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, 0.42))

	# декали на полу (фиксированный узор)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 14:
		var pos := Vector2(rng.randf_range(90, 1190), rng.randf_range(90, 630))
		var kind := rng.randi_range(0, 5)
		draw_set_transform(pos, rng.randf_range(0.0, TAU), Vector2.ONE * rng.randf_range(1.0, 1.7))
		draw_texture_rect(GameAtlas.cell("decals", kind, Vector2(40, 40)), Rect2(-20, -20, 40, 40), false, Color(1, 1, 1, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# рамка из стальных тайлов
	for x in int(SIZE.x / TILE):
		_draw_wall_tile(Vector2(x, 0))
		_draw_wall_tile(Vector2(x, SIZE.y / TILE - 1))
	for y in range(1, int(SIZE.y / TILE) - 1):
		_draw_wall_tile(Vector2(0, y))
		_draw_wall_tile(Vector2(SIZE.x / TILE - 1, y))

	# ящики по углам
	for crate in [[Vector2(58, 58), 0], [Vector2(130, 58), 1], [Vector2(1150, 58), 2], [Vector2(1078, 58), 3],
			[Vector2(58, 590), 3], [Vector2(130, 590), 2], [Vector2(1150, 590), 0], [Vector2(1078, 590), 1]]:
		var rect := Rect2(crate[0], Vector2(72, 72))
		draw_rect(Rect2(rect.position + Vector2(5, 7), rect.size), Color(0, 0, 0, 0.35))  # тень
		draw_texture_rect(GameAtlas.cell("crates", crate[1], Vector2(36, 36)), rect, false)

	# следы и пули
	for shot in _shots:
		var trail: Array = shot.trail
		var color: Color = shot.color
		for i in range(1, trail.size()):
			var t := float(i) / trail.size()
			draw_line(trail[i - 1], trail[i], Color(color, 0.9 * t), 2.0 + 6.0 * t)
		if shot.alive:
			draw_circle(shot.pos, 8.0, Color(color, 0.25))
			draw_circle(shot.pos, 6.5, Color(0.05, 0.05, 0.07, 0.9))
			draw_circle(shot.pos, 5.0, color)
			draw_circle(shot.pos + Vector2(-1.5, -1.5), 2.0, Color(1, 1, 1, 0.8))
	for flash in _flashes:
		var k: float = flash.time / 0.16
		draw_circle(flash.pos, 20.0 * k + 6.0, Color(1.0, 0.85, 0.4, 0.8 * k))
		draw_circle(flash.pos, 10.0 * k + 3.0, Color(1, 1, 1, k))


func _draw_wall_tile(cell: Vector2) -> void:
	var variant := posmod(int(cell.x) * 7 + int(cell.y) * 13, 3)
	draw_texture_rect(GameAtlas.tex("tiles", Rect2(STEEL_THEME * TILE, variant * TILE, TILE, TILE)), Rect2(cell * TILE, Vector2(TILE, TILE)), false)


func _make_tank(player: int, pos: Vector2, rot: float) -> Node2D:
	var holder := Node2D.new()
	holder.position = pos
	holder.rotation = rot
	holder.scale = Vector2.ONE * TANK_SCALE
	for tex in [GameAtlas.tex(HULLS[player]), GameAtlas.tex(TURRETS[player])]:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # танки гладкие, как в игре
		holder.add_child(sprite)
	add_child(holder)
	# лёгкое покачивание
	var tween := create_tween().set_loops()
	tween.tween_property(holder, "rotation", rot + 0.04, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(holder, "rotation", rot - 0.04, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return holder


func _fire(player: int) -> void:
	var tank: Node2D = _tanks[player]
	var facing := Vector2.RIGHT.rotated(0.0 if player == 1 else PI)
	var angle := _rng.randf_range(0.28, 0.75) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var dir := facing.rotated(angle)
	var muzzle := tank.position + facing * 78.0 * TANK_SCALE
	_shots.append({
		"pos": muzzle, "vel": dir * BULLET_SPEED, "trail": [muzzle] as Array, "color": SHOT_COLORS[player],
		"alive": true, "life": 9.0, "bounces": 0,
	})
	_flashes.append({"pos": muzzle, "time": 0.16})
	# отдача
	var home := tank.position
	var tween := create_tween()
	tween.tween_property(tank, "position", home - facing * 12.0, 0.06)
	tween.tween_property(tank, "position", home, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _step_shot(shot: Dictionary, delta: float) -> void:
	var trail: Array = shot.trail
	if shot.alive:
		shot.life -= delta
		var pos: Vector2 = shot.pos + shot.vel * delta
		var vel: Vector2 = shot.vel
		if pos.x < BOUNDS.position.x or pos.x > BOUNDS.end.x:
			vel.x = -vel.x
			pos.x = clampf(pos.x, BOUNDS.position.x, BOUNDS.end.x)
			shot.bounces += 1
		if pos.y < BOUNDS.position.y or pos.y > BOUNDS.end.y:
			vel.y = -vel.y
			pos.y = clampf(pos.y, BOUNDS.position.y, BOUNDS.end.y)
			shot.bounces += 1
		shot.pos = pos
		shot.vel = vel
		trail.append(pos)
		if shot.life <= 0.0 or shot.bounces > 7:
			shot.alive = false
	# след догоняет: короткий хвост, а после гибели пули тает целиком
	var limit := TRAIL_POINTS if shot.alive else 0
	while trail.size() > limit:
		trail.pop_front()
		if not shot.alive:
			break


func _add_vignette() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.0))
	gradient.set_color(1, Color(0, 0, 0, 0.72))
	gradient.set_offset(0, 0.45)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.95)
	texture.width = 256
	texture.height = 144
	var rect := TextureRect.new()
	rect.texture = texture
	rect.size = SIZE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
