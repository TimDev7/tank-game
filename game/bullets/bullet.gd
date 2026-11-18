class_name Bullet
extends Node2D
## Снаряд с рикошетом от стен (как в Tank Trouble). Без физических тел: движение лучом
## по слоям wall+tank в _physics_process (одинаково на 60/144 Гц, правила CrazyGames).
## Попадание в любой живой танк (в том числе в стрелявшего после рикошета) убивает его.

const SPEED := 420.0
const RADIUS := 5.0
const MAX_STEPS_PER_FRAME := 6

const COLORS := {
	1: Color(0.55, 0.78, 1.0),
	2: Color(1.0, 0.55, 0.45),
}

var shooter: Tank
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 6.0
var bounces: int = 0


func launch(from_tank: Tank, at: Vector2, dir: Vector2) -> void:
	shooter = from_tank
	global_position = at
	direction = dir.normalized()
	queue_redraw()


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	var remaining := SPEED * delta
	var space := get_world_2d().direct_space_state
	var mask := (1 << (PhysicsLayers.WALL - 1)) | (1 << (PhysicsLayers.TANK - 1))
	for _i in MAX_STEPS_PER_FRAME:
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + direction * remaining, mask)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			global_position += direction * remaining
			return
		var collider: Object = hit.collider
		if collider is Tank:
			(collider as Tank).die()
			queue_free()
			return
		# стена: отражаем и продолжаем с остатком пути
		var travelled := global_position.distance_to(hit.position)
		global_position = hit.position + hit.normal * 0.5
		direction = direction.bounce(hit.normal).normalized()
		bounces += 1
		remaining = maxf(0.0, remaining - travelled)
		if remaining <= 0.01:
			return


func _draw() -> void:
	var color: Color = COLORS.get(shooter.player_index if shooter else 1, Color.WHITE)
	draw_circle(Vector2.ZERO, RADIUS + 1.5, Color(0.05, 0.05, 0.07, 0.9))
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_circle(Vector2(-1.5, -1.5), RADIUS * 0.4, Color(1, 1, 1, 0.75))
