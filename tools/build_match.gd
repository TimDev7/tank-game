extends SceneTree
## Собирает играбельные сцены матча и автотесты. Редактор ДОЛЖЕН быть закрыт (CLAUDE.md).
##   Godot_console.exe --headless --path . --script res://tools/build_match.gd
## Результат:
##   game/match/match.tscn      — PvP на одном устройстве
##   game/match/match_ai.tscn   — игрок против компьютера (красный — ИИ)
##   tools/match_selftest.tscn, tools/ai_selftest.tscn — автотесты (запускаются как обычная сцена)

const OUTPUTS := {
	"res://game/match/match.tscn": false,
	"res://game/match/match_ai.tscn": true,
}


func _init() -> void:
	var ok := true
	for path in OUTPUTS:
		ok = _save(_build_match(OUTPUTS[path]), path) and ok
	for pair in [["MatchSelftest", "match_selftest"], ["AiSelftest", "ai_selftest"]]:
		var test := Node.new()
		test.name = pair[0]
		test.set_script(load("res://tools/%s.gd" % pair[1]))
		ok = _save(test, "res://tools/%s.tscn" % pair[1]) and ok
	quit(0 if ok else 1)


func _build_match(vs_ai: bool) -> Node:
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
	manager.vs_ai = vs_ai
	return root


func _save(node: Node, path: String) -> bool:
	var packed := PackedScene.new()
	var err := packed.pack(node)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("saved ", path, " err=", err)
	return err == OK
