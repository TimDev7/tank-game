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

# «характер» — можно менять для уровней сложности
var reaction_time: float = 0.28  ## сколько цель должна быть на линии огня до первого выстрела
var aim_tolerance: float = 0.11  ## рад
var fire_range: float = 780.0
var lead_factor: float = 0.6  ## 0 — без упреждения
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
var _reverse_left: float = 0.0
var _reverse_turn: float = 1.0
var _stuck_timer: float = 0.0
var _stuck_origin: Vector2 = Vector2.ZERO
var _stuck_throttle_sum: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(arena: Arena, target: Tank, bullets_root: Node2D) -> void:
	_arena = arena
	_target = target
	_bullets_root = bullets_root
	_walls = arena.walls
	_rng.randomize()
	_build_grid()


func reset() -> void:
	_path.clear()
	_repath_left = 0.0
	_los_time = 0.0
	_evade_left = 0.0
	_reverse_left = 0.0
	_stuck_timer = 0.0


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
	if threat != Vector2.ZERO:
		_evade_left = 0.55
		var side := threat.orthogonal()
		if side.dot(tank.global_position - _arena.get_playfield_rect().get_center()) > 0.0:
			side = -side  # уходим в сторону центра поля, а не в угол
		_evade_heading = side.angle()
	if _evade_left > 0.0:
		_evade_left -= delta
		_steer(tank, _evade_heading, cmd, 1.0)
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


## Направление ближайшей опасной пули (нулевой вектор — угрозы нет).
func _find_threat(tank: Tank) -> Vector2:
	var best := Vector2.ZERO
	var best_time := EVADE_LOOKAHEAD
	for node in _bullets_root.get_children():
		var bullet := node as Bullet
		if bullet == null or bullet.shooter == tank:
			continue
		var rel := tank.global_position - bullet.global_position
		var along := rel.dot(bullet.direction)
		if along <= 0.0:
			continue
		var lateral := (rel - bullet.direction * along).length()
		var time := along / Bullet.SPEED
		if lateral < EVADE_LATERAL and time < best_time:
			best_time = time
			best = bullet.direction
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
