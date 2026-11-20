"""Собирает ЕДИНЫЙ атлас игры game/art/atlas.png в одном стиле.

Запуск:  py -3.11 tools/build_atlas.py [--preview <папка>]     (нужен Pillow)

Конвейер:
  1. draw_arena_art.py и draw_tanks.py рисуют сырые спрайты в tools/art_src/;
  2. здесь рисуются недостающие (пули, частицы);
  3. ВСЕ спрайты проходят единый «стилизатор»:
       - палитра: только цвета AAP-64 (assets/pallette/aap64.png), без дизеринга;
       - альфа: у спрайтов жёсткая (пиксель-арт), у декалей 4 ступени;
       - контур: 1-2 px самого тёмного цвета палитры по краю спрайта (танки, ящики, пули);
  4. всё пакуется в атлас по фиксированной раскладке (REGIONS) и пишется game/art/atlas_regions.gd.
Свет везде сверху-слева (так нарисованы тайлы, ящики и танки).
"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "art_src")
OUT = os.path.join(HERE, "..", "game", "art")
PALETTE_PNG = os.path.join(HERE, "..", "assets", "pallette", "aap64.png")
TANK_PLACEHOLDER_DIR = os.path.join(HERE, "..", "game", "tanks", "art")  # на них ссылается tank.tscn

ATLAS_W, ATLAS_H = 640, 320

# имя -> (x, y, w, h) в атласе. Сетки (тайлы, полы, декали, ящики) - ячейки одного размера подряд.
REGIONS = {
    "tiles": (0, 0, 320, 120),  # 8 тем x 3 варианта, ячейка 40
    "floor_0": (320, 0, 80, 80), "floor_1": (400, 0, 80, 80), "floor_2": (480, 0, 80, 80), "floor_3": (560, 0, 80, 80),
    "floor_4": (320, 80, 80, 80), "floor_5": (400, 80, 80, 80), "floor_6": (480, 80, 80, 80), "floor_7": (560, 80, 80, 80),
    "decals": (0, 120, 240, 40),  # 6 декалей, ячейка 40
    "crates": (0, 160, 144, 36),  # 4 ящика, ячейка 36
    "tank_blue_hull": (0, 200, 96, 64), "tank_red_hull": (96, 200, 96, 64),
    "tank_blue_turret": (192, 200, 160, 64), "tank_red_turret": (352, 200, 160, 64),
    "bullet_blue": (0, 264, 16, 16), "bullet_red": (16, 264, 16, 16),
    "fx_puff": (32, 264, 16, 16), "fx_spark": (48, 264, 8, 8), "fx_pixel": (56, 264, 4, 4),
}

OUTLINE_PX = {"tank_blue_hull": 2, "tank_red_hull": 2, "tank_blue_turret": 2, "tank_red_turret": 2, "crates": 1,
              "bullet_blue": 1, "bullet_red": 1}
SOFT_ALPHA = {"decals"}  # мягкие пятна: альфа в 4 ступенях вместо порога


def load_palette():
    img = Image.open(PALETTE_PNG).convert("RGB")
    return [img.getpixel((x, y)) for y in range(img.height) for x in range(img.width)]


PALETTE = load_palette()
DARKEST = min(PALETTE, key=lambda c: sum(c))


def nearest(c):
    r, g, b = c
    # взвешенное расстояние (глаз чувствительнее к зелёному)
    return min(PALETTE, key=lambda p: 2 * (p[0] - r) ** 2 + 4 * (p[1] - g) ** 2 + 3 * (p[2] - b) ** 2)


_cache = {}


def snap(c):
    if c not in _cache:
        _cache[c] = nearest(c)
    return _cache[c]


def stylize(img, name):
    """Единый стиль: палитра AAP-64 + жёсткая/ступенчатая альфа + тёмный контур."""
    img = img.convert("RGBA")
    px = img.load()
    soft = name in SOFT_ALPHA
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if soft:
                a = min(255, round(a / 85) * 85)
            else:
                a = 255 if a >= 128 else 0
            if a == 0:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = snap((r, g, b)) + (a,)
    width = OUTLINE_PX.get(name, 0)
    if width:
        img = outline(img, width, name)
    return img


def outline(img, width, name):
    """Внутренний контур: непрозрачные пиксели у края спрайта (или ячейки сетки) -> тёмный цвет."""
    cell = {"crates": (36, 36)}.get(name, img.size)
    out = img.copy()
    src = img.load()
    dst = out.load()
    cw, ch = cell
    for y in range(img.height):
        for x in range(img.width):
            if src[x, y][3] == 0:
                continue
            lx, ly = x % cw, y % ch
            edge = False
            for dy in range(-width, width + 1):
                for dx in range(-width, width + 1):
                    nx, ny = lx + dx, ly + dy
                    if nx < 0 or ny < 0 or nx >= cw or ny >= ch:
                        edge = True
                    elif src[(x - lx) + nx, (y - ly) + ny][3] == 0:
                        edge = True
                    if edge:
                        break
                if edge:
                    break
            if edge:
                dst[x, y] = DARKEST + (255,)
    return out


# --------------------------------------------------------------- недостающие спрайты


def draw_bullet(color):
    s = 8
    img = Image.new("RGBA", (16 * s, 16 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2 * s, 2 * s, 14 * s - 1, 14 * s - 1], fill=color + (255,))
    d.ellipse([4 * s, 3 * s, 8 * s, 7 * s], fill=(255, 255, 255, 255))  # блик сверху-слева
    return img.resize((16, 16), Image.LANCZOS)


def draw_puff():
    s = 8
    img = Image.new("RGBA", (16 * s, 16 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1 * s, 1 * s, 15 * s - 1, 15 * s - 1], fill=(255, 255, 255, 255))
    return img.resize((16, 16), Image.LANCZOS)


def draw_spark():
    img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(3.5, 0), (7, 3.5), (3.5, 7), (0, 3.5)], fill=(255, 255, 255, 255))
    return img


def draw_pixel():
    return Image.new("RGBA", (4, 4), (255, 255, 255, 255))


# --------------------------------------------------------------- сборка


def run_generators():
    os.makedirs(SRC, exist_ok=True)
    for script in ("draw_arena_art.py", "draw_tanks.py"):
        subprocess.run([sys.executable, os.path.join(HERE, script)], check=True)


def source_sprites():
    sprites = {}
    for name in ("tiles", "decals", "crates"):
        sprites[name] = Image.open(os.path.join(SRC, name + ".png"))
    for i in range(8):
        sprites[f"floor_{i}"] = Image.open(os.path.join(SRC, f"floor_{i}.png"))
    for color in ("blue", "red"):
        for part in ("hull", "turret"):
            sprites[f"tank_{color}_{part}"] = Image.open(os.path.join(SRC, f"tank_{color}_{part}.png"))
    sprites["bullet_blue"] = draw_bullet((130, 190, 255))
    sprites["bullet_red"] = draw_bullet((255, 120, 100))
    sprites["fx_puff"] = draw_puff()
    sprites["fx_spark"] = draw_spark()
    sprites["fx_pixel"] = draw_pixel()
    return sprites


def build():
    if "--skip-draw" not in sys.argv:
        run_generators()
    sprites = source_sprites()
    atlas = Image.new("RGBA", (ATLAS_W, ATLAS_H), (0, 0, 0, 0))
    for name, (x, y, w, h) in REGIONS.items():
        sprite = sprites[name]
        assert sprite.size == (w, h), (name, sprite.size, (w, h))
        atlas.paste(stylize(sprite, name), (x, y))
    os.makedirs(OUT, exist_ok=True)
    atlas.save(os.path.join(OUT, "atlas.png"))
    write_regions()
    # заглушки для tank.tscn (сцену правит редактор, а не мы): тот же арт, что и в атласе
    os.makedirs(TANK_PLACEHOLDER_DIR, exist_ok=True)
    for part in ("hull", "turret"):  # tank.tscn ссылается только на синие
        x, y, w, h = REGIONS[f"tank_blue_{part}"]
        atlas.crop((x, y, x + w, y + h)).save(os.path.join(TANK_PLACEHOLDER_DIR, f"tank_blue_{part}.png"))
    print("atlas:", os.path.abspath(os.path.join(OUT, "atlas.png")), atlas.size)
    return atlas


def write_regions():
    lines = [
        "class_name GameAtlas",
        "extends RefCounted",
        "## СГЕНЕРИРОВАНО tools/build_atlas.py - не править руками.",
        "## Единый атлас игры (палитра AAP-64, общий контур). Регионы: имя -> Rect2(x, y, w, h).",
        "",
        'const ATLAS := preload("res://game/art/atlas.png")',
        "",
        "const REGIONS := {",
    ]
    for name, (x, y, w, h) in REGIONS.items():
        lines.append(f'\t"{name}": Rect2({x}, {y}, {w}, {h}),')
    lines += [
        "}",
        "",
        "static var _cache: Dictionary = {}",
        "",
        "",
        "## Регион атласа целиком (или его часть: sub - прямоугольник внутри региона, например ячейка сетки).",
        "static func tex(region: String, sub: Rect2 = Rect2()) -> AtlasTexture:",
        '\tvar key := "%s|%s" % [region, sub]',
        "\tif not _cache.has(key):",
        "\t\tvar r: Rect2 = REGIONS[region]",
        "\t\tvar t := AtlasTexture.new()",
        "\t\tt.atlas = ATLAS",
        "\t\tt.region = r if sub.size == Vector2.ZERO else Rect2(r.position + sub.position, sub.size)",
        "\t\t_cache[key] = t",
        "\treturn _cache[key]",
        "",
        "",
        "## Ячейка сетки внутри региона (тайлы 40, декали 40, ящики 36): index по горизонтали.",
        "static func cell(region: String, index: int, cell_size: Vector2) -> AtlasTexture:",
        "\treturn tex(region, Rect2(Vector2(index * cell_size.x, 0), cell_size))",
        "",
        "",
        "## Бесшовный пол как отдельная текстура (AtlasTexture не умеет тайлиться в TextureRect).",
        "static func standalone(region: String) -> ImageTexture:",
        '\tvar key := "standalone|" + region',
        "\tif not _cache.has(key):",
        "\t\tvar r: Rect2 = REGIONS[region]",
        "\t\t_cache[key] = ImageTexture.create_from_image(ATLAS.get_image().get_region(Rect2i(r)))",
        "\treturn _cache[key]",
        "",
    ]
    with open(os.path.join(OUT, "atlas_regions.gd"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def preview(path, atlas):
    """Контрольный лист: атлас на тёмной подложке x2."""
    bg = Image.new("RGBA", atlas.size, (22, 24, 28, 255))
    bg.alpha_composite(atlas)
    bg.resize((atlas.width * 2, atlas.height * 2), Image.NEAREST).convert("RGB").save(path)


if __name__ == "__main__":
    atlas_img = build()
    if "--preview" in sys.argv:
        out_dir = sys.argv[sys.argv.index("--preview") + 1]
        preview(os.path.join(out_dir, "atlas_preview.png"), atlas_img)
        print("preview saved")
