#!/usr/bin/env python3
"""Illustrations des cinématiques (plans fixes animés en jeu par zoom et panoramique lents).

Même direction que tools/gen_art.py : craie désaturée, gris-bleu froids, ocres éteints, trait d'encre ;
turquoise pour la Meute et le vaisseau, violet pour les Gardiens. Déterministe.
Usage : python3 tools/gen_cinematics.py
"""

from pathlib import Path

import numpy as np
from gen_art import INK, PACK, chalk, fbm, jag, to_img
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "cinematics"
N = 960  # taille finale
S = 2  # suréchantillonnage
GUARD = (150, 96, 210)
VOID, VOID_L = (14, 17, 26), (40, 48, 64)
OCHRE, OCHRE_D = (176, 152, 124), (96, 82, 76)
STONE, STONE_D, STONE_L = (104, 112, 128), (52, 58, 74), (160, 168, 178)


def canvas():
    return N * S


def gradient(n, top, bottom):
    t = np.linspace(0, 1, n, dtype=np.float32)[:, None, None]
    return np.array(top, np.float32) * (1 - t) + np.array(bottom, np.float32) * t * np.ones((n, n, 1), np.float32)


def haze(a, rng, col, amount, octaves=(3, 6, 12)):
    m = fbm(rng, a.shape[0], octaves)[..., None] * amount
    return a * (1 - m) + np.array(col, np.float32) * m


def grain(a, rng, strength=0.14):
    return a * chalk(rng, a.shape[0], strength)[..., None]


def stars(d, rng, n, count, area=None):
    x0, y0, x1, y1 = area or (0, 0, n, n)
    for _ in range(count):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.choice([1, 1, 1, 2]) * S
        v = int(rng.uniform(120, 220))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(v, v, v + 10))


def glow(img, pts_fn, col, radius):
    layer = Image.new("RGB", img.size, (0, 0, 0))
    pts_fn(ImageDraw.Draw(layer))
    layer = layer.filter(ImageFilter.GaussianBlur(radius))
    a = np.asarray(img, np.float32) + np.asarray(layer, np.float32) * (np.array(col, np.float32) / 255)
    return to_img(a)


def planet(img, rng, cx, cy, r, grid=True):
    n = img.size[0]
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    inside = dist <= 1
    surf = fbm(rng, n, (4, 8, 16, 32))
    base = np.array(OCHRE_D, np.float32) * (1 - surf[..., None]) + np.array((150, 140, 130), np.float32) * surf[..., None]
    clouds = np.clip((fbm(rng, n, (6, 12, 24)) - 0.55) * 3, 0, 1)[..., None]
    base = base * (1 - clouds * 0.7) + np.array((196, 200, 206), np.float32) * clouds * 0.7
    light = np.clip(((xx - cx) * -0.6 + (yy - cy) * -0.8) / r * 0.7 + 0.35, 0, 1)[..., None]  # nord-ouest
    base = base * (0.15 + 0.85 * light)
    a = np.asarray(img, np.float32).copy()
    a[inside] = base[inside]
    rim = (dist > 0.985) & (dist < 1.02)
    a[rim] = a[rim] * 0.4 + np.array((150, 180, 200), np.float32) * 0.6
    out = to_img(a)
    if grid:
        layer = Image.new("RGB", out.size, (0, 0, 0))
        d = ImageDraw.Draw(layer)
        step = r / 7
        for k in range(-7, 8):
            for x0 in (cx + k * step,):
                d.line([(x0, cy - r), (x0 + r * 0.25, cy + r)], fill=GUARD, width=S * 2)
            d.line([(cx - r, cy + k * step), (cx + r, cy + k * step + r * 0.12)], fill=GUARD, width=S * 2)
        mask = (inside & (light[..., 0] > 0.25) & (fbm(rng, n, (3, 6)) > 0.45)).astype(np.float32)
        g = np.asarray(layer, np.float32) * mask[..., None] * 0.55
        out = to_img(np.asarray(out, np.float32) * (1 - (g.sum(-1, keepdims=True) > 0) * 0.35) + g)
    return out


