extends SceneTree
## Собирает game/tanks/tank.tscn (заглушка танка).
## Запуск (редактор ДОЛЖЕН быть закрыт, см. CLAUDE.md):
##   Godot_console.exe --headless --path . --script res://tools/build_tank.gd

const SCENE_PATH := "res://game/tanks/tank.tscn"


func _init() -> void:
	var root := Tank.new()
	root.name = "Tank"

	var hull := Sprite2D.new()
	hull.name = "Hull"
	hull.texture = load("res://game/tanks/art/tank_blue_hull.png")
	root.add_child(hull)

	var turret := Sprite2D.new()
	turret.name = "Turret"
	turret.texture = load("res://game/tanks/art/tank_blue_turret.png")
	root.add_child(turret)

	var muzzle := Marker2D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector2(78, 0)  # кончик ствола в локальных координатах башни (центр холста 160x64)
	root.add_child(muzzle)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(88, 58)
	shape.shape = rect
	root.add_child(shape)

	for child in root.get_children():
		child.owner = root

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, SCENE_PATH)
	print("tank saved: ", SCENE_PATH, " err=", err)
	quit(0 if err == OK else 1)
