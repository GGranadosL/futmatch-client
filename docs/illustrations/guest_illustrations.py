"""Guest-mode illustrations for Interfut (Home, Reserved, Profile).

Flat grayscale scenes with one brand-blue accent. Written as plain SVG
(paths, rects, circles, linear/radial gradients only, no filters or masks),
so Xcode's asset catalog can keep them as vectors.

Usage: python3 docs/illustrations/guest_illustrations.py <out_dir>
Writes guestHome{,-dark}.svg, guestReserved{,-dark}.svg, guestProfile{,-dark}.svg.
Copy each pair into FutMatch-Client/FutMatch-Client/Assets.xcassets/<name>.imageset/
(the -dark file is the dark-appearance variant). The bottom of every scene fades
into FMColors.background, so keep `bg` in both palettes in sync with it.
"""
import os
import sys

W, H = 390, 440

LIGHT = dict(
    sky_top="#D7DAE2", sky_mid="#E9EBF0", bg="#F9F9FF",
    far="#CDD1D9", mid="#B6BBC6", near="#9AA0AC", deep="#6E7480", ink="#4A505B",
    lite="#FFFFFF", soft="#EEF0F4", ground="#E4E7ED", ground2="#D9DDE4",
    accent="#1F63E6", accent_lt="#4C8BF5", accent_dk="#1748B0", cyan="#2CC4EE",
    glow="#FFFFFF", star="#FFFFFF", shadow="#000000", shadow_op="0.10",
)
DARK = dict(
    sky_top="#1A1D24", sky_mid="#181B21", bg="#111318",
    far="#262A33", mid="#323743", near="#434956", deep="#5C6371", ink="#8A91A0",
    lite="#C9CED8", soft="#2B3039", ground="#1E2128", ground2="#252932",
    accent="#5B95FF", accent_lt="#86B2FF", accent_dk="#3A6FD8", cyan="#4FD3F5",
    glow="#DCE6FF", star="#9AA4B8", shadow="#000000", shadow_op="0.35",
)


