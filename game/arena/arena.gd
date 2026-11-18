class_name Arena
extends Node2D
## Арена: стены из TileMapLayer + точки появления + оформление уровня (тема) + ящики.
##
## Структура сцены (собирается в редакторе):
##   Arena (Node2D, этот скрипт)
##   ├─ Floor (ColorRect)  — база пола; текстура пола добавляется кодом
##   ├─ Walls (TileMapLayer, TileSet с physics layer, слой коллизии = PhysicsLayers.WALL)
##   └─ SpawnPoints (Node2D)
##      ├─ SpawnPoint (player_index = 1)
##      └─ SpawnPoint (player_index = 2)
##
## load_level(i) целиком оформляет арену кодом: тайлсет стен (по теме), бесшовный пол, декали, ящики.
## Тема = индекс уровня: 0 бетон, 1 песчаник, 2 мох, 3 сталь, 4 кирпич.
## Арена не знает про логику танков: она отдаёт позиции, границы поля и ящики.

signal level_changed(index: int)

const TILE := 40
const TILE_ATLAS := preload("res://game/arena/art/tiles.png")
const DECAL_ATLAS := preload("res://game/arena/art/decals.png")
const FLOOR_TEXTURES := [
	preload("res://game/arena/art/floor_0.png"),
	preload("res://game/arena/art/floor_1.png"),
	preload("res://game/arena/art/floor_2.png"),
	preload("res://game/arena/art/floor_3.png"),
	preload("res://game/arena/art/floor_4.png"),
]
const FLOOR_COLORS := [
	Color(0.15, 0.17, 0.16), Color(0.46, 0.38, 0.27), Color(0.19, 0.31, 0.18),
	Color(0.18, 0.21, 0.27), Color(0.30, 0.23, 0.17),
]
## Какие декали (индексы в decals.png: 0 трещина, 1 пятно, 2 камешки, 3 трава, 4 копоть, 5 лужа) уместны теме.
const THEME_DECALS := [[0, 1, 5, 4], [0, 2, 4, 0], [3, 3, 2, 5], [0, 1, 4, 5], [2, 4, 5, 2]]
const THEME_COUNT := 5
const DECAL_COUNT := 18

@export var walls: TileMapLayer

static var _tile_set_cache: TileSet

var level_index: int = 0
var theme: int = 0

var _spawns: Dictionary = {}  # int -> SpawnPoint
var _decor: Node2D
var _crates: Array[Crate] = []


func _ready() -> void:
	_collect_spawns()
	_validate()


## Перерисовывает арену по данным Levels. Точки появления не двигаются.
func load_level(index: int) -> void:
	level_index = posmod(index, Levels.count())
	theme = level_index % THEME_COUNT
	_apply_walls()
	_apply_floor()
	_spawn_decor()
	_spawn_crates()
	level_changed.emit(level_index)


func get_level_name() -> String:
	return Levels.level_name(level_index)


## Живые ящики арены.
func get_crates() -> Array[Crate]:
	var result: Array[Crate] = []
	for crate in _crates:
		if is_instance_valid(crate) and crate.alive:
			result.append(crate)
	return result


## Помещает танк (любой Node2D) в точку появления игрока и разворачивает по её повороту.
func place_tank(tank: Node2D, player_index: int) -> void:
	var spawn := get_spawn(player_index)
	if spawn == null:
		push_error("Arena: нет SpawnPoint для игрока %d" % player_index)
		return
	tank.global_position = spawn.global_position
	tank.global_rotation = spawn.global_rotation


func get_spawn(player_index: int) -> SpawnPoint:
	if _spawns.is_empty() and is_inside_tree():
		_collect_spawns()  # вызвали раньше, чем отработал _ready арены (например, в том же кадре, что и создание)
	return _spawns.get(player_index)


func get_spawn_transform(player_index: int) -> Transform2D:
	var spawn := get_spawn(player_index)
	return spawn.global_transform if spawn else Transform2D.IDENTITY


## Прямоугольник поля в глобальных координатах (по занятым тайлам Walls).
## Пригодится камере, ИИ и проверке «пуля вылетела за арену».
func get_playfield_rect() -> Rect2:
	if walls == null or walls.tile_set == null:
		return Rect2()
	var used := walls.get_used_rect()
	var tile := Vector2(walls.tile_set.tile_size)
	var top_left := walls.to_global(Vector2(used.position) * tile)
	return Rect2(top_left, Vector2(used.size) * tile)


# --- оформление ---------------------------------------------------------------

