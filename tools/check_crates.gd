extends SceneTree
## Проверка ящиков и тем арены. Запуск:
##   Godot_console.exe --headless --path . --script res://tools/check_crates.gd

var _ok := true
var _arena: Arena


func _init() -> void:
	TankInput.register_actions()
	_arena = (load("res://game/arena/arena.tscn") as PackedScene).instantiate()
	root.add_child(_arena)
	await process_frame
	_arena.load_level(0)
	await _frames(3)

	# --- ящики и темы по уровням ---
	_check(_arena.get_crates().size() == Levels.crates(0).size() and _arena.get_crates().size() >= 12,
		"уровень 1: ящиков %d" % _arena.get_crates().size())
	var variants := {}
	for c in _arena.get_crates():
		variants[c.variant] = true
	_check(variants.size() == 4, "на уровне есть все 4 вида ящиков")
	for i in Levels.count():
		_arena.load_level(i)
		await _frames(2)
		var tile := _arena.walls.get_cell_atlas_coords(Vector2i(0, 0))
		_check(tile.x == i and _arena.theme == i, "уровень %d: своя тема стен (столбец атласа %d)" % [i + 1, tile.x])
	_arena.load_level(0)
	await _frames(3)

	var tank: Tank = (load("res://game/tanks/tank.tscn") as PackedScene).instantiate()
	_arena.add_child(tank)
	await process_frame

	# --- 1) толкание: танк наезжает, ящик едет, танк за ним ---
	_clear_crates()
	var crate := _make_crate(Vector2(230, 480))
	tank.global_position = Vector2(150, 480)
	tank.rotation = 0.0
	await _frames(2)
	Input.action_press("p1_up")
	await _frames(40)
	_check(crate.position.x > 250.0 and tank.global_position.x > 150.0 + 40.0,
		"наезд сдвигает ящик (ящик x=%.0f, танк x=%.0f)" % [crate.position.x, tank.global_position.x])
	_check(tank.global_position.x + 44.0 <= crate.position.x - 18.0 + 3.0, "танк не заезжает на ящик")

	# --- 2) упор в стену: дальше центра поля ящик не уедет, танк не продавит ---
	await _frames(300)
	_check(crate.position.x <= 600.0 - 18.0 + 2.0 and crate.alive, "ящик упирается в стену (x=%.0f)" % crate.position.x)
	_check(tank.global_position.x + 44.0 <= crate.position.x - 18.0 + 3.0, "танк не продавливает ящик через стену")
	Input.action_release("p1_up")

	# --- 3) инерции нет: отпустили — ящик встал ---
	_clear_crates()
	crate = _make_crate(Vector2(230, 480))
	tank.global_position = Vector2(150, 480)
	await _frames(2)
	Input.action_press("p1_up")
	await _frames(20)
	Input.action_release("p1_up")
	await _frames(40)
	var rest := crate.position
	await _frames(10)
	_check(crate.position.is_equal_approx(rest), "после остановки танка ящик стоит на месте")

	# --- 4) цепочка: два ящика подряд едут вместе ---
	_clear_crates()
	var a := _make_crate(Vector2(230, 480))
	var b := _make_crate(Vector2(270, 480))
	tank.global_position = Vector2(150, 480)
	await _frames(2)
	Input.action_press("p1_up")
	await _frames(50)
	Input.action_release("p1_up")
	_check(a.position.x > 250.0 and b.position.x > 290.0, "цепочка ящиков едет вместе (%.0f и %.0f)" % [a.position.x, b.position.x])

	# --- 5) пуля разбивает ящик и исчезает ---
	_clear_crates()
	tank.global_position = Vector2(150, 200)  # убрать танк с линии огня
	var target := _make_crate(Vector2(800, 600))
	var bullet := Bullet.new()
	_arena.add_child(bullet)
	bullet.launch(null, Vector2(700, 600), Vector2.RIGHT)
	await _frames(30)
	_check(not is_instance_valid(target) or not target.alive, "пуля разбивает ящик")
	_check(not is_instance_valid(bullet) or bullet.is_queued_for_deletion(), "пуля исчезает вместе с ящиком")
	await _frames(5)
	_check(not is_instance_valid(target), "разбитый ящик удалён из сцены")

	# --- 6) каждый раунд ящики возвращаются на места ---
	_arena.load_level(0)
	await _frames(3)
	for c in _arena.get_crates():
		c.destroy()
	await _frames(3)
	_check(_arena.get_crates().is_empty(), "все ящики можно разбить")
	_arena.load_level(0)
	await _frames(3)
	_check(_arena.get_crates().size() == Levels.crates(0).size(), "новый раунд восстанавливает все ящики (%d)" % _arena.get_crates().size())

	print("ALL OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _clear_crates() -> void:
	for c in _arena.get_children():
		if c is Crate:
			_arena.remove_child(c)
			c.free()


func _make_crate(pos: Vector2) -> Crate:
	var crate := Crate.new()
	crate.position = pos
	_arena.add_child(crate)
	return crate


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(cond: bool, label: String) -> void:
	print("%s %s" % ["OK  " if cond else "FAIL", label])
	_ok = _ok and cond
