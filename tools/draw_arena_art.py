"""Рисует арт арены: тайлы стен (5 тем x 3 варианта), бесшовные полы, декали, ящики.

Запуск:  python tools/draw_arena_art.py [--preview <папка>]   (нужен Pillow; Python 3.11)
Выход в game/arena/art/:
  tiles.png    320x120  — тайлы стен 40x40: столбец = тема (0..7), строка = вариант (0..2)
  floor_N.png  80x80    — бесшовный пол темы N (0..7)
  decals.png   240x40   — 6 декалей 40x40 на прозрачном фоне
  crates.png   144x36   — 4 вида ящиков 36x36: 0 дерево, 1 металл, 2 армейский, 3 «опасность»
Темы (индекс уровня % 8): 0 бетон, 1 песчаник, 2 мох/трава, 3 сталь, 4 кирпич, 5 лёд, 6 лава, 7 неон.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "art_src")  # сырой арт; в игру попадает только через build_atlas.py
T = 40
F = 80  # размер бесшовного пола
C = 36  # размер ящика


def clamp(v):
    return max(0, min(255, int(v)))


def tint(c, k):
    return tuple(clamp(v * k) for v in c)


def jitter(c, amt, rnd):
    d = rnd.randint(-amt, amt)
    return tuple(clamp(v + d) for v in c)


def bevel(img, light=70, dark=90, w=2):
    """Подсветка сверху-слева и тень снизу-справа: объём тайла."""
    d = ImageDraw.Draw(img, "RGBA")
    s = img.size[0]
    for i in range(w):
        a = 1.0 - i / w
        d.line([(i, i), (s - 2 - i, i)], fill=(255, 255, 255, int(light * a)))
        d.line([(i, i), (i, s - 2 - i)], fill=(255, 255, 255, int(light * a)))
        d.line([(i, s - 1 - i), (s - 1 - i, s - 1 - i)], fill=(0, 0, 0, int(dark * a)))
        d.line([(s - 1 - i, i), (s - 1 - i, s - 1 - i)], fill=(0, 0, 0, int(dark * a)))
    return img


def speckle(img, rnd, n, amt, area=None):
    px = img.load()
    w, h = img.size
    for _ in range(n):
        x, y = rnd.randrange(w), rnd.randrange(h)
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        d = rnd.randint(-amt, amt)
        px[x, y] = (clamp(r + d), clamp(g + d), clamp(b + d), a)


# --------------------------------------------------------------------------- стены


def wall_concrete(v):
    rnd = random.Random(100 + v)
    img = Image.new("RGBA", (T, T), jitter((116, 120, 126), 6, rnd) + (255,))
    speckle(img, rnd, 260, 14)
    d = ImageDraw.Draw(img, "RGBA")
    seam = 14 + v * 6
    d.line([(0, seam), (T, seam)], fill=(40, 44, 50, 150), width=1)
    d.line([(0, seam + 1), (T, seam + 1)], fill=(255, 255, 255, 40), width=1)
    if v == 1:
        d.line([(24, seam), (22, T)], fill=(40, 44, 50, 110), width=1)
    if v == 2:  # трещина
        x, y = 8, 4
        for _ in range(9):
            nx, ny = x + rnd.randint(1, 4), y + rnd.randint(2, 4)
            d.line([(x, y), (nx, ny)], fill=(30, 32, 36, 170), width=1)
            x, y = nx, ny
    return bevel(img)


def wall_sandstone(v):
    rnd = random.Random(200 + v)
    img = Image.new("RGBA", (T, T), (190, 158, 108, 255))
    d = ImageDraw.Draw(img, "RGBA")
    rows = [(0, 13), (13, 27), (27, 40)] if v != 1 else [(0, 19), (19, 40)]
    for y0, y1 in rows:
        x = 0
        while x < T:
            wd = rnd.randint(14, 24)
            col = jitter((196, 164, 112), 12, rnd)
            d.rectangle([x, y0, min(T, x + wd) - 1, y1 - 1], fill=col + (255,))
            d.rectangle([x, y0, min(T, x + wd) - 1, y1 - 1], outline=(120, 92, 58, 200))
            x += wd
    speckle(img, rnd, 320, 16)
    return bevel(img, 80, 80)


def wall_mossy(v):
    rnd = random.Random(300 + v)
    img = Image.new("RGBA", (T, T), (104, 112, 104, 255))
    d = ImageDraw.Draw(img, "RGBA")
    for gx in range(2):
        for gy in range(2):
            x0, y0 = gx * 20 + rnd.randint(0, 2), gy * 20 + rnd.randint(0, 2)
            col = jitter((120, 128, 118), 10, rnd)
            d.rounded_rectangle([x0, y0, x0 + 18, y0 + 18], radius=5, fill=col + (255,), outline=(58, 64, 58, 255))
    moss = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    md = ImageDraw.Draw(moss)
    for _ in range(5 + v * 2):
        x, y, r = rnd.randrange(T), rnd.randrange(T), rnd.randint(3, 7)
        md.ellipse([x - r, y - r, x + r, y + r], fill=(70, 130, 60, 150))
    moss = moss.filter(ImageFilter.GaussianBlur(1.2))
    img.alpha_composite(moss)
    speckle(img, rnd, 200, 12)
    return bevel(img, 60, 90)


def wall_steel(v):
    rnd = random.Random(400 + v)
    img = Image.new("RGBA", (T, T), (92, 108, 132, 255))
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([4, 4, T - 5, T - 5], fill=jitter((82, 98, 122), 5, rnd) + (255,), outline=(40, 50, 66, 255))
    d.rectangle([5, 5, T - 6, T - 6], outline=(130, 148, 176, 120))
    for x, y in ((3, 3), (T - 4, 3), (3, T - 4), (T - 4, T - 4)):
        d.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=(150, 164, 186, 255), outline=(30, 38, 52, 255))
    if v == 1:
        d.line([(8, 20), (T - 9, 20)], fill=(40, 50, 66, 200), width=1)
    if v == 2:
        for i in range(4):
            d.line([(10 + i * 6, 10), (4 + i * 6, 30)], fill=(60, 72, 92, 140), width=1)
    speckle(img, rnd, 120, 10)
    return bevel(img, 90, 110)


def wall_brick(v):
    rnd = random.Random(500 + v)
    img = Image.new("RGBA", (T, T), (74, 44, 40, 255))
    d = ImageDraw.Draw(img, "RGBA")
    bh = 9
    for row in range(5):
        y = row * bh - (v * 2)
        off = 0 if (row + v) % 2 == 0 else -9
        x = off
        while x < T:
            col = jitter((156, 66, 52), 16, rnd)
            d.rectangle([x + 1, y + 1, x + 16, y + bh - 1], fill=col + (255,))
            d.line([(x + 1, y + 1), (x + 16, y + 1)], fill=(255, 255, 255, 35))
            x += 18
    speckle(img, rnd, 240, 14)
    return bevel(img, 50, 100)


def wall_ice(v):
    rnd = random.Random(600 + v)
    img = Image.new("RGBA", (T, T), (146, 192, 222, 255))
    d = ImageDraw.Draw(img, "RGBA")
    d.polygon([(0, 0), (T, 0), (T * 0.62, T * 0.38), (0, T * 0.5)], fill=(190, 228, 246, 255))  # светлая грань
    d.polygon([(T, T), (0, T), (T * 0.38, T * 0.62), (T, T * 0.5)], fill=(102, 150, 190, 255))  # тёмная грань
    for _ in range(3 + v):  # трещины
        x, y = rnd.randint(6, 34), rnd.randint(6, 34)
        for _ in range(4):
            nx, ny = x + rnd.randint(-6, 6), y + rnd.randint(-6, 6)
            d.line([(x, y), (nx, ny)], fill=(236, 248, 255, 150), width=1)
            x, y = nx, ny
    for _ in range(5):  # блики
        x, y = rnd.randint(3, 36), rnd.randint(3, 36)
        d.line([(x - 2, y), (x + 2, y)], fill=(255, 255, 255, 220), width=1)
        d.line([(x, y - 2), (x, y + 2)], fill=(255, 255, 255, 220), width=1)
    speckle(img, rnd, 200, 10)
    return bevel(img, 110, 90)


def wall_lava(v):
    rnd = random.Random(700 + v)
    img = Image.new("RGBA", (T, T), (52, 40, 44, 255))
    d = ImageDraw.Draw(img, "RGBA")
    for gx in range(2):  # плиты базальта
        for gy in range(2):
            x0, y0 = gx * 20 + 1, gy * 20 + 1
            col = jitter((66, 52, 56), 8, rnd)
            d.polygon([(x0 + rnd.randint(0, 3), y0), (x0 + 18, y0 + rnd.randint(0, 3)),
                       (x0 + 18 - rnd.randint(0, 3), y0 + 18), (x0, y0 + 18 - rnd.randint(0, 3))], fill=col + (255,))
    glow = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    x, y = rnd.randint(0, 6), 20
    for _ in range(9):  # светящаяся трещина
        nx, ny = x + rnd.randint(2, 6), y + rnd.randint(-7, 7)
        ny = max(2, min(T - 3, ny))
        gd.line([(x, y), (nx, ny)], fill=(255, 120, 30, 255), width=2)
        if rnd.random() < 0.35:
            gd.line([(nx, ny), (nx + rnd.randint(-5, 5), ny + rnd.randint(4, 8))], fill=(255, 100, 20, 255), width=1)
        x, y = nx, ny
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(2.2)))
    img.alpha_composite(glow.point(lambda a: int(a * 0.85)))
    speckle(img, rnd, 140, 8)
    return bevel(img, 50, 110)


def wall_neon(v):
    rnd = random.Random(800 + v)
    img = Image.new("RGBA", (T, T), (28, 24, 48, 255))
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([5, 5, T - 6, T - 6], fill=(36, 30, 62, 255))
    glow = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cyan, magenta = (60, 230, 255, 255), (255, 60, 200, 255)
    gd.rectangle([4, 4, T - 5, T - 5], outline=cyan, width=1)
    gd.line([(4, 4), (13, 4)], fill=magenta, width=2)
    gd.line([(T - 5, T - 5), (T - 14, T - 5)], fill=magenta, width=2)
    if v == 1:
        gd.line([(10, 20), (T - 11, 20)], fill=cyan, width=1)
        gd.ellipse([T / 2 - 3, 17, T / 2 + 3, 23], outline=magenta, width=1)
    if v == 2:
        gd.line([(10, 10), (10, 28), (22, 28), (22, 16), (30, 16)], fill=cyan, width=1)
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(2.0)))
    img.alpha_composite(glow)
    speckle(img, rnd, 100, 6)
    return bevel(img, 40, 120, 1)


WALLS = [wall_concrete, wall_sandstone, wall_mossy, wall_steel, wall_brick, wall_ice, wall_lava, wall_neon]


# --------------------------------------------------------------------------- полы (бесшовные)


class Wrap:
    """Рисование на тайле F x F с переносом через края (бесшовность)."""

    def __init__(self, base):
        self.img = Image.new("RGBA", (F, F), base + (255,))
        self.d = ImageDraw.Draw(self.img, "RGBA")

    def each(self, fn, x, y):
        for ox in (-F, 0, F):
            for oy in (-F, 0, F):
                fn(x + ox, y + oy)

    def ellipse(self, x, y, rx, ry, col):
        self.each(lambda a, b: self.d.ellipse([a - rx, b - ry, a + rx, b + ry], fill=col), x, y)

    def line(self, x0, y0, x1, y1, col, w=1):
        self.each(lambda a, b: self.d.line([(x0 + a - x0, y0 + b - y0), (x1 + a - x0, y1 + b - y0)], fill=col, width=w), x0, y0)

    def dots(self, rnd, n, col_fn):
        px = self.img.load()
        for _ in range(n):
            x, y = rnd.randrange(F), rnd.randrange(F)
            r, g, b, a = px[x, y]
            d = col_fn(rnd)
            px[x, y] = (clamp(r + d), clamp(g + d), clamp(b + d), 255)


def floor_concrete():
    rnd = random.Random(1)
    w = Wrap((38, 42, 40))
    w.dots(rnd, 500, lambda r: r.randint(-9, 9))
    for p in (0, 40):  # плиты 40x40
        w.d.line([(p, 0), (p, F)], fill=(58, 62, 60, 255))
        w.d.line([(0, p), (F, p)], fill=(58, 62, 60, 255))
        w.d.line([(p + 1, 0), (p + 1, F)], fill=(24, 26, 25, 200))
        w.d.line([(0, p + 1), (F, p + 1)], fill=(24, 26, 25, 200))
    return w.img


def floor_sand():
    rnd = random.Random(2)
    w = Wrap((126, 104, 72))
    w.dots(rnd, 700, lambda r: r.randint(-12, 12))
    for _ in range(9):  # волны дюн
        x, y = rnd.randrange(F), rnd.randrange(F)
        w.line(x, y, x + rnd.randint(10, 22), y + rnd.randint(-3, 3), (150, 126, 90, 120), 1)
    for _ in range(14):
        w.ellipse(rnd.randrange(F), rnd.randrange(F), 1.2, 1, (96, 78, 54, 255))
    return w.img


def floor_grass():
    rnd = random.Random(3)
    w = Wrap((48, 80, 46))
    w.dots(rnd, 600, lambda r: r.randint(-10, 10))
    for _ in range(46):
        x, y = rnd.randrange(F), rnd.randrange(F)
        c = (70 + rnd.randint(0, 25), 120 + rnd.randint(0, 30), 60, 255)
        w.line(x, y, x + rnd.randint(-2, 2), y - rnd.randint(3, 6), c, 1)
    for _ in range(5):
        w.ellipse(rnd.randrange(F), rnd.randrange(F), 1.5, 1.5, (210, 200, 90, 255))
    return w.img


def floor_metal():
    rnd = random.Random(4)
    w = Wrap((46, 54, 68))
    w.dots(rnd, 300, lambda r: r.randint(-6, 6))
    for p in (0, 40):
        w.d.line([(p, 0), (p, F)], fill=(26, 32, 44, 255), width=2)
        w.d.line([(0, p), (F, p)], fill=(26, 32, 44, 255), width=2)
        w.d.line([(p + 2, 0), (p + 2, F)], fill=(70, 82, 100, 160))
        w.d.line([(0, p + 2), (F, p + 2)], fill=(70, 82, 100, 160))
    for x in (6, 46):
        for y in (6, 46):
            for ox, oy in ((0, 0), (28, 0), (0, 28), (28, 28)):
                w.ellipse(x + ox, y + oy, 1.4, 1.4, (86, 98, 118, 255))
    return w.img


def floor_dirt():
    rnd = random.Random(5)
    w = Wrap((78, 58, 44))
    w.dots(rnd, 650, lambda r: r.randint(-12, 12))
    for _ in range(16):
        r = rnd.randint(1, 2)
        x, y = rnd.randrange(F), rnd.randrange(F)
        w.ellipse(x, y, r + 1, r, (58, 42, 32, 255))
        w.ellipse(x - 0.5, y - 0.5, r, r - 0.5, (112, 92, 72, 255))
    for _ in range(4):  # следы колёс
        x, y = rnd.randrange(F), rnd.randrange(F)
        w.line(x, y, x + 18, y + rnd.randint(-2, 2), (54, 40, 30, 130), 2)
    return w.img


def _glow_wrap(layer, blur):
    """Размытие бесшовного слоя: размываем 3x3 копии и берём центр."""
    big = Image.new("RGBA", (F * 3, F * 3))
    for ox in range(3):
        for oy in range(3):
            big.paste(layer, (ox * F, oy * F))
    return big.filter(ImageFilter.GaussianBlur(blur)).crop((F, F, F * 2, F * 2))


def floor_ice():
    rnd = random.Random(6)
    w = Wrap((100, 128, 156))
    w.dots(rnd, 600, lambda r: r.randint(-10, 10))
    for _ in range(8):  # трещины льда
        x, y = rnd.randrange(F), rnd.randrange(F)
        for _ in range(4):
            nx, ny = x + rnd.randint(-9, 9), y + rnd.randint(-9, 9)
            w.line(x, y, nx, ny, (190, 220, 240, 120), 1)
            x, y = nx, ny
    for _ in range(26):  # снежинки / блики
        w.ellipse(rnd.randrange(F), rnd.randrange(F), 1, 1, (232, 244, 255, 230))
    return w.img


def floor_lava():
    rnd = random.Random(7)
    w = Wrap((38, 30, 32))
    w.dots(rnd, 500, lambda r: r.randint(-8, 8))
    glow = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for _ in range(4):  # редкие тонкие светящиеся трещины (с переносом через края)
        x, y = rnd.randrange(F), rnd.randrange(F)
        for _ in range(4):
            nx, ny = x + rnd.randint(-14, 14), y + rnd.randint(-14, 14)
            for ox in (-F, 0, F):
                for oy in (-F, 0, F):
                    gd.line([(x + ox, y + oy), (nx + ox, ny + oy)], fill=(255, 110, 24, 255), width=1)
            x, y = nx, ny
    w.img.alpha_composite(_glow_wrap(glow, 1.8).point(lambda a: int(a * 0.55)))
    w.img.alpha_composite(glow.point(lambda a: int(a * 0.7)))
    for _ in range(10):  # угольки
        w.ellipse(rnd.randrange(F), rnd.randrange(F), 1, 1, (255, 180, 70, 255))
    return w.img


def floor_neon():
    rnd = random.Random(8)
    w = Wrap((20, 17, 34))
    w.dots(rnd, 260, lambda r: r.randint(-5, 5))
    glow = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for p in (0, 40):
        gd.line([(p, 0), (p, F)], fill=(60, 220, 255, 255), width=1)
        gd.line([(0, p), (F, p)], fill=(255, 70, 200, 255), width=1)
    for x in (0, 40, 80):
        for y in (0, 40, 80):
            gd.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(255, 255, 255, 255))
    w.img.alpha_composite(_glow_wrap(glow, 2.0).point(lambda a: int(a * 0.55)))
    w.img.alpha_composite(glow.point(lambda a: int(a * 0.45)))
    return w.img


FLOORS = [floor_concrete, floor_sand, floor_grass, floor_metal, floor_dirt, floor_ice, floor_lava, floor_neon]


# --------------------------------------------------------------------------- декали (40x40, прозрачные)


def decal_crack():
    rnd = random.Random(11)
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x, y = 4, 20
    for _ in range(10):
        nx, ny = x + rnd.randint(2, 5), y + rnd.randint(-5, 5)
        d.line([(x, y), (nx, ny)], fill=(0, 0, 0, 130), width=1)
        if rnd.random() < 0.3:
            d.line([(nx, ny), (nx + rnd.randint(2, 5), ny + rnd.randint(-6, 6))], fill=(0, 0, 0, 90), width=1)
        x, y = nx, ny
    return img


def _blob(col, rx, ry, blur, seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(4):
        cx, cy = 20 + rnd.randint(-4, 4), 20 + rnd.randint(-3, 3)
        a, b = rx * rnd.uniform(0.6, 1.0), ry * rnd.uniform(0.6, 1.0)
        d.ellipse([cx - a, cy - b, cx + a, cy + b], fill=col)
    return img.filter(ImageFilter.GaussianBlur(blur))


def decal_stain():
    return _blob((0, 0, 0, 120), 13, 9, 2.0, 12)


def decal_pebbles():
    rnd = random.Random(13)
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(6):
        x, y, r = rnd.randint(6, 33), rnd.randint(6, 33), rnd.randint(2, 4)
        d.ellipse([x - r, y - r + 1, x + r, y + r + 1], fill=(0, 0, 0, 90))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(138, 140, 142, 230), outline=(70, 72, 74, 230))
        d.ellipse([x - r * 0.4 - 1, y - r * 0.5, x, y - r * 0.1], fill=(210, 212, 214, 200))
    return img


def decal_tuft():
    rnd = random.Random(14)
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(9):
        a = math.radians(rnd.randint(-70, 70) - 90)
        ln = rnd.randint(8, 15)
        x1, y1 = 20 + math.cos(a) * ln, 24 + math.sin(a) * ln
        d.line([(20, 24), (x1, y1)], fill=(60 + rnd.randint(0, 40), 120 + rnd.randint(0, 40), 52, 235), width=2)
    return img


def decal_scorch():
    return _blob((10, 8, 6, 170), 12, 11, 3.0, 15)


def decal_puddle():
    img = _blob((70, 110, 150, 120), 14, 9, 1.4, 16)
    d = ImageDraw.Draw(img)
    d.arc([10, 14, 28, 26], 200, 290, fill=(220, 235, 250, 150), width=1)
    return img


DECALS = [decal_crack, decal_stain, decal_pebbles, decal_tuft, decal_scorch, decal_puddle]


# --------------------------------------------------------------------------- ящики 36x36 (рисуем в 4x)

S = 4


def _crate_canvas():
    return Image.new("RGBA", (C * S, C * S), (0, 0, 0, 0))


def _rr(d, box, r, fill, outline=None, w=1):
    d.rounded_rectangle([v * S for v in box], radius=max(1, round(r * S)), fill=fill, outline=outline, width=max(1, round(w * S)))


def _finish(img):
    out = img.resize((C, C), Image.LANCZOS)
    # внутренний блик сверху-слева
    d = ImageDraw.Draw(out, "RGBA")
    d.line([(2, 2), (C - 4, 2)], fill=(255, 255, 255, 50))
    d.line([(2, 2), (2, C - 4)], fill=(255, 255, 255, 35))
    return out


def crate_wood():
    img = _crate_canvas()
    d = ImageDraw.Draw(img, "RGBA")
    _rr(d, (1, 1, C - 1, C - 1), 3, (122, 80, 40, 255), (58, 36, 18, 255), 1)
    for i, y in enumerate((3, 12, 21, 30)):  # доски
        shade = (178, 128, 72) if i % 2 == 0 else (164, 114, 62)
        _rr(d, (3, y, C - 3, y + 6), 1, shade + (255,), (96, 62, 30, 255), 0.6)
        d.line([(6 * S, (y + 2) * S), ((C - 7) * S, (y + 2) * S)], fill=(205, 158, 98, 90), width=S // 2)
    d.line([(4 * S, 4 * S), ((C - 4) * S, (C - 4) * S)], fill=(84, 52, 24, 255), width=3 * S)  # раскос
    d.line([(4 * S, 4 * S), ((C - 4) * S, (C - 4) * S)], fill=(150, 104, 56, 255), width=1 * S)
    for x, y in ((4, 4), (C - 5, 4), (4, C - 5), (C - 5, C - 5)):
        d.ellipse([(x - 1) * S, (y - 1) * S, (x + 1) * S, (y + 1) * S], fill=(60, 60, 64, 255))
    return _finish(img)


def crate_metal():
    img = _crate_canvas()
    d = ImageDraw.Draw(img, "RGBA")
    _rr(d, (1, 1, C - 1, C - 1), 3, (112, 122, 136, 255), (36, 42, 52, 255), 1)
    _rr(d, (4, 4, C - 4, C - 4), 2, (134, 146, 162, 255), (70, 80, 96, 255), 0.8)
    for y in range(8, C - 6, 5):  # рёбра
        d.line([(7 * S, y * S), ((C - 8) * S, y * S)], fill=(84, 94, 110, 255), width=S)
        d.line([(7 * S, (y + 1) * S), ((C - 8) * S, (y + 1) * S)], fill=(176, 188, 204, 120), width=S // 2)
    for x, y in ((3, 3), (C - 4, 3), (3, C - 4), (C - 4, C - 4)):  # угловые заклёпки
        d.ellipse([(x - 1.4) * S, (y - 1.4) * S, (x + 1.4) * S, (y + 1.4) * S], fill=(188, 198, 212, 255), outline=(40, 48, 60, 255))
    return _finish(img)


def crate_military():
    img = _crate_canvas()
    d = ImageDraw.Draw(img, "RGBA")
    _rr(d, (1, 1, C - 1, C - 1), 3, (72, 90, 52, 255), (30, 40, 22, 255), 1)
    _rr(d, (4, 4, C - 4, C - 4), 2, (92, 112, 66, 255), (50, 64, 36, 255), 0.8)
    d.rectangle([8 * S, 14 * S, (C - 8) * S, 22 * S], outline=(232, 232, 214, 230), width=S)
    for i in range(4):  # трафарет
        d.line([((11 + i * 4) * S, 16 * S), ((11 + i * 4) * S, 20 * S)], fill=(232, 232, 214, 230), width=S)
    for x in (6, C - 7):
        d.rectangle([(x - 1) * S, 6 * S, (x + 1) * S, 9 * S], fill=(50, 62, 34, 255))
    return _finish(img)


def crate_hazard():
    img = _crate_canvas()
    d = ImageDraw.Draw(img, "RGBA")
    _rr(d, (1, 1, C - 1, C - 1), 3, (224, 178, 30, 255), (40, 32, 10, 255), 1)
    stripes = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(stripes)
    for k in range(-C * S, C * 2 * S, 9 * S):
        sd.polygon([(k, 0), (k + 4 * S, 0), (k + 4 * S + C * S, C * S), (k + C * S, C * S)], fill=(26, 24, 20, 255))
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([2 * S, 2 * S, (C - 2) * S, (C - 2) * S], radius=2 * S, fill=255)
    md.rounded_rectangle([9 * S, 9 * S, (C - 9) * S, (C - 9) * S], radius=1 * S, fill=0)
    from PIL import ImageChops
    stripes.putalpha(ImageChops.multiply(stripes.getchannel("A"), mask))
    img.alpha_composite(stripes)
    _rr(d, (9, 9, C - 9, C - 9), 1, (60, 56, 48, 255), (24, 22, 18, 255), 1)
    d.line([(13 * S, 18 * S), ((C - 13) * S, 18 * S)], fill=(224, 178, 30, 255), width=2 * S)
    return _finish(img)


CRATES = [crate_wood, crate_metal, crate_military, crate_hazard]


# --------------------------------------------------------------------------- сборка


def build():
    os.makedirs(OUT, exist_ok=True)
    tiles = Image.new("RGBA", (T * len(WALLS), T * 3))
    for theme, fn in enumerate(WALLS):
        for v in range(3):
            tiles.paste(fn(v), (theme * T, v * T))
    tiles.save(os.path.join(OUT, "tiles.png"))
    for i, fn in enumerate(FLOORS):
        fn().save(os.path.join(OUT, f"floor_{i}.png"))
    decals = Image.new("RGBA", (T * len(DECALS), T), (0, 0, 0, 0))
    for i, fn in enumerate(DECALS):
        decals.paste(fn(), (i * T, 0))
    decals.save(os.path.join(OUT, "decals.png"))
    crates = Image.new("RGBA", (C * len(CRATES), C), (0, 0, 0, 0))
    for i, fn in enumerate(CRATES):
        crates.paste(fn(), (i * C, 0))
    crates.save(os.path.join(OUT, "crates.png"))
    print("saved to", os.path.abspath(OUT))


def preview(path):
    """Контрольный лист: 5 тем (пол + стены + декали) и ящики."""
    sheet = Image.new("RGBA", (8 * 260, 330), (16, 18, 16, 255))
    tiles = Image.open(os.path.join(OUT, "tiles.png"))
    decals = Image.open(os.path.join(OUT, "decals.png"))
    crates = Image.open(os.path.join(OUT, "crates.png"))
    for theme in range(8):
        ox = theme * 260 + 10
        floor = Image.open(os.path.join(OUT, f"floor_{theme}.png"))
        for fx in range(0, 240, F):
            for fy in range(0, 160, F):
                sheet.alpha_composite(floor, (ox + fx, 10 + fy))
        for v in range(3):  # тайлы стен
            sheet.alpha_composite(tiles.crop((theme * T, v * T, theme * T + T, v * T + T)), (ox + v * 44, 180))
        for i in range(6):  # декали на полу
            sheet.alpha_composite(decals.crop((i * T, 0, i * T + T, T)), (ox + i * 38, 100))
        for i in range(4):
            sheet.alpha_composite(crates.crop((i * C, 0, i * C + C, C)), (ox + i * 40, 230 + (theme % 2) * 0))
    sheet = sheet.resize((sheet.width, sheet.height), Image.NEAREST)
    sheet.convert("RGB").save(path)


if __name__ == "__main__":
    build()
    if "--preview" in sys.argv:
        preview(os.path.join(sys.argv[sys.argv.index("--preview") + 1], "arena_art_preview.png"))
        print("preview saved")
