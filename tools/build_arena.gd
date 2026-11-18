extends SceneTree
## Собирает тестовую арену: TileSet + game/arena/arena.tscn.
## Запуск (редактор ДОЛЖЕН быть закрыт, см. CLAUDE.md):
##   Godot_console.exe --headless --path . --script res://tools/build_arena.gd

const TILE := 40
const COLS := 32  # 1280 / 40
const ROWS := 18  # 720 / 40
const TILESET_PATH := "res://game/arena/arena_tileset.tres"
const SCENE_PATH := "res://game/arena/arena.tscn"


func _init() -> void:
	var tile_set := _make_tileset()
	var err := ResourceSaver.save(tile_set, TILESET_PATH)
	if err != OK:
		push_error("tileset save failed: %d" % err)
		quit(1)
		return
	tile_set = load(TILESET_PATH)

	var root := Arena.new()
	root.name = "Arena"

	var floor_rect := ColorRect.new()
	floor_rect.name = "Floor"
	floor_rect.color = Color(0.13, 0.15, 0.13)
	floor_rect.size = Vector2(COLS * TILE, ROWS * TILE)
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(floor_rect)

	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = tile_set
	for cell in _wall_cells():
		walls.set_cell(cell, 0, Vector2i.ZERO)
	root.add_child(walls)

	var spawns := Node2D.new()
	spawns.name = "SpawnPoints"
	root.add_child(spawns)
	var row_center := ROWS * TILE / 2.0
	_add_spawn(spawns, "Spawn1", 1, Vector2(2.5 * TILE, row_center), 0.0)
	_add_spawn(spawns, "Spawn2", 2, Vector2((COLS - 2.5) * TILE, row_center), PI)

	root.walls = walls
	_set_owner_recursive(root, root)

	var packed := PackedScene.new()
	err = packed.pack(root)
	if err != OK:
		push_error("pack failed: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, SCENE_PATH)
	print("arena saved: ", SCENE_PATH, " err=", err, " walls=", walls.get_used_cells().size())
	quit(0 if err == OK else 1)


func _make_tileset() -> TileSet:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.45, 0.47, 0.50))
	for i in TILE:
		for edge in [0, 1, TILE - 2, TILE - 1]:
			var dark := Color(0.30, 0.32, 0.35)
			img.set_pixel(i, edge, dark)
			img.set_pixel(edge, i, dark)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1 << (PhysicsLayers.WALL - 1))
	ts.set_physics_layer_collision_mask(0, 0)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(img)
	atlas.texture_region_size = Vector2i(TILE, TILE)
	atlas.create_tile(Vector2i.ZERO)
	ts.add_source(atlas, 0)

	var data := atlas.get_tile_data(Vector2i.ZERO, 0)
	data.add_collision_polygon(0)
	var h := TILE / 2.0
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	return ts


## Рамка по периметру + симметричные препятствия (зеркало по горизонтали).
func _wall_cells() -> Array[Vector2i]:
	var cells: Dictionary = {}
	for x in COLS:
		cells[Vector2i(x, 0)] = true
		cells[Vector2i(x, ROWS - 1)] = true
	for y in ROWS:
		cells[Vector2i(0, y)] = true
		cells[Vector2i(COLS - 1, y)] = true

	var half: Array[Vector2i] = []
	for x in range(6, 10):  # горизонтальные планки
		half.append(Vector2i(x, 4))
		half.append(Vector2i(x, ROWS - 1 - 4))
	for y in range(7, 11):  # вертикальные планки
		half.append(Vector2i(10, y))
	for y in range(8, 10):  # маленькие блоки перед спавном (с запасом под ствол)
		half.append(Vector2i(6, y))
	for c in half:
		cells[c] = true
		cells[Vector2i(COLS - 1 - c.x, c.y)] = true
	# центральный столб
	for y in range(6, 12):
		cells[Vector2i(15, y)] = true
		cells[Vector2i(16, y)] = true

	var result: Array[Vector2i] = []
	for c in cells:
		result.append(c)
	return result


func _add_spawn(parent: Node, node_name: String, player: int, pos: Vector2, rot: float) -> void:
	var sp := SpawnPoint.new()
	sp.name = node_name
	sp.player_index = player
	sp.position = pos
	sp.rotation = rot
	parent.add_child(sp)


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)
