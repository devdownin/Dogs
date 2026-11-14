"""Exporte les ressources M4 à partir des originaux. Python 3, Pillow, NumPy et SciPy."""
from pathlib import Path
import json

import numpy as np
from PIL import Image
from scipy.ndimage import label

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parents[1]
TARGET = ROOT / "assets/maps/m4_le_veilleur"
MISSION = ROOT / "data/missions/m4_le_veilleur.json"
CELL = 192
RESAMPLE = Image.Resampling.LANCZOS

# Rectangles dans la planche source. Chaque objet est isolé sur fond transparent.
# Le plus grand composant opaque conserve le dessin et écarte les particules
# détachées autour de la silhouette.
SPRITES = {
    "scout": ((5, 0, 420, 626), 220, (288, 288)),
    "technician": ((420, 0, 860, 626), 205, (288, 288)),
    "sentinel": ((860, 0, 1254, 626), 224, (288, 288)),
    "patroller": ((0, 626, 414, 1254), 224, (288, 288)),
    "beacon": ((414, 626, 855, 1254), 150, (192, 288)),
}


def export_sprite(sheet, name, region, height, frame):
    sprite = sheet.crop(region)
    alpha = np.array(sprite.getchannel("A"))
    components, _ = label(alpha >= 64)
    count = np.bincount(components.ravel())
    count[0] = 0
    if count.max() == 0:
        raise ValueError(f"{name}: silhouette vide")
    alpha[components != count.argmax()] = 0
    sprite.putalpha(Image.fromarray(alpha))
    sprite = sprite.crop(sprite.getbbox(alpha_only=True))
    factor = min(height / sprite.height, (frame[0] * 0.86) / sprite.width)
    sprite = sprite.resize(
        (round(sprite.width * factor), round(sprite.height * factor)), RESAMPLE
    )
    image = Image.new("RGBA", frame)
    image.paste(sprite, ((frame[0] - sprite.width) // 2, round(frame[1] * 0.78) - sprite.height))
    image.save(TARGET / f"{name}.png", optimize=True)


def main():
    grid = json.loads(MISSION.read_text())["map"]
    ground = Image.open(SOURCE / "peinture_source.png").convert("RGB")
    TARGET.mkdir(parents=True, exist_ok=True)
    ground.resize((grid["width"] * CELL, grid["height"] * CELL), RESAMPLE).save(
        TARGET / "ground.png", optimize=True
    )
    sheet = Image.open(SOURCE / "sprites_source.png").convert("RGBA")
    for name, (region, height, frame) in SPRITES.items():
        export_sprite(sheet, name, region, height, frame)


if __name__ == "__main__":
    main()
