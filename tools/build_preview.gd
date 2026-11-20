extends SceneTree
## Собирает tools/record_preview.tscn. Редактор должен быть закрыт (CLAUDE.md).
##   Godot_console.exe --headless --path . --script res://tools/build_preview.gd
func _init() -> void:
	var node := Node.new()
	node.name = "RecordPreview"
	node.set_script(load("res://tools/record_preview.gd"))
	var packed := PackedScene.new()
	packed.pack(node)
	quit(0 if ResourceSaver.save(packed, "res://tools/record_preview.tscn") == OK else 1)
