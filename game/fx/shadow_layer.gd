class_name ShadowLayer
extends Node2D
## Тени арены. Свет один и фиксированный - сверху-слева, поэтому все тени падают вниз-вправо.
## Слой стоит в Arena между полом/декалями и стенами/танками: тень лежит на полу, а предметы поверх неё.
##
## - Стены: одна мягкая тень-маска на всю арену (без «двойного затемнения» там, где тени соседних клеток
##   пересекаются), строится при смене уровня: set_walls().
## - Танки (корпус и башня раздельно - башня «выше», её тень дальше) и ящики: тень = силуэт их спрайта,
##   смещённый в мировых координатах (поворот танка не крутит направление света): track().
## - Пули: тень рисует сам Bullet (она летит выше всех, тень дальше всего).

const SHADOW_COLOR := Color(0.02, 0.02, 0.06)  ## холодный почти-чёрный, как самый тёмный цвет палитры
const WALL_ALPHA := 0.42
const WALL_OFFSET := Vector2(6, 8)
const HULL_OFFSET := Vector2(3, 4)
const TURRET_OFFSET := Vector2(5, 7)
const CRATE_OFFSET := Vector2(4, 5)
const MASK_SCALE := 2  ## маска стен в половинном разрешении; растягивается линейно - края мягкие

var _wall_sprite: Sprite2D
var _tracked: Array[Dictionary] = []  ## {src: Sprite2D, shadow: Sprite2D, offset: Vector2}


func _init() -> void:
	name = "Shadows"
	process_priority = 100  # после движения танков и ящиков - тень не отстаёт на кадр


func set_walls(cells: Array[Vector2i], tile: int, cols: int, rows: int) -> void:
	var size := Vector2i(cols * tile, rows * tile) / MASK_SCALE
	var mask := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var half_off := Vector2i(WALL_OFFSET / MASK_SCALE)
	var cell_px := tile / MASK_SCALE
	for cell in cells:
		mask.fill_rect(Rect2i(Vector2i(cell) * cell_px + half_off, Vector2i(cell_px, cell_px)), Color(1, 1, 1, 1))
	if _wall_sprite == null:
		_wall_sprite = Sprite2D.new()
		_wall_sprite.centered = false
		_wall_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_wall_sprite.modulate = Color(SHADOW_COLOR, WALL_ALPHA)
		add_child(_wall_sprite)
	_wall_sprite.texture = ImageTexture.create_from_image(mask)
	_wall_sprite.scale = Vector2.ONE * MASK_SCALE


## Тень по силуэту спрайта: следит за положением/поворотом/видимостью src, пока тот жив.
func track(src: Sprite2D, offset: Vector2) -> void:
	var shadow := Sprite2D.new()
	shadow.modulate = Color(SHADOW_COLOR, 0.4)
	shadow.texture_filter = src.texture_filter
	add_child(shadow)
	_tracked.append({"src": src, "shadow": shadow, "offset": offset})
	_sync_one(_tracked[-1])


func _process(_delta: float) -> void:
	var i := _tracked.size() - 1
	while i >= 0:
		var entry := _tracked[i]
		if not is_instance_valid(entry.src):
			(entry.shadow as Node).queue_free()
			_tracked.remove_at(i)
		else:
			_sync_one(entry)
		i -= 1


func _sync_one(entry: Dictionary) -> void:
	var src: Sprite2D = entry.src
	var shadow: Sprite2D = entry.shadow
	shadow.visible = src.is_visible_in_tree()
	shadow.texture = src.texture
	shadow.global_position = src.global_position + (entry.offset as Vector2)
	shadow.global_rotation = src.global_rotation
	shadow.global_scale = src.global_scale