def svg(body, p, defs=""):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{p['sky_top']}"/>
    <stop offset="0.55" stop-color="{p['sky_mid']}"/>
    <stop offset="1" stop-color="{p['bg']}"/>
  </linearGradient>
  <linearGradient id="fade" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{p['bg']}" stop-opacity="0"/>
    <stop offset="1" stop-color="{p['bg']}" stop-opacity="1"/>
  </linearGradient>
  <linearGradient id="ball" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{p['accent_lt']}"/>
    <stop offset="1" stop-color="{p['accent_dk']}"/>
  </linearGradient>
  <linearGradient id="accentV" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{p['accent_lt']}"/>
    <stop offset="1" stop-color="{p['accent']}"/>
  </linearGradient>
  <linearGradient id="beam" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{p['glow']}" stop-opacity="0.45"/>
    <stop offset="1" stop-color="{p['glow']}" stop-opacity="0"/>
  </linearGradient>
{defs}
</defs>
<rect width="{W}" height="{H}" fill="url(#sky)"/>
{body}
<rect x="0" y="{H-70}" width="{W}" height="70" fill="url(#fade)"/>
</svg>
"""


def sparkle(x, y, r, color, op=1.0):
    t = r * 0.18
    return (f'<path d="M{x} {y-r} L{x+t} {y-t} L{x+r} {y} L{x+t} {y+t} L{x} {y+r} '
            f'L{x-t} {y+t} L{x-r} {y} L{x-t} {y-t} Z" fill="{color}" opacity="{op}"/>')


def dots(p, pts, r=1.6, op=0.8):
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{p["star"]}" opacity="{op}"/>' for x, y in pts)


def soccer_ball(cx, cy, r, p, fill="url(#ball)", line=None):
    """Brand-like ball: solid disc, white ring and a pentagon panel pattern."""
    line = line or p["lite"]
    s = r / 50.0
    def pt(x, y):
        return f"{cx + x*s:.1f} {cy + y*s:.1f}"
    pent = [(-4, -18), (14, -10), (12, 10), (-8, 14), (-18, -2)]
    pent_d = "M" + " L".join(pt(x, y) for x, y in pent) + " Z"
    spokes = [((-4, -18), (-10, -38)), ((14, -10), (34, -20)), ((12, 10), (28, 30)),
              ((-8, 14), (-14, 36)), ((-18, -2), (-38, 4))]
    spoke_d = "".join(f'M{pt(*a)} L{pt(*b)} ' for a, b in spokes)
    w = 4.2 * s
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r*0.86:.1f}" fill="none" stroke="{line}" stroke-width="{w:.1f}"/>'
            f'<path d="{pent_d}" fill="none" stroke="{line}" stroke-width="{w:.1f}" stroke-linejoin="round"/>'
            f'<path d="{spoke_d}" stroke="{line}" stroke-width="{w:.1f}" stroke-linecap="round"/>')


def swoosh(cx, cy, r, p):
    """Two motion arcs trailing the ball, echoing the logo."""
    return (f'<path d="M{cx+r*0.35} {cy-r*1.18} A{r*1.2} {r*1.2} 0 0 1 {cx+r*0.55} {cy+r*1.12}" '
            f'fill="none" stroke="{p["cyan"]}" stroke-width="{r*0.16:.1f}" stroke-linecap="round" opacity="0.95"/>'
            f'<path d="M{cx+r*0.95} {cy-r*0.78} A{r*1.45} {r*1.45} 0 0 1 {cx+r*0.7} {cy+r*1.25}" '
            f'fill="none" stroke="{p["accent_lt"]}" stroke-width="{r*0.12:.1f}" stroke-linecap="round" opacity="0.8"/>')


# --------------------------------------------------------------------------
# Home: evening pitch, floodlights, goal and the ball
# --------------------------------------------------------------------------
def home(p):
    b = []
    # stars
    b.append(dots(p, [(40, 60), (88, 34), (150, 70), (232, 40), (300, 78), (352, 30), (196, 22), (120, 112)], 1.5, 0.7))
    b.append(sparkle(70, 96, 9, p["star"], 0.9))
    b.append(sparkle(318, 118, 7, p["star"], 0.8))
    # stadium stands silhouette
    b.append(f'<path d="M0 236 L0 150 Q195 118 390 150 L390 236 Z" fill="{p["far"]}"/>')
    b.append(f'<path d="M0 236 L0 184 Q195 158 390 184 L390 236 Z" fill="{p["mid"]}" opacity="0.8"/>')
    # stand rows (seats)
    for i, (y, k) in enumerate([(160, 0.0), (170, 0.0), (194, 1), (204, 1), (214, 1)]):
        b.append(f'<path d="M0 {y+18-i*0} Q195 {y-12} 390 {y+18}" fill="none" stroke="{p["near"] if k else p["mid"]}" stroke-width="1.6" opacity="0.6"/>')
    # roof canopy over the main stand
    b.append(f'<path d="M96 132 Q195 112 294 132 L282 142 Q195 124 108 142 Z" fill="{p["near"]}"/>')
    for x in (120, 170, 220, 270):
        b.append(f'<rect x="{x}" y="132" width="3" height="26" fill="{p["near"]}" opacity="0.8"/>')
    # floodlight towers + beams
    for x, flip in [(38, 1), (352, -1)]:
        b.append(f'<path d="M{x-14*flip} 70 L{x+20*flip} 70 L{x+170*flip} 250 L{x+30*flip} 250 Z" fill="url(#beam)"/>')
        b.append(f'<rect x="{x-3}" y="70" width="6" height="170" fill="{p["near"]}"/>')
        b.append(f'<rect x="{x-20}" y="46" width="40" height="26" rx="3" fill="{p["deep"]}"/>')
        for r in range(2):
            for c in range(4):
                b.append(f'<circle cx="{x-13+c*8.7:.1f}" cy="{54+r*10}" r="3" fill="{p["glow"]}"/>')
    # pitch
    b.append(f'<path d="M0 236 L390 236 L390 {H} L0 {H} Z" fill="{p["ground"]}"/>')
    for i in range(6):
        y0 = 236 + i * 34
        b.append(f'<rect x="0" y="{y0}" width="{W}" height="17" fill="{p["ground2"]}" opacity="0.8"/>')
    # touchline + penalty arc
    b.append(f'<path d="M0 252 L390 252" stroke="{p["lite"]}" stroke-width="2.5" opacity="0.9"/>')
    b.append(f'<path d="M95 252 L95 300 L295 300 L295 252" fill="none" stroke="{p["lite"]}" stroke-width="2.5" opacity="0.9"/>')
    b.append(f'<path d="M160 300 Q195 330 230 300" fill="none" stroke="{p["lite"]}" stroke-width="2.5" opacity="0.9"/>')
    # goal: back net + frame
    gx, gy, gw, gh = 120, 172, 150, 82
    b.append(f'<path d="M{gx} {gy} L{gx+14} {gy+14} L{gx+gw-14} {gy+14} L{gx+gw} {gy} Z" fill="{p["mid"]}" opacity="0.35"/>')
    net = []
    for i in range(1, 15):
        x = gx + i * gw / 15
        net.append(f'M{x:.1f} {gy} L{x:.1f} {gy+gh}')
    for j in range(1, 8):
        y = gy + j * gh / 8
        net.append(f'M{gx} {y:.1f} L{gx+gw} {y:.1f}')
    b.append(f'<path d="{" ".join(net)}" stroke="{p["near"]}" stroke-width="1" opacity="0.7"/>')
    b.append(f'<path d="M{gx} {gy+gh} L{gx} {gy} L{gx+gw} {gy} L{gx+gw} {gy+gh}" fill="none" stroke="{p["lite"]}" stroke-width="6" stroke-linejoin="round"/>')
    b.append(f'<path d="M{gx+3} {gy+gh} L{gx+3} {gy+3} L{gx+gw-3} {gy+3}" fill="none" stroke="{p["mid"]}" stroke-width="1.5" opacity="0.5"/>')
    # ball shadow + ball + swoosh
    b.append(f'<ellipse cx="200" cy="384" rx="46" ry="9" fill="{p["shadow"]}" opacity="{p["shadow_op"]}"/>')
    b.append(swoosh(196, 338, 44, p))
    b.append(soccer_ball(196, 338, 44, p))
    # grass tufts
    for x in [62, 84, 300, 330]:
        b.append(f'<path d="M{x} 360 l4 -12 l3 12 l4 -9 l2 9 Z" fill="{p["mid"]}" opacity="0.7"/>')
    return svg("".join(b), p)


# --------------------------------------------------------------------------
# Reserved: kit bag, boots and a match ticket
# --------------------------------------------------------------------------
def boot(x, y, s, p, color, sole, stud, lace, flip=False):
    """Side view of a football boot, toe pointing right (or left with flip)."""
    tr = f'translate({x} {y}) scale({-s if flip else s} {s})'
    upper = ("M0 0 C0 -22 6 -40 20 -46 L34 -48 C40 -40 48 -34 60 -30 "
             "C82 -24 104 -20 112 -10 C116 -4 116 2 112 6 L0 6 Z")
    collar = "M18 -46 C24 -52 34 -54 36 -48"
    swoop = "M10 -10 C36 -26 64 -28 96 -16"
    laces = " ".join(f"M{44+i*9} -32 L{50+i*9} -24" for i in range(5))
    studs = "".join(f'<rect x="{sx}" y="6" width="8" height="7" rx="2" fill="{stud}"/>' for sx in (8, 30, 62, 86))
    return (f'<g transform="{tr}">'
            f'<path d="{upper}" fill="{color}"/>'
            f'<path d="M0 2 L114 2 L112 8 L0 8 Z" fill="{sole}"/>'
            f'{studs}'
            f'<path d="{collar}" fill="none" stroke="{sole}" stroke-width="4" stroke-linecap="round"/>'
            f'<path d="{swoop}" fill="none" stroke="{p["lite"]}" stroke-width="5" stroke-linecap="round" opacity="0.9"/>'
            f'<path d="{laces}" stroke="{lace}" stroke-width="3" stroke-linecap="round"/>'
            f'</g>')


def reserved(p):
    b = []
    b.append(dots(p, [(46, 50), (120, 30), (270, 44), (340, 70), (200, 64)], 1.5, 0.6))
    b.append(sparkle(312, 104, 8, p["star"], 0.85))
    # distant stadium bowl + hills
    b.append(f'<path d="M0 220 Q90 150 195 150 Q300 150 390 220 Z" fill="{p["far"]}"/>')
    b.append(f'<path d="M40 220 Q120 168 195 168 Q270 168 350 220 Z" fill="{p["mid"]}" opacity="0.55"/>')
    # floor
    b.append(f'<rect x="0" y="216" width="{W}" height="{H-216}" fill="{p["ground"]}"/>')
    b.append(f'<path d="M0 216 L390 216" stroke="{p["lite"]}" stroke-width="2" opacity="0.6"/>')
    # ticket leaning at the back (accent)
    b.append(f'<g transform="rotate(-8 290 200)">'
             f'<rect x="236" y="138" width="108" height="66" rx="8" fill="url(#accentV)"/>'
             f'<circle cx="236" cy="171" r="9" fill="{p["sky_mid"]}"/><circle cx="344" cy="171" r="9" fill="{p["sky_mid"]}"/>'
             f'<path d="M314 146 L314 196" stroke="{p["lite"]}" stroke-width="2" stroke-dasharray="4 4" opacity="0.8"/>'
             f'<rect x="252" y="154" width="44" height="7" rx="3.5" fill="{p["lite"]}" opacity="0.95"/>'
             f'<rect x="252" y="168" width="30" height="5" rx="2.5" fill="{p["lite"]}" opacity="0.7"/>'
             f'<rect x="252" y="180" width="38" height="5" rx="2.5" fill="{p["lite"]}" opacity="0.7"/>'
             f'</g>')
    # kit bag (duffel)
    b.append(f'<ellipse cx="170" cy="318" rx="128" ry="12" fill="{p["shadow"]}" opacity="{p["shadow_op"]}"/>')
    b.append(f'<path d="M110 196 C110 150 140 136 152 136 L188 136 C200 136 230 150 230 196" fill="none" stroke="{p["deep"]}" stroke-width="9" stroke-linecap="round"/>')
    b.append(f'<rect x="52" y="190" width="236" height="124" rx="40" fill="{p["near"]}"/>')
    b.append(f'<rect x="52" y="190" width="236" height="56" rx="28" fill="{p["mid"]}" opacity="0.55"/>')
    b.append(f'<path d="M80 204 L260 204" stroke="{p["deep"]}" stroke-width="3" stroke-dasharray="7 5" opacity="0.7"/>')
    b.append(f'<rect x="60" y="250" width="220" height="14" fill="{p["deep"]}" opacity="0.55"/>')
    b.append(f'<rect x="52" y="226" width="22" height="64" rx="8" fill="{p["deep"]}"/>')
    b.append(f'<rect x="266" y="226" width="22" height="64" rx="8" fill="{p["deep"]}"/>')
    b.append(f'<circle cx="170" cy="282" r="12" fill="{p["lite"]}" opacity="0.9"/>')
    b.append(f'<circle cx="170" cy="282" r="5" fill="url(#ball)"/>')
    # boots in front (accent)
    b.append(f'<ellipse cx="236" cy="384" rx="118" ry="9" fill="{p["shadow"]}" opacity="{p["shadow_op"]}"/>')
    b.append(boot(156, 362, 1.12, p, p["accent_dk"], p["ink"], p["deep"], p["lite"]))
    b.append(boot(206, 376, 1.16, p, p["accent"], p["ink"], p["deep"], p["lite"]))
    # small ball on the left
    b.append(f'<ellipse cx="78" cy="392" rx="30" ry="6" fill="{p["shadow"]}" opacity="{p["shadow_op"]}"/>')
    b.append(soccer_ball(78, 362, 30, p, fill=p["mid"], line=p["lite"]))
    return svg("".join(b), p)


# --------------------------------------------------------------------------
# Profile: locker room, jersey hanging, bench and lamp
# --------------------------------------------------------------------------
def profile(p):
    b = []
    # back wall panels (lockers)
    b.append(f'<rect x="0" y="0" width="{W}" height="300" fill="{p["far"]}" opacity="0.65"/>')
    for i in range(5):
        x = 6 + i * 78
        b.append(f'<rect x="{x}" y="70" width="72" height="230" rx="4" fill="{p["mid"]}" opacity="0.75"/>')
        b.append(f'<rect x="{x+8}" y="82" width="56" height="6" rx="3" fill="{p["far"]}"/>')
        b.append(f'<rect x="{x+8}" y="94" width="56" height="6" rx="3" fill="{p["far"]}"/>')
        b.append(f'<rect x="{x+58}" y="170" width="5" height="22" rx="2.5" fill="{p["deep"]}"/>')
    # pendant lamp + light cone
    b.append(f'<path d="M195 0 L195 42" stroke="{p["deep"]}" stroke-width="2"/>')
    b.append(f'<path d="M130 210 L260 210 L212 66 L178 66 Z" fill="{p["glow"]}" opacity="0.22"/>')
    b.append(f'<path d="M160 70 Q160 40 195 40 Q230 40 230 70 Z" fill="{p["near"]}"/>')
    b.append(f'<rect x="158" y="68" width="74" height="5" rx="2.5" fill="{p["deep"]}"/>')
    b.append(f'<circle cx="195" cy="74" r="6" fill="{p["glow"]}"/>')
    # floor
    b.append(f'<rect x="0" y="300" width="{W}" height="{H-300}" fill="{p["ground"]}"/>')
    b.append(f'<path d="M0 300 L390 300" stroke="{p["lite"]}" stroke-width="2" opacity="0.6"/>')
    # jersey on hanger (accent)
    jx, jy = 195, 118
    b.append(f'<path d="M{jx} {jy-26} q0 -8 6 -8" fill="none" stroke="{p["ink"]}" stroke-width="3" stroke-linecap="round"/>')
    b.append(f'<path d="M{jx-46} {jy-4} L{jx} {jy-24} L{jx+46} {jy-4}" fill="none" stroke="{p["ink"]}" stroke-width="3" stroke-linecap="round"/>')
    shirt = (f"M{jx-24} {jy-14} Q{jx} {jy-2} {jx+24} {jy-14} "
             f"L{jx+62} {jy+4} L{jx+52} {jy+40} L{jx+36} {jy+34} "
             f"L{jx+38} {jy+112} L{jx-38} {jy+112} L{jx-36} {jy+34} "
             f"L{jx-52} {jy+40} L{jx-62} {jy+4} Z")
    b.append(f'<path d="{shirt}" fill="url(#accentV)"/>')
    b.append(f'<path d="M{jx-24} {jy-14} Q{jx} {jy+8} {jx+24} {jy-14}" fill="none" stroke="{p["accent_dk"]}" stroke-width="5"/>')
    b.append(f'<path d="M{jx+62} {jy+4} L{jx+52} {jy+40}" stroke="{p["lite"]}" stroke-width="5" opacity="0.9"/>')
    b.append(f'<path d="M{jx-62} {jy+4} L{jx-52} {jy+40}" stroke="{p["lite"]}" stroke-width="5" opacity="0.9"/>')
    b.append(f'<path d="M{jx-37} {jy+60} L{jx+37} {jy+60}" stroke="{p["cyan"]}" stroke-width="6" opacity="0.9"/>')
    # number on the back, drawn as shapes (no text): a "1" and a "0"
    b.append(f'<rect x="{jx-20}" y="{jy+72}" width="7" height="30" rx="2" fill="{p["lite"]}"/>')
    b.append(f'<rect x="{jx-3}" y="{jy+72}" width="22" height="30" rx="10" fill="none" stroke="{p["lite"]}" stroke-width="6"/>')
    # bench
    b.append(f'<ellipse cx="195" cy="372" rx="160" ry="10" fill="{p["shadow"]}" opacity="{p["shadow_op"]}"/>')
    b.append(f'<rect x="38" y="296" width="314" height="16" rx="5" fill="{p["near"]}"/>')
    b.append(f'<rect x="38" y="296" width="314" height="6" rx="3" fill="{p["mid"]}" opacity="0.7"/>')
    for x in (60, 322):
        b.append(f'<rect x="{x}" y="310" width="10" height="58" rx="3" fill="{p["deep"]}"/>')
    # folded towels on bench
    b.append(f'<rect x="78" y="276" width="78" height="12" rx="5" fill="{p["lite"]}"/>')
    b.append(f'<rect x="84" y="288" width="72" height="10" rx="4" fill="{p["soft"]}"/>')
    b.append(f'<rect x="78" y="284" width="78" height="3" fill="{p["mid"]}" opacity="0.6"/>')
    # ball on bench
    b.append(soccer_ball(296, 274, 22, p, fill=p["mid"], line=p["lite"]))
    # boots under bench (accent)
    b.append(boot(150, 360, 0.72, p, p["accent"], p["ink"], p["deep"], p["lite"]))
    b.append(boot(186, 366, 0.72, p, p["accent_dk"], p["ink"], p["deep"], p["lite"]))
    return svg("".join(b), p)


def main(out):
    os.makedirs(out, exist_ok=True)
    for name, fn in (("guestHome", home), ("guestReserved", reserved), ("guestProfile", profile)):
        for suffix, pal in (("", LIGHT), ("-dark", DARK)):
            with open(os.path.join(out, f"{name}{suffix}.svg"), "w") as f:
                f.write(fn(pal))
    print("written to", out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
