"""Pose les sprites peints existants avec des déformations locales réversibles."""
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.interpolate import RBFInterpolator
from scipy.ndimage import map_coordinates

PROJECT = Path(__file__).resolve().parents[2]
PAINTED = PROJECT / "assets/maps/m4_le_veilleur"
DIRECTIONS = Path(__file__).resolve().parent / "directions"
TARGET = PROJECT / "assets/units/m4_motion"
CELL = 288
GROUND = round(CELL * 0.78)
COLUMNS = 6
Y, X = np.mgrid[:CELL, :CELL].astype(float)

# Points d'appui des Gardiens dans le cadre de jeu de 288 px.
FEET = {
    "patroller": ((90, 218), (132, 162), (200, 205)),
    "patroller_n": ((92, 189), (146, 223), (195, 189)),
    "patroller_s": ((91, 223), (132, 171), (198, 210)),
}
# Hanche, articulation, patin et déphasage. Le profil du Technicien masque la quatrième patte.
LEGS = {
    "scout": (
        ((112, 109), (109, 138), (93, 199), .5),
        ((145, 99), (135, 150), (122, 217), 0),
        ((166, 82), (171, 106), (158, 151), 0),
        ((189, 69), (196, 113), (186, 172), .5),
    ),
    "scout_n": (
        ((127, 135), (120, 167), (117, 218), 0),
        ((160, 137), (164, 167), (168, 218), .5),
        ((124, 86), (118, 115), (112, 155), .5),
        ((163, 86), (170, 115), (176, 155), 0),
    ),
    "scout_s": (
        ((128, 119), (125, 164), (118, 218), .5),
        ((159, 119), (163, 164), (169, 218), 0),
        ((124, 65), (120, 94), (114, 135), 0),
        ((164, 65), (168, 94), (174, 135), .5),
    ),
    "technician": (
        ((92, 139), (78, 152), (73, 180), .5),
        ((159, 153), (149, 172), (134, 216), 0),
        ((190, 132), (207, 145), (214, 180), .75),
    ),
    "technician_n": (
        ((111, 167), (105, 189), (99, 216), 0),
        ((175, 167), (181, 189), (189, 216), .5),
        ((103, 121), (90, 137), (88, 158), .25),
        ((184, 121), (196, 137), (201, 158), .75),
    ),
    "technician_s": (
        ((111, 166), (105, 191), (98, 216), .25),
        ((175, 166), (183, 191), (190, 216), .75),
        ((103, 120), (90, 138), (88, 158), 0),
        ((184, 120), (197, 138), (200, 158), .5),
    ),
}
ACTION = {
    "scout": (133, 25, -6, -10),
    "technician": (122, 56, -16, 4),
    "sentinel": (144, 75, 0, 0),
    "patroller": (146, 74, -7, 3),
    "scout_n": (144, 61, -3, -9),
    "scout_s": (144, 92, 3, -9),
    "technician_n": (152, 45, 9, -5),
    "technician_s": (119, 100, -10, 6),
    "patroller_n": (145, 65, -4, 6),
    "patroller_s": (144, 61, 4, 6),
}
CLIPS = (("idle", 8), ("walk", 8), ("action", 8), ("hit", 4), ("disabled", 7))
DRONE_WALK_FRAMES = 12
GRID = np.column_stack((X.ravel(), Y.ravel()))
FRAME_ANCHORS = (
    (0, 0), (144, 0), (287, 0), (0, 144), (287, 144), (0, 287), (144, 287), (287, 287),
)


def mask(x, y, rx, ry):
    return np.exp(-0.5 * (((X - x) / rx) ** 2 + ((Y - y) / ry) ** 2))


def ease(t):
    return t * t * (3 - 2 * t)


def walk_coords(unit, t):
    heavy = unit.startswith("technician")
    duty, stride, lift = (0.75, 53, 11) if heavy else (0.58, 60, 15)
    if unit == "scout":
        stride = 46  # Les tibias se recouvrent plus vite dans cette projection oblique.
    forward = np.array((0, -1) if unit.endswith("_n") else (0, 1) if unit.endswith("_s") else (-1, 0))
    vertical = np.array((0, 1))
    # Le châssis s'incline légèrement dans le sens du déplacement et charge l'appui.
    body = forward * (2.5 + 1.5 * math.sin(t * math.tau))
    body -= vertical * (1 - math.cos(t * math.tau * (4 if heavy else 2))) * 1.5
    source_points = list(FRAME_ANCHORS)
    offsets = [np.zeros(2) for _ in FRAME_ANCHORS]
    for point in ((144, 40), (143, 101), (144, 139)):
        source_points.append(point)
        offsets.append(body)

    for hip, knee, foot, offset in LEGS[unit]:
        phase = (t + offset) % 1.0
        # En appui le patin recule à vitesse constante par rapport au châssis.
        # En reprise, une arche le ramène vers son prochain point de contact.
        if phase < duty:
            travel = stride * (duty / 2 - phase)
            raise_by = 0.0
        else:
            flight = (phase - duty) / (1 - duty)
            travel = stride * duty * (ease(flight) - 0.5)
            raise_by = lift * math.sin(math.pi * flight) ** 2
        toe = forward * travel - vertical * raise_by
        hinge = body * 0.62 + toe * 0.38 - vertical * (raise_by * 0.12)
        source_points.extend((hip, knee, foot))
        offsets.extend((body, hinge, toe))
        if not heavy:
            # Les tiges restent droites entre les articulations, même en extension.
            hip, knee, foot = map(np.array, (hip, knee, foot))
            source_points.extend(((hip + knee) / 2, (2 * knee + foot) / 3, (knee + 2 * foot) / 3))
            offsets.extend(((body + hinge) / 2, (2 * hinge + toe) / 3, (hinge + 2 * toe) / 3))

    source_points = np.array(source_points)
    offsets = np.array(offsets)
    inverse_warp = RBFInterpolator(source_points + offsets, -offsets, smoothing=4)
    x, y = (GRID + inverse_warp(GRID)).T.reshape(2, CELL, CELL)
    return y, x


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
        if unit in LEGS:
            return sample_rgba(source, walk_coords(unit, t))
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

    return sample_rgba(source, (Y - dy, X - dx))


def sample_rgba(source, coords):
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
        directory = DIRECTIONS if "_" in unit else PAINTED
        with Image.open(directory / f"{unit}.png") as image:
            rgba = image.convert("RGBA").resize((CELL, CELL), Image.Resampling.LANCZOS)
        source = np.asarray(rgba)
        frames = []
        for clip, default_count in CLIPS:
            count = DRONE_WALK_FRAMES if clip == "walk" and unit in LEGS else default_count
            frames.extend(pose(source, unit, clip, i, count) for i in range(count))
        rows = math.ceil(len(frames) / COLUMNS)
        atlas = Image.new("RGBA", (CELL * COLUMNS, CELL * rows))
        for i, image in enumerate(frames):
            atlas.paste(image, ((i % COLUMNS) * CELL, (i // COLUMNS) * CELL))
        atlas.save(TARGET / f"{unit}.png", optimize=True)


if __name__ == "__main__":
    main()
