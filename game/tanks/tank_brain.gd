class_name TankBrain
extends RefCounted
## ИИ танка: вместо клавиатуры выдаёт команду {turn, throttle, fire} (как TankInput).
##
## - Путь: AStarGrid2D по сетке Walls; клетки вокруг стен «раздуты» на 1 клетку (танк 88x58).
## - При прямой видимости цели: разворот и стрельба (с упреждением), иначе движение по пути.
## - Уворачивается от пуль, летящих в танк, выбирается из заклинивания (реверс с поворотом).
## Физика только в _physics_process танка: think() зовётся оттуда (одинаково на любой частоте).

const ARRIVE_DISTANCE := 34.0
const HOLD_DISTANCE := 300.0  ## при видимости ближе этого — не подъезжаем дальше
const STUCK_CHECK := 1.0
const STUCK_MIN_MOVE := 10.0
const EVADE_LOOKAHEAD := 0.75  ## с
const EVADE_LATERAL := 60.0  ## px от траектории пули
const INFLATE_CELLS := 1
const THREAT_RADIUS := 30.0  ## пуля, пролетающая ближе этого к центру танка, считается опасной
const THREAT_HORIZON := 1.6  ## с - на сколько вперёд считаем траекторию пули (с рикошетами); при сближении лоб в лоб время до попадания вдвое короче
const DODGE_TIME := 0.4
const BANK_STEP := 0.0349066  ## 2 градуса: шаг перебора углов для выстрела с рикошетом
const BANK_MAX_LENGTH := 850.0
const BANK_MAX_BOUNCES := 2
const BANK_INTERVAL := 0.35

# «характер» — можно менять для уровней сложности
var reaction_time: float = 0.12  ## сколько цель должна быть на линии огня до первого выстрела
var aim_tolerance: float = 0.09  ## рад
var fire_range: float = 780.0
var lead_factor: float = 0.9  ## 0 — без упреждения
var repath_interval: float = 0.3

var _arena: Arena
var _target: Tank
var _bullets_root: Node2D
var _walls: TileMapLayer
var _astar: AStarGrid2D
var _path: Array[Vector2] = []
var _repath_left: float = 0.0
var _los_time: float = 0.0
var _evade_left: float = 0.0
var _evade_heading: float = 0.0
var _evade_threat_dir: Vector2 = Vector2.ZERO
var _reverse_left: float = 0.0
var _reverse_turn: float = 1.0
var _stuck_timer: float = 0.0
var _stuck_origin: Vector2 = Vector2.ZERO
var _stuck_throttle_sum: float = 0.0
var _rng := RandomNumberGenerator.new()
var _bank_left: float = 0.0
var _bank_angle: float = NAN  ## NAN - подходящего выстрела с рикошетом нет
var _bank_time: float = 0.0


func setup(arena: Arena, target: Tank, bullets_root: Node2D) -> void:
	_arena = arena
	_target = target
	_bullets_root = bullets_root
	_walls = arena.walls
	_rng.randomize()
	_build_grid()


## Пересобрать сетку поиска пути после смены уровня арены.
func rebuild() -> void:
	_build_grid()
	reset()


func reset() -> void:
	_path.clear()
	_repath_left = 0.0
	_los_time = 0.0
	_evade_left = 0.0
	_reverse_left = 0.0
	_stuck_timer = 0.0
	_bank_left = 0.0
	_bank_angle = NAN
	_bank_time = 0.0


## Команда на этот физический кадр: {"turn": -1..1, "throttle": -1..1, "fire": bool}
func think(tank: Tank, delta: float) -> Dictionary:
	var cmd := {"turn": 0.0, "throttle": 0.0, "fire": false}
	if _target == null or not _target.alive:
		return cmd

	_update_stuck(tank, delta)
	if _reverse_left > 0.0:
		_reverse_left -= delta
		cmd.turn = _reverse_turn
		cmd.throttle = -1.0
		return cmd

	var threat := _find_threat(tank)
	if not threat.is_empty():
		# сторону уклонения выбираем один раз и держим: пересчёт каждый кадр даёт дрожь «вверх-вниз» на месте
		if _evade_left <= 0.0 or absf(threat.direction.angle_to(_evade_threat_dir)) > 0.6:
			_evade_heading = _pick_dodge_heading(tank, threat.direction)
			_evade_threat_dir = threat.direction
		_evade_left = DODGE_TIME
	if _evade_left > 0.0:
		_evade_left -= delta
		_move_toward(tank, _evade_heading, cmd)
		# отстреливаемся на ходу, если случайно смотрим на цель
		var to_enemy := (_target.global_position - tank.global_position).angle()
		cmd.fire = _line_of_sight(tank) and absf(wrapf(to_enemy - tank.rotation, -PI, PI)) < aim_tolerance
		return cmd

	var to_target := _target.global_position - tank.global_position
	var distance := to_target.length()
	var has_los := _line_of_sight(tank)
	_los_time = _los_time + delta if has_los else 0.0

	if has_los:
		var aim_point := _target.global_position + _target.velocity * (distance / Bullet.SPEED) * lead_factor
		var aim := (aim_point - tank.global_position).angle()
		var advance := 1.0 if distance > HOLD_DISTANCE else 0.0
		_steer(tank, aim, cmd, advance)
		var err := absf(wrapf(aim - tank.rotation, -PI, PI))
		cmd.fire = _los_time >= reaction_time and err <= aim_tolerance and distance <= fire_range
	else:
		_bank_left -= delta
		if _bank_left <= 0.0:
			_bank_left = BANK_INTERVAL
			var found := _find_bank_angle(tank)
			if is_nan(found) or is_nan(_bank_angle) or absf(wrapf(found - _bank_angle, -PI, PI)) > 0.1:
				_bank_time = 0.0
			_bank_angle = found
		if not is_nan(_bank_angle):
			# выстрел с рикошетом: встаём, целимся и стреляем
			_steer(tank, _bank_angle, cmd, 0.0)
			_bank_time += delta
			var bank_err := absf(wrapf(_bank_angle - tank.rotation, -PI, PI))
			cmd.fire = _bank_time >= reaction_time and bank_err <= aim_tolerance * 0.6
			return cmd
		_repath_left -= delta
		if _repath_left <= 0.0 or _path.is_empty():
			_repath_left = repath_interval
			_path = plan_path(tank.global_position, _target.global_position)
		while _path.size() > 1 and tank.global_position.distance_to(_path[0]) < ARRIVE_DISTANCE:
			_path.pop_front()
		if not _path.is_empty():
			_steer(tank, (_path[0] - tank.global_position).angle(), cmd, 1.0)
	_stuck_throttle_sum += absf(cmd.throttle) * delta
	return cmd


