"""Hermes Sans: Inter (Rasmus Andersson, SIL Open Font License 1.1, no reserved name), renamed, with its curly
quote marks redrawn as feathers from the Hermes wing, so every quote in the app wears the mark.
Inter is drawn in the spirit of San Francisco and Helvetica: open shapes, even proportional spacing, built for screens.

Same method as coda's Quip Sans and turing's Samantha Sans: pinned release, renamed, OFL shipped beside the fonts,
original copyright kept in the name table, fixed timestamps so every build is the same bytes.

    python3 scripts/gen_font.py            # writes fonts/HermesSans-{Regular,Medium,Semibold,Bold}.{ttf,woff2} + OFL.txt
    python3 scripts/gen_font.py --check    # named Hermes Sans, OFL present, original copyright kept
Needs fonttools and brotli (uv run --with fonttools --with brotli).
"""
import io
import os
import sys
import urllib.request

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "fonts")
SOURCE = "https://cdn.jsdelivr.net/npm/@fontsource/inter@5.2.5/"
WEIGHTS = {"Regular": 400, "Medium": 500, "Semibold": 600, "Bold": 700}


def fetch(path):
    """Bytes of one file from the pinned Inter release."""
    with urllib.request.urlopen(SOURCE + path, timeout=60) as r:
        return r.read()


QUOTES = {"quoteright": 1, "quotedblright": 2, "quoteleft": 1, "quotedblleft": 2}


def feather(pen, x0, y0, w, h):
    """One feather: a crescent that sweeps from the bottom left to a tip at the top right, like a stroke of the wing."""
    pen.moveTo((x0 + 0.05 * w, y0 + 0.12 * h))
    pen.curveTo((x0 + 0.10 * w, y0 + 0.70 * h), (x0 + 0.45 * w, y0 + h), (x0 + w, y0 + h))
    pen.curveTo((x0 + 0.62 * w, y0 + 0.72 * h), (x0 + 0.40 * w, y0 + 0.45 * h), (x0 + 0.32 * w, y0))
    pen.closePath()


def redraw_quotes(font):
    """Replace the four curly quotes with feathers inside each original's box, so spacing never moves."""
    glyphs = font.getGlyphSet()
    glyf, hmtx, cmap = font["glyf"], font["hmtx"], font.getBestCmap()
    names = {cmap[0x2019]: 1, cmap[0x201D]: 2, cmap[0x2018]: 1, cmap[0x201C]: 2}
    for name, count in names.items():
        bp = BoundsPen(glyphs)
        glyphs[name].draw(bp)
        x0, y0, x1, y1 = bp.bounds
        gap = 0.12 * (x1 - x0) if count == 2 else 0
        w = (x1 - x0 - gap) / count
        tt = TTGlyphPen(None)
        pen = Cu2QuPen(tt, max_err=1.0)
        if name in (cmap[0x2019], cmap[0x201D]):   # closing marks are the opening feathers turned 180 degrees
            pen = TransformPen(pen, (-1, 0, 0, -1, x0 + x1, y0 + y1))
        for i in range(count):
            feather(pen, x0 + i * (w + gap), y0, w, y1 - y0)
        glyf[name] = tt.glyph()
        glyf[name].recalcBounds(glyf)
        hmtx[name] = (hmtx[name][0], glyf[name].xMin)


def rename(font, style):
    """Give the outlines the Hermes Sans name; copyright (0) and license (13, 14) stay as the authors wrote them."""
    names = {1: "Hermes Sans", 2: style, 3: f"HermesSans-{style}", 4: f"Hermes Sans {style}", 5: "Version 1.000",
             6: f"HermesSans-{style}", 16: "Hermes Sans", 17: style}
    table = font["name"]
    table.names = [n for n in table.names if n.nameID in (0, 13, 14)]
    for nid, text in names.items():
        table.setName(text, nid, 3, 1, 0x409)
        table.setName(text, nid, 1, 0, 0)
    font["head"].created = font["head"].modified = 3_700_000_000
    font["OS/2"].achVendID = "HRMS"


def check():
    """Self-check of the shipped files."""
    assert os.path.exists(os.path.join(OUT, "OFL.txt")), "the OFL must ship with the fonts"
    for style in WEIGHTS:
        for ext in ("ttf", "woff2"):
            f = TTFont(os.path.join(OUT, f"HermesSans-{style}.{ext}"))
            assert f["name"].getDebugName(1) == "Hermes Sans", "family name"
            assert f["name"].getDebugName(6) == f"HermesSans-{style}", "postscript name"
            assert f["name"].getDebugName(0), "the original copyright must stay in the name table"
            cmap, hmtx, glyf = f.getBestCmap(), f["hmtx"], f["glyf"]
            for cp, n in ((0x2019, 1), (0x201D, 2), (0x2018, 1), (0x201C, 2)):
                g = glyf[cmap[cp]]
                assert g.numberOfContours == n, f"U+{cp:04X} is not the feather"
                assert 0 <= g.xMin and g.xMax <= hmtx[cmap[cp]][0], f"U+{cp:04X} spills out of its advance"
    print(f"font ok: Hermes Sans (Inter, OFL), {len(WEIGHTS)} weights, quotes are feathers")


def main():
    if "--check" in sys.argv:
        return check()
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "OFL.txt"), "wb") as f:
        f.write(fetch("LICENSE"))
    for style, weight in WEIGHTS.items():
        font = TTFont(io.BytesIO(fetch(f"files/inter-latin-{weight}-normal.woff2")))
        redraw_quotes(font)
        rename(font, style)
        for ext, flavor in (("ttf", None), ("woff2", "woff2")):
            font.flavor = flavor
            font.save(os.path.join(OUT, f"HermesSans-{style}.{ext}"), reorderTables=False)
        print(f"HermesSans-{style}: Inter {weight}")


if __name__ == "__main__":
    main()
