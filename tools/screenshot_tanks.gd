extends SceneTree
## Снимок арены с двумя танками на точках появления (нужно окно, НЕ --headless):
##   Godot_console.exe --path . --resolution 1280x720 --script res://tools/screenshot_tanks.gd -- out.png

func _init() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://tanks.png"
	var arena: Arena = (load("res://game/arena/arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	var scene: PackedScene = load("res://game/tanks/tank.tscn")
	for i in [1, 2]:
		var t: Tank = scene.instantiate()
		t.player_index = i
		arena.add_child(t)
	await process_frame
	for i in [1, 2]:
		arena.place_tank(arena.get_child(arena.get_child_count() - 3 + i), i)
	await create_timer(0.4).timeout
	await process_frame
	root.get_texture().get_image().save_png(out_path)
	print("saved ", out_path)
	quit()