def ship(d, x, y, s, lit=True):
    """Silhouette de l'Asterion : coque allongée, anneau de laboratoires, mât de capteurs."""
    hull = [(x - 60 * s, y), (x - 40 * s, y - 9 * s), (x + 50 * s, y - 7 * s), (x + 70 * s, y), (x + 50 * s, y + 8 * s), (x - 40 * s, y + 9 * s)]
    d.polygon(hull, fill=(150, 156, 166), outline=INK, width=S * 2)
    d.polygon([(x - 40 * s, y - 9 * s), (x + 50 * s, y - 7 * s), (x + 50 * s, y), (x - 40 * s, y)], fill=(196, 200, 204))
    d.ellipse([x - 16 * s, y - 22 * s, x + 4 * s, y + 22 * s], outline=(120, 126, 138), width=int(4 * s))
    d.line([(x + 60 * s, y), (x + 92 * s, y - 4 * s)], fill=(120, 126, 138), width=int(2 * s))
    for k in range(5):
        d.rectangle([x - 34 * s + k * 16 * s, y - 2 * s, x - 28 * s + k * 16 * s, y + 2 * s], fill=PACK if lit else (60, 70, 80))


def save(img, name):
    img = img.resize((N, N), Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.webp", quality=84, method=6)
    return img


# ------------------------------------------------------------------ plans


def p_transit(rng):
    n = canvas()
    a = gradient(n, VOID, VOID_L)
    img = to_img(grain(haze(a, rng, (60, 64, 86), 0.4), rng))
    d = ImageDraw.Draw(img)
    stars(d, rng, n, 260)
    cx, cy = n * 0.58, n * 0.42

    def tear(dd):
        for k in range(14):
            w, h = n * (0.05 + k * 0.018), n * (0.28 - k * 0.008)
            pts = jag(rng, [(cx - w, cy), (cx - w * 0.3, cy - h), (cx + w * 0.4, cy - h * 0.8), (cx + w, cy), (cx + w * 0.3, cy + h), (cx - w * 0.4, cy + h * 0.9)], n * 0.01)
            dd.line([*pts, pts[0]], fill=(200, 220, 230) if k < 4 else (90, 110, 140), width=S * (3 if k < 4 else 1))
        dd.ellipse([cx - n * 0.03, cy - n * 0.2, cx + n * 0.03, cy + n * 0.2], fill=(235, 240, 240))

    img = glow(img, tear, (230, 240, 255), n * 0.02)
    d = ImageDraw.Draw(img)
    tear(d)
    ship(d, n * 0.24, n * 0.72, S * 1.6)
    return save(img, "transit")


def p_rupture(rng):
    img = p_transit(np.random.default_rng(7)).resize((canvas(),) * 2)
    a = np.asarray(img, np.float32) * 0.35
    n = canvas()
    for _ in range(40):  # bandes de signal déchiré
        y = int(rng.uniform(0, n))
        h = int(rng.uniform(2, 14)) * S
        shift = int(rng.uniform(-60, 60)) * S
        a[y:y + h] = np.roll(a[y:y + h], shift, axis=1) * rng.uniform(0.6, 1.6)
    return save(to_img(grain(a, rng, 0.25)), "rupture")


def p_bridge(rng):
    n = canvas()
    a = gradient(n, (20, 24, 32), (44, 50, 62))
    img = to_img(grain(haze(a, rng, (30, 34, 46), 0.3), rng))
    d = ImageDraw.Draw(img)
    hz = n * 0.45  # ligne d'horizon, point de fuite au centre
    vp = (n * 0.5, hz)
    for k in range(-5, 6):  # nervures du plafond et du sol
        d.line([vp, (n * 0.5 + k * n * 0.22, 0)], fill=(58, 64, 78), width=S * 2)
        d.line([vp, (n * 0.5 + k * n * 0.22, n)], fill=(52, 58, 70), width=S * 2)
    d.rectangle([n * 0.32, hz - n * 0.12, n * 0.68, hz + n * 0.05], fill=(12, 14, 20), outline=(80, 90, 104), width=S * 3)
    img = planet(img, rng, n * 0.5, hz + n * 0.2, n * 0.22, grid=False)  # la planète dans la baie
    d = ImageDraw.Draw(img)
    for side in (-1, 1):  # consoles
        for k in range(3):
            x = n * 0.5 + side * (n * 0.22 + k * n * 0.1)
            top = hz + n * (0.12 + k * 0.06)
            d.polygon([(x, top), (x + side * n * 0.09, top + n * 0.03), (x + side * n * 0.09, n), (x, n)], fill=(34, 38, 48), outline=INK, width=S * 2)
            for j in range(4):
                c = PACK if (k + j) % 3 == 0 else (70, 80, 94)
                xa, xb = sorted((x + side * n * 0.02, x + side * n * 0.05))
                d.rectangle([xa, top + n * (0.05 + j * 0.03), xb, top + n * (0.06 + j * 0.03)], fill=c)
    d.ellipse([n * 0.47, hz - n * 0.3, n * 0.53, hz - n * 0.24], fill=PACK)  # œil d'ATHENA
    img = glow(img, lambda dd: dd.ellipse([n * 0.46, hz - n * 0.31, n * 0.54, hz - n * 0.23], fill=PACK), PACK, n * 0.03)
    return save(img, "bridge")


def p_pods(rng):
    n = canvas()
    a = gradient(n, (26, 30, 40), (58, 66, 80))
    img = to_img(grain(haze(a, rng, (90, 104, 120), 0.35), rng))
    d = ImageDraw.Draw(img)
    for k in range(6):  # six caissons, en perspective
        sc = 0.55 + k * 0.09
        cx = n * (0.12 + k * 0.155)
        cy = n * 0.55 + k * n * 0.025
        w, h = n * 0.06 * sc, n * 0.3 * sc
        d.rounded_rectangle([cx - w, cy - h, cx + w, cy + h], radius=int(w), fill=(88, 100, 114), outline=INK, width=S * 3)
        d.rounded_rectangle([cx - w * 0.65, cy - h * 0.8, cx + w * 0.65, cy + h * 0.7], radius=int(w * 0.6), fill=(150, 170, 182))
        frost = fbm(rng, 64, (4, 8))
        for _ in range(int(30 * sc)):
            fx, fy = rng.uniform(-w * 0.6, w * 0.6), rng.uniform(-h * 0.75, h * 0.65)
            r = rng.uniform(2, 7) * S
            d.ellipse([cx + fx - r, cy + fy - r, cx + fx + r, cy + fy + r], fill=(210, 222, 228))
        d.rectangle([cx - w * 0.3, cy + h * 0.78, cx + w * 0.3, cy + h * 0.84], fill=PACK if k != 3 else (170, 60, 60))
        _ = frost
    return save(img, "pods")


def p_orbit(rng):
    n = canvas()
    a = gradient(n, VOID, (24, 28, 40))
    img = to_img(grain(a, rng, 0.08))
    d = ImageDraw.Draw(img)
    stars(d, rng, n, 320)
    img = planet(img, rng, n * 0.38, n * 1.02, n * 0.72)
    d = ImageDraw.Draw(img)
    ship(d, n * 0.68, n * 0.22, S * 1.4)
    return save(img, "orbit")


def p_descent(rng):
    n = canvas()
    a = gradient(n, (120, 128, 136), (176, 156, 128))
    a = haze(a, rng, (196, 186, 170), 0.5)
    img = to_img(grain(a, rng))
    d = ImageDraw.Draw(img)
    for k, (h, col) in enumerate([(0.55, (128, 120, 118)), (0.66, (110, 100, 98)), (0.78, OCHRE_D)]):  # crêtes
        pts = [(0, n)]
        x = 0
        while x <= n:
            pts.append((x, n * h + rng.uniform(-1, 1) * n * 0.04 * (k + 1)))
            x += n * 0.04
        pts.append((n, n))
        d.polygon(pts, fill=col)
    d.polygon([(n * 0.5, n * 0.05), (n * 0.62, n * 0.05), (n * 0.6, n * 0.17), (n * 0.52, n * 0.17)], fill=(150, 156, 166), outline=INK, width=S * 3)
    for k in range(4):  # quatre drones sous voilure
        x, y = n * (0.3 + k * 0.13), n * (0.28 + (k % 2) * 0.09 + k * 0.03)
        d.arc([x - n * 0.05, y - n * 0.07, x + n * 0.05, y + n * 0.03], 180, 360, fill=(220, 216, 204), width=S * 4)
        d.line([(x - n * 0.05, y - n * 0.02), (x, y + n * 0.04)], fill=(220, 216, 204), width=S)
        d.line([(x + n * 0.05, y - n * 0.02), (x, y + n * 0.04)], fill=(220, 216, 204), width=S)
        d.rectangle([x - n * 0.015, y + n * 0.04, x + n * 0.015, y + n * 0.06], fill=(224, 218, 204), outline=INK, width=S * 2)
        d.point((x, y + n * 0.05), fill=PACK)
    return save(img, "descent")


def p_grid(rng):
    n = canvas()
    a = gradient(n, (150, 132, 112), (120, 104, 92))
    a = grain(haze(a, rng, (172, 160, 146), 0.35), rng)
    img = to_img(a)
    layer = Image.new("RGB", img.size, (0, 0, 0))
    d = ImageDraw.Draw(layer)
    front = n * 0.55
    step = n / 18
    for k in range(-2, 20):  # quadrillage violet, au nord d'un front irrégulier
        d.line([(k * step, 0), (k * step + n * 0.05, front)], fill=GUARD, width=S * 3)
    y = 0
    while y < front:
        d.line([(0, y), (n, y + n * 0.02)], fill=GUARD, width=S * 3)
        y += step
    mask = np.zeros((n, n), np.float32)
    mask[: int(front)] = 1
    mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(n * 0.02)), np.float32) / 255
    g = np.asarray(layer, np.float32) * mask[..., None] * 0.8
    tint = np.array(GUARD, np.float32) * 0.12 * mask[..., None]
    img = to_img(np.asarray(img, np.float32) * (1 - 0.12 * mask[..., None]) + tint + g)
    d = ImageDraw.Draw(img)
    for x in (0.3, 0.52, 0.71):  # trois drones en contrebas, minuscules
        cx, cy = n * x, n * (0.82 + x * 0.05)
        d.rectangle([cx - S * 8, cy - S * 5, cx + S * 8, cy + S * 3], fill=(224, 218, 204), outline=INK, width=S)
        d.point((cx + S * 6, cy - S * 2), fill=PACK)
    return save(img, "surface_grid")


