"""Assemble le terrain Surface à partir des peintures et exporte les calques PNG."""
from pathlib import Path
import json
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import label

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE = ROOT / "art-src/m4_le_veilleur/peinture_source.png"
TARGET = ROOT / "assets/terrain/surface"
SIZE = 384
SMALL = 192
RESAMPLE = Image.Resampling.LANCZOS
SIDES = ("n", "e", "s", "w")
SIGN_NAMES = dict(zip(".RMrCGBX", ("plain", "rock", "mesa", "ramp", "canyon", "ford", "basin", "ruin")))
COUNTS = dict(zip(SIGN_NAMES.values(), (4, 3, 3, 2, 3, 2, 3, 4)))
EDGED = ("mesa", "canyon", "basin")

# Les détails de matière peuvent varier au centre. Les huit pixels extérieurs
# reposent sur le même échantillon périodique pour chaque famille.
Y, X = np.mgrid[:SIZE, :SIZE]
EDGE_DIST = np.minimum.reduce((X, Y, SIZE - 1 - X, SIZE - 1 - Y))
FADE = np.clip((EDGE_DIST - 8) / 55, 0, 1)
FADE = (FADE**2 * (3 - 2 * FADE))[..., None]


def crop(image, box, size=(SIZE, SIZE)):
    return image.crop(box).resize(size, RESAMPLE)


