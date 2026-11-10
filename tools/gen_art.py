#!/usr/bin/env python3
"""Generates the placeholder sprite atlas and stage floors for MusicalGuys.

Usage: python3 tools/gen_art.py   (from the project root, needs Pillow + numpy)

Output: assets/generated/atlas.png, assets/generated/atlas.json, assets/generated/floor_*.png
Everything uses the DawnBringer-32 palette of the hand drawn frog and Noteguy
sprites, a 32 px cell and a dark one pixel outline so old and new art match.
"""
import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "generated")

P = {
    "k": (0, 0, 0), "ink": (34, 32, 52), "plum": (69, 40, 60), "bark": (102, 57, 49),
    "brown": (143, 86, 59), "orange": (223, 113, 38), "tan": (217, 160, 102),
    "skin": (238, 195, 154), "yellow": (251, 242, 54), "lime": (153, 229, 80),
    "green": (106, 190, 48), "teal": (55, 148, 110), "moss": (75, 105, 47),
    "olive": (82, 75, 36), "swamp": (50, 60, 57), "navy": (63, 63, 116),
    "ocean": (48, 96, 130), "blue": (91, 110, 225), "sky": (99, 155, 255),
    "cyan": (95, 205, 228), "ice": (203, 219, 252), "white": (255, 255, 255),
    "silver": (155, 173, 183), "gray": (132, 126, 135), "iron": (105, 106, 106),
    "stone": (89, 86, 82), "purple": (118, 66, 138), "red": (172, 50, 50),
    "rose": (217, 87, 99), "pink": (215, 123, 186), "khaki": (143, 151, 74),
    "gold": (138, 111, 48),
}
T = (0, 0, 0, 0)


def c(name, a=255):
    r, g, b = P[name]
    return (r, g, b, a)


