class_name GameAtlas
extends RefCounted
## СГЕНЕРИРОВАНО tools/build_atlas.py - не править руками.
## Единый атлас игры (палитра AAP-64, общий контур). Регионы: имя -> Rect2(x, y, w, h).

const ATLAS := preload("res://game/art/atlas.png")

const REGIONS := {
	"tiles": Rect2(0, 0, 320, 120),
	"floor_0": Rect2(320, 0, 80, 80),
	"floor_1": Rect2(400, 0, 80, 80),
	"floor_2": Rect2(480, 0, 80, 80),
	"floor_3": Rect2(560, 0, 80, 80),
	"floor_4": Rect2(320, 80, 80, 80),
	"floor_5": Rect2(400, 80, 80, 80),
	"floor_6": Rect2(480, 80, 80, 80),
	"floor_7": Rect2(560, 80, 80, 80),
	"decals": Rect2(0, 120, 240, 40),
	"crates": Rect2(0, 160, 144, 36),
	"tank_blue_hull": Rect2(0, 200, 96, 64),
	"tank_red_hull": Rect2(96, 200, 96, 64),
	"tank_blue_turret": Rect2(192, 200, 160, 64),
	"tank_red_turret": Rect2(352, 200, 160, 64),
	"bullet_blue": Rect2(0, 264, 16, 16),
	"bullet_red": Rect2(16, 264, 16, 16),
	"fx_puff": Rect2(32, 264, 16, 16),
	"fx_spark": Rect2(48, 264, 8, 8),
	"fx_pixel": Rect2(56, 264, 4, 4),
}

static var _cache: Dictionary = {}


## Регион атласа целиком (или его часть: sub - прямоугольник внутри региона, например ячейка сетки).
static func tex(region: String, sub: Rect2 = Rect2()) -> AtlasTexture:
	var key := "%s|%s" % [region, sub]
	if not _cache.has(key):
		var r: Rect2 = REGIONS[region]
		var t := AtlasTexture.new()
		t.atlas = ATLAS
		t.region = r if sub.size == Vector2.ZERO else Rect2(r.position + sub.position, sub.size)
		_cache[key] = t
	return _cache[key]


## Ячейка сетки внутри региона (тайлы 40, декали 40, ящики 36): index по горизонтали.
static func cell(region: String, index: int, cell_size: Vector2) -> AtlasTexture:
	return tex(region, Rect2(Vector2(index * cell_size.x, 0), cell_size))


## Бесшовный пол как отдельная текстура (AtlasTexture не умеет тайлиться в TextureRect).
static func standalone(region: String) -> ImageTexture:
	var key := "standalone|" + region
	if not _cache.has(key):
		var r: Rect2 = REGIONS[region]
		_cache[key] = ImageTexture.create_from_image(ATLAS.get_image().get_region(Rect2i(r)))
	return _cache[key]
