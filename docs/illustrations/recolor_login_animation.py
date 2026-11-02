"""Recolor the login hero Lottie (football_team_players.json) into three
Mexican kits: national team (left), Cruz Azul (center), Pumas (right).

Shirt and sock colors share the same values in the source file, so colors
are swapped per layer group (torso/arms vs legs), never globally.

Usage: python3 docs/illustrations/recolor_login_animation.py <in.json> <out.json>

<in.json> must be the ORIGINAL red/teal animation: the script matches its exact
source colors, so running it on the already recolored file changes nothing.
The original is in git history, e.g.:
  git show 95ff6d8:Packages/Features/OnboardingFeature/Sources/OnboardingFeature/Resources/Animations/football_team_players.json > original.json
"""
import json
import sys

# Source palette (0-255)
RED, RED_LT, RED_DK = (198, 32, 32), (244, 66, 66), (178, 29, 29)
TEAL, TEAL_LT, TEAL_DK = (29, 125, 106), (57, 160, 143), (15, 94, 79)
GOLD = (237, 174, 99)

# Kits
MX_GREEN, MX_GREEN_LT = (0, 104, 71), (22, 138, 94)
MX_WHITE, MX_WHITE_SH = (234, 237, 242), (198, 204, 213)
MX_RED, MX_RED_LT = (206, 17, 38), (232, 58, 72)

CA_BLUE, CA_BLUE_LT, CA_BLUE_DK = (20, 70, 170), (58, 115, 214), (12, 44, 118)
CA_WHITE = (246, 246, 246)

PU_NAVY, PU_NAVY_LT, PU_NAVY_DK = (14, 34, 66), (38, 64, 110), (8, 22, 46)
PU_GOLD, PU_GOLD_LT = (196, 154, 62), (222, 186, 102)


def remap(node, mapping):
    """Replace solid fill/stroke colors found in `mapping` (exact 0-255 match)."""
    if isinstance(node, dict):
        if node.get("ty") in ("fl", "st") and isinstance(node.get("c"), dict):
            k = node["c"].get("k")
            if isinstance(k, list) and len(k) >= 3 and all(isinstance(x, (int, float)) for x in k[:3]):
                key = tuple(round(x * 255) for x in k[:3])
                if key in mapping:
                    node["c"]["k"] = [c / 255 for c in mapping[key]] + list(k[3:])
        for v in node.values():
            remap(v, mapping)
    elif isinstance(node, list):
        for v in node:
            remap(v, mapping)


def main(src, dst):
    d = json.load(open(src))
    layers = {l["ind"]: l for l in d["layers"]}
    by_name = lambda names: [l for l in d["layers"] if l.get("nm", "").strip() in names]

    # --- Center player (layers 1-8): Cruz Azul, all blue with the red cross detail.
    ca_top = {TEAL: CA_BLUE, TEAL_LT: CA_BLUE_LT, TEAL_DK: CA_BLUE_DK, GOLD: CA_WHITE}
    ca_legs = {TEAL: CA_BLUE_DK, TEAL_LT: CA_BLUE, TEAL_DK: CA_BLUE_DK}
    for ind in (1, 2, 3, 4, 5, 7):          # head, arms, hands, body
        remap(layers[ind], ca_top)
    remap(layers[8], ca_legs)                # legs: shorts + socks, boots keep gold

    # --- Left player (layers 11-19): national team. Green shirt, white shorts, red socks.
    mx_top = {RED: MX_GREEN, RED_LT: MX_GREEN_LT, TEAL_LT: MX_WHITE, TEAL: MX_WHITE}
    mx_legs = {TEAL_LT: MX_WHITE, TEAL: MX_WHITE_SH, RED: MX_RED, RED_LT: MX_RED_LT}
    for ind in (12, 14, 16):                 # r arm, l arm, body
        remap(layers[ind], mx_top)
    for ind in (17, 18, 19):                 # l leg, r thigh, r leg
        remap(layers[ind], mx_legs)

    # --- Right player (precomp comp_0): Pumas, navy and gold.
    comp = next(a for a in d["assets"] if a.get("id") == "comp_0")
    pu_top = {RED: PU_NAVY, RED_LT: PU_NAVY_LT, TEAL_LT: PU_GOLD, TEAL: PU_GOLD, GOLD: PU_GOLD_LT}
    pu_legs = {TEAL_LT: PU_NAVY_LT, TEAL: PU_NAVY, RED: PU_GOLD, RED_LT: PU_GOLD_LT}
    for l in comp["layers"]:
        name = l.get("nm", "").strip()
        if name in ("l arm", "r arm", "body"):
            remap(l, pu_top)
        elif name in ("thigh", "l leg", "r leg"):
            remap(l, pu_legs)

    with open(dst, "w") as f:
        json.dump(d, f, separators=(",", ":"))
    print("written", dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
