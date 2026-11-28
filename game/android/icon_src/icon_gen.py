# Makes Sol's app icon SVGs (432 x 432, Android's adaptive icon size):
#   python3 game/android/icon_gen.py game/android
# writes icon_src.svg (whole icon), icon_bg.svg / icon_fg.svg (adaptive
# layers) and icon_mono.svg (Android 13 themed icon). The PNGs are rendered
# from these by Godot (see the commit that added this file).
# The adaptive mask keeps about the central circle 72..360, so the sun and
# the tower sit inside it; the sky and skyline run to the edges.
import os
import random
import sys

W = 432
SUN = (256, 176, 92)

DEFS = '''<defs>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#05403F"/><stop offset="0.55" stop-color="#0A2E30"/><stop offset="1" stop-color="#021819"/></linearGradient>
<radialGradient id="glow" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FF3A1F" stop-opacity="0.55"/><stop offset="0.55" stop-color="#FF2A14" stop-opacity="0.18"/><stop offset="1" stop-color="#FF1A0F" stop-opacity="0"/></radialGradient>
<linearGradient id="sun" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FF4A2A"/><stop offset="1" stop-color="#E8120A"/></linearGradient>
<linearGradient id="haze" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2E6B66" stop-opacity="0"/><stop offset="1" stop-color="#2E6B66" stop-opacity="0.35"/></linearGradient>
<linearGradient id="face" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#031A1B"/><stop offset="1" stop-color="#011012"/></linearGradient>
</defs>'''


def background():
    s = f'<rect width="{W}" height="{W}" fill="url(#sky)"/>'
    rnd = random.Random(7)
    for _ in range(14):   # a few faint stars high up
        x, y = rnd.uniform(20, 412), rnd.uniform(18, 150)
        s += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rnd.uniform(0.8, 1.6):.1f}" fill="#BFE3DD" opacity="{rnd.uniform(0.25, 0.55):.2f}"/>'
    s += f'<rect y="230" width="{W}" height="202" fill="url(#haze)"/>'
    return s


def sun():
    cx, cy, r = SUN
    s = f'<circle cx="{cx}" cy="{cy}" r="{r * 1.75:.0f}" fill="url(#glow)"/>'
    s += f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#sun)"/>'
    return s


def skyline():
    rnd = random.Random(11)
    s = ''
    x = -6.0
    while x < W:   # far row
        w = rnd.uniform(18, 34)
        h = rnd.uniform(40, 95)
        s += f'<rect x="{x:.1f}" y="{330 - h:.1f}" width="{w:.1f}" height="{h + 120:.1f}" fill="#0F3B3B"/>'
        x += w + rnd.uniform(1, 4)
    x = -4.0
    while x < W:   # near row, darker, a few lit windows
        w = rnd.uniform(22, 40)
        h = rnd.uniform(28, 70)
        s += f'<rect x="{x:.1f}" y="{352 - h:.1f}" width="{w:.1f}" height="{h + 100:.1f}" fill="#06292A"/>'
        for _ in range(2):
            if rnd.random() < 0.45:
                wx = x + rnd.uniform(4, w - 8)
                wy = 352 - h + rnd.uniform(8, h - 6)
                s += f'<rect x="{wx:.1f}" y="{wy:.1f}" width="4" height="3" fill="#FF4A2A" opacity="0.7"/>'
        x += w + rnd.uniform(0, 3)
    s += f'<rect y="352" width="{W}" height="2" fill="#FF3A1F" opacity="0.28"/>'   # horizon
    return s


