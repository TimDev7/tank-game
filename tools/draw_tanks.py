"""Рисует спрайты танков (вид сверху, смотрят ВПРАВО = +X, как SpawnPoint с rotation 0).

Запуск:  python tools/draw_tanks.py   (нужен Pillow; Python 3.11: pip install pillow)
Выход:   game/tanks/art/tank_{blue,red}_{hull,turret}.png  +  tank_preview.png в --preview <папка>

Размеры (финальные пиксели):
  hull   96 x 64   — корпус с гусеницами, pivot в центре
  turret 160 x 64  — башня + ствол, pivot башни ровно в центре холста (80, 32)
Башня вращается вокруг центра холста, ствол смотрит вправо.
"""
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 4  # суперсэмплинг
OUT = os.path.join(os.path.dirname(__file__), "art_src")

PALETTES = {
    "blue": {"base": (58, 110, 200), "light": (110, 165, 240), "dark": (26, 52, 112), "edge": (14, 28, 66)},
    "red": {"base": (205, 56, 50), "light": (245, 110, 98), "dark": (112, 24, 24), "edge": (62, 12, 12)},
}
STEEL = {"base": (88, 94, 102), "light": (150, 158, 168), "dark": (42, 46, 52), "edge": (22, 24, 28)}
TRACK = (34, 36, 40)
TRACK_LINK = (62, 65, 70)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shaded(size, pts, pal, horizontal=False):
    """Заливка полигона вертикальным градиентом light->base->dark + контур."""
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    n = w if horizontal else h
    for i in range(n):
        t = i / max(1, n - 1)
        col = lerp(pal["light"], pal["base"], t / 0.45) if t < 0.45 else lerp(pal["base"], pal["dark"], (t - 0.45) / 0.55)
        if horizontal:
            d.line([(i, 0), (i, h)], fill=col + (255,))
        else:
            d.line([(0, i), (w, i)], fill=col + (255,))
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(layer, (0, 0), mask)
    od = ImageDraw.Draw(out)
    od.line(list(pts) + [pts[0]], fill=pal["edge"] + (255,), width=int(1.6 * S), joint="curve")
    return out


def sc(points):
    return [(x * S, y * S) for x, y in points]


