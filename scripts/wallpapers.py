#!/usr/bin/env python3
"""Draw the Hermes wallpapers into brand/wallpapers/ (desktop 5120x2880, phone 1320x2868), dressed like the landing:
the blue band, Giambologna's Mercury as a halftone mask in scanlines, film grain, a thin frame, tiny caps.
  python3 scripts/wallpapers.py"""
import io, subprocess
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "brand" / "wallpapers"
FONTS = ROOT / "fonts"
BAND, ART, SUB = (8, 71, 196), (169, 194, 247), (214, 224, 250)   # tokens.css: --band, --band-art, --band-sub


def scan_mask(size, period):
    """The landing's --scan: half of every line period dark, so the engraving sits in scanlines."""
    W, H = size
    col = Image.new("L", (1, H)); col.putdata([0 if y % period >= period // 2 else 255 for y in range(H)])
    return col.resize((W, H), Image.NEAREST)


def grain(img, amount=.07):
    """White film grain over the blue, like the landing's fractal noise."""
    W, H = img.size
    n = Image.effect_noise((W // 2, H // 2), 60).resize((W, H), Image.NEAREST)
    white = Image.new("RGBA", (W, H), (255, 255, 255, 0)); white.putalpha(n.point(lambda v: int(max(0, v - 128) * amount * 2)))
    img.alpha_composite(white); return img


def mark_png(px):
    svg = (ROOT / "brand" / "mark.svg").read_text().replace("currentColor", "#fff").replace('color="inherit"', "")
    png = subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), "-"], input=svg.encode(), capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA")


def caps(d, xy, text, size, fill, track=.22, weight="Medium"):
    f = ImageFont.truetype(str(FONTS / f"HermesSans-{weight}.ttf"), size); x, y = xy
    for ch in text:   # tiny caps with wide tracking, the Nous label
        d.text((x, y), ch, font=f, fill=fill); x += f.getlength(ch) + size * track
    return x


def wallpaper(kind):
    W, H = (5120, 2880) if kind == "desktop" else (1320, 2868)
    img = Image.new("RGBA", (W, H), BAND + (255,))
    art = Image.open(ROOT / "landing" / "art" / "giambologna.png").convert("LA").split()[1]
    if kind == "desktop":
        s = H * .97 / art.height; cx = W * .7; lift = -int(H * .02)   # statue centre sits at x 915 of 1800 in the source
    else:
        s = H * .8 / art.height; cx = W * .52; lift = int(H * .15)
    art = art.resize((int(art.width * s), int(art.height * s)), Image.LANCZOS)
    ox, oy = int(cx - 915 * s), H - art.height - lift
    layer = Image.new("L", (W, H)); layer.paste(art, (ox, oy))
    layer = ImageChops.multiply(layer, scan_mask((W, H), 6 if kind == "desktop" else 4))
    tint = Image.new("RGBA", (W, H), ART + (0,)); tint.putalpha(layer)
    img.alpha_composite(tint)
    grain(img)
    d = ImageDraw.Draw(img)
    u = W / 5120 if kind == "desktop" else W / 1320 * .45   # one unit of the desktop layout
    m = int(64 * u) if kind == "desktop" else 40
    d.rectangle([m, m, W - 1 - m, H - 1 - m], outline=ART + (110,), width=max(2, int(3 * u)))
    if kind == "desktop":
        left, base, big, small, mk = 220, H - 300, 420, 44, 200
    else:
        left, base, big, small, mk = 92, H - 300, 210, 26, 120
    f = ImageFont.truetype(str(FONTS / "HermesSans-Bold.ttf"), big)
    d.text((left - big * .06, base - big), "Hermes", font=f, fill=(255, 255, 255, 255))
    caps(d, (left, base - big - small * 2.6), "MESSENGER OF THE GODS", small, SUB + (255,))
    img.alpha_composite(mark_png(mk), (int(left - mk * .12), int(base - big - small * 2.6 - mk - small * 1.2)))
    caps(d, (left, base + small * 1.4), "APP STORE CONNECT, ON YOUR MAC", small, SUB + (200,))
    cred = "GIAMBOLOGNA, MERCURY, 1580. PUBLIC DOMAIN"
    cs = int(small * .7); fw = caps(ImageDraw.Draw(Image.new("RGBA", (1, 1))), (0, 0), cred, cs, SUB)
    caps(d, (W - m - int(48 * u if kind == "desktop" else 28) - fw, H - m - int(48 * u if kind == "desktop" else 28) - cs), cred, cs, SUB + (150,))
    return img.convert("RGB")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in ("desktop", "phone"):
        wallpaper(kind).save(OUT / f"hermes-{kind}.png", optimize=True)
    print("\n".join(str(p) for p in sorted(OUT.glob("*.png"))))