class S:
    """A small canvas with pixel art helpers."""

    def __init__(self, w=32, h=32):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), T)
        self.d = ImageDraw.Draw(self.im)

    def ell(self, x0, y0, x1, y1, col):
        self.d.ellipse([x0, y0, x1, y1], fill=c(col))
        return self

    def rect(self, x0, y0, x1, y1, col):
        self.d.rectangle([x0, y0, x1, y1], fill=c(col))
        return self

    def poly(self, pts, col):
        self.d.polygon(pts, fill=c(col))
        return self

    def line(self, pts, col, w=1):
        self.d.line(pts, fill=c(col), width=w)
        return self

    def px(self, x, y, col):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((x, y), c(col))
        return self

    def arc(self, box, a0, a1, col, w=1):
        self.d.arc(box, a0, a1, fill=c(col), width=w)
        return self

    def eye(self, x, y, r=3, iris="green", look=0):
        """The big Noteguy style eye."""
        self.ell(x - r, y - r, x + r, y + r, "ice")
        self.rect(x - 1 + look, y - 1, x + look, y, iris)
        self.px(x + look, y - 1, "ink")
        return self

    def eyes(self, x, y, gap=6, col="white", pupil="ink"):
        for ex in (x - gap // 2, x + gap // 2):
            self.rect(ex - 1, y - 1, ex, y, col)
            self.px(ex, y, pupil)
        return self

    def done(self, outline="ink", shade=True):
        if shade:
            shade_pass(self.im)
        if outline:
            outline_pass(self.im, c(outline))
        return self.im


def outline_pass(im, col):
    src = im.copy()
    w, h = im.size
    sp = src.load()
    dp = im.load()
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and sp[nx, ny][3] != 0:
                    dp[x, y] = col
                    break


def shade_pass(im):
    src = im.copy()
    w, h = im.size
    sp = src.load()
    dp = im.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = sp[x, y]
            if a == 0:
                continue
            below = sp[x, y + 1][3] if y + 1 < h else 0
            right = sp[x + 1, y][3] if x + 1 < w else 0
            above = sp[x, y - 1][3] if y > 0 else 0
            if below == 0 or right == 0:
                dp[x, y] = (int(r * 0.72), int(g * 0.72), int(b * 0.78), a)
            elif above == 0:
                dp[x, y] = (min(255, int(r * 1.12 + 10)), min(255, int(g * 1.12 + 10)), min(255, int(b * 1.1 + 8)), a)


def squash(im, amount=2):
    """Second animation frame: the sprite squashed toward its feet."""
    w, h = im.size
    box = im.getbbox()
    if not box:
        return im.copy()
    x0, y0, x1, y1 = box
    body = im.crop(box)
    nh = max(1, (y1 - y0) - amount)
    body = body.resize((x1 - x0, nh), Image.NEAREST)
    out = Image.new("RGBA", (w, h), T)
    out.paste(body, (x0, y1 - nh))
    return out


def shifted(im, dx, dy):
    out = Image.new("RGBA", im.size, T)
    out.paste(im, (dx, dy))
    return out


def flash(im):
    arr = np.array(im)
    arr[..., 0:3] = np.where(arr[..., 3:4] > 0, 255, 0)
    return Image.fromarray(arr).copy()


def tint(im, mul, add=(0, 0, 0)):
    arr = np.array(im).astype(np.float32)
    for i in range(3):
        arr[..., i] = np.clip(arr[..., i] * mul[i] + add[i], 0, 255)
    return Image.fromarray(arr.astype(np.uint8)).copy()


SPR = {}


def put(name, im):
    SPR[name] = im


def put_enemy(name, im, f1=None, big=False):
    f1 = f1 if f1 is not None else squash(im, 3 if big else 2)
    put(name + "_0", im)
    put(name + "_1", f1)
    put(name + "_f0", flash(im))
    put(name + "_f1", flash(f1))


# --------------------------------------------------------------------------- enemies

def legs(s, xs, y, col="ink"):
    for x in xs:
        s.rect(x, y, x + 1, y + 3, col)


def en_ghoul():
    s = S()
    s.ell(8, 6, 23, 21, "moss").rect(9, 14, 22, 27, "moss")
    s.rect(6, 16, 8, 23, "moss").rect(23, 15, 25, 22, "moss")
    s.eye(13, 12, 3, "red").rect(18, 11, 20, 12, "ink")
    s.rect(12, 19, 19, 22, "plum").px(13, 19, "white").px(17, 19, "white").px(15, 22, "white")
    s.line([(18, 4), (18, 8)], "lime").arc([17, 5, 21, 9], 270, 90, "lime")
    legs(s, (11, 18), 27, "moss")
    return s.done()


def en_bat():
    s = S()
    s.poly([(15, 14), (2, 6), (4, 14), (1, 17), (7, 17), (9, 21)], "purple")
    s.poly([(16, 14), (29, 6), (27, 14), (30, 17), (24, 17), (22, 21)], "purple")
    s.ell(10, 9, 21, 22, "plum")
    s.poly([(11, 10), (12, 5), (14, 9)], "plum").poly([(20, 10), (19, 5), (17, 9)], "plum")
    s.eye(15, 15, 3, "yellow")
    s.px(14, 20, "white").px(17, 20, "white")
    a = s.done()
    s = S()
    s.poly([(15, 16), (3, 20), (6, 16), (3, 13), (9, 13)], "purple")
    s.poly([(16, 16), (28, 20), (25, 16), (28, 13), (22, 13)], "purple")
    s.ell(10, 10, 21, 23, "plum")
    s.poly([(11, 11), (12, 6), (14, 10)], "plum").poly([(20, 11), (19, 6), (17, 10)], "plum")
    s.eye(15, 16, 3, "yellow")
    s.px(14, 21, "white").px(17, 21, "white")
    return a, s.done()


def en_imp():
    s = S()
    s.ell(10, 10, 21, 22, "red").rect(12, 20, 19, 26, "red")
    s.poly([(10, 12), (8, 5), (13, 10)], "rose").poly([(21, 12), (23, 5), (18, 10)], "rose")
    s.eyes(15, 15, 6, "yellow")
    s.rect(13, 19, 18, 19, "ink")
    s.line([(21, 24), (26, 22), (27, 18)], "red").poly([(26, 16), (29, 18), (26, 20)], "rose")
    legs(s, (12, 18), 26, "red")
    return s.done()


def en_wraith():
    s = S()
    s.ell(8, 4, 23, 20, "cyan").rect(8, 12, 23, 24, "cyan")
    s.poly([(8, 24), (10, 29), (12, 24)], "cyan").poly([(13, 24), (15, 29), (18, 24)], "cyan").poly([(19, 24), (21, 29), (23, 24)], "cyan")
    s.ell(11, 8, 20, 18, "ocean")
    s.eyes(15, 12, 6, "white")
    for i, y in enumerate((20, 22)):
        s.line([(10, y), (12, y - 1), (14, y), (16, y - 1), (18, y), (20, y - 1)], "white")
    return s.done()


def en_specter():
    s = S()
    s.ell(7, 3, 24, 21, "navy").rect(7, 12, 24, 25, "navy")
    s.poly([(7, 25), (9, 30), (12, 25)], "navy").poly([(13, 25), (16, 30), (18, 25)], "navy").poly([(19, 25), (22, 30), (24, 25)], "navy")
    s.rect(11, 10, 13, 12, "white").rect(18, 10, 20, 12, "white")
    s.line([(12, 17), (19, 22)], "rose").line([(19, 17), (12, 22)], "rose")
    return s.done()


def en_gnome():
    s = S()
    s.poly([(15, 3), (16, 3), (24, 27), (7, 27)], "brown")
    s.poly([(15, 6), (16, 6), (20, 20), (11, 20)], "tan")
    s.line([(15, 22), (20, 7)], "ink").rect(19, 8, 21, 10, "silver")
    s.eye(15, 23, 2, "red")
    legs(s, (9, 20), 27, "bark")
    a = s.done()
    s = S()
    s.poly([(15, 3), (16, 3), (24, 27), (7, 27)], "brown")
    s.poly([(15, 6), (16, 6), (20, 20), (11, 20)], "tan")
    s.line([(15, 22), (11, 7)], "ink").rect(10, 8, 12, 10, "silver")
    s.eye(15, 23, 2, "red")
    legs(s, (9, 20), 27, "bark")
    return a, s.done()


def en_record():
    s = S()
    s.ell(4, 5, 27, 28, "ink").ell(6, 7, 25, 26, "swamp").ell(8, 9, 23, 24, "ink")
    s.ell(11, 12, 20, 21, "red").eye(15, 16, 2, "yellow")
    s.line([(16, 5), (19, 11), (17, 14)], "white")
    return s.done(outline="gray", shade=False)


def en_shard():
    s = S()
    s.poly([(10, 24), (22, 24), (16, 8)], "ink").poly([(12, 22), (20, 22), (16, 12)], "swamp")
    s.rect(14, 19, 17, 21, "red").px(16, 16, "white")
    return s.done(outline="gray", shade=False)


def en_cassette():
    s = S()
    s.rect(5, 9, 26, 23, "stone").rect(7, 11, 24, 18, "tan")
    s.ell(9, 12, 14, 17, "white").ell(17, 12, 22, 17, "white")
    s.rect(11, 14, 12, 15, "ink").rect(19, 14, 20, 15, "ink")
    s.poly([(9, 23), (11, 20), (20, 20), (22, 23)], "iron")
    legs(s, (7, 12, 18, 23), 24, "ink")
    return s.done()


def en_speaker():
    s = S()
    s.rect(7, 3, 24, 26, "bark").rect(9, 5, 22, 24, "plum")
    s.ell(10, 10, 21, 21, "ink").ell(12, 12, 19, 19, "iron").eye(15, 15, 2, "red")
    s.ell(13, 5, 18, 8, "iron")
    s.rect(8, 27, 12, 29, "ink").rect(19, 27, 23, 29, "ink")
    s.rect(4, 12, 6, 20, "bark").rect(25, 12, 27, 20, "bark")
    return s.done()


def en_snake():
    s = S()
    s.line([(6, 27), (12, 24), (8, 19), (16, 17), (14, 12)], "ink", 3)
    s.ell(9, 2, 20, 12, "silver").rect(12, 11, 17, 15, "iron")
    for x in (11, 14, 17):
        s.line([(x, 3), (x, 10)], "gray")
    s.eye(14, 7, 2, "green")
    return s.done()


def en_slime():
    s = S()
    s.ell(5, 10, 26, 28, "sky").rect(5, 20, 26, 27, "sky")
    s.ell(9, 13, 14, 17, "ice")
    s.eyes(15, 20, 8, "white")
    s.rect(13, 24, 18, 24, "navy")
    s.rect(3, 17, 5, 20, "orange").rect(26, 17, 28, 20, "orange")
    return s.done()


def en_boombox():
    s = S()
    s.rect(3, 10, 28, 25, "red").rect(9, 5, 22, 6, "iron").rect(9, 6, 10, 10, "iron").rect(21, 6, 22, 10, "iron")
    s.ell(5, 13, 13, 21, "ink").ell(18, 13, 26, 21, "ink")
    s.ell(7, 15, 11, 19, "yellow").ell(20, 15, 24, 19, "yellow")
    s.rect(14, 12, 17, 14, "tan").rect(13, 22, 18, 23, "ink")
    legs(s, (6, 24), 26, "ink")
    return s.done()


def en_wasp():
    def body(wy):
        s = S()
        s.ell(4, wy, 13, wy + 6, "ice").ell(17, wy, 26, wy + 6, "ice")
        s.ell(9, 10, 22, 22, "yellow")
        s.rect(12, 10, 13, 22, "ink").rect(17, 10, 18, 22, "ink")
        s.eye(15, 14, 2, "red")
        s.rect(14, 22, 16, 26, "silver").rect(12, 25, 13, 30, "silver").rect(17, 25, 18, 30, "silver")
        return s.done()
    return body(5), body(8)


def en_crab():
    s = S()
    s.ell(5, 9, 26, 22, "gold").ell(8, 11, 23, 19, "yellow").ell(14, 13, 17, 16, "tan")
    s.rect(11, 20, 13, 22, "white").rect(18, 20, 20, 22, "white").px(12, 21, "ink").px(19, 21, "ink")
    s.ell(1, 13, 6, 18, "orange").ell(25, 13, 30, 18, "orange")
    for x in (7, 11, 19, 23):
        s.rect(x, 23, x + 1, 26, "orange")
    return s.done()


def en_diva():
    s = S()
    s.poly([(7, 28), (9, 10), (22, 10), (24, 28)], "rose")
    s.ell(9, 2, 22, 15, "skin")
    s.poly([(8, 9), (9, 1), (22, 1), (23, 9), (20, 4), (11, 4)], "purple")
    s.rect(7, 6, 9, 20, "purple").rect(22, 6, 24, 20, "purple")
    s.eyes(15, 8, 6, "white")
    s.ell(13, 10, 18, 15, "ink").rect(14, 12, 17, 13, "red")
    return s.done()


def en_beetle():
    s = S()
    s.rect(6, 9, 25, 24, "red").rect(6, 9, 25, 11, "silver").rect(6, 22, 25, 24, "silver")
    for x in (9, 15, 21):
        s.line([(x, 12), (x + 2, 21)], "tan")
    s.ell(8, 4, 23, 11, "skin")
    s.eyes(15, 7, 8, "ink", "ink")
    for x in (4, 26):
        s.rect(x, 13, x + 1, 15, "ink").rect(x, 19, x + 1, 21, "ink")
    legs(s, (9, 21), 25, "ink")
    return s.done()


def en_static():
    s = S()
    pts = []
    rnd = random.Random(7)
    for i in range(14):
        a = i / 14 * math.tau
        r = 11 if i % 2 == 0 else 5 + rnd.random() * 2
        pts.append((15.5 + math.cos(a) * r, 15.5 + math.sin(a) * r))
    s.poly(pts, "cyan")
    s.ell(11, 11, 20, 20, "white")
    s.px(14, 15, "ink").px(17, 15, "ink")
    a = s.done(outline="ocean", shade=False)
    b = a.rotate(25, resample=Image.NEAREST)
    return a, b


def en_rghost():
    s = S()
    for dx, col in ((6, "navy"), (3, "blue"), (0, "ice")):
        s.ell(5 + dx, 6, 18 + dx, 20, col).rect(5 + dx, 13, 18 + dx, 25, col)
        s.poly([(5 + dx, 25), (8 + dx, 29), (11 + dx, 25), (14 + dx, 29), (18 + dx, 25)], col)
    s.rect(8, 12, 9, 14, "ink").rect(13, 12, 14, 14, "ink").rect(10, 18, 12, 20, "ink")
    return s.done(shade=False)


def en_ember():
    s = S()
    s.poly([(9, 22), (11, 12), (14, 16), (16, 6), (19, 15), (22, 11), (23, 22)], "orange")
    s.ell(8, 15, 23, 28, "orange").ell(11, 18, 20, 27, "yellow")
    s.eyes(15, 22, 6, "ink", "ink")
    s.rect(22, 3, 23, 14, "red").poly([(23, 3), (28, 5), (23, 8)], "red")
    return s.done(outline="red")


def en_knight():
    s = S()
    s.rect(9, 12, 22, 25, "silver").rect(11, 14, 20, 18, "iron")
    for i, x in enumerate((9, 13, 17, 21)):
        s.rect(x, 2 + (i % 2) * 3, x + 2, 12, "tan")
        s.rect(x, 9, x + 2, 9, "gold")
    s.rect(11, 15, 20, 16, "ink").px(13, 15, "red").px(18, 15, "red")
    s.rect(4, 14, 8, 22, "navy").rect(23, 10, 24, 26, "gray")
    legs(s, (11, 19), 26, "iron")
    return s.done()


def en_gargoyle():
    s = S()
    s.poly([(10, 14), (1, 5), (4, 20)], "stone").poly([(21, 14), (30, 5), (27, 20)], "stone")
    s.ell(9, 6, 22, 18, "gray").rect(10, 14, 21, 26, "gray")
    s.poly([(10, 8), (9, 3), (13, 7)], "gray").poly([(21, 8), (22, 3), (18, 7)], "gray")
    s.eyes(15, 11, 6, "yellow")
    s.ell(11, 17, 20, 26, "gold").ell(13, 19, 18, 24, "yellow")
    return s.done()


def en_moss():
    s = S()
    s.ell(5, 9, 26, 27, "moss")
    for x, y in ((8, 8), (14, 5), (20, 8), (11, 12), (18, 12)):
        s.poly([(x, y + 5), (x + 2, y), (x + 4, y + 5)], "green")
    s.eye(15, 19, 3, "yellow")
    s.rect(9, 27, 11, 29, "bark").rect(20, 27, 22, 29, "bark")
    return s.done()


def en_moth():
    def body(spread):
        s = S()
        s.ell(2, 7 + spread, 14, 19, "ice").ell(17, 7 + spread, 29, 19, "ice")
        s.ell(5, 17, 13, 25 - spread, "silver").ell(18, 17, 26, 25 - spread, "silver")
        s.ell(6, 11 + spread, 9, 14 + spread, "pink").ell(22, 11 + spread, 25, 14 + spread, "pink")
        s.ell(13, 8, 18, 25, "tan")
        s.eyes(15, 12, 4, "ink", "ink")
        s.line([(14, 8), (11, 3)], "ink").line([(17, 8), (20, 3)], "ink")
        return s.done()
    return body(0), body(3)


def en_cultist():
    s = S()
    s.poly([(6, 28), (10, 9), (21, 9), (25, 28)], "purple")
    s.ell(9, 2, 22, 15, "purple").ell(11, 5, 20, 14, "ink")
    s.eyes(15, 9, 6, "yellow", "yellow")
    s.rect(11, 18, 20, 23, "ice").line([(15, 18), (15, 23)], "gray").line([(12, 20), (14, 20)], "ink").line([(17, 20), (19, 20)], "ink")
    return s.done()


def en_tick():
    s = S()
    s.ell(10, 13, 21, 23, "bark").ell(12, 15, 16, 18, "orange")
    s.rect(14, 8, 17, 13, "silver").rect(14, 5, 14, 8, "tan").rect(17, 5, 17, 8, "tan")
    s.px(13, 19, "white").px(18, 19, "white")
    for x in (8, 22):
        s.rect(x, 16, x + 1, 17, "ink").rect(x, 21, x + 1, 22, "ink")
    return s.done()


def en_shroom():
    s = S()
    s.ell(4, 5, 27, 20, "rose").rect(4, 13, 27, 17, "rose")
    s.ell(8, 8, 12, 12, "white").ell(18, 7, 23, 11, "white").ell(14, 12, 17, 15, "white")
    s.rect(11, 17, 20, 27, "skin")
    s.rect(12, 21, 14, 21, "ink").rect(17, 21, 19, 21, "ink").rect(14, 24, 17, 24, "ink")
    return s.done()


def en_grub():
    s = S()
    for i, (x, y) in enumerate(((5, 22), (10, 19), (15, 21), (20, 18))):
        s.ell(x, y, x + 8, y + 8, "bark" if i % 2 else "brown")
    s.ell(19, 10, 29, 20, "tan")
    s.eye(24, 15, 2, "green")
    s.rect(12, 14, 17, 15, "ink")
    return s.done()


def en_troll():
    s = S()
    s.ell(4, 10, 27, 28, "orange").rect(4, 10, 27, 18, "orange").ell(4, 6, 27, 14, "skin")
    s.rect(4, 14, 27, 15, "gold")
    s.eyes(15, 20, 8, "white")
    s.rect(12, 24, 19, 25, "ink").px(13, 23, "white").px(18, 23, "white")
    s.rect(1, 14, 3, 22, "tan").rect(28, 14, 30, 22, "tan")
    return s.done()


def en_spider():
    s = S()
    for x in (4, 8, 23, 27):
        s.line([(15, 16), (x, 8)], "tan").line([(x, 8), (x, 27)], "tan")
    s.ell(9, 11, 22, 24, "plum").ell(12, 6, 19, 13, "plum")
    s.eyes(15, 9, 4, "red", "red")
    for x in (12, 15, 18):
        s.line([(x, 14), (x, 22)], "yellow")
    return s.done()


def en_headbanger():
    s = S()
    s.rect(11, 16, 20, 26, "ink").rect(13, 18, 18, 20, "red")
    s.ell(9, 5, 22, 17, "ice")
    s.rect(11, 9, 13, 11, "ink").rect(18, 9, 20, 11, "ink").rect(13, 14, 18, 15, "ink")
    s.poly([(8, 16), (9, 3), (22, 3), (23, 16), (21, 6), (10, 6)], "bark")
    s.rect(6, 6, 8, 20, "bark").rect(23, 6, 25, 20, "bark")
    legs(s, (12, 18), 26, "ink")
    return s.done()


def en_glitch():
    s = S()
    s.rect(6, 9, 21, 24, "pink").rect(11, 6, 26, 21, "cyan").rect(9, 8, 23, 23, "ink")
    s.rect(11, 12, 14, 15, "white").rect(18, 12, 21, 15, "white")
    s.rect(11, 19, 21, 20, "lime").rect(4, 14, 8, 15, "cyan").rect(24, 18, 28, 19, "pink")
    return s.done(shade=False)


def en_wisp():
    s = S()
    s.ell(8, 10, 23, 25, "silver").ell(5, 15, 14, 24, "gray").ell(17, 6, 26, 15, "gray")
    s.ell(12, 3, 18, 9, "silver")
    s.eyes(15, 17, 6, "ink", "ink")
    return s.done(outline="stone")


def en_bully():
    s = S()
    s.ell(4, 4, 27, 20, "yellow").ell(8, 7, 23, 17, "ink").ell(11, 9, 20, 15, "gold")
    s.rect(11, 18, 20, 27, "gold").rect(8, 21, 10, 25, "yellow").rect(21, 21, 23, 25, "yellow")
    s.eyes(15, 22, 6, "white")
    legs(s, (12, 18), 27, "gold")
    return s.done()


def en_shade():
    s = S()
    s.poly([(7, 29), (10, 10), (21, 10), (24, 29)], "ink")
    s.ell(10, 2, 21, 13, "ink")
    s.eyes(15, 7, 6, "red", "red")
    s.poly([(14, 13), (17, 13), (15, 18)], "white")
    s.line([(22, 14), (29, 4)], "white").px(29, 4, "yellow")
    s.rect(5, 14, 9, 16, "ink").rect(22, 14, 24, 16, "ink")
    return s.done(outline="purple", shade=False)


def en_dummy():
    s = S()
    s.rect(14, 16, 17, 28, "brown").ell(8, 4, 23, 19, "tan")
    s.ell(11, 7, 20, 16, "white").ell(13, 9, 18, 14, "red")
    s.rect(9, 27, 22, 29, "bark")
    return s.done()


# --------------------------------------------------------------------------- bosses (64 px)

def boss_tapeworm():
    s = S(64, 64)
    s.rect(6, 10, 57, 44, "stone").rect(10, 14, 53, 34, "tan")
    s.ell(14, 16, 28, 30, "white").ell(35, 16, 49, 30, "white")
    s.ell(18, 20, 24, 26, "red").ell(39, 20, 45, 26, "red")
    s.poly([(16, 44), (20, 37), (43, 37), (47, 44)], "iron")
    for i in range(6):
        y = 46 + i * 3
        s.line([(20 + (i % 2) * 4, y), (44 - (i % 2) * 4, y + 2)], "bark", 3)
    s.poly([(6, 10), (2, 2), (14, 8)], "stone").poly([(57, 10), (61, 2), (49, 8)], "stone")
    s.rect(24, 31, 39, 33, "ink")
    for x in (26, 30, 34):
        s.poly([(x, 33), (x + 2, 36), (x + 4, 33)], "white")
    return s.done()


def boss_organist():
    s = S(64, 64)
    for i, x in enumerate(range(6, 58, 6)):
        h = 4 + abs(4 - i) * 4
        s.rect(x, h, x + 4, 40, "tan").rect(x, h + 6, x + 4, h + 7, "gold").rect(x + 1, 30, x + 3, 34, "ink")
    s.rect(4, 38, 59, 58, "bark").rect(8, 42, 55, 46, "white")
    for x in range(10, 55, 4):
        s.rect(x, 42, x + 1, 44, "ink")
    s.ell(22, 14, 41, 34, "plum").ell(25, 18, 38, 31, "ice")
    s.rect(28, 22, 30, 25, "ink").rect(34, 22, 36, 25, "ink").rect(29, 28, 35, 29, "ink")
    s.rect(18, 48, 45, 52, "plum").rect(8, 50, 14, 62, "bark").rect(49, 50, 55, 62, "bark")
    return s.done()


def boss_dj():
    s = S(64, 64)
    s.rect(4, 40, 59, 58, "navy").ell(8, 42, 26, 56, "ink").ell(37, 42, 55, 56, "ink")
    s.ell(14, 46, 20, 52, "pink").ell(43, 46, 49, 52, "cyan")
    s.rect(29, 44, 34, 54, "iron")
    s.rect(20, 22, 43, 42, "purple").ell(20, 4, 43, 26, "skin")
    s.rect(22, 11, 41, 16, "ink").rect(23, 12, 30, 15, "cyan").rect(33, 12, 40, 15, "pink")
    s.arc([17, 0, 46, 24], 180, 360, "red", 3).rect(16, 10, 21, 20, "red").rect(42, 10, 47, 20, "red")
    s.rect(27, 20, 36, 21, "ink")
    s.rect(10, 30, 20, 34, "purple").rect(43, 30, 53, 34, "purple")
    return s.done()


def boss_scat():
    s = S(64, 64)
    s.poly([(14, 60), (20, 26), (43, 26), (49, 60)], "ink")
    s.poly([(28, 26), (31, 44), (35, 26)], "white").poly([(29, 28), (31, 32), (34, 28)], "red")
    s.ell(20, 6, 43, 30, "brown")
    s.rect(16, 2, 47, 8, "ink").rect(22, -4, 41, 4, "ink").rect(22, 3, 41, 5, "rose")
    s.rect(24, 14, 29, 17, "ink").rect(34, 14, 39, 17, "ink").rect(29, 15, 34, 15, "ink")
    s.ell(27, 20, 36, 27, "white").rect(28, 23, 35, 24, "ink")
    s.ell(48, 20, 62, 40, "yellow").rect(44, 28, 50, 31, "gold").ell(52, 24, 58, 36, "gold")
    s.rect(8, 34, 16, 38, "ink").rect(43, 30, 48, 34, "ink")
    return s.done()


def boss_shredder():
    s = S(64, 64)
    s.poly([(18, 60), (22, 28), (41, 28), (45, 60)], "ink")
    s.ell(20, 8, 43, 30, "ice")
    s.rect(24, 15, 29, 19, "ink").rect(34, 15, 39, 19, "ink").px(26, 17, "red").px(36, 17, "red")
    s.rect(26, 24, 37, 26, "ink")
    for x in (27, 30, 33):
        s.rect(x, 24, x + 1, 25, "white")
    s.poly([(16, 30), (20, 4), (26, 12), (31, 2), (37, 12), (43, 4), (47, 30), (42, 14), (21, 14)], "orange")
    s.poly([(20, 4), (23, 12), (18, 14)], "yellow").poly([(43, 4), (40, 12), (45, 14)], "yellow")
    s.poly([(6, 56), (14, 36), (22, 44), (30, 40), (20, 60)], "red").line([(22, 44), (52, 30)], "bark", 3)
    s.rect(50, 26, 58, 32, "bark")
    return s.done()


def boss_conductor():
    s = S(64, 64)
    s.poly([(12, 62), (20, 26), (43, 26), (51, 62)], "ink")
    s.poly([(20, 26), (12, 62), (22, 62), (28, 34)], "red").poly([(43, 26), (51, 62), (41, 62), (35, 34)], "red")
    s.poly([(27, 26), (31, 40), (36, 26)], "white")
    s.ell(21, 6, 42, 28, "skin")
    s.poly([(19, 16), (20, 2), (31, 6), (43, 2), (44, 16), (40, 8), (23, 8)], "white")
    s.rect(25, 15, 29, 17, "ink").rect(34, 15, 38, 17, "ink").rect(27, 22, 36, 23, "ink")
    s.line([(46, 32), (60, 4)], "white", 2).ell(58, 2, 62, 6, "yellow")
    s.rect(4, 30, 20, 34, "ink").rect(43, 30, 48, 34, "ink")
    s.ell(1, 28, 7, 36, "skin")
    return s.done()


# --------------------------------------------------------------------------- characters

def character(body, belly, head, ear, snout, extra=None, tool="guitar"):
    frames = []
    for f in range(2):
        s = S()
        ly = 27
        s.rect(11, ly, 13, ly + (3 if f == 0 else 2), "ink").rect(18, ly, 20, ly + (2 if f == 0 else 3), "ink")
        s.ell(8, 15, 23, 28, body).ell(11, 18, 20, 27, belly)
        s.ell(8, 5, 23, 18, head)
        if ear == "round":
            s.ell(6, 3, 12, 9, head).ell(19, 3, 25, 9, head).ell(8, 5, 10, 7, belly).ell(21, 5, 23, 7, belly)
        elif ear == "pointy":
            s.poly([(8, 9), (9, 1), (14, 6)], head).poly([(23, 9), (22, 1), (17, 6)], head)
            s.px(10, 5, belly).px(21, 5, belly)
        elif ear == "long":
            s.rect(10, -2, 12, 7, head).rect(19, -2, 21, 7, head).rect(11, 0, 11, 5, belly).rect(20, 0, 20, 5, belly)
        elif ear == "tuft":
            s.poly([(8, 8), (7, 2), (12, 6)], head).poly([(23, 8), (24, 2), (19, 6)], head)
        elif ear == "big":
            s.ell(1, 4, 10, 17, head).ell(21, 4, 30, 17, head)
        elif ear == "top":
            s.ell(8, 3, 13, 8, head).ell(18, 3, 23, 8, head)
        elif ear == "crest":
            s.poly([(13, 6), (15, 0), (17, 3), (19, 0), (19, 6)], "red")
        if ear == "top":
            s.rect(10, 5, 11, 6, "white").rect(20, 5, 21, 6, "white").px(11, 6, "ink").px(21, 6, "ink")
        else:
            s.rect(11, 10, 12, 12, "white").rect(19, 10, 20, 12, "white").px(12, 12, "ink").px(20, 12, "ink")
        if snout == "muzzle":
            s.ell(12, 12, 19, 17, belly).rect(15, 13, 16, 13, "ink")
        elif snout == "beak":
            s.poly([(14, 13), (17, 13), (15, 17)], "orange")
        elif snout == "trunk":
            s.rect(14, 13, 17, 21, head).rect(14, 21, 19, 22, head)
        elif snout == "wide":
            s.rect(11, 15, 20, 15, "ink")
        elif snout == "long":
            s.ell(11, 12, 20, 18, belly).rect(14, 13, 17, 14, "ink")
        elif snout == "mask":
            s.rect(9, 9, 22, 13, "ink").rect(11, 10, 12, 12, "white").rect(19, 10, 20, 12, "white")
        if extra:
            extra(s)
        if tool == "guitar":
            s.line([(4, 15), (14, 24)], "bark", 2).ell(11, 20, 19, 28, "orange").ell(14, 23, 16, 25, "ink")
        elif tool == "sticks":
            s.line([(3, 14), (10, 21)], "tan").line([(28, 14), (21, 21)], "tan")
        elif tool == "bass":
            s.line([(26, 6), (17, 24)], "bark", 2).ell(12, 19, 21, 28, "red").ell(15, 22, 17, 24, "ink")
        elif tool == "violin":
            s.ell(4, 16, 11, 24, "brown").line([(2, 14), (12, 25)], "ice")
        elif tool == "horn":
            s.rect(18, 20, 25, 22, "yellow").poly([(25, 17), (29, 15), (29, 27), (25, 25)], "yellow")
        elif tool == "keys":
            s.rect(7, 23, 24, 26, "white")
            for x in range(8, 24, 3):
                s.rect(x, 23, x, 24, "ink")
        elif tool == "harp":
            s.arc([20, 12, 30, 28], 270, 90, "yellow", 2).line([(24, 13), (24, 27)], "yellow").line([(26, 15), (26, 26)], "tan")
        elif tool == "synth":
            s.rect(6, 22, 25, 26, "purple").rect(7, 24, 24, 25, "white").rect(8, 22, 10, 22, "cyan")
        elif tool == "deck":
            s.ell(4, 19, 13, 27, "ink").ell(7, 22, 10, 24, "red")
        elif tool == "book":
            s.rect(10, 21, 21, 26, "ice").line([(15, 21), (15, 26)], "gray")
        elif tool == "antenna":
            s.rect(24, 8, 24, 24, "silver").arc([2, 18, 10, 26], 0, 360, "silver")
        elif tool == "bell":
            s.poly([(21, 18), (27, 18), (29, 26), (19, 26)], "tan").rect(22, 16, 26, 17, "gold")
        frames.append(s.done())
    return frames


def hat_beanie(s):
    s.ell(8, 2, 23, 10, "rose").rect(8, 6, 23, 8, "red")


def hat_beret(s):
    s.ell(7, 1, 22, 7, "ink").px(15, 0, "ink")


def stripes(s):
    for y in (18, 21, 24):
        s.rect(10, y, 21, y, "ink")


def shades(s):
    s.rect(9, 10, 14, 13, "ink").rect(17, 10, 22, 13, "ink").rect(14, 11, 17, 11, "ink")


def headphones(s):
    s.arc([7, 1, 24, 16], 180, 360, "red", 2).rect(6, 8, 8, 14, "red").rect(23, 8, 25, 14, "red")


def shell(s):
    s.arc([6, 12, 25, 30], 180, 360, "gray", 3)
    for x in (10, 15, 20):
        s.line([(x, 14), (x, 18)], "stone")


# --------------------------------------------------------------------------- icons

def frame_icon(s, evo=False):
    return s.done()


def ico_drums():
    s = S()
    s.rect(6, 12, 25, 24, "red").ell(6, 8, 25, 16, "ice").ell(6, 20, 25, 28, "red")
    s.rect(6, 12, 25, 13, "silver").rect(6, 23, 25, 24, "silver")
    s.line([(3, 3), (13, 11)], "tan", 2).line([(28, 3), (18, 11)], "tan", 2)
    return s.done()


def ico_guitar():
    s = S()
    s.line([(26, 4), (14, 17)], "bark", 3).rect(24, 2, 29, 6, "ink")
    s.poly([(4, 20), (10, 12), (18, 14), (20, 22), (14, 29), (6, 28)], "red")
    s.ell(10, 18, 15, 23, "ink").line([(22, 6), (10, 22)], "ice")
    return s.done()


def ico_bass():
    s = S()
    s.line([(27, 3), (14, 18)], "bark", 2).rect(25, 1, 29, 5, "bark")
    s.ell(4, 14, 19, 29, "navy").ell(8, 18, 15, 25, "blue")
    for dx in (0, 2):
        s.line([(26 + dx, 4), (9 + dx, 23)], "ice")
    return s.done()


def ico_violin():
    s = S()
    s.ell(8, 14, 20, 26, "brown").ell(10, 8, 18, 17, "brown").rect(13, 2, 15, 9, "bark")
    s.rect(13, 12, 15, 22, "ink").line([(26, 4), (6, 28)], "ice")
    return s.done()


def ico_trumpet():
    s = S()
    s.rect(4, 14, 20, 17, "yellow").poly([(19, 11), (28, 6), (28, 25), (19, 20)], "yellow")
    s.rect(8, 10, 9, 14, "gold").rect(12, 10, 13, 14, "gold").rect(16, 10, 17, 14, "gold")
    s.rect(7, 17, 16, 22, "gold").rect(9, 19, 14, 20, "ink").rect(2, 13, 4, 18, "gold")
    return s.done()


def ico_piano():
    s = S()
    s.rect(3, 8, 28, 24, "ink").rect(4, 13, 27, 23, "white")
    for x in range(8, 27, 4):
        s.line([(x, 13), (x, 23)], "gray")
    for x in (6, 10, 18, 22):
        s.rect(x, 13, x + 2, 18, "ink")
    return s.done()


def ico_harp():
    s = S()
    s.arc([6, 3, 34, 31], 150, 260, "yellow", 3).line([(8, 26), (8, 4)], "gold", 3).line([(8, 27), (24, 27)], "gold", 3)
    for x in (12, 16, 20):
        s.line([(x, 7 + (x - 12) // 2), (x, 26)], "ice")
    return s.done()


def ico_synth():
    s = S()
    s.rect(2, 9, 29, 24, "purple").rect(3, 17, 28, 23, "white")
    for x in range(6, 28, 3):
        s.line([(x, 17), (x, 23)], "gray")
    for x in (5, 11, 17, 23):
        s.rect(x, 17, x + 1, 20, "ink")
    s.line([(4, 13), (7, 11), (10, 14), (13, 11), (16, 14)], "cyan")
    s.ell(20, 11, 22, 13, "pink").ell(25, 11, 27, 13, "lime")
    return s.done()


def ico_cello():
    s = S()
    s.ell(7, 14, 22, 29, "bark").ell(9, 6, 20, 17, "bark").rect(13, 0, 15, 8, "brown")
    s.rect(13, 12, 15, 24, "ink").rect(14, 28, 14, 31, "silver")
    s.line([(28, 6), (10, 24)], "ice")
    return s.done()


def ico_flute():
    s = S()
    s.line([(3, 26), (28, 5)], "silver", 3)
    for i in range(4):
        s.px(10 + i * 4, 21 - i * 3 - 1, "ink")
    s.poly([(24, 16), (25, 22), (27, 22), (27, 18)], "cyan")
    s.ell(22, 21, 26, 25, "cyan")
    return s.done()


def ico_choir():
    s = S()
    for x, col in ((6, "rose"), (15, "sky"), (24, "lime")):
        s.ell(x - 4, 6, x + 4, 14, "skin").poly([(x - 6, 28), (x - 3, 14), (x + 3, 14), (x + 6, 28)], col)
        s.ell(x - 2, 9, x + 2, 13, "ink")
    return s.done()


def ico_turntable():
    s = S()
    s.rect(2, 6, 29, 27, "iron").ell(4, 8, 22, 26, "ink").ell(10, 14, 16, 20, "red").px(13, 17, "white")
    s.line([(26, 9), (20, 20)], "silver", 2).rect(24, 21, 27, 24, "lime")
    return s.done()


def ico_triangle():
    s = S()
    s.line([(15, 4), (4, 25), (22, 25)], "silver", 3).line([(15, 4), (26, 22)], "silver", 3)
    s.line([(22, 9), (29, 15)], "ice", 2)
    return s.done()


def ico_organ():
    s = S()
    for i, x in enumerate((3, 8, 13, 18, 23)):
        h = 3 + abs(2 - i) * 4
        s.rect(x, h, x + 4, 22, "tan").rect(x + 1, 16, x + 3, 19, "ink")
    s.rect(2, 22, 29, 28, "bark").rect(4, 24, 27, 26, "white")
    return s.done()


def ico_theremin():
    s = S()
    s.rect(6, 18, 25, 26, "bark").rect(24, 4, 25, 18, "silver").arc([0, 14, 10, 24], 0, 360, "silver")
    for i, r in enumerate((3, 6)):
        s.arc([18 - r, 8 - r, 18 + r, 8 + r], 150, 250, "cyan")
    s.rect(10, 26, 12, 30, "bark").rect(19, 26, 21, 30, "bark")
    return s.done()


def ico_cowbell():
    s = S()
    s.poly([(9, 8), (22, 8), (27, 27), (4, 27)], "tan").rect(11, 4, 20, 8, "gold").rect(4, 25, 27, 27, "gold")
    s.line([(23, 2), (29, 12)], "bark", 2)
    return s.done()


def ico_kazoo():
    s = S()
    s.poly([(3, 13), (26, 10), (28, 20), (3, 19)], "rose").ell(13, 5, 21, 13, "red").ell(15, 7, 19, 11, "ice")
    return s.done()


def passive_icons():
    out = {}
    s = S(); s.poly([(15, 2), (16, 2), (25, 28), (6, 28)], "brown").poly([(15, 6), (16, 6), (21, 22), (10, 22)], "tan").line([(15, 24), (21, 6)], "ink").rect(20, 8, 22, 10, "silver"); out["metronome"] = s.done()
    s = S(); s.rect(5, 4, 26, 28, "ink").rect(7, 6, 24, 10, "gold").ell(9, 12, 22, 25, "iron").ell(13, 16, 18, 21, "ink")
    for x in (9, 13, 17, 21):
        s.px(x, 8, "ink")
    out["amplifier"] = s.done()
    s = S(); s.rect(4, 22, 27, 27, "iron").poly([(8, 22), (12, 8), (20, 8), (24, 22)], "yellow").rect(12, 8, 20, 10, "gold"); out["sustain_pedal"] = s.done()
    s = S(); s.ell(5, 5, 26, 26, "ink").ell(8, 8, 23, 23, "iron").line([(15, 15), (21, 8)], "white", 2)
    for a in range(-120, 121, 40):
        s.px(int(15.5 + math.cos(math.radians(a - 90)) * 13), int(15.5 + math.sin(math.radians(a - 90)) * 13), "white")
    out["volume_knob"] = s.done()
    s = S(); s.rect(10, 3, 12, 18, "silver").rect(19, 3, 21, 18, "silver").rect(10, 17, 21, 19, "silver").rect(14, 19, 17, 29, "silver"); out["tuning_fork"] = s.done()
    s = S(); s.ell(4, 16, 13, 24, "rose").rect(12, 4, 13, 20, "rose").ell(17, 18, 26, 26, "rose").rect(25, 6, 26, 22, "rose").poly([(12, 4), (26, 6), (26, 10), (12, 8)], "rose").rect(26, 2, 28, 4, "yellow").rect(27, 0, 27, 6, "yellow"); out["encore"] = s.done()
    s = S(); s.arc([5, 3, 26, 26], 180, 360, "red", 5).rect(5, 14, 9, 24, "red").rect(22, 14, 26, 24, "red").rect(5, 24, 9, 27, "silver").rect(22, 24, 26, 27, "silver"); out["groupie_magnet"] = s.done()
    s = S(); s.poly([(15, 27), (4, 14), (4, 9), (9, 5), (15, 9), (22, 5), (27, 9), (27, 14)], "red").ell(8, 8, 12, 12, "rose"); out["stage_presence"] = s.done()
    s = S(); s.ell(4, 8, 14, 22, "orange").rect(12, 13, 16, 17, "orange").ell(17, 8, 27, 22, "orange").line([(14, 15), (17, 15)], "blue", 2).ell(7, 11, 10, 14, "yellow"); out["earplugs"] = s.done()
    s = S(); s.ell(5, 5, 26, 26, "gold").ell(7, 7, 24, 24, "yellow").rect(14, 10, 17, 21, "gold").rect(12, 12, 19, 13, "gold").rect(12, 18, 19, 19, "gold"); out["royalties"] = s.done()
    s = S(); s.poly([(15, 28), (5, 8), (9, 4), (22, 4), (26, 8)], "lime").poly([(15, 22), (10, 9), (21, 9)], "green").px(15, 12, "white"); out["lucky_pick"] = s.done()
    s = S(); s.rect(6, 12, 25, 26, "ink").rect(8, 14, 23, 24, "stone").rect(12, 8, 19, 12, "ink").ell(12, 16, 19, 23, "red").rect(15, 17, 16, 22, "white").rect(13, 19, 18, 20, "white"); out["roadie"] = s.done()
    s = S(); s.rect(4, 12, 27, 18, "iron").rect(6, 8, 9, 12, "silver").rect(22, 18, 25, 24, "silver").rect(10, 14, 21, 16, "rose"); out["capo"] = s.done()
    s = S(); s.rect(6, 3, 25, 28, "ice")
    for y in (8, 13, 18, 23):
        s.line([(9, y), (22, y)], "gray")
    s.rect(11, 7, 12, 9, "ink").rect(16, 12, 17, 14, "ink").rect(13, 17, 14, 19, "ink"); out["setlist"] = s.done()
    s = S(); s.rect(7, 8, 24, 28, "sky").rect(13, 3, 18, 9, "silver").rect(10, 13, 21, 16, "white").rect(10, 19, 21, 24, "navy").ell(14, 20, 17, 23, "yellow"); out["backstage_pass"] = s.done()
    s = S(); s.poly([(11, 3), (20, 3), (23, 12), (8, 12)], "iron").poly([(9, 12), (22, 12), (30, 29), (1, 29)], "yellow").rect(8, 11, 23, 13, "ink"); out["spotlight"] = s.done()
    return out


def pickup_icons():
    out = {}
    s = S(16, 16); s.poly([(7, 1), (8, 1), (13, 7), (13, 8), (8, 14), (7, 14), (2, 8), (2, 7)], "sky").px(6, 5, "white").px(7, 4, "white"); out["gem1"] = s.done()
    s = S(16, 16); s.poly([(4, 2), (11, 2), (14, 7), (11, 13), (4, 13), (1, 7)], "lime").rect(5, 4, 7, 5, "white"); out["gem2"] = s.done()
    s = S(16, 16)
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 7 if i % 2 == 0 else 3.2
        pts.append((7.5 + math.cos(a) * r, 7.5 + math.sin(a) * r))
    s.poly(pts, "rose").px(7, 5, "white"); out["gem3"] = s.done()
    s = S(16, 16); s.ell(2, 2, 13, 13, "yellow").ell(4, 4, 11, 11, "gold").rect(7, 5, 8, 10, "yellow"); out["coin"] = s.done()
    s = S(16, 16); s.ell(2, 5, 13, 14, "brown").rect(5, 2, 10, 5, "tan").rect(6, 8, 9, 11, "yellow"); out["coinbag"] = s.done()
    s = S(16, 16); s.poly([(1, 4), (14, 4), (8, 14), (7, 14)], "yellow").rect(1, 2, 14, 4, "tan").ell(4, 5, 6, 7, "red").ell(9, 6, 11, 8, "red").px(7, 10, "red"); out["food"] = s.done()
    s = S(16, 16); s.arc([2, 1, 13, 13], 180, 360, "red", 3).rect(2, 7, 4, 12, "red").rect(11, 7, 13, 12, "red").rect(2, 12, 4, 14, "white").rect(11, 12, 13, 14, "white"); out["magnet"] = s.done()
    s = S(16, 16); s.ell(2, 4, 13, 15, "ink").ell(4, 6, 7, 9, "iron").rect(7, 2, 8, 4, "tan").px(9, 1, "yellow").px(10, 0, "orange"); out["bomb"] = s.done(outline="gray", shade=False)
    s = S(16, 16)
    for a in range(0, 180, 60):
        dx, dy = math.cos(math.radians(a)) * 7, math.sin(math.radians(a)) * 7
        s.line([(7.5 - dx, 7.5 - dy), (7.5 + dx, 7.5 + dy)], "cyan")
    s.rect(7, 7, 8, 8, "white"); out["freeze"] = s.done(outline="ocean", shade=False)
    s = S(); s.rect(4, 12, 27, 27, "brown").ell(4, 6, 27, 20, "brown").rect(4, 15, 27, 17, "yellow").rect(14, 13, 17, 20, "yellow").rect(6, 12, 7, 27, "gold").rect(24, 12, 25, 27, "gold"); out["chest"] = s.done()
    s = S(16, 16); s.rect(3, 2, 12, 13, "ice").line([(5, 5), (10, 5)], "ink").line([(5, 8), (10, 8)], "ink").line([(5, 11), (8, 11)], "ink"); out["relic"] = s.done(outline="yellow")
    return out


def prop_sprites():
    out = {}
    s = S(); s.rect(15, 14, 16, 29, "bark").rect(11, 6, 20, 15, "yellow").rect(10, 5, 21, 6, "ink").rect(10, 15, 21, 16, "ink").rect(14, 9, 17, 13, "white"); out["forest"] = s.done()
    s = S(); s.rect(15, 14, 16, 28, "gold").rect(8, 27, 23, 29, "gold").rect(7, 14, 24, 15, "gold")
    for x in (8, 15, 22):
        s.rect(x, 8, x + 1, 13, "ice").poly([(x, 7), (x + 1, 3), (x + 2, 7)], "orange")
    out["cathedral"] = s.done()
    s = S(); s.rect(15, 16, 16, 29, "iron").rect(5, 4, 26, 16, "ink").rect(7, 6, 24, 14, "pink").line([(9, 12), (12, 8), (15, 12), (18, 8), (21, 12)], "cyan"); out["neon"] = s.done()
    s = S(); s.rect(15, 14, 16, 27, "gold").rect(11, 27, 20, 29, "gold").poly([(8, 15), (12, 4), (19, 4), (23, 15)], "rose").rect(8, 14, 23, 15, "red"); out["jazz"] = s.done()
    s = S(); s.poly([(6, 14), (25, 14), (21, 24), (10, 24)], "iron").rect(14, 24, 17, 29, "iron").poly([(9, 14), (12, 5), (15, 11), (18, 3), (22, 14)], "orange").poly([(13, 14), (16, 8), (19, 14)], "yellow"); out["volcano"] = s.done()
    s = S(); s.rect(14, 12, 17, 29, "bark").rect(12, 10, 19, 13, "iron").poly([(12, 10), (14, 3), (16, 7), (18, 2), (19, 10)], "orange").poly([(14, 10), (16, 6), (18, 10)], "yellow"); out["castle"] = s.done()
    return out


def obstacle_sprites():
    out = {}
    s = S(48, 48); s.ell(6, 20, 41, 44, "bark").ell(8, 14, 39, 34, "brown").ell(13, 17, 34, 30, "tan").ell(19, 20, 28, 27, "brown").poly([(4, 40), (10, 32), (14, 42)], "bark").poly([(43, 40), (37, 32), (33, 42)], "bark"); out["forest"] = s.done()
    s = S(48, 48); s.rect(12, 6, 35, 42, "gray").rect(8, 2, 39, 8, "silver").rect(8, 40, 39, 46, "silver")
    for x in (17, 23, 29):
        s.line([(x, 9), (x, 39)], "stone")
    out["cathedral"] = s.done()
    s = S(48, 48); s.rect(10, 4, 37, 44, "navy").rect(13, 8, 34, 22, "ink").rect(15, 10, 32, 20, "cyan").rect(13, 26, 34, 32, "purple").ell(16, 27, 20, 31, "pink").rect(26, 28, 31, 30, "lime").rect(13, 36, 34, 40, "ink"); out["neon"] = s.done()
    s = S(48, 48); s.ell(4, 10, 43, 36, "bark").ell(7, 12, 40, 32, "brown").rect(22, 34, 25, 44, "bark").rect(14, 43, 33, 45, "bark").ell(18, 16, 24, 22, "white").rect(28, 18, 30, 26, "cyan"); out["jazz"] = s.done()
    s = S(48, 48); s.poly([(6, 44), (16, 10), (22, 26), (28, 4), (34, 22), (42, 44)], "stone").poly([(16, 44), (22, 30), (28, 18), (32, 44)], "iron").line([(24, 44), (27, 30), (25, 22)], "orange", 2); out["volcano"] = s.done()
    s = S(48, 48); s.rect(12, 34, 35, 45, "gray").rect(16, 30, 31, 34, "silver").ell(16, 4, 31, 19, "silver").rect(18, 18, 29, 31, "silver").rect(10, 20, 17, 23, "silver").rect(30, 20, 37, 23, "silver").rect(36, 8, 37, 22, "tan"); out["castle"] = s.done()
    return out


def shot_sprites():
    out = {}
    s = S(16, 16); s.ell(2, 9, 8, 14, "white").rect(8, 2, 9, 12, "white").poly([(9, 2), (14, 4), (14, 7), (9, 5)], "white"); out["note"] = s.done(shade=False)
    s = S(16, 16); s.ell(1, 9, 6, 14, "white").ell(9, 7, 14, 12, "white").rect(6, 3, 6, 11, "white").rect(14, 1, 14, 9, "white").poly([(6, 3), (14, 1), (14, 3), (6, 5)], "white"); out["note2"] = s.done(shade=False)
    s = S(16, 16); s.ell(1, 1, 14, 14, "ink").ell(3, 3, 12, 12, "swamp").ell(5, 5, 10, 10, "white").px(7, 7, "ink"); out["vinyl"] = s.done(outline="gray", shade=False)
    s = S(16, 16); s.poly([(5, 3), (10, 3), (13, 12), (2, 12)], "tan").rect(6, 1, 9, 3, "gold").rect(2, 11, 13, 12, "gold").rect(7, 13, 8, 14, "ink"); out["bell"] = s.done()
    s = S(16, 16); s.poly([(1, 7), (11, 5), (15, 7), (11, 10)], "white"); out["needle"] = s.done(shade=False)
    s = S(16, 16); s.arc([-6, 0, 12, 15], 300, 60, "white", 3); out["slash"] = s.done(shade=False)
    s = S(16, 16); s.line([(1, 8), (4, 3), (8, 12), (12, 3), (15, 8)], "white", 2); out["wave"] = s.done(shade=False)
    s = S(16, 16); s.rect(5, 2, 10, 14, "tan").rect(5, 4, 10, 5, "gold").rect(6, 9, 9, 12, "ink"); out["pipe"] = s.done()
    s = S(16, 16); s.ell(3, 3, 12, 12, "white"); out["orb"] = s.done(shade=False)
    s = S(16, 16); s.ell(2, 2, 13, 13, "rose").ell(5, 5, 10, 10, "white"); out["ebullet"] = s.done(outline="red", shade=False)
    return out


def misc_icons():
    out = {}
    s = S(); s.rect(8, 14, 23, 27, "gold").arc([10, 4, 21, 20], 180, 360, "silver", 3).rect(14, 18, 17, 23, "ink"); out["lock"] = s.done()
    s = S(); s.poly([(8, 6), (23, 6), (21, 18), (10, 18)], "yellow").rect(14, 18, 17, 24, "gold").rect(10, 24, 21, 27, "gold").arc([3, 6, 11, 16], 90, 270, "yellow", 2).arc([20, 6, 28, 16], 270, 90, "yellow", 2); out["trophy"] = s.done()
    s = S(); s.rect(6, 3, 25, 28, "ice")
    for y in (9, 13, 17, 21):
        s.line([(8, y), (23, y)], "gray")
    s.ell(10, 18, 14, 22, "ink").rect(14, 9, 14, 20, "ink").ell(17, 15, 21, 19, "ink").rect(21, 7, 21, 17, "ink").line([(14, 9), (21, 7)], "ink", 2); out["sheet"] = s.done(outline="gold")
    s = S(); s.rect(13, 6, 18, 9, "gray").rect(16, 9, 18, 15, "gray").rect(13, 15, 16, 19, "gray").rect(13, 23, 16, 26, "gray").rect(11, 6, 13, 10, "gray"); out["unknown"] = s.done()
    s = S(); s.ell(5, 5, 26, 26, "yellow").ell(7, 7, 24, 24, "gold").rect(14, 10, 17, 21, "yellow"); out["gold"] = s.done()
    s = S(); s.poly([(15, 3), (27, 9), (27, 17), (15, 28), (4, 17), (4, 9)], "ice").rect(14, 9, 17, 20, "red").rect(10, 13, 21, 16, "red"); out["revive"] = s.done()
    s = S(); s.arc([5, 5, 26, 26], 30, 330, "cyan", 3).poly([(22, 6), (29, 10), (22, 14)], "cyan"); out["reroll"] = s.done()
    s = S(); s.poly([(6, 6), (16, 15), (6, 25)], "silver").poly([(16, 6), (26, 15), (16, 25)], "silver"); out["skip"] = s.done()
    s = S(); s.arc([4, 4, 27, 27], 0, 360, "red", 3).line([(8, 8), (23, 23)], "red", 3); out["banish"] = s.done()
    s = S(); s.ell(6, 3, 25, 22, "ice").rect(11, 20, 20, 27, "ice").rect(9, 9, 13, 14, "ink").rect(18, 9, 22, 14, "ink").rect(13, 22, 14, 26, "ink").rect(17, 22, 18, 26, "ink"); out["curse"] = s.done()
    s = S(); s.poly([(20, 2), (8, 16), (14, 16), (11, 29), (24, 12), (17, 12)], "yellow"); out["speed"] = s.done()
    s = S(); s.poly([(15, 2), (19, 11), (29, 12), (21, 19), (24, 29), (15, 23), (7, 29), (10, 19), (2, 12), (12, 11)], "yellow"); out["star"] = s.done()
    return out


# --------------------------------------------------------------------------- floors

def floor(name, size=256):
    rnd = np.random.default_rng(abs(hash(name)) % (2 ** 32))
    im = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(im)

    def speck(cols, n, sz=1):
        for _ in range(n):
            x, y = rnd.integers(0, size, 2)
            col = cols[rnd.integers(0, len(cols))]
            d.rectangle([x, y, x + sz - 1, y + sz - 1], fill=col)

    if name == "cathedral":
        d.rectangle([0, 0, size, size], fill=(58, 54, 72))
        t = 32
        for ty in range(size // t):
            for tx in range(size // t):
                col = (66, 62, 84) if (tx + ty) % 2 == 0 else (52, 49, 66)
                d.rectangle([tx * t + 1, ty * t + 1, tx * t + t - 2, ty * t + t - 2], fill=col)
                d.line([tx * t + 1, ty * t + 1, tx * t + t - 2, ty * t + 1], fill=(78, 74, 98))
        speck([(46, 43, 58), (74, 70, 92)], 500)
        for _ in range(10):
            x, y = rnd.integers(8, size - 8, 2)
            d.line([x, y, x + rnd.integers(-6, 6), y + rnd.integers(3, 9)], fill=(40, 38, 52))
    elif name == "neon":
        d.rectangle([0, 0, size, size], fill=(24, 20, 44))
        speck([(30, 26, 54), (20, 17, 38)], 900)
        for i in range(0, size, 64):
            d.line([i, 0, i, size], fill=(172, 50, 140), width=1)
            d.line([0, i, size, i], fill=(55, 150, 190), width=1)
        for i in range(32, size, 64):
            d.line([i, 0, i, size], fill=(48, 34, 78), width=1)
            d.line([0, i, size, i], fill=(34, 44, 84), width=1)
    elif name == "jazz":
        d.rectangle([0, 0, size, size], fill=(94, 58, 44))
        pw, ph = 32, 8
        for row in range(size // ph):
            off = (row % 2) * (pw // 2)
            for col in range(-1, size // pw + 1):
                x = col * pw + off
                shade = int(rnd.integers(-8, 8))
                d.rectangle([x, row * ph, x + pw - 2, row * ph + ph - 2], fill=(104 + shade, 64 + shade, 48 + shade))
        speck([(84, 50, 38), (116, 74, 54)], 400)
    elif name == "volcano":
        d.rectangle([0, 0, size, size], fill=(44, 34, 40))
        speck([(54, 42, 48), (36, 28, 34), (62, 48, 52)], 1600, 2)
        for _ in range(9):
            x, y = (int(v) for v in rnd.integers(0, size, 2))
            for _ in range(int(rnd.integers(5, 12))):
                nx, ny = x + int(rnd.integers(-9, 10)), y + int(rnd.integers(-9, 10))
                for ox in (-size, 0, size):
                    for oy in (-size, 0, size):
                        d.line([x + ox, y + oy, nx + ox, ny + oy], fill=(200, 90, 36), width=2)
                        d.line([x + ox, y + oy, nx + ox, ny + oy], fill=(250, 190, 60), width=1)
                x, y = nx % size, ny % size
    elif name == "castle":
        d.rectangle([0, 0, size, size], fill=(60, 66, 84))
        for ty in range(0, size, 16):
            off = (ty // 16 % 2) * 12
            for tx in range(-24, size, 24):
                shade = int(rnd.integers(-6, 7))
                d.rounded_rectangle([tx + off + 1, ty + 1, tx + off + 22, ty + 14], radius=3, fill=(78 + shade, 86 + shade, 108 + shade))
        speck([(92, 100, 124), (56, 62, 80)], 500)
    else:
        d.rectangle([0, 0, size, size], fill=(40, 96, 70))
    return im


# --------------------------------------------------------------------------- build

def load_existing():
    def ld(path, n, prefix):
        frames = []
        for i in range(n):
            frames.append(Image.open(os.path.join(ROOT, path % i)).convert("RGBA"))
        return frames
    frog = ld("assets/player/Froguitar/frog%03d.png", 7, "frog")
    for i, f in enumerate(frog):
        put("char_froguitar_%d" % i, f)
    note = ld("assets/enemy/Noteguy/noteguy%03d.png", 4, "note")
    put("en_noteguy_0", note[0]); put("en_noteguy_1", note[2])
    put("en_noteguy_f0", flash(note[0])); put("en_noteguy_f1", flash(note[2]))
    lemon = ld("assets/weapon/attack%03d.png", 4, "lemon")
    put("shot_lemon", lemon[0])
    coin = Image.open(os.path.join(ROOT, "assets/world/coin.webp")).convert("RGBA")
    return coin


def build():
    os.makedirs(OUT, exist_ok=True)
    load_existing()
    singles = {
        "ghoul": en_ghoul, "imp": en_imp, "wraith": en_wraith, "specter": en_specter,
        "record": en_record, "shard": en_shard, "cassette": en_cassette, "speaker": en_speaker,
        "snake": en_snake, "slime": en_slime, "boombox": en_boombox, "crab": en_crab,
        "diva": en_diva, "beetle": en_beetle, "rghost": en_rghost, "ember": en_ember,
        "knight": en_knight, "gargoyle": en_gargoyle, "moss": en_moss, "cultist": en_cultist,
        "tick": en_tick, "shroom": en_shroom, "grub": en_grub, "troll": en_troll,
        "spider": en_spider, "headbanger": en_headbanger, "glitch": en_glitch, "wisp": en_wisp,
        "bully": en_bully, "shade": en_shade, "dummy": en_dummy,
    }
    for name, fn in singles.items():
        put_enemy("en_" + name, fn())
    for name, fn in {"bat": en_bat, "gnome": en_gnome, "wasp": en_wasp, "static": en_static, "moth": en_moth}.items():
        a, b = fn()
        put_enemy("en_" + name, a, b)
    for name, fn in {"tapeworm": boss_tapeworm, "organist": boss_organist, "dj": boss_dj, "scat": boss_scat,
                     "shredder": boss_shredder, "conductor": boss_conductor}.items():
        put_enemy("boss_" + name, fn(), big=True)

    chars = {
        "drumadillo": ("gray", "tan", "tan", "top", "long", shell, "sticks"),
        "bassbear": ("bark", "tan", "bark", "round", "muzzle", None, "bass"),
        "violynx": ("tan", "skin", "tan", "pointy", "muzzle", None, "violin"),
        "trumpelephant": ("silver", "ice", "silver", "big", "trunk", None, "horn"),
        "pianowl": ("brown", "skin", "brown", "tuft", "beak", None, "keys"),
        "harphare": ("ice", "white", "ice", "long", "muzzle", None, "harp"),
        "synthfox": ("orange", "white", "orange", "pointy", "muzzle", shades, "synth"),
        "djgecko": ("lime", "yellow", "lime", "top", "wide", headphones, "deck"),
        "choircrow": ("navy", "purple", "navy", "crest", "beak", None, "book"),
        "mime": ("white", "ice", "white", "none", "wide", lambda s: (stripes(s), hat_beret(s)), "antenna"),
        "lofisloth": ("khaki", "tan", "tan", "none", "mask", hat_beanie, "bell"),
    }
    for name, (body, belly, head, ear, snout, extra, tool) in chars.items():
        for i, f in enumerate(character(body, belly, head, ear, snout, extra, tool)):
            put("char_%s_%d" % (name, i), f)

    icons = {
        "drums": ico_drums, "guitar": ico_guitar, "bass": ico_bass, "violin": ico_violin,
        "trumpet": ico_trumpet, "piano": ico_piano, "harp": ico_harp, "synth": ico_synth,
        "cello": ico_cello, "flute": ico_flute, "choir": ico_choir, "turntable": ico_turntable,
        "triangle": ico_triangle, "organ": ico_organ, "theremin": ico_theremin, "cowbell": ico_cowbell,
        "kazoo": ico_kazoo,
    }
    star = misc_icons()["star"].resize((12, 12), Image.NEAREST)
    for name, fn in icons.items():
        base = fn()
        put("ico_" + name, base)
        evo = tint(base, (1.15, 1.0, 0.55), (40, 30, 0))
        outline_pass(evo, c("yellow"))
        evo.alpha_composite(star, (20, 0))
        put("ico_" + name + "_evo", evo)
    for name, im in passive_icons().items():
        put("ico_" + name, im)
    for name, im in pickup_icons().items():
        put("pk_" + name, im)
    for name, im in prop_sprites().items():
        put("prop_" + name, im)
    for name, im in obstacle_sprites().items():
        put("obs_" + name, im)
    for name, im in shot_sprites().items():
        put("shot_" + name, im)
    for name, im in misc_icons().items():
        put("ui_" + name, im)

    # Shelf packing.
    width = 1024
    x = y = row_h = 0
    pos = {}
    for name in sorted(SPR, key=lambda n: (-SPR[n].size[1], n)):
        w, h = SPR[name].size
        if x + w + 1 > width:
            x = 0
            y += row_h + 1
            row_h = 0
        pos[name] = (x, y, w, h)
        x += w + 1
        row_h = max(row_h, h)
    height = 1
    while height < y + row_h + 1:
        height *= 2
    atlas = Image.new("RGBA", (width, height), T)
    for name, (px_, py_, w, h) in pos.items():
        atlas.paste(SPR[name], (px_, py_))
    atlas.save(os.path.join(OUT, "atlas.png"))
    with open(os.path.join(OUT, "atlas.json"), "w") as fh:
        json.dump({k: list(v) for k, v in sorted(pos.items())}, fh, indent=0)
    for name in ("cathedral", "neon", "jazz", "volcano", "castle"):
        floor(name).save(os.path.join(OUT, "floor_%s.png" % name))
    print("atlas %dx%d, %d sprites" % (width, height, len(pos)))


if __name__ == "__main__":
    random.seed(1)
    build()
