"""Pose les sprites peints existants avec des déformations locales réversibles."""
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates

PROJECT = Path(__file__).resolve().parents[2]
PAINTED = PROJECT / "assets/maps/m4_le_veilleur"
TARGET = PROJECT / "assets/units/m4_motion"
CELL = 288
GROUND = round(CELL * 0.78)
COLUMNS = 6
Y, X = np.mgrid[:CELL, :CELL].astype(float)

# Points d'appui vus sur le rendu peint, d'avant en arrière.
FEET = {
    "scout": ((95, 199), (120, 217), (158, 187), (184, 172)),
    "technician": ((69, 181), (132, 216), (210, 180)),
    "patroller": ((90, 218), (132, 162), (200, 205)),
}
ACTION = {
    "scout": (133, 25, -6, -10),
    "technician": (122, 56, -16, 4),
    "sentinel": (144, 75, 0, 0),
    "patroller": (146, 74, -7, 3),
}
CLIPS = (("idle", 8), ("walk", 8), ("action", 8), ("hit", 4), ("disabled", 7))


def mask(x, y, rx, ry):
    return np.exp(-0.5 * (((X - x) / rx) ** 2 + ((Y - y) / ry) ** 2))


def ease(t):
    return t * t * (3 - 2 * t)


def pose(source, unit, clip, frame, count):
    t = frame / (count if clip in ("idle", "walk") else count - 1)
    cycle = t * math.tau
    dx = np.zeros_like(X)
    dy = np.zeros_like(Y)
    from_ground = np.clip((GROUND - Y) / 115, 0, 1)
    joint = mask(*ACTION[unit][:2], 37, 39)

    if clip == "idle":
        dy += (math.cos(cycle) - 1) * 1.0 * from_ground
    elif clip == "walk":
        if unit == "sentinel":
            return Image.fromarray(source)
        dy -= (1 - math.cos(2 * cycle)) * 1.8 * from_ground
        for i, (x, y) in enumerate(FEET[unit]):
            phase = cycle + (i % 2) * math.pi
            influence = mask(x, y - 8, 15, 23)
            dx += math.sin(phase) * 9 * influence
            dy -= max(0, math.cos(phase)) * 10 * influence
    elif clip == "action":
        amount = math.sin(t * math.pi) ** 1.4
        dx += ACTION[unit][2] * amount * joint
        dy += ACTION[unit][3] * amount * joint
        if unit == "patroller":
            dx -= 4 * from_ground * amount
    elif clip == "hit":
        dx += (0.0, 8.0, -3.0, 0.0)[frame] * from_ground
    elif clip == "disabled":
        amount = ease(t)
        scale = 1 - amount * (0.09 if unit == "sentinel" else 0.25)
        sample_y = GROUND + (Y - GROUND) / scale
        dx += (GROUND - Y) * amount * 0.075
        dy += Y - sample_y

    coords = (Y - dy, X - dx)
    # Interpolation prémultipliée pour conserver les bords peints sans frange.
    alpha = source[..., 3].astype(float) / 255
    warped_alpha = map_coordinates(alpha, coords, order=1, mode="constant")
    channels = []
    for i in range(3):
        value = map_coordinates(source[..., i] * alpha, coords, order=1, mode="constant")
        channels.append(np.divide(value, warped_alpha, out=np.zeros_like(value), where=warped_alpha > 0))
    return Image.fromarray(np.uint8(np.clip(np.dstack((*channels, warped_alpha * 255)), 0, 255)))


def main():
    TARGET.mkdir(parents=True, exist_ok=True)
    for unit in ACTION:
        source = np.array(Image.open(PAINTED / f"{unit}.png").convert("RGBA"))
        frames = [
            pose(source, unit, clip, i, count)
            for clip, count in CLIPS
            for i in range(count)
        ]
        rows = math.ceil(len(frames) / COLUMNS)
        atlas = Image.new("RGBA", (CELL * COLUMNS, CELL * rows))
        for i, image in enumerate(frames):
            atlas.paste(image, ((i % COLUMNS) * CELL, (i // COLUMNS) * CELL))
        atlas.save(TARGET / f"{unit}.png", optimize=True)


if __name__ == "__main__":
    main()
