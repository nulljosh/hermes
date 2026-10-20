"""Talaria Sans: Instrument Sans (Google Fonts, SIL Open Font License 1.1, no reserved name), renamed.

Same method as coda's Quip Sans and turing's Samantha Sans: pinned release, renamed, OFL shipped beside the fonts,
original copyright kept in the name table, fixed timestamps so every build is the same bytes.

    python3 scripts/gen_font.py            # writes fonts/TalariaSans-{Regular,Medium,Semibold,Bold}.{ttf,woff2} + OFL.txt
    python3 scripts/gen_font.py --check    # named Talaria Sans, OFL present, original copyright kept
Needs fonttools and brotli (uv run --with fonttools --with brotli).
"""
import io
import os
import sys
import urllib.request

from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "fonts")
SOURCE = "https://cdn.jsdelivr.net/npm/@fontsource/instrument-sans@5.2.5/"
WEIGHTS = {"Regular": 400, "Medium": 500, "Semibold": 600, "Bold": 700}


def fetch(path):
    """Bytes of one file from the pinned Instrument Sans release."""
    with urllib.request.urlopen(SOURCE + path, timeout=60) as r:
        return r.read()


def rename(font, style):
    """Give the outlines the Talaria Sans name; copyright (0) and license (13, 14) stay as the authors wrote them."""
    names = {1: "Talaria Sans", 2: style, 3: f"TalariaSans-{style}", 4: f"Talaria Sans {style}", 5: "Version 1.000",
             6: f"TalariaSans-{style}", 16: "Talaria Sans", 17: style}
    table = font["name"]
    table.names = [n for n in table.names if n.nameID in (0, 13, 14)]
    for nid, text in names.items():
        table.setName(text, nid, 3, 1, 0x409)
        table.setName(text, nid, 1, 0, 0)
    font["head"].created = font["head"].modified = 3_700_000_000
    font["OS/2"].achVendID = "TLRA"


def check():
    """Self-check of the shipped files."""
    assert os.path.exists(os.path.join(OUT, "OFL.txt")), "the OFL must ship with the fonts"
    for style in WEIGHTS:
        for ext in ("ttf", "woff2"):
            f = TTFont(os.path.join(OUT, f"TalariaSans-{style}.{ext}"))
            assert f["name"].getDebugName(1) == "Talaria Sans", "family name"
            assert f["name"].getDebugName(6) == f"TalariaSans-{style}", "postscript name"
            assert f["name"].getDebugName(0), "the original copyright must stay in the name table"
    print(f"font ok: Talaria Sans (Instrument Sans, OFL), {len(WEIGHTS)} weights")


def main():
    if "--check" in sys.argv:
        return check()
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "OFL.txt"), "wb") as f:
        f.write(fetch("LICENSE"))
    for style, weight in WEIGHTS.items():
        font = TTFont(io.BytesIO(fetch(f"files/instrument-sans-latin-{weight}-normal.woff2")))
        rename(font, style)
        for ext, flavor in (("ttf", None), ("woff2", "woff2")):
            font.flavor = flavor
            font.save(os.path.join(OUT, f"TalariaSans-{style}.{ext}"), reorderTables=False)
        print(f"TalariaSans-{style}: Instrument Sans {weight}")


if __name__ == "__main__":
    main()