def draw_hull(pal, out_scale=1):
    W, H = 96, 64
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # гусеницы
    for y0 in (1, 47):
        d.rounded_rectangle([2 * S, y0 * S, 94 * S, (y0 + 16) * S], radius=5 * S, fill=TRACK + (255,), outline=(14, 15, 17, 255), width=int(1.5 * S))
        x = 6
        while x < 92:  # звенья гусеницы
            d.line([(x * S, (y0 + 2) * S), (x * S, (y0 + 14) * S)], fill=TRACK_LINK + (255,), width=int(1.4 * S))
            x += 4
        for cx in (11, 27, 43, 59, 75, 87):  # катки
            r = 4.2
            cy = y0 + 8
            d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=(78, 82, 90, 255), outline=(20, 22, 25, 255), width=int(1.2 * S))
            d.ellipse([(cx - 1.4) * S, (cy - 1.4) * S, (cx + 1.4) * S, (cy + 1.4) * S], fill=(30, 32, 36, 255))

    # крылья над гусеницами (цвет корпуса, чуть темнее)
    for y0, y1 in ((6, 15), (49, 58)):
        fender = shaded((W * S, H * S), sc([(5, y0), (88, y0), (90, (y0 + y1) / 2), (88, y1), (5, y1)]), {**pal, "light": pal["base"], "base": pal["dark"], "dark": pal["dark"]})
        img.alpha_composite(fender)

    # корпус: скошенный нос, угловатый корма
    hull_pts = sc([(5, 15), (11, 12), (74, 12), (88, 22), (92, 32), (88, 42), (74, 52), (11, 52), (5, 49)])
    img.alpha_composite(shaded((W * S, H * S), hull_pts, pal))
    d = ImageDraw.Draw(img)

    edge = pal["edge"] + (255,)
    hi = pal["light"] + (160,)
    # лобовая плита: линия перелома и швы
    d.line(sc([(74, 12), (74, 52)]), fill=edge, width=int(1.1 * S))
    d.line(sc([(75.5, 13), (75.5, 51)]), fill=hi, width=int(0.8 * S))
    d.line(sc([(74, 32), (92, 32)]), fill=pal["edge"] + (120,), width=int(0.8 * S))
    # моторный отсек (решётка) сзади
    d.rectangle([7 * S, 17 * S, 24 * S, 47 * S], fill=STEEL["dark"] + (255,), outline=edge, width=int(1.1 * S))
    for i in range(6):
        y = 20 + i * 4.6
        d.line([(9 * S, y * S), (22 * S, y * S)], fill=(98, 102, 110, 255), width=int(1.3 * S))
    # люки/панели
    d.rounded_rectangle([30 * S, 16 * S, 44 * S, 24 * S], radius=2 * S, outline=edge, width=int(1.0 * S), fill=pal["dark"] + (110,))
    d.rounded_rectangle([30 * S, 40 * S, 44 * S, 48 * S], radius=2 * S, outline=edge, width=int(1.0 * S), fill=pal["dark"] + (110,))
    # фары
    for y in (22, 42):
        d.ellipse([85 * S, (y - 2) * S, 89 * S, (y + 2) * S], fill=(255, 238, 170, 255), outline=edge, width=int(0.9 * S))
    # заклёпки
    for x in (14, 60, 68):
        for y in (14.5, 49.5):
            d.ellipse([(x - 0.9) * S, (y - 0.9) * S, (x + 0.9) * S, (y + 0.9) * S], fill=pal["light"] + (255,))
    return img.resize((W * out_scale, H * out_scale), Image.LANCZOS)


