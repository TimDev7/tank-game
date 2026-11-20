"""Монтаж превью-видео для CrazyGames из записи tools/record_preview.gd.

Запуск:  python tools/make_preview_video.py <preview.avi> [intro_секунд=0.5]     (нужны Pillow и ffmpeg в PATH)
Выход (assets/store/): preview_landscape_1080p.mp4 (1920x1080), preview_portrait_1080x1620.mp4 (2:3)

Правила портала (docs/crazygames-requirements.md §5): 15-20 с, <= 50 МБ, без звука, без ускорения,
первый кадр = статичная обложка, без чёрных экранов/полос, без курсора и промо-текста.
Вертикальная версия: геймплей по центру, фон — он же размытый (чёрных полос нет).
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import make_store_assets as store

src = os.path.abspath(sys.argv[1])
intro = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5
tmp = os.path.dirname(src)

land_cover = os.path.join(store.OUT, "cover_landscape_1920x1080.png")
port_cover = os.path.join(tmp, "cover_portrait_1080x1620.png")
store.cover(1080, 1620, 1.0).save(port_cover)  # та же обложка, но сразу в 1080x1620, без апскейла


def encode(cover, out, gameplay_filter, size):
    w, h = size
    graph = (
        f"[0:v]scale={w}:{h},setsar=1,fps=60,format=yuv420p[intro];"
        f"[1:v]{gameplay_filter},setsar=1,fps=60,format=yuv420p[game];"
        "[intro][game]concat=n=2:v=1:a=0[v]"
    )
    subprocess.run([
        "ffmpeg", "-v", "error", "-y",
        "-loop", "1", "-framerate", "60", "-t", str(intro), "-i", cover,
        "-i", src,
        "-filter_complex", graph, "-map", "[v]", "-an",
        "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-movflags", "+faststart", out,
    ], check=True)
    print(out, round(os.path.getsize(out) / 1e6, 1), "MB")


encode(land_cover, os.path.join(store.OUT, "preview_landscape_1080p.mp4"), "scale=1920:1080", (1920, 1080))
encode(port_cover, os.path.join(store.OUT, "preview_portrait_1080x1620.mp4"),
       "split[a][b];[a]scale=-2:1620,crop=1080:1620,boxblur=40:2,eq=brightness=-0.12[bg];"
       "[b]scale=1080:-2[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2", (1080, 1620))
