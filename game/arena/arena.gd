class_name Arena
extends Node2D
## Тестовая арена: стены из TileMapLayer + точки появления игроков.
##
## Структура сцены (собирается в редакторе):
##   Arena (Node2D, этот скрипт)
##   ├─ Walls (TileMapLayer, TileSet с physics layer, слой коллизии = PhysicsLayers.WALL)
##   └─ SpawnPoints (Node2D)
##      ├─ SpawnPoint (player_index = 1)
##      └─ SpawnPoint (player_index = 2)
##
## Арена не знает про логику танков: она только отдаёт позиции и границы поля.

@export var walls: TileMapLayer

var _spawns: Dictionary = {}  # int -> SpawnPoint


func _ready() -> void:
	_collect_spawns()
	_validate()


## Помещает танк (любой Node2D) в точку появления игрока и разворачивает по её повороту.
func place_tank(tank: Node2D, player_index: int) -> void:
	var spawn := get_spawn(player_index)
	if spawn == null:
		push_error("Arena: нет SpawnPoint для игрока %d" % player_index)
		return
	tank.global_position = spawn.global_position
	tank.global_rotation = spawn.global_rotation


func get_spawn(player_index: int) -> SpawnPoint:
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