## Путь в мировых координатах (центры клеток). Пустой, если пути нет.
func plan_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if _astar == null:
		return result
	var start := _nearest_free(_world_to_cell(from))
	var goal := _nearest_free(_world_to_cell(to))
	if start.x < 0 or goal.x < 0:
		return result
	for cell in _astar.get_id_path(start, goal):
		result.append(_cell_to_world(cell))
	return result


# ----------------------------------------------------------------------------

func _steer(tank: Tank, heading: float, cmd: Dictionary, throttle: float) -> void:
	var diff := wrapf(heading - tank.rotation, -PI, PI)
	cmd.turn = clampf(diff * 3.0, -1.0, 1.0)
	if absf(diff) < 0.04:
		cmd.turn = 0.0
	# сначала разворот, потом газ (танк поворачивает на месте)
	var align := clampf(1.0 - absf(diff) / 1.1, 0.0, 1.0)
	cmd.throttle = throttle * align


func _line_of_sight(tank: Tank) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
		tank.global_position, _target.global_position, 1 << (PhysicsLayers.WALL - 1))
	return tank.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Ближайшая по времени угроза: {"direction": Vector2, "time": float} или пустой словарь.
## Траектория каждой пули прогнозируется с рикошетами, а не только по прямой.
func _find_threat(tank: Tank) -> Dictionary:
	var best := {}
	var best_time := THREAT_HORIZON
	for node in _bullets_root.get_children():
		var bullet := node as Bullet
		if bullet == null or (bullet.shooter == tank and bullet.bounces == 0):
			continue
		var traveled := 0.0
		var hit_found := false
		for seg: Dictionary in _trace(tank, bullet.global_position, bullet.direction, Bullet.SPEED * THREAT_HORIZON, 3):
			var seg_len: float = seg.a.distance_to(seg.b)
			var samples := maxi(1, int(seg_len / 16.0))
			for k in samples + 1:
				var along := seg_len * float(k) / samples
				var time := (traveled + along) / Bullet.SPEED
				# где будет наш танк к этому моменту, если продолжит ехать как сейчас (до 0.6 с)
				var tank_at: Vector2 = tank.global_position + tank.velocity * minf(time, 0.6)
				var bullet_at: Vector2 = seg.a.lerp(seg.b, float(k) / samples)
				if bullet_at.distance_to(tank_at) < THREAT_RADIUS:
					if time < best_time:
						best_time = time
						best = {"direction": (seg.b - seg.a).normalized(), "time": time}
					hit_found = true
					break
			if hit_found:
				break
			traveled += seg_len
	return best


## Участки пути пули с отскоками от стен (как у Bullet): [{a, b}, ...]. Ящик гасит пулю.
func _trace(tank: Tank, from: Vector2, dir: Vector2, length: float, max_bounces: int) -> Array:
	var segments: Array = []
	var mask := (1 << (PhysicsLayers.WALL - 1)) | (1 << (PhysicsLayers.CRATE - 1))
	var space := tank.get_world_2d().direct_space_state
	var pos := from
	var heading := dir
	var remaining := length
	for _i in max_bounces + 1:
		var query := PhysicsRayQueryParameters2D.create(pos, pos + heading * remaining, mask)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			segments.append({"a": pos, "b": pos + heading * remaining})
			break
		segments.append({"a": pos, "b": hit.position})
		if hit.collider is Crate:
			break
		remaining -= pos.distance_to(hit.position)
		if remaining <= 1.0:
			break
		pos = hit.position + hit.normal * 0.5
		heading = heading.bounce(hit.normal).normalized()
	return segments


