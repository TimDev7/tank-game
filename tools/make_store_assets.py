"""Логотип и обложки для портала (CrazyGames): синий танк в центре, из тех же векторов, что и спрайты в игре.

Запуск:  python tools/make_store_assets.py      (нужен Pillow)
Выход (assets/store/, папка с .gdignore — Godot её не импортирует и в билд не кладёт):
  logo.png                     1024x1024, прозрачный фон — знак игры
  cover_landscape_1920x1080.png   16:9
  cover_portrait_800x1200.png     2:3
  cover_square_800x800.png        1:1

Правила CrazyGames (docs/crazygames-requirements.md §5): без рамок, без текста кроме названия,
без иконок/логотипов магазинов, не размытые, все три в едином стиле.
"""
import math
import os
import random
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import draw_tanks as dt

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "assets", "store")
FONT = os.path.join(ROOT, "assets", "font", "marimpa.regular.ttf")
TITLE = ("RICOCHET", "RUMBLE")
GOLD = (255, 199, 56)
GOLD_DARK = (92, 51, 10)
INK = (20, 26, 34)


def tank_image(k):
    """Синий танк (корпус + башня) стоит по центру холста, смотрит вправо. k — масштаб к 96x64 корпусу."""
    dt.S = max(4, k)
    pal = dt.PALETTES["blue"]
    hull = dt.draw_hull(pal, k)
    turret = dt.draw_turret(pal, k)
    w, h = 160 * k + 20 * k, 64 * k + 20 * k
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    img.alpha_composite(hull, (w // 2 - 48 * k, h // 2 - 32 * k))
    img.alpha_composite(turret, (w // 2 - 80 * k, h // 2 - 32 * k))
    return img


def background(w, h, seed=7):
    rnd = random.Random(seed)
    img = Image.new("RGB", (w, h))
    px = img.load()
    cx, cy = w / 2, h / 2
    maxd = math.hypot(cx, cy)
    for y in range(h):
        for x in range(w):
            t = math.hypot(x - cx, y - cy) / maxd
            px[x, y] = (int(54 - 34 * t), int(78 - 48 * t), int(60 - 38 * t))
    img = img.convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    tile = max(w, h) // 20
    for x in range(0, w, tile):
        d.line([(x, 0), (x, h)], fill=(255, 255, 255, 7), width=2)
    for y in range(0, h, tile):
        d.line([(0, y), (w, y)], fill=(255, 255, 255, 7), width=2)
    # стены-блоки арены по краям, как в игре (серые тайлы), не заходят в центр
    for _ in range(26):
        gx, gy = rnd.randrange(0, w // tile), rnd.randrange(0, h // tile)
        x0, y0 = gx * tile, gy * tile
        if math.hypot(x0 + tile / 2 - cx, y0 + tile / 2 - cy) < min(w, h) * 0.42:
            continue
        d.rectangle([x0 + 3, y0 + 3, x0 + tile - 3, y0 + tile - 3], fill=(120, 128, 136, 70), outline=(190, 198, 206, 60), width=2)
    return img


def glow(size, color, radius):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([size[0] * .5 - radius, size[1] * .5 - radius, size[0] * .5 + radius, size[1] * .5 + radius], fill=color)
    return layer.filter(ImageFilter.GaussianBlur(radius * .45))


def text_line(img, text, cx, cy, size, fill, shadow):
    font = ImageFont.truetype(FONT, size)
    d = ImageDraw.Draw(img)
    stroke = max(3, size // 16)
    off = max(4, size // 14)
    d.text((cx + off, cy + off), text, font=font, fill=shadow + (255,), anchor="mm", stroke_width=stroke, stroke_fill=shadow + (255,))
    d.text((cx, cy), text, font=font, fill=fill + (255,), anchor="mm", stroke_width=stroke, stroke_fill=INK + (255,))


def draw_logo(canvas, cx, cy, unit):
    """Знак: заголовок сверху, танк в центре, второе слово снизу. unit — ширина знака в пикселях."""
    k = max(1, round(unit / 330))
    tank = tank_image(k).rotate(14, resample=Image.BICUBIC, expand=True)
    tw, th = tank.size
    scale = unit * 0.78 / tw  # танк с башней ~72% ширины знака
    tank = tank.resize((int(tw * scale), int(th * scale)), Image.LANCZOS)
    tw, th = tank.size
    g = glow((int(unit * 1.2), int(unit * 1.2)), (255, 214, 120, 110), unit * 0.34)
    canvas.alpha_composite(g, (int(cx - g.width / 2), int(cy - g.height / 2)))
    # тень танка
    sh = Image.new("RGBA", tank.size, (0, 0, 0, 0))
    sh.putalpha(tank.getchannel("A").point(lambda v: int(v * .45)))
    sh = sh.filter(ImageFilter.GaussianBlur(unit * 0.012))
    canvas.alpha_composite(sh, (int(cx - tw / 2 + unit * .015), int(cy - th / 2 + unit * .03)))
    canvas.alpha_composite(tank, (int(cx - tw / 2), int(cy - th / 2)))
    # название: слова не залезают на танк
    big = int(unit * 0.15)
    text_line(canvas, TITLE[0], cx, cy - th / 2 - big * 0.25, big, (255, 255, 255), INK)
    text_line(canvas, TITLE[1], cx, cy + th / 2 + big * 0.35, int(big * 1.25), GOLD, GOLD_DARK)


def cover(w, h, unit_ratio):
    img = background(w, h)
    draw_logo(img, w / 2, h / 2, min(w, h) * unit_ratio)
    return img.convert("RGB")


def logo_png():
    img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    draw_logo(img, 512, 512, 960)
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    logo_png().save(os.path.join(OUT, "logo.png"))
    cover(1920, 1080, 1.0).save(os.path.join(OUT, "cover_landscape_1920x1080.png"))
    cover(800, 1200, 1.0).save(os.path.join(OUT, "cover_portrait_800x1200.png"))
    cover(800, 800, 0.98).save(os.path.join(OUT, "cover_square_800x800.png"))
    print("saved to", os.path.abspath(OUT))
