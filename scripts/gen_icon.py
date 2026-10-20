# Draws the Hermes wing: feathers hung from a curved leading edge, cut apart by thin gaps, white on a clrs.cc blue tile.
# Writes Hermes.icon/Assets/glyph.png, icon.svg, favicon.svg, favicon-32.png, apple-touch-icon.png,
# brand/icon-1024.png, brand/icon-tile.svg and brand/mark.svg. Run from the repo root.
import math, re, subprocess, tempfile

tokens = open('brand/tokens.css').read()
LIGHT, DEEP = (re.search(rf'--accent-{k}: (#[0-9A-Fa-f]{{6}})', tokens).group(1) for k in ('light', 'deep'))
NS = 'xmlns="http://www.w3.org/2000/svg"'

def feather(root, angle, length, width):
    rx, ry = root; a = math.radians(angle); ca, sa = math.cos(a), math.sin(a)
    def p(x, y): return f'{rx + x * ca - y * sa:.1f} {ry - (x * sa + y * ca):.1f}'
    w = width / 2; k = length * .55
    return (f'M{p(0, -w * .6)} C{p(k * .5, -w)} {p(k, -w)} {p(length * .86, -w * .7)} '
            f'C{p(length * .97, -w * .45)} {p(length, -w * .1)} {p(length, 0)} '
            f'C{p(length, w * .25)} {p(length * .95, w * .6)} {p(length * .84, w * .8)} '
            f'C{p(k, w)} {p(k * .5, w)} {p(0, w * .6)} Z')

# Longest at the top, so it reads as a wing and not a fan.
roots = [(318, 318), (292, 398), (280, 478), (282, 558), (298, 638), (326, 716)]
angles = [30, 22, 14, 6, -2, -10]
lengths = [600, 565, 520, 460, 390, 310]
EDGE = 'M312 318 C248 430 246 620 320 716'

def glyph(fill='#fff', small=False):
    """small: the 16 to 32 px cut, four thick primaries and no coverts, so the gaps survive."""
    rows = [(r, a, l) for i, (r, a, l) in enumerate(zip(roots, angles, lengths)) if not small or i % 2 == 0 or i == 5]
    shapes = [feather(r, a, l, 150 if small else 104) for r, a, l in rows][::-1]
    if not small: shapes += [feather(r, a + 4, l * .42, 112) for r, a, l in rows][::-1]
    gap = 34 if small else 16
    mask = ''.join(f'<path d="{d}" fill="#fff" stroke="#000" stroke-width="{gap}" stroke-linejoin="round"/>' for d in shapes)
    mask += (f'<path d="{EDGE}" fill="none" stroke="#000" stroke-width="{100 + 2 * gap}" stroke-linecap="round"/>'
             f'<path d="{EDGE}" fill="none" stroke="#fff" stroke-width="{120 if small else 100}" stroke-linecap="round"/>')
    mid = 'ms' if small else 'm'
    return (f'<defs><mask id="{mid}" maskUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><rect width="1024" height="1024" fill="#000"/>{mask}</mask></defs>'
            f'<g transform="translate(512 512) scale(.8) translate(-470 -500)"><rect width="1024" height="1024" fill="{fill}" mask="url(#{mid})"/></g>')

def tile(size, rx, small=False):
    return (f'<svg {NS} width="{size}" height="{size}" viewBox="0 0 1024 1024"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{LIGHT}"/><stop offset="1" stop-color="{DEEP}"/></linearGradient></defs>'
            f'<rect width="1024" height="1024" rx="{rx}" fill="url(#g)"/>{glyph(small=small)}</svg>\n')

def png(svg, out, size):
    with tempfile.NamedTemporaryFile('w', suffix='.svg') as f:
        f.write(svg); f.flush()
        subprocess.run(['rsvg-convert', '-w', str(size), '-h', str(size), f.name, '-o', out], check=True)

open('icon.svg', 'w').write(tile(200, 224))
open('favicon.svg', 'w').write(tile(64, 224, small=True))
open('brand/icon-tile.svg', 'w').write(tile(1024, 0))
open('brand/mark.svg', 'w').write(f'<svg {NS} viewBox="0 0 1024 1024" color="inherit">{glyph("currentColor")}</svg>\n')
png(f'<svg {NS} width="1024" height="1024" viewBox="0 0 1024 1024">{glyph()}</svg>', 'Hermes.icon/Assets/glyph.png', 1024)
png(tile(1024, 0), 'brand/icon-1024.png', 1024)
subprocess.run(['magick', 'brand/icon-1024.png', '-background', DEEP, '-alpha', 'remove', '-alpha', 'off', 'brand/icon-1024.png'], check=True)
png(tile(1024, 224, small=True), 'favicon-32.png', 32)
png(tile(1024, 0), 'apple-touch-icon.png', 180)
