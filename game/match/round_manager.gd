class_name RoundManager
extends Node
## Матч PvP на одном устройстве: появление танков, выстрелы, раунды, счёт, пауза, перезапуск.
##
## Клавиши: P — пауза (НЕ Esc: он выходит из fullscreen), R — перезапуск раунда
## (после конца матча — новый матч).
## SDK (правила CrazyGames): gameplayStart на каждом старте/возобновлении игры,
## gameplayStop на каждой паузе/конце раунда. Реклама в этом классе не показывается.

signal scores_changed(blue: int, red: int)
signal round_started
signal round_ended(winner: int)  ## 0 — ничья
signal match_ended(winner: int)
signal menu_requested

enum State { PLAYING, ROUND_OVER, MATCH_OVER }

const TANK_SCENE := preload("res://game/tanks/tank.tscn")
const MENU_SCENE := "res://game/menu/main_menu.tscn"
const WINS_TO_MATCH := 5
const ROUND_END_DELAY := 1.8
const MAX_BULLETS_PER_TANK := 5
const PLAYER_NAMES := {1: "Blue", 2: "Red"}

@export var arena: Arena
@export var bullets_root: Node2D
@export var hud: Hud
## Красным (игрок 2) управляет компьютер. Включается и из главного меню через MatchConfig.vs_ai.
@export var vs_ai: bool = false
## false — только сигнал menu_requested, без смены сцены (для автотестов).
@export var auto_change_scene: bool = true

var state: State = State.ROUND_OVER
var scores: Dictionary = {1: 0, 2: 0}
var tanks: Dictionary = {}  # int -> Tank

var _round_id: int = 0
var _resolve_queued: bool = false
var _paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # ловим клавишу паузы, пока дерево на паузе
	for player in range(1, TankInput.PLAYER_COUNT + 1):
		var tank: Tank = TANK_SCENE.instantiate()
		tank.player_index = player
		tank.name = "Tank%d" % player
		tank.process_mode = Node.PROCESS_MODE_PAUSABLE
		arena.add_child(tank)
		tank.fired.connect(_on_tank_fired)
		tank.died.connect(_on_tank_died)
		tanks[player] = tank
	if vs_ai or MatchConfig.vs_ai:
		var brain := TankBrain.new()
		brain.setup(arena, tanks[1], bullets_root)
		(tanks[2] as Tank).brain = brain
		vs_ai = true
	_apply_hint.call_deferred()
	# Hud — следующий сосед в сцене и строит UI в своём _ready, который идёт после нашего.
	start_match.call_deferred()


func start_match() -> void:
	scores = {1: 0, 2: 0}
	_emit_scores()
	start_round()


func start_round() -> void:
	_round_id += 1
	_resolve_queued = false
	for bullet in bullets_root.get_children():
		bullet.queue_free()
	for player in tanks:
		var tank: Tank = tanks[player]
		tank.respawn(arena.get_spawn_transform(player))
		tank.controls_enabled = true
	state = State.PLAYING
	if hud:
		hud.show_message("")
	_sdk_gameplay(true)
	round_started.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if state == State.PLAYING or _paused:
			_set_paused(not _paused)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu") and not event.is_echo():
		if _paused or state == State.MATCH_OVER:
			get_viewport().set_input_as_handled()
			go_to_menu()
	elif event.is_action_pressed("restart_round") and not event.is_echo() and not _paused:
		if state == State.MATCH_OVER:
			start_match()
		else:
			start_round()
		get_viewport().set_input_as_handled()


## В главное меню. gameplayStop уже был отправлен при паузе/конце матча — повторно не шлём.
func go_to_menu() -> void:
	_paused = false
	var core := get_node_or_null("/root/Core")
	if core:
		core.toggle_pause(false, "player")
	else:
		get_tree().paused = false
	if auto_change_scene:
		get_tree().change_scene_to_file(MENU_SCENE)
	menu_requested.emit()


func _set_paused(on: bool) -> void:
	_paused = on
	var core := get_node_or_null("/root/Core")
	if core:
		core.toggle_pause(on, "player")  # раздельные источники паузы, см. CLAUDE.md
	else:
		get_tree().paused = on
	if hud:
		hud.show_pause(on)
	_sdk_gameplay(not on)


func _on_tank_fired(tank: Tank, muzzle_position: Vector2, direction: Vector2) -> void:
	if state != State.PLAYING:
		return
	var own := 0
	for bullet in bullets_root.get_children():
		if (bullet as Bullet).shooter == tank:
			own += 1
	if own >= MAX_BULLETS_PER_TANK:
		return
	# Если дуло внутри стены/танка (упёрлись носом) — решаем выстрел в упор лучом от центра танка.
	var space := arena.get_world_2d().direct_space_state
	var mask := (1 << (PhysicsLayers.WALL - 1)) | (1 << (PhysicsLayers.TANK - 1))
	var query := PhysicsRayQueryParameters2D.create(tank.global_position, muzzle_position, mask)
	query.exclude = [tank.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider is Tank:
			(hit.collider as Tank).die()
		return
	var bullet := Bullet.new()
	bullets_root.add_child(bullet)
	bullet.launch(tank, muzzle_position, direction)


func _on_tank_died(_tank: Tank) -> void:
	if state != State.PLAYING or _resolve_queued:
		return
	# Откладываем до конца кадра: двойное попадание в один кадр = ничья.
	_resolve_queued = true
	_resolve_round.call_deferred()


func _resolve_round() -> void:
	var alive: Array[int] = []
	for player in tanks:
		if (tanks[player] as Tank).alive:
			alive.append(player)
	var winner := alive[0] if alive.size() == 1 else 0
	for player in tanks:
		(tanks[player] as Tank).controls_enabled = false
	_sdk_gameplay(false)

	if winner != 0:
		scores[winner] += 1
	_emit_scores()
	round_ended.emit(winner)

	if winner != 0 and scores[winner] >= WINS_TO_MATCH:
		state = State.MATCH_OVER
		if hud:
			hud.show_message(tr("%s wins the match!") % tr(PLAYER_NAMES[winner]) + "\n" + tr("R - new match   |   M - menu"))
		match_ended.emit(winner)
		return

	state = State.ROUND_OVER
	if hud:
		hud.show_message(tr("%s scores!") % tr(PLAYER_NAMES[winner]) if winner != 0 else tr("Draw!"))
	var id := _round_id
	await get_tree().create_timer(ROUND_END_DELAY).timeout
	if id == _round_id and state == State.ROUND_OVER:  # не перезапускали вручную за это время
		start_round()


func _apply_hint() -> void:
	if hud == null:
		return
	if vs_ai:
		hud.set_hint(tr("Blue (you): WASD + Space   |   Red: computer   |   P - pause   |   R - restart round"))
	else:
		hud.set_hint(tr("Blue: WASD + Space   |   Red: Arrows + Enter   |   P - pause   |   R - restart round"))


func _emit_scores() -> void:
	if hud:
		hud.set_scores(scores[1], scores[2])
	scores_changed.emit(scores[1], scores[2])


## SDK — единая точка входа (CLAUDE.md). В тестовом режиме --script автозагрузок нет — тогда пропускаем.
func _sdk_gameplay(started: bool) -> void:
	if get_node_or_null("/root/Bridge") == null:
		return
	if started:
		SDK.notify_gameplay_started()
	else:
		SDK.notify_gameplay_stopped()
