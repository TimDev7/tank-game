extends SceneTree
## Собирает game/match/match.tscn (играбельная сцена: арена + танки + раунды + HUD)
## и tools/match_selftest.tscn (автотест). Редактор ДОЛЖЕН быть закрыт (CLAUDE.md).
##   Godot_console.exe --headless --path . --script res://tools/build_match.gd

const MATCH_PATH := "res://game/match/match.tscn"
const SELFTEST_PATH := "res://tools/match_selftest.tscn"


func _init() -> void:
	var root := Node2D.new()
	root.name = "Match"

	var arena: Arena = (load("res://game/arena/arena.tscn") as PackedScene).instantiate()
	arena.name = "Arena"
	root.add_child(arena)
	arena.owner = root

	var bullets := Node2D.new()
	bullets.name = "Bullets"
	root.add_child(bullets)
	bullets.owner = root

	var manager := RoundManager.new()
	manager.name = "RoundManager"
	root.add_child(manager)
	manager.owner = root

	var hud := Hud.new()
	hud.name = "Hud"
	root.add_child(hud)
	hud.owner = root

	manager.arena = arena
	manager.bullets_root = bullets
	manager.hud = hud

	var ok := _save(root, MATCH_PATH)

	var test := Node.new()
	test.name = "MatchSelftest"
	test.set_script(load("res://tools/match_selftest.gd"))
	ok = _save(test, SELFTEST_PATH) and ok
	quit(0 if ok else 1)


func _save(node: Node, path: String) -> bool:
	var packed := PackedScene.new()
	var err := packed.pack(node)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("saved ", path, " err=", err)
	return err == OK