def p_guardian(rng):
    n = canvas()
    a = gradient(n, (150, 154, 156), (164, 146, 124))
    img = to_img(grain(a, rng))
    d = ImageDraw.Draw(img)
    cx, base = n * 0.6, n * 0.8
    for lx, ly in ((-0.16, 0.0), (0.14, 0.02), (0.02, 0.05)):  # tripode
        d.line([(cx, base - n * 0.42), (cx + lx * n * 0.6, base - n * 0.2), (cx + lx * n, base + ly * n)], fill=STONE_D, width=S * 16, joint="curve")
    d.polygon([(cx - n * 0.1, base - n * 0.46), (cx + n * 0.08, base - n * 0.5), (cx + n * 0.14, base - n * 0.42), (cx - n * 0.06, base - n * 0.36)], fill=STONE, outline=INK, width=S * 3)
    eye = (cx + n * 0.08, base - n * 0.44)
    a = np.asarray(img, np.float32)
    a = haze(a, rng, (176, 172, 166), 0.45, (2, 4, 8))  # la brume avale en partie la machine
    img = to_img(a)
    img = glow(img, lambda dd: dd.ellipse([eye[0] - n * 0.02, eye[1] - n * 0.02, eye[0] + n * 0.02, eye[1] + n * 0.02], fill=GUARD), GUARD, n * 0.025)
    ImageDraw.Draw(img).ellipse([eye[0] - S * 6, eye[1] - S * 6, eye[0] + S * 6, eye[1] + S * 6], fill=(220, 190, 255))
    return save(img, "guardian_mist")


