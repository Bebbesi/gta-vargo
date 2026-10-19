"""Genera l'icona dell'app (icon.png, 512x512) senza asset esterni."""
import sys
from PIL import Image, ImageDraw, ImageFont

S = 512
out = sys.argv[1] if len(sys.argv) > 1 else "icon.png"
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bg = Image.new("RGBA", (S, S))
px = bg.load()
for y in range(S):
    t = y / (S - 1)
    r = int(40 + (235 - 40) * t ** 1.4)
    g = int(20 + (110 - 20) * t ** 1.6)
    b = int(70 + (40 - 70) * t)
    for x in range(S):
        px[x, y] = (r, g, b, 255)
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, S - 1, S - 1), radius=96, fill=255)
img.paste(bg, (0, 0), mask)
d = ImageDraw.Draw(img)
# skyline
import random
random.seed(7)
x = 20
while x < S - 20:
    w = random.randint(28, 58)
    h = random.randint(70, 190)
    d.rectangle((x, S - 70 - h, x + w, S - 70), fill=(25, 18, 40, 255))
    x += w + random.randint(4, 12)
d.rectangle((16, S - 72, S - 16, S - 40), fill=(25, 18, 40, 255))
font_path = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
try:
    big = ImageFont.truetype(font_path, 112)
    small = ImageFont.truetype(font_path, 50)
    ini = ImageFont.truetype(font_path, 60)
except OSError:
    big = small = ini = ImageFont.load_default()
def center_text(y, text, font, fill, stroke=8):
    w = d.textlength(text, font=font)
    d.text(((S - w) / 2, y), text, font=font, fill=fill, stroke_width=stroke, stroke_fill=(10, 8, 15, 255))
center_text(52, "APRILIA", big, (255, 190, 50, 255), 8)
center_text(206, "SIMULATOR 2026", small, (255, 255, 255, 255), 5)
for i, (col, letter) in enumerate([((235, 77, 56), "M"), ((77, 153, 242), "T"), ((115, 204, 89), "N")]):
    cx = S / 2 + (i - 1) * 120
    cy = 360
    d.ellipse((cx - 50, cy - 50, cx + 50, cy + 50), fill=(10, 8, 15, 255))
    d.ellipse((cx - 44, cy - 44, cx + 44, cy + 44), fill=col + (255,))
    w = d.textlength(letter, font=ini)
    d.text((cx - w / 2, cy - 38), letter, font=ini, fill=(255, 255, 255, 255), stroke_width=4, stroke_fill=(10, 8, 15, 255))
img.save(out)
print("icona salvata in", out)
