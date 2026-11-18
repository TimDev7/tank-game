extends SceneTree
## Собирает game/menu/main_menu.tscn и tools/menu_selftest.tscn. Редактор ДОЛЖЕН быть закрыт (CLAUDE.md).
##   Godot_console.exe --headless --path . --script res://tools/build_menu.gd


func _init() -> void:
	var menu := MainMenu.new()
	menu.name = "MainMenu"
	var ok := _save(menu, "res://game/menu/main_menu.tscn")

	var test := Node.new()
	test.name = "MenuSelftest"
	test.set_script(load("res://tools/menu_selftest.gd"))
	ok = _save(test, "res://tools/menu_selftest.tscn") and ok
	quit(0 if ok else 1)


func _save(node: Node, path: String) -> bool:
	var packed := PackedScene.new()
	var err := packed.pack(node)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("saved ", path, " err=", err)
	return err == OK