func _apply_walls() -> void:
	if walls.tile_set != _get_tile_set():
		walls.tile_set = _get_tile_set()
	walls.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	walls.clear()
	for cell in Levels.cells(level_index):
		var variant := posmod(cell.x * 7 + cell.y * 13 + cell.x * cell.y, 3)  # детерминированный «шум» вариантов
		walls.set_cell(cell, 0, Vector2i(theme, variant))
	walls.update_internals()  # физика тайлов обновляется сразу, а не в конце кадра


func _apply_floor() -> void:
	var base := get_node_or_null("Floor") as ColorRect
	if base == null:
		return
	base.color = FLOOR_COLORS[theme]
	var tex := base.get_node_or_null("FloorTexture") as TextureRect
	if tex == null:
		tex = TextureRect.new()
		tex.name = "FloorTexture"
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.stretch_mode = TextureRect.STRETCH_TILE
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.size = base.size
		base.add_child(tex)
	tex.texture = FLOOR_TEXTURES[theme]


func _spawn_decor() -> void:
	if _decor != null and is_instance_valid(_decor):
		remove_child(_decor)
		_decor.queue_free()
	_decor = Node2D.new()
	_decor.name = "Decor"
	add_child(_decor)
	var base := get_node_or_null("Floor")
	move_child(_decor, base.get_index() + 1 if base else 0)  # над полом, под стенами и танками

	var wall_cells := {}
	for cell in Levels.cells(level_index):
		wall_cells[cell] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (level_index + 1)  # тот же узор при каждом заходе на уровень
	var kinds: Array = THEME_DECALS[theme]
	var placed := 0
	var attempts := 0
	while placed < DECAL_COUNT and attempts < 200:
		attempts += 1
		var cell := Vector2i(rng.randi_range(1, Levels.COLS - 2), rng.randi_range(1, Levels.ROWS - 2))
		var near_spawn := absi(cell.y - Levels.ROWS / 2) <= 2 and (cell.x <= 4 or cell.x >= Levels.COLS - 5)
		if wall_cells.has(cell) or near_spawn:
			continue
		var sprite := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = DECAL_ATLAS
		atlas.region = Rect2(kinds[rng.randi() % kinds.size()] * TILE, 0, TILE, TILE)
		sprite.texture = atlas
		sprite.position = Vector2(cell) * TILE + Vector2(TILE, TILE) / 2.0 + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
		sprite.rotation = rng.randf_range(0.0, TAU)
		sprite.scale = Vector2.ONE * rng.randf_range(0.85, 1.4)
		sprite.modulate = Color(1, 1, 1, rng.randf_range(0.55, 0.9))
		_decor.add_child(sprite)
		placed += 1


func _spawn_crates() -> void:
	for crate in _crates:
		if is_instance_valid(crate):
			if crate.get_parent() == self:
				remove_child(crate)  # сразу уходит из физики, не ждём конца кадра
			crate.queue_free()
	_crates.clear()
	for entry in Levels.crates(level_index):
		var crate := Crate.new()
		crate.variant = entry.z
		crate.position = Vector2(entry.x, entry.y) * TILE + Vector2(TILE, TILE) / 2.0
		add_child(crate)
		_crates.append(crate)


static func _get_tile_set() -> TileSet:
	if _tile_set_cache == null:
		_tile_set_cache = _build_tile_set()
	return _tile_set_cache


## TileSet из art/tiles.png: столбец = тема, строка = вариант; у каждого тайла квадратная коллизия (слой wall).
static func _build_tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1 << (PhysicsLayers.WALL - 1))
	ts.set_physics_layer_collision_mask(0, 0)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = TILE_ATLAS
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for x in THEME_COUNT:
		for y in 3:
			atlas.create_tile(Vector2i(x, y))
	ts.add_source(atlas, 0)
	var half := TILE / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for x in THEME_COUNT:
		for y in 3:
			var data := atlas.get_tile_data(Vector2i(x, y), 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	return ts


# --- спавны и проверки ---------------------------------------------------------

func _collect_spawns() -> void:
	_spawns.clear()
	for node in find_children("*", "SpawnPoint", true, false):
		var spawn := node as SpawnPoint
		if _spawns.has(spawn.player_index):
			push_warning("Arena: дублирующийся SpawnPoint для игрока %d (%s)" % [spawn.player_index, spawn.name])
			continue
		_spawns[spawn.player_index] = spawn


func _validate() -> void:
	for player in range(1, TankInput.PLAYER_COUNT + 1):
		if not _spawns.has(player):
			push_warning("Arena: нет SpawnPoint для игрока %d" % player)
	if walls == null:
		push_warning("Arena: не назначен узел Walls (TileMapLayer)")
	elif walls.tile_set == null or walls.tile_set.get_physics_layers_count() == 0:
		push_warning("Arena: в TileSet нет physics layer — стены не будут блокировать танки")