def draw_turret(pal, out_scale=1):
    W, H = 160, 64
    cx, cy = 80, 32
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # ствол
    barrel = shaded((W * S, H * S), sc([(cx + 12, cy - 4.5), (cx + 66, cy - 4.5), (cx + 66, cy + 4.5), (cx + 12, cy + 4.5)]), STEEL)
    img.alpha_composite(barrel)
    d = ImageDraw.Draw(img)
    d.line(sc([(cx + 14, cy - 2.2), (cx + 64, cy - 2.2)]), fill=(190, 198, 208, 150), width=int(1.0 * S))
    # дульный тормоз
    brake = shaded((W * S, H * S), sc([(cx + 62, cy - 7.5), (cx + 75, cy - 7.5), (cx + 75, cy + 7.5), (cx + 62, cy + 7.5)]), STEEL)
    img.alpha_composite(brake)
    d = ImageDraw.Draw(img)
    for x in (65.5, 69, 72.5):
        d.line(sc([(cx + x, cy - 7), (cx + x, cy + 7)]), fill=STEEL["edge"] + (255,), width=int(1.1 * S))
    d.ellipse([(cx + 73) * S, (cy - 2.2) * S, (cx + 76.5) * S, (cy + 2.2) * S], fill=(12, 12, 14, 255))
    # маска орудия
    mantlet = shaded((W * S, H * S), sc([(cx + 14, cy - 12), (cx + 28, cy - 10), (cx + 28, cy + 10), (cx + 14, cy + 12)]), {**pal, "base": pal["dark"], "light": pal["base"]})
    img.alpha_composite(mantlet)

    # башня
    pts = sc([(cx - 30, cy - 17), (cx + 6, cy - 21), (cx + 24, cy - 13), (cx + 28, cy - 6),
              (cx + 28, cy + 6), (cx + 24, cy + 13), (cx + 6, cy + 21), (cx - 30, cy + 17),
              (cx - 37, cy + 9), (cx - 37, cy - 9)])
    img.alpha_composite(shaded((W * S, H * S), pts, pal))
    d = ImageDraw.Draw(img)
    edge = pal["edge"] + (255,)
    # кормовая ниша
    d.rounded_rectangle([(cx - 36) * S, (cy - 9) * S, (cx - 27) * S, (cy + 9) * S], radius=2 * S, fill=pal["dark"] + (255,), outline=edge, width=int(1.0 * S))
    d.line(sc([(cx - 31.5, cy - 8), (cx - 31.5, cy + 8)]), fill=(0, 0, 0, 70), width=int(0.8 * S))
    # швы брони
    d.line(sc([(cx - 24, cy - 17), (cx - 24, cy + 17)]), fill=edge[:3] + (110,), width=int(0.9 * S))
    d.line(sc([(cx + 12, cy - 19), (cx + 12, cy + 19)]), fill=edge[:3] + (110,), width=int(0.9 * S))
    # люк командира
    hx, hy, hr = cx - 12, cy - 7, 7.5
    d.ellipse([(hx - hr) * S, (hy - hr) * S, (hx + hr) * S, (hy + hr) * S], fill=pal["dark"] + (255,), outline=edge, width=int(1.3 * S))
    d.ellipse([(hx - 5) * S, (hy - 5) * S, (hx + 5) * S, (hy + 5) * S], fill=(70, 76, 84, 255), outline=edge, width=int(1.0 * S))
    d.ellipse([(hx - 1.8) * S, (hy - 1.8) * S, (hx + 1.8) * S, (hy + 1.8) * S], fill=(150, 158, 168, 255))
    # люк заряжающего + перископ
    d.ellipse([(cx - 11) * S, (cy + 5) * S, (cx - 3) * S, (cy + 13) * S], fill=pal["dark"] + (255,), outline=edge, width=int(1.1 * S))
    d.rectangle([(cx + 4) * S, (cy - 3) * S, (cx + 10) * S, (cy + 3) * S], fill=(30, 40, 52, 255), outline=edge, width=int(1.0 * S))
    # антенна (вид сверху — тонкая линия назад)
    d.line(sc([(cx - 28, cy + 10), (cx - 44, cy + 22)]), fill=(20, 20, 22, 255), width=int(0.9 * S))
    # блик
    d.line(sc([(cx - 28, cy - 15), (cx + 2, cy - 19)]), fill=pal["light"] + (200,), width=int(1.0 * S))
    return img.resize((W * out_scale, H * out_scale), Image.LANCZOS)


def preview(path):
    bg = Image.new("RGBA", (640, 360), (33, 38, 33, 255))
    d = ImageDraw.Draw(bg)
    for x in range(0, 640, 40):
        d.line([(x, 0), (x, 360)], fill=(40, 46, 40, 255))
    for y in range(0, 360, 40):
        d.line([(0, y), (640, y)], fill=(40, 46, 40, 255))
    d.rectangle([0, 160, 40, 200], fill=(115, 120, 128, 255))  # тайл для масштаба
    for color, (px, py), ang in (("blue", (160, 110), 0), ("red", (480, 250), 180), ("blue", (160, 270), 35), ("red", (480, 100), 215)):
        hull = Image.open(os.path.join(OUT, f"tank_{color}_hull.png"))
        turret = Image.open(os.path.join(OUT, f"tank_{color}_turret.png"))
        layer = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
        layer.alpha_composite(hull, (100 - 48, 100 - 32))
        layer.alpha_composite(turret, (100 - 80, 100 - 32))
        layer = layer.rotate(-ang, resample=Image.BICUBIC)
        bg.alpha_composite(layer, (px - 100, py - 100))
    bg = bg.resize((1280, 720), Image.NEAREST)
    bg.save(path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, pal in PALETTES.items():
        draw_hull(pal).save(os.path.join(OUT, f"tank_{name}_hull.png"))
        draw_turret(pal).save(os.path.join(OUT, f"tank_{name}_turret.png"))
    print("saved to", os.path.abspath(OUT))
    if "--preview" in sys.argv:
        out_dir = sys.argv[sys.argv.index("--preview") + 1]
        preview(os.path.join(out_dir, "tank_preview.png"))
        print("preview saved")