## Куда уходить от пули: перпендикулярно её траектории, туда, где больше свободного места.
func _pick_dodge_heading(tank: Tank, bullet_dir: Vector2) -> float:
	var side := bullet_dir.orthogonal()
	var free_a := _free_distance(tank, side)
	var free_b := _free_distance(tank, -side)
	if free_a >= 60.0 and free_b >= 60.0:
		# места хватает с обеих сторон - уходим к центру поля (там больше манёвра)
		var to_center := _arena.get_playfield_rect().get_center() - tank.global_position
		return side.angle() if side.dot(to_center) >= 0.0 else (-side).angle()
	return side.angle() if free_a > free_b else (-side).angle()


func _free_distance(tank: Tank, dir: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(tank.global_position, tank.global_position + dir * 110.0,
		(1 << (PhysicsLayers.WALL - 1)) | (1 << (PhysicsLayers.CRATE - 1)))
	query.exclude = [tank.get_rid()]
	var hit := tank.get_world_2d().direct_space_state.intersect_ray(query)
	return 110.0 if hit.is_empty() else tank.global_position.distance_to(hit.position)


## Едем в направлении heading кратчайшим способом: если оно сзади - задним ходом, без разворота на месте.
func _move_toward(tank: Tank, heading: float, cmd: Dictionary) -> void:
	var diff := wrapf(heading - tank.rotation, -PI, PI)
	if absf(diff) > deg_to_rad(110.0):
		var back_diff := wrapf(heading + PI - tank.rotation, -PI, PI)
		cmd.turn = clampf(back_diff * 4.0, -1.0, 1.0)
		cmd.throttle = -clampf(1.0 - absf(back_diff) / 0.9, 0.0, 1.0)
	else:
		cmd.turn = clampf(diff * 4.0, -1.0, 1.0)
		# пока не развернулись к стороне уклонения - стоим: ехать вперёд значит ехать по линии огня
		cmd.throttle = clampf(1.0 - absf(diff) / 0.9, 0.0, 1.0)


## Угол выстрела, при котором пуля после 1-2 рикошетов попадёт в цель, не вернувшись в нас.
## NAN - такого угла нет; из подходящих берётся с самым коротким путём.
func _find_bank_angle(tank: Tank) -> float:
	var best := NAN
	var best_length := INF
	var origin := tank.global_position
	var steps := int(TAU / BANK_STEP)
	for i in steps:
		var angle := i * BANK_STEP
		var traveled := 0.0
		var segments := _trace(tank, origin, Vector2.RIGHT.rotated(angle), BANK_MAX_LENGTH, BANK_MAX_BOUNCES)
		for index in segments.size():
			var seg: Dictionary = segments[index]
			var on_target := Geometry2D.get_closest_point_to_segment(_target.global_position, seg.a, seg.b)
			if on_target.distance_to(_target.global_position) < 20.0:
				var total: float = traveled + seg.a.distance_to(on_target)
				if index > 0 and total < best_length:
					best_length = total
					best = angle
				break
			if index > 0:
				var on_self := Geometry2D.get_closest_point_to_segment(origin, seg.a, seg.b)
				if on_self.distance_to(origin) < 28.0:
					break
			traveled += seg.a.distance_to(seg.b)
	return best


func _update_stuck(tank: Tank, delta: float) -> void:
	_stuck_timer += delta
	if _stuck_timer < STUCK_CHECK:
		return
	var moved := tank.global_position.distance_to(_stuck_origin)
	if _stuck_throttle_sum > 0.5 * STUCK_CHECK and moved < STUCK_MIN_MOVE:
		_reverse_left = 0.6
		_reverse_turn = 1.0 if _rng.randf() < 0.5 else -1.0
		_path.clear()
	_stuck_timer = 0.0
	_stuck_origin = tank.global_position
	_stuck_throttle_sum = 0.0


func _build_grid() -> void:
	var used := _walls.get_used_rect()
	_astar = AStarGrid2D.new()
	_astar.region = used
	_astar.cell_size = Vector2(_walls.tile_set.tile_size)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for wall in _walls.get_used_cells():
		for dx in range(-INFLATE_CELLS, INFLATE_CELLS + 1):
			for dy in range(-INFLATE_CELLS, INFLATE_CELLS + 1):
				var cell := wall + Vector2i(dx, dy)
				if _astar.is_in_boundsv(cell):
					_astar.set_point_solid(cell, true)


func _nearest_free(cell: Vector2i) -> Vector2i:
	for radius in range(0, 8):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := cell + Vector2i(dx, dy)
				if _astar.is_in_boundsv(c) and not _astar.is_point_solid(c):
					return c
	return Vector2i(-1, -1)


func _world_to_cell(pos: Vector2) -> Vector2i:
	return _walls.local_to_map(_walls.to_local(pos))


func _cell_to_world(cell: Vector2i) -> Vector2:
	return _walls.to_global(_walls.map_to_local(cell))
