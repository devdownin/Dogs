#!/usr/bin/env python3
"""Génère les graphismes du jeu (tuiles, unités, points d'intérêt) de façon procédurale.

Direction : craie et pastel désaturés, gris-bleu froids, ocres éteints, rouille sombre ;
turquoise (Meute) et violet (Gardiens) réservés à l'information de jeu.
Déterministe : relancer le script redonne les mêmes fichiers.  Usage : python3 tools/gen_art.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets"
T = 192  # tuile
U = 256  # sprite
SS = 3  # suréchantillonnage

INK = (22, 26, 36)
PACK = (47, 224, 200)
GUARD = (168, 90, 240)
SAND, SAND_D = (178, 152, 122), (128, 104, 88)
SLATE_L, SLATE, SLATE_D = (158, 168, 178), (96, 106, 122), (48, 56, 72)
MESA = (214, 200, 176)
RUST, RUST_D = (112, 44, 38), (44, 22, 30)
ICE, ICE_L, ICE_D = (164, 190, 200), (224, 234, 236), (104, 134, 152)
HULL, HULL_D = (224, 218, 204), (132, 140, 152)
STONE, STONE_D = (112, 118, 132), (58, 62, 78)


def fbm(rng, n, octaves=(4, 8, 16, 32, 64)):
    acc = np.zeros((n, n), np.float32)
    amp, tot = 1.0, 0.0
    for o in octaves:
        g = rng.random((o + 1, o + 1)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
        acc += np.asarray(im, np.float32) / 255 * amp
        tot += amp
        amp *= 0.55
    return acc / tot


def chalk(rng, n, strength=0.16):
    """Grain de pastel : bruit fin + stries obliques."""
    fine = rng.random((n, n)).astype(np.float32)
    fine = np.asarray(Image.fromarray((fine * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)), np.float32) / 255
    yy, xx = np.mgrid[0:n, 0:n]
    stripes = fbm(rng, n, (48, 96))[(yy + xx) % n, (xx - yy) % n]
    return 1.0 + ((fine - 0.5) * 1.6 + (stripes - 0.5) * 0.9) * strength


def ground(rng, n, col, col_d, contrast=1.0):
    f = fbm(rng, n)[..., None]
    f = np.clip((f - 0.5) * 1.8 * contrast + 0.5, 0, 1)
    base = np.array(col_d, np.float32) * (1 - f) + np.array(col, np.float32) * f
    cold = fbm(rng, n, (3, 6))[..., None]  # voiles gris-bleu
    base = base * (1 - 0.22 * cold) + np.array((120, 132, 148), np.float32) * 0.22 * cold
    return base * chalk(rng, n)[..., None]


def to_img(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")


def cracks(d, rng, n, count, col, width=2, length=0.5):
    for _ in range(count):
        x, y = rng.random(2) * n
        ang = rng.random() * 6.283
        pts = [(x, y)]
        for _ in range(int(rng.integers(4, 9))):
            ang += (rng.random() - 0.5) * 1.4
            step = n * length / 6 * (0.5 + rng.random())
            x, y = x + np.cos(ang) * step, y + np.sin(ang) * step
            pts.append((x, y))
        d.line(pts, fill=col, width=width, joint="curve")


def jag(rng, pts, amt):
    return [(x + (rng.random() - 0.5) * amt, y + (rng.random() - 0.5) * amt) for x, y in pts]


def finish(img, rng, n=T):
    """Réduit, ajoute grain final et léger vignettage de case."""
    img = img.resize((n, n), Image.LANCZOS)
    a = np.asarray(img, np.float32) * chalk(rng, n, 0.07)[..., None]
    return to_img(a)


def tile_plain(rng, mesa=False):
    n = T * SS
    img = to_img(ground(rng, n, MESA if mesa else SAND, (172, 156, 138) if mesa else SAND_D, 0.8))
    d = ImageDraw.Draw(img)
    cracks(d, rng, n, 5 if not mesa else 3, (92, 76, 70), SS, 0.45)
    cracks(d, rng, n, 3, (206, 190, 166), SS, 0.3)
    if mesa:  # strates
        for k in range(3):
            y = n * (0.2 + 0.3 * k + rng.random() * 0.08)
            d.line(jag(rng, [(0, y), (n * 0.35, y), (n * 0.7, y), (n, y)], n * 0.04), fill=(160, 138, 118), width=SS)
    return img


def peak(d, rng, n, cx, base_y, w, h):
    top = (cx + (rng.random() - 0.5) * w * 0.3, base_y - h)
    left, right = (cx - w / 2, base_y), (cx + w / 2, base_y + w * 0.08)
    mid = (cx + w * 0.12, base_y + w * 0.14)
    d.polygon([(left[0] + w * 0.25, base_y + w * 0.1), (right[0] + w * 0.45, base_y + w * 0.3), right], fill=(60, 52, 58))  # ombre SE
    d.polygon(jag(rng, [left, top, mid], w * 0.05), fill=SLATE_L)
    d.polygon(jag(rng, [top, right, mid], w * 0.05), fill=SLATE_D)
    d.line([top, mid], fill=INK, width=SS)
    for _ in range(3):  # hachures sur la face éclairée
        t = 0.25 + rng.random() * 0.6
        a = (left[0] + (top[0] - left[0]) * t, left[1] + (top[1] - left[1]) * t)
        d.line([a, (a[0] + w * 0.12, a[1] + w * 0.16)], fill=SLATE, width=SS)


def tile_rock(rng):
    img = tile_plain(rng)
    n = T * SS
    d = ImageDraw.Draw(img)
    for cx, by, w, h in sorted([(0.3, 0.5, 0.4, 0.34), (0.66, 0.62, 0.46, 0.44), (0.42, 0.86, 0.5, 0.36)], key=lambda p: p[1]):
        peak(d, rng, n, n * (cx + (rng.random() - 0.5) * 0.08), n * by, n * w, n * h)
    return img


def tile_ramp(rng):
    n = T * SS
    top = np.asarray(tile_plain(rng, True), np.float32)
    bot = np.asarray(tile_plain(rng), np.float32)
    g = np.linspace(0, 1, n, dtype=np.float32)[:, None, None]
    img = to_img(top * (1 - g) + bot * g)
    d = ImageDraw.Draw(img)
    for k in range(1, 6):
        y = n * k / 6
        d.line(jag(rng, [(n * 0.14, y), (n * 0.5, y), (n * 0.86, y)], n * 0.02), fill=(104, 88, 80), width=SS * 2)
        d.line([(n * 0.14, y + SS * 2), (n * 0.86, y + SS * 2)], fill=(214, 198, 172), width=SS)
    for x in (0.12, 0.88):
        d.line([(n * x, 0), (n * x, n)], fill=(86, 74, 72), width=SS * 2)
    return img


def tile_canyon(rng, ford=False):
    n = T * SS
    img = to_img(ground(rng, n, RUST, RUST_D, 1.3))
    d = ImageDraw.Draw(img)
    cracks(d, rng, n, 7, (26, 18, 30), SS * 3, 0.7)
    cracks(d, rng, n, 6, (150, 72, 58), SS, 0.4)
    img = img.filter(ImageFilter.GaussianBlur(SS * 0.6))
    d = ImageDraw.Draw(img)
    if ford:
        for _ in range(9):
            x, y = n * (0.18 + rng.random() * 0.64), n * (0.08 + rng.random() * 0.84)
            w = n * (0.14 + rng.random() * 0.12)
            k = 0.78 + rng.random() * 0.3
            box = [(x - w, y - w * 0.6), (x + w, y - w * 0.7), (x + w * 0.9, y + w * 0.6), (x - w * 0.8, y + w * 0.7)]
            d.polygon([(px + SS * 4, py + SS * 5) for px, py in box], fill=(30, 20, 30))
            d.polygon(jag(rng, box, w * 0.3), fill=tuple(int(c * k) for c in (164, 150, 138)), outline=INK)
    return img


def tile_basin(rng):
    n = T * SS
    img = to_img(ground(rng, n, ICE, ICE_D, 0.9))
    d = ImageDraw.Draw(img)
    pts = [(rng.random() * n, rng.random() * n) for _ in range(9)]
    for i, p in enumerate(pts):  # plaques géométriques
        near = sorted(pts, key=lambda q: (q[0] - p[0]) ** 2 + (q[1] - p[1]) ** 2)[1:3]
        if i % 3 == 0:
            d.polygon([p, *near], fill=tuple(int(c * (0.92 + rng.random() * 0.14)) for c in ICE_L))
        for q in near:
            d.line([p, q], fill=ICE_L, width=SS)
            d.line([(p[0] + SS, p[1] + SS * 2), (q[0] + SS, q[1] + SS * 2)], fill=ICE_D, width=SS)
    return img


def tile_ruin(rng):
    img = tile_plain(rng, True)
    n = T * SS
    d = ImageDraw.Draw(img)
    u = n / 100
    d.polygon([(30 * u, 80 * u), (96 * u, 96 * u), (96 * u, 84 * u), (78 * u, 74 * u)], fill=(92, 78, 78))  # ombre
    for x0, h in ((20, 58), (62, 40)):  # piliers ; le second est brisé
        d.polygon([(x0 * u, 80 * u), (x0 * u, (80 - h) * u), ((x0 + 10) * u, (80 - h - 3) * u), ((x0 + 10) * u, 80 * u)], fill=SLATE_L)
        d.polygon([((x0 + 10) * u, 80 * u), ((x0 + 10) * u, (80 - h - 3) * u), ((x0 + 17) * u, (80 - h + 2) * u), ((x0 + 17) * u, 82 * u)], fill=SLATE_D)
        for k in range(1, 5):
            y = (80 - h * k / 5) * u
            d.line([(x0 * u, y), ((x0 + 17) * u, y + u)], fill=INK, width=SS)
    d.polygon(jag(rng, [(18 * u, 22 * u), (30 * u, 12 * u), (50 * u, 9 * u), (58 * u, 14 * u), (52 * u, 22 * u), (38 * u, 21 * u), (36 * u, 26 * u)], u), fill=SLATE)  # arche rompue
    d.line([(18 * u, 22 * u), (30 * u, 12 * u), (50 * u, 9 * u), (58 * u, 14 * u)], fill=SLATE_L, width=SS * 2)
    for bx, by in ((70, 70), (84, 62), (48, 86)):  # blocs tombés
        d.polygon(jag(rng, [(bx * u, by * u), ((bx + 8) * u, (by - 2) * u), ((bx + 9) * u, (by + 5) * u), ((bx + 1) * u, (by + 6) * u)], u), fill=SLATE, outline=INK)
    return img


def tile_fog(rng):
    n = T * SS
    return to_img(ground(rng, n, (44, 52, 64), (22, 26, 34), 1.1))


# ------------------------------------------------------------------ sprites


class Sprite:
    def __init__(self, seed):
        self.rng = np.random.default_rng(seed)
        self.n = U * SS
        self.u = self.n / 100
        self.col = Image.new("RGB", (self.n, self.n), INK)
        self.mask = Image.new("L", (self.n, self.n), 0)
        self.glow = Image.new("RGBA", (self.n, self.n), (0, 0, 0, 0))
        self.dc, self.dm, self.dg = ImageDraw.Draw(self.col), ImageDraw.Draw(self.mask), ImageDraw.Draw(self.glow)

    def p(self, pts):
        return [(x * self.u, y * self.u) for x, y in pts]

    def poly(self, pts, fill):
        self.dc.polygon(self.p(pts), fill=fill)
        self.dm.polygon(self.p(pts), fill=255)
        self.dc.line(self.p([*pts, pts[0]]), fill=INK, width=SS * 2)

    def limb(self, pts, fill, w=3.0):
        w = int(w * self.u)
        self.dc.line(self.p(pts), fill=INK, width=w + SS * 3, joint="curve")
        self.dm.line(self.p(pts), fill=255, width=w + SS * 3, joint="curve")
        self.dc.line(self.p(pts), fill=fill, width=w, joint="curve")
        for x, y in pts[1:-1]:
            self.dot(x, y, w / self.u * 0.5, STONE_D)

    def dot(self, x, y, r, fill):
        box = [(x - r) * self.u, (y - r) * self.u, (x + r) * self.u, (y + r) * self.u]
        self.dc.ellipse(box, fill=fill, outline=INK, width=SS)
        self.dm.ellipse(box, fill=255)

    def seam(self, pts, col, w=1.2):
        self.dc.line(self.p(pts), fill=col, width=int(w * self.u))
        self.dg.line(self.p(pts), fill=(*col, 255), width=int(w * 2.4 * self.u))

    def eye(self, x, y, r, col):
        self.dot(x, y, r, col)
        self.dot(x - r * 0.25, y - r * 0.25, r * 0.4, (240, 250, 250))
        self.dg.ellipse([(x - r * 2.2) * self.u, (y - r * 2.2) * self.u, (x + r * 2.2) * self.u, (y + r * 2.2) * self.u], fill=(*col, 200))

    def render(self):
        n, rng = self.n, self.rng
        a = np.asarray(self.col, np.float32)
        m = np.asarray(self.mask.filter(ImageFilter.GaussianBlur(n * 0.02)), np.float32) / 255
        sh = int(n * 0.018)  # relief : lumière du nord-ouest
        emb = np.roll(m, (sh, sh), (0, 1)) - np.roll(m, (-sh, -sh), (0, 1))
        a = a * (1 - 0.42 * emb[..., None]) * chalk(rng, n, 0.2)[..., None]
        a = a * (1 - 0.14 * fbm(rng, n, (5, 11))[..., None])  # salissures
        body = to_img(a).convert("RGBA")
        body.putalpha(self.mask)
        out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        shadow = Image.new("L", (n, n), 0)
        ImageDraw.Draw(shadow).ellipse(self.p([(22, 80), (92, 98)]), fill=120)
        out.paste((14, 16, 24), mask=shadow.filter(ImageFilter.GaussianBlur(n * 0.02)))
        out.alpha_composite(self.glow.filter(ImageFilter.GaussianBlur(n * 0.012)))
        out.alpha_composite(body)
        return out.resize((U, U), Image.LANCZOS)


def legs(s, xs, top, foot, col, w=3.0, bend=3):
    for x, dx in xs:
        s.limb([(x, top), (x + dx, (top + foot) / 2 - bend), (x + dx * 0.4, foot)], col, w)


def scout():
    s = Sprite(11)
    legs(s, [(36, -5), (66, 5)], 52, 84, HULL_D, 2.2)
    s.limb([(42, 46), (38, 16)], HULL_D, 1.6)
    s.poly([(26, 48), (62, 43), (76, 50), (62, 58), (30, 58)], HULL)
    s.poly([(72, 42), (88, 46), (86, 55), (74, 55)], HULL)
    legs(s, [(30, -6), (60, 6)], 56, 90, HULL, 2.4)
    s.seam([(32, 53), (58, 51)], PACK)
    s.eye(82, 49, 2.6, PACK)
    s.dot(38, 14, 5.5, HULL)
    s.eye(38, 14, 2.4, PACK)
    return s.render()


def technician():
    s = Sprite(12)
    legs(s, [(34, -3), (68, 3)], 58, 82, HULL_D, 4.2, 1)
    s.poly([(22, 42), (70, 40), (78, 60), (22, 64)], HULL)
    s.poly([(72, 44), (90, 48), (88, 60), (76, 60)], HULL)
    s.poly([(28, 34), (56, 32), (60, 42), (26, 43)], HULL_D)  # caisson d'outils
    s.limb([(40, 36), (44, 16), (66, 14), (76, 26)], HULL, 3.4)
    s.limb([(76, 26), (82, 22)], INK, 1.6)
    s.limb([(76, 26), (80, 32)], INK, 1.6)
    legs(s, [(28, -3), (62, 3)], 62, 90, HULL, 4.6, 1)
    s.seam([(28, 52), (66, 50)], PACK)
    s.eye(44, 16, 2.6, PACK)
    s.eye(84, 53, 2.6, PACK)
    return s.render()


def protector():
    s = Sprite(13)
    legs(s, [(30, -2), (64, 2)], 62, 84, HULL_D, 5.0, 0)
    s.poly([(14, 48), (70, 42), (78, 66), (14, 70)], HULL)
    s.poly([(18, 42), (62, 37), (66, 46), (20, 51)], HULL_D)
    s.poly([(68, 28), (88, 36), (94, 68), (76, 78), (70, 60)], HULL)  # plaques frontales
    s.poly([(74, 38), (86, 43), (89, 62), (78, 68)], HULL_D)
    legs(s, [(22, -2), (56, 2)], 66, 92, HULL, 5.6, 0)
    s.seam([(20, 60), (64, 57)], PACK)
    s.seam([(80, 46), (84, 60)], PACK, 1.6)
    return s.render()


def interceptor():
    s = Sprite(14)
    legs(s, [(34, -9), (64, -7)], 54, 82, HULL_D, 2.8, 6)
    s.poly([(10, 56), (30, 46), (62, 42), (96, 54), (62, 62), (28, 62)], HULL)
    s.poly([(30, 46), (22, 28), (48, 44)], HULL_D)  # dérive
    s.poly([(62, 42), (96, 54), (70, 52)], HULL_D)
    legs(s, [(28, -10), (58, -8)], 58, 90, HULL, 3.0, 6)
    s.seam([(20, 56), (60, 54), (88, 54)], PACK)
    s.eye(80, 50, 2.2, PACK)
    return s.render()


def sentinel():
    s = Sprite(21)
    s.poly([(26, 92), (74, 92), (66, 78), (34, 78)], STONE_D)
    s.poly([(36, 78), (64, 78), (60, 26), (40, 26)], STONE)
    s.poly([(52, 78), (64, 78), (60, 26), (52, 26)], STONE_D)
    s.poly([(32, 26), (68, 26), (72, 8), (28, 8)], STONE)
    for y in (40, 54, 66):
        s.seam([(38, y), (62, y)], GUARD, 0.9)
    s.eye(50, 17, 5.2, GUARD)
    return s.render()


def patroller():
    s = Sprite(22)
    s.limb([(50, 30), (58, 58), (52, 90)], STONE_D, 3.0)
    s.poly([(30, 14), (64, 10), (78, 24), (56, 38), (28, 30)], STONE)
    s.poly([(56, 38), (78, 24), (64, 22), (50, 28)], STONE_D)
    s.limb([(36, 30), (18, 56), (22, 92)], STONE, 3.4)
    s.limb([(66, 30), (88, 54), (84, 90)], STONE, 3.4)
    s.seam([(34, 20), (60, 17)], GUARD, 1.0)
    s.eye(68, 22, 3.4, GUARD)
    return s.render()


def regulator():
    s = Sprite(23)
    s.poly([(12, 90), (88, 90), (82, 54), (18, 54)], STONE)
    s.poly([(60, 90), (88, 90), (82, 54), (62, 54)], STONE_D)
    s.poly([(6, 56), (94, 56), (88, 34), (50, 26), (12, 34)], STONE)  # bouclier
    s.poly([(50, 26), (88, 34), (94, 56), (56, 56)], STONE_D)
    for x in (26, 40, 54, 68):
        s.seam([(x, 60), (x + 1, 86)], GUARD, 0.9)
    s.seam([(14, 46), (50, 38), (88, 46)], GUARD, 1.3)
    s.eye(50, 46, 3.6, GUARD)
    return s.render()


def node():
    s = Sprite(31)
    s.poly([(30, 90), (70, 90), (64, 76), (36, 76)], STONE_D)
    s.poly([(40, 76), (60, 76), (57, 34), (43, 34)], STONE)
    s.poly([(34, 34), (66, 34), (60, 22), (40, 22)], STONE_D)
    s.dot(50, 28, 7, (200, 196, 184))
    s.seam([(46, 44), (46, 70)], (226, 218, 200), 1.0)
    s.seam([(54, 44), (54, 70)], (226, 218, 200), 1.0)
    return s.render()


def beacon():
    s = Sprite(32)
    legs(s, [(40, -10), (60, 10)], 60, 90, HULL_D, 2.4, 0)
    s.limb([(50, 60), (50, 90)], HULL, 2.4)
    s.poly([(38, 44), (62, 44), (66, 62), (34, 62)], HULL)
    s.limb([(50, 44), (50, 16)], HULL_D, 1.8)
    s.eye(50, 14, 4.2, PACK)
    s.seam([(40, 54), (60, 54)], PACK)
    return s.render()


def main():
    tiles = {"plain": (tile_plain, 4), "rock": (tile_rock, 3), "mesa": (lambda r: tile_plain(r, True), 3),
             "ramp": (tile_ramp, 1), "canyon": (tile_canyon, 3), "ford": (lambda r: tile_canyon(r, True), 1),
             "basin": (tile_basin, 3), "ruin": (tile_ruin, 1), "fog": (tile_fog, 3)}
    made = {}
    for i, (name, (fn, count)) in enumerate(tiles.items()):
        for v in range(count):
            rng = np.random.default_rng(1000 + i * 10 + v)
            img = finish(fn(rng), rng)
            img.save(OUT / "terrain" / f"{name}_{v}.png", optimize=True)
            made[f"{name}_{v}"] = img
    sprites = {"units": {"scout": scout, "technician": technician, "protector": protector, "interceptor": interceptor,
                         "sentinel": sentinel, "patroller": patroller, "regulator": regulator},
               "features": {"node": node, "beacon": beacon}}
    for folder, items in sprites.items():
        for name, fn in items.items():
            img = fn()
            img.save(OUT / folder / f"{name}.png", optimize=True)
            made[name] = img
    # planche de contrôle
    names = list(made)
    sheet = Image.new("RGB", (6 * 200 + 8, ((len(names) + 5) // 6) * 200 + 8), (30, 35, 41))
    for k, name in enumerate(names):
        im = made[name]
        cell = made["plain_0"].copy() if im.mode == "RGBA" else im
        if im.mode == "RGBA":
            cell.paste(im.resize((T, T), Image.LANCZOS), (0, 0), im.resize((T, T), Image.LANCZOS))
        sheet.paste(cell, (8 + (k % 6) * 200, 8 + (k // 6) * 200))
    sheet.save(OUT.parent / "docs" / "art" / "planche-assets.png", optimize=True)


if __name__ == "__main__":
    main()
