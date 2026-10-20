# Draws the Hermes wing: three fanned rows of feathers cut apart by thin gaps, white on a clrs.cc blue tile.
# Writes Hermes.icon/Assets/glyph.png, icon.svg, brand/icon-1024.png and brand/mark.svg. Run from the repo root.
import math, subprocess, sys
LIGHT, DEEP = '#0074D9', '#004C8F'   # clrs.cc BLUE, deepening toward NAVY
ROOT = (300, 520)

def feather(angle, length, width, tip=0.55, root=None):
    PX, PY = root or ROOT
    a = math.radians(angle); ca, sa = math.cos(a), math.sin(a)
    def p(x, y): return f'{PX + x * ca - y * sa:.1f} {PY - (x * sa + y * ca):.1f}'
    w = width / 2; k = length * tip
    return (f'M{p(0, -w * .6)} C{p(k * .5, -w)} {p(k, -w)} {p(length * .86, -w * .7)} '
            f'C{p(length * .97, -w * .45)} {p(length, -w * .1)} {p(length, 0)} '
            f'C{p(length, w * .25)} {p(length * .95, w * .6)} {p(length * .84, w * .8)} '
            f'C{p(k, w)} {p(k * .5, w)} {p(0, w * .6)} Z')

# Feathers hang from a curved leading edge, longest at the top, so it reads as a wing and not a fan.
roots = [(318, 318), (292, 398), (280, 478), (282, 558), (298, 638), (326, 716)]
angles = [30, 22, 14, 6, -2, -10]
lengths = [600, 565, 520, 460, 390, 310]
shapes = [feather(a, l, 104, root=r) for r, a, l in zip(roots, angles, lengths)][::-1]
shapes += [feather(a + 4, l * .42, 112, root=r) for r, a, l in zip(roots, angles, lengths)][::-1]
edge = 'M312 318 C248 430 246 620 320 716'
mask = ''.join(f'<path d="{d}" fill="#fff" stroke="#000" stroke-width="16" stroke-linejoin="round"/>' for d in shapes)
quills = ''
mask += f'<path d="{edge}" fill="none" stroke="#000" stroke-width="132" stroke-linecap="round" stroke-linejoin="round"/><path d="{edge}" fill="none" stroke="#fff" stroke-width="100" stroke-linecap="round" stroke-linejoin="round"/>'
glyph = (f'<defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><rect width="1024" height="1024" fill="#000"/>{mask}{quills}</mask></defs>'
         f'<g transform="translate(512 512) scale(.8) translate(-470 -500)"><rect width="1024" height="1024" fill="#fff" mask="url(#m)"/></g>')
NS = 'xmlns="http://www.w3.org/2000/svg"'
def tile(size, rx): return (f'<svg {NS} width="{size}" height="{size}" viewBox="0 0 1024 1024"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">'
                            f'<stop offset="0" stop-color="{LIGHT}"/><stop offset="1" stop-color="{DEEP}"/></linearGradient></defs>'
                            f'<rect width="1024" height="1024" rx="{rx}" fill="url(#g)"/>{glyph}</svg>\n')
out = sys.argv[1] if len(sys.argv) > 1 else '.'
open(f'{out}/icon.svg', 'w').write(tile(200, 224))
open(f'{out}/favicon.svg', 'w').write(tile(64, 224))
open(f'{out}/brand/mark.svg', 'w').write(f'<svg {NS} viewBox="0 0 1024 1024">{glyph}</svg>\n')
open('/tmp/hermes-glyph.svg', 'w').write(f'<svg {NS} width="1024" height="1024" viewBox="0 0 1024 1024">{glyph}</svg>\n')
open('/tmp/hermes-tile.svg', 'w').write(tile(1024, 0))
subprocess.run(['rsvg-convert', '-w', '1024', '-h', '1024', '/tmp/hermes-glyph.svg', '-o', f'{out}/Hermes.icon/Assets/glyph.png'], check=True)
subprocess.run(['rsvg-convert', '-w', '1024', '-h', '1024', '/tmp/hermes-tile.svg', '-o', f'{out}/brand/icon-1024.png'], check=True)
subprocess.run(['magick', f'{out}/brand/icon-1024.png', '-background', DEEP, '-alpha', 'remove', '-alpha', 'off', f'{out}/brand/icon-1024.png'], check=True)