def tower():
    x0, top, w = 128, 150, 112
    s = ''
    # Roof: plant room, water tank on legs, antenna with a red beacon.
    s += f'<rect x="{x0 + 14}" y="{top - 16}" width="30" height="16" fill="#011213"/>'
    s += f'<rect x="{x0 + 56}" y="{top - 20}" width="20" height="12" fill="#011213"/>'
    s += f'<rect x="{x0 + 59}" y="{top - 8}" width="2.5" height="8" fill="#011213"/><rect x="{x0 + 70}" y="{top - 8}" width="2.5" height="8" fill="#011213"/>'
    s += f'<rect x="{x0 + 28}" y="{top - 44}" width="3.5" height="30" fill="#011213"/>'
    s += f'<rect x="{x0 + 22}" y="{top - 34}" width="16" height="2.5" fill="#011213"/>'
    s += f'<circle cx="{x0 + 29.7}" cy="{top - 46}" r="8" fill="#FF3A1F" opacity="0.25"/><circle cx="{x0 + 29.7}" cy="{top - 46}" r="4" fill="#FF3A1F"/>'
    # Body, ledge and the shaded side.
    s += f'<rect x="{x0 - 4}" y="{top}" width="{w + 8}" height="6" fill="#011012"/>'
    s += f'<rect x="{x0}" y="{top}" width="{w}" height="{W - top}" fill="url(#face)"/>'
    s += f'<rect x="{x0 + w}" y="{top + 6}" width="12" height="{W - top}" fill="#0A2A2B"/>'
    # The sun catches the roof ledge and the corner facing it.
    s += f'<rect x="{x0 - 4}" y="{top}" width="{w + 8}" height="1.6" fill="#FF3A1F" opacity="0.8"/>'
    s += f'<rect x="{x0 + w + 10.5}" y="{top + 6}" width="1.5" height="{W - top}" fill="#FF3A1F" opacity="0.5"/>'
    # Windows: four columns, some lit red with a bright top edge.
    cols, ww, wh = 3, 24, 15
    pad = (w - cols * ww) / (cols + 1)
    lit = {(2, 0), (0, 1), (1, 3), (2, 4), (0, 6), (1, 7)}
    row = 0
    y = top + 14
    while y < W - 30:
        for c in range(cols):
            wx = x0 + pad + c * (ww + pad)
            if (c, row) in lit:
                s += f'<rect x="{wx:.1f}" y="{y:.1f}" width="{ww}" height="{wh}" rx="1" fill="#FF2A14"/>'
                s += f'<rect x="{wx:.1f}" y="{y:.1f}" width="{ww}" height="2.5" fill="#FF7A55" opacity="0.55"/>'
            else:
                s += f'<rect x="{wx:.1f}" y="{y:.1f}" width="{ww}" height="{wh}" rx="1" fill="#0C2B2D"/>'
        row += 1
        y += wh + 12
    for c in range(1, cols):   # slim pillars between the columns
        px = x0 + pad * 0.5 + c * (ww + pad) - 0.5
        s += f'<rect x="{px:.1f}" y="{top + 8}" width="1" height="{W - top}" fill="#17393A" opacity="0.8"/>'
    return s


def ground():
    return f'<rect y="{W - 26}" width="{W}" height="26" fill="#010C0D"/><rect y="{W - 26}" width="{W}" height="1.5" fill="#1F4746"/>'


def svg(body, size=W, defs=True, view=f"0 0 {W} {W}"):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="{view}">{DEFS if defs else ""}{body}</svg>\n'


def mono():
    # Android 13 themed icon: one colour, the sun ring and the tower with
    # its windows cut out, all inside the safe zone.
    cx, cy, r = SUN
    # The sun as a solid disc, cut back around the tower so they read apart.
    s = ('<defs><clipPath id="c"><path clip-rule="evenodd" d="M0 0 H432 V432 H0 Z M118 96 H250 V432 H118 Z"/></clipPath></defs>'
         f'<circle cx="{cx}" cy="{cy}" r="{r - 4}" fill="#FFFFFF" clip-path="url(#c)"/>')
    d = 'M128 150 H240 V356 H128 Z'
    for row in range(7):
        for c in range(3):
            if (row + c) % 2 == 0:
                x, y = 138 + c * 34, 166 + row * 26
                d += f' M{x} {y} V{y + 15} H{x + 24} V{y} Z'
    s += f'<path fill-rule="evenodd" d="{d}" fill="#FFFFFF"/>'
    s += '<rect x="156" y="106" width="4" height="30" fill="#FFFFFF"/><rect x="142" y="134" width="30" height="16" fill="#FFFFFF"/>'
    return svg(s, defs=False)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    full = background() + sun() + skyline() + tower() + ground()
    files = {
        "icon_src.svg": svg(full),
        "icon_legacy.svg": svg(full, 288, view="72 72 288 288"),   # what a launcher shows: the safe zone
        "icon_bg.svg": svg(background()),
        "icon_fg.svg": svg(sun() + skyline() + tower() + ground()),
        "icon_mono.svg": mono(),
    }
    for name, text in files.items():
        with open(os.path.join(out, name), "w") as f:
            f.write(text)
    print("wrote", ", ".join(files))