def p_relay(rng):
    n = canvas()
    a = gradient(n, (52, 58, 74), (150, 132, 114))
    img = to_img(grain(haze(a, rng, (96, 100, 116), 0.4), rng))
    d = ImageDraw.Draw(img)
    stars(d, rng, n, 60, (0, 0, n, n * 0.3))
    d.polygon([(0, n * 0.78), (n, n * 0.72), (n, n), (0, n)], fill=OCHRE_D)
    cx = n * 0.5
    d.polygon([(cx - n * 0.07, n * 0.76), (cx - n * 0.04, n * 0.42), (cx + n * 0.04, n * 0.42), (cx + n * 0.07, n * 0.75)], fill=STONE, outline=INK, width=S * 3)
    d.polygon([(cx, n * 0.42), (cx + n * 0.04, n * 0.42), (cx + n * 0.07, n * 0.75), (cx + n * 0.02, n * 0.76)], fill=STONE_D)
    img = glow(img, lambda dd: dd.line([(cx, n * 0.42), (cx + n * 0.02, 0)], fill=PACK, width=S * 10), PACK, n * 0.02)
    d = ImageDraw.Draw(img)
    d.line([(cx, n * 0.42), (cx + n * 0.02, 0)], fill=(200, 255, 245), width=S * 3)
    for x, s in ((0.2, 1.0), (0.82, 1.1)):  # Patrouilleurs qui convergent
        px = n * x
        for lx in (-1, 0, 1):
            d.line([(px, n * 0.6), (px + lx * n * 0.05 * s, n * 0.76)], fill=STONE_D, width=S * 4)
        d.ellipse([px - S * 14, n * 0.58, px + S * 14, n * 0.62], fill=STONE, outline=INK, width=S * 2)
        d.ellipse([px - S * 4, n * 0.595, px + S * 4, n * 0.605], fill=GUARD)
    return save(img, "relay_signal")


