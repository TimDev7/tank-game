extends SceneTree
## Снимок сцены. Запуск (нужно окно, НЕ --headless):
##   Godot_console.exe --path . --resolution 1280x720 --script res://tools/screenshot.gd -- res://game/arena/arena.tscn out.png

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://game/arena/arena.tscn"
	var out_path: String = args[1] if args.size() > 1 else "user://screenshot.png"
	var packed: PackedScene = load(scene_path)
	root.add_child(packed.instantiate())
	await create_timer(0.5).timeout
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_path)
	print("screenshot saved: ", out_path, " size=", img.get_size())
	quit()