def periodic(image):
    part = image.resize((SIZE // 2, SIZE // 2), RESAMPLE)
    mirror = Image.Transpose.FLIP_LEFT_RIGHT
    flip = Image.Transpose.FLIP_TOP_BOTTOM
    result = Image.new("RGB", (SIZE, SIZE))
    result.paste(part, (0, 0))
    result.paste(part.transpose(mirror), (SIZE // 2, 0))
    result.paste(part.transpose(flip), (0, SIZE // 2))
    result.paste(part.transpose(flip).transpose(mirror), (SIZE // 2, SIZE // 2))
    return result


def material(source, boxes, target, contrast=1.0):
    variants = []
    for box in boxes:
        sample = np.asarray(crop(source, box)).astype(float)
        low = np.asarray(Image.fromarray(np.uint8(sample)).filter(ImageFilter.GaussianBlur(23)))
        sample = (sample - low) * 0.75 + (low - np.mean(low, axis=(0, 1))) * contrast
        variants.append(Image.fromarray(np.uint8(np.clip(sample + target, 0, 255))))
    baseline = np.asarray(periodic(variants[0])).astype(float)
    return [
        Image.fromarray(np.uint8(np.asarray(sample) * FADE + baseline * (1 - FADE)))
        for sample in variants
    ]


def rgba(rgb, alpha):
    return Image.fromarray(
        np.uint8(np.clip(np.dstack((rgb, alpha * 255)), 0, 255)), "RGBA"
    )


def edge_strip(material_image, name, side):
    source = np.asarray(material_image).astype(float)
    profile = {
        "mesa": ((133, 109, 91), 55, 2.0),
        "canyon": ((145, 89, 73), 118, 4.8),
        "basin": ((110, 116, 117), 39, 2.1),
    }
    color, width, frequency = profile[name]
    depth, tangent = ((Y, X), (SIZE - 1 - X, Y), (SIZE - 1 - Y, X), (X, Y))[side]
    phase = tangent * 2 * np.pi / SIZE
    waviness = np.sin(3 * phase) * 5 + np.sin(7 * phase) * 2.5
    distance = depth - waviness
    south = side == 2
    if name == "mesa" and south:
        width = 106
    peak = 1 - np.clip(distance / width, 0, 1)
    laminae = np.sin(distance / frequency + np.sin(phase) * 0.9) * 12
    rim = np.exp(-((distance - 8) / 6) ** 2) * 19
    grain = (source - np.mean(source, axis=(0, 1))) * 0.68
    shade = laminae * peak + rim
    if name == "mesa":
        shade -= 34 * peak if south else -12 * peak
    elif name == "canyon":
        shade -= 22 * (1 - peak)
        if side == 0:
            shade -= 25 * peak
        elif side == 2:
            shade += 10 * peak
    rgb = np.array(color) + grain + shade[..., None]
    return rgba(rgb, peak**0.72)


def footing(base, image, height, shadow_opacity=68, max_width=SIZE - 45):
    box = image.getbbox(alpha_only=True)
    if box is None:
        raise ValueError("Découpe sans sujet")
    image = image.crop(box)
    scale = min(height / image.height, max_width / image.width)
    image = image.resize((round(image.width * scale), round(image.height * scale)), RESAMPLE)
    origin = ((SIZE - image.width) // 2 - 6, (SIZE - image.height) // 2 - 16)
    shadow = Image.new("L", base.size)
    draw = ImageDraw.Draw(shadow)
    x, y = origin
    bottom = y + image.height
    draw.ellipse((x + 15, bottom - 35, x + image.width + 34, bottom + 25), fill=shadow_opacity)
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    shadow_array = np.asarray(shadow).copy()
    shadow_array[EDGE_DIST < 8] = 0
    layer = Image.new("RGBA", base.size, (24, 24, 32, 0))
    layer.putalpha(Image.fromarray(shadow_array))
    layer.alpha_composite(image, origin)
    return layer


def extract_detail(sheet, col, row):
    w, h = sheet.size
    box = (round(col * w / 4), round(row * h / 2),
           round((col + 1) * w / 4), round((row + 1) * h / 2))
    shape = sheet.crop(box)
    alpha = np.array(shape.getchannel("A"))
    components, _ = label(alpha >= 36)
    counts = np.bincount(components.ravel())
    counts[0] = 0
    if not counts.max():
        raise ValueError(f"Planche vide en {col}, {row}")
    # Les petits éclats peints font partie des ruines.
    keep = counts >= counts.max() * 0.012
    keep[0] = False
    alpha[~keep[components]] = 0
    shape.putalpha(Image.fromarray(alpha))
    return shape


def pass_tile(source, box, base, flip=False):
    subject = crop(source, box)
    if flip:
        subject = subject.rotate(90, resample=Image.Resampling.BICUBIC)
    cross = Y if flip else X
    longitudinal = X if flip else Y
    a = np.clip((SIZE * 0.46 - abs(cross - SIZE / 2)) / 50, 0, 1)
    a *= np.clip(np.minimum(longitudinal, SIZE - 1 - longitudinal) / 18, 0, 1) * 0.99
    detail = rgba(np.asarray(subject), a)
    return Image.alpha_composite(base.convert("RGBA"), detail).convert("RGB")


def main():
    source = Image.open(SOURCE).convert("RGB")
    sheet = Image.open(HERE / "reliefs_source.png").convert("RGBA")
    materials = {
        "plain": material(source, (
            (300, 1010, 448, 1140), (430, 777, 585, 917),
            (620, 851, 724, 984), (871, 1040, 1034, 1175)), (164, 149, 135)),
        "mesa": material(source, (
            (394, 18, 525, 92), (548, 16, 700, 94),
            (392, 91, 486, 156)), (194, 179, 158), 0.20),
        "canyon": material(source, (
            (25, 530, 119, 597), (182, 523, 300, 598),
            (557, 528, 694, 604)), (71, 50, 48), 0.10),
        "basin": material(source, (
            (1016, 780, 1130, 914), (1112, 797, 1240, 926),
            (1041, 861, 1186, 978)), (137, 153, 159)),
    }
    layers = {}
    for family, variants in materials.items():
        for i, image in enumerate(variants):
            layers[f"{family}_{i}"] = image

    for family, row, count in (("rock", 0, 3), ("ruin", 1, 4)):
        for i in range(count):
            base = materials["plain"][i]
            details = footing(base, extract_detail(sheet, i, row), 285 if row == 0 else 270)
            # Une ruine peut occuper une plaine ou un plateau sous-jacent.
            if family == "ruin":
                layers[f"ruin_high_{i}"] = details
            layers[f"{family}_{i}"] = Image.alpha_composite(base.convert("RGBA"), details).convert("RGB")

    for i in range(2):
        layers[f"ramp_{i}"] = pass_tile(
            source, (500, 240, 629, 369), materials["plain"][0], flip=bool(i)
        )
        layers[f"ford_{i}"] = pass_tile(
            source, (383, 500, 495, 625), materials["plain"][0], flip=bool(i)
        )

    for family in EDGED:
        strips = [edge_strip(materials[family][0], family, side) for side in range(4)]
        for mask in range(16):
            overlay = Image.new("RGBA", (SIZE, SIZE))
            for side, strip in enumerate(strips):
                if mask & (1 << side):
                    overlay.alpha_composite(strip)
            layers[f"{family}_edge_{mask:02d}"] = overlay

    editable = HERE / "calques_384"
    editable.mkdir(exist_ok=True)
    TARGET.mkdir(parents=True, exist_ok=True)
    for stem, layer in layers.items():
        layer.save(editable / f"{stem}.png", optimize=True)
        layer.resize((SMALL, SMALL), RESAMPLE).save(TARGET / f"{stem}.png", optimize=True)
    manifest = {
        "cell_size": SMALL, "source_cell_size": SIZE, "terrain": SIGN_NAMES,
        "variants": COUNTS, "edge_terrains": list(EDGED), "edge_side_bits": dict(zip(SIDES, (1, 2, 4, 8))),
    }
    (TARGET / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if len(sys.argv) > 1 and sys.argv[1] == "--count":
        print(f"{sum(COUNTS.values())} tuiles, {16 * len(EDGED)} bordures, 4 calques de ruine")


if __name__ == "__main__":
    main()