def p_archive(rng):
    n = canvas()
    a = gradient(n, (34, 38, 50), (70, 74, 86))
    img = to_img(grain(haze(a, rng, (90, 96, 110), 0.3), rng))
    d = ImageDraw.Draw(img)
    for k in range(5):  # arches monumentales en enfilade
        sc = 1 - k * 0.16
        w, h = n * 0.42 * sc, n * 0.8 * sc
        cx, by = n * 0.5, n * 0.95 - k * n * 0.05
        col = tuple(int(c * (0.9 - k * 0.1)) for c in STONE)
        d.rectangle([cx - w, by - h, cx - w * 0.78, by], fill=col, outline=INK, width=S * 2)
        d.rectangle([cx + w * 0.78, by - h, cx + w, by], fill=col, outline=INK, width=S * 2)
        d.rectangle([cx - w, by - h, cx + w, by - h * 0.86], fill=col, outline=INK, width=S * 2)
    for row in range(6):  # tablette de glyphes, lueur turquoise de l'ouverture
        for col in range(9):
            if rng.random() < 0.7:
                x, y = n * (0.39 + col * 0.026), n * (0.6 + row * 0.03)
                d.rectangle([x, y, x + n * 0.016, y + n * 0.012], fill=(150, 214, 206))
    img = glow(img, lambda dd: dd.rectangle([n * 0.38, n * 0.58, n * 0.62, n * 0.78], fill=PACK), PACK, n * 0.04)
    return save(img, "ruins_archive")


def main():
    plans = [p_transit, p_rupture, p_bridge, p_pods, p_orbit, p_descent, p_grid, p_guardian, p_relay, p_archive]
    imgs = [fn(np.random.default_rng(500 + i)) for i, fn in enumerate(plans)]
    sheet = Image.new("RGB", (5 * 248 + 8, 2 * 248 + 8), (20, 24, 30))
    for k, im in enumerate(imgs):
        sheet.paste(im.resize((240, 240), Image.LANCZOS), (8 + (k % 5) * 248, 8 + (k // 5) * 248))
    sheet.save(OUT.parent.parent / "docs" / "art" / "planche-cinematiques.png", optimize=True)


if __name__ == "__main__":
    main()
