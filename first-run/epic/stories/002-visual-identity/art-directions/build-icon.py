#!/usr/bin/env python3
"""Generator for the Zeo brand mark — a faceted amethyst crystal cluster.

Provenance for story 002, sub-task 6.2. The mark is CONSTRUCTED, not traced: every
polygon comes out of the crystal model below, so the geometry is reproducible and the
SVG stays hand-editable afterwards.

The palette is derived from the Zeo accent rather than merely harmonised with it: the
two mid-tones of the icon's five-step ramp ARE the two brand hexes — #BD93F9 (the Zeo
Dark accent) and #7C3AED (the Zeo Light accent). The other three steps extend that
ramp outward to a near-white tip highlight and two shadow violets.

A crystal is a hexagonal prism with a pyramidal tip. In this projection only four
facets are ever visible, which is what keeps the mark legible at 32px:

      apex
      /  \\        tip-left  (light)   tip-right (highlight)
     /____\\
    |  |   |      shaft-left (dark)   shaft-right (mid)
    |  |   |      ...meeting at a front ridge running down the middle
    |__|___|

The front ridge sits LOWER than the two side shoulders (dy), which is what reads as
depth. Tilt rotates the whole crystal about its base centre.
"""

import math

# --- palette: a five-step ramp whose two middle steps are the Zeo brand accents ----
HI = "#EDE7FE"  # tip highlight — near-white lavender
LIGHT = "#BD93F9"  # ← the Zeo Dark accent, verbatim
MID = "#7C3AED"  # ← the Zeo Light accent, verbatim
DARK = "#4C1D95"  # shadow facets
DEEP = "#2E1065"  # the recessed crystal, and the base's shadow side


def crystal(cx, base_y, shoulder_y, apex_y, w, tilt=0.0, depth=0.42, shades=None):
    """One crystal → four polygons, back-to-front.

    cx/base_y     the point the crystal stands on (and the pivot for `tilt`)
    shoulder_y    where the shaft ends and the tip begins
    apex_y        the point
    w             half-width of the shaft
    tilt          degrees; positive leans right
    depth         how far the front ridge drops below the side shoulders, as a
                  fraction of w. This single number is the whole illusion.
    """
    sh = shades or (DARK, MID, LIGHT, HI)
    dy = w * depth

    # side shoulders sit high, the front ridge drops toward the viewer
    sl, sc, sr = (cx - w, shoulder_y - dy), (cx, shoulder_y + dy), (cx + w, shoulder_y - dy)
    bl, bc, br = (cx - w, base_y - dy), (cx, base_y + dy), (cx + w, base_y - dy)
    apex = (cx, apex_y)

    faces = [
        ([sl, sc, bc, bl], sh[0]),  # shaft-left   — in shadow
        ([sc, sr, br, bc], sh[1]),  # shaft-right  — the lit side
        ([sl, sc, apex], sh[2]),  # tip-left
        ([sc, sr, apex], sh[3]),  # tip-right    — catches the highlight
    ]

    if tilt:
        t = math.radians(tilt)
        cos_t, sin_t = math.cos(t), math.sin(t)

        def rot(p):
            x, y = p[0] - cx, p[1] - base_y
            return (
                cx + x * cos_t - y * sin_t,
                base_y + x * sin_t + y * cos_t,
            )

        faces = [([rot(p) for p in poly], fill) for poly, fill in faces]

    return faces


def base_slab(bx, by, rx, ry, thickness):
    """The hexagonal slab the cluster grows out of. Drawn LAST so it occludes the
    crystals' feet — which is why the crystals never need a bottom facet."""
    a = (bx - rx, by)  # left
    b = (bx - rx * 0.52, by - ry)  # back-left
    c = (bx + rx * 0.52, by - ry)  # back-right
    d = (bx + rx, by)  # right
    e = (bx + rx * 0.52, by + ry)  # front-right
    f = (bx - rx * 0.52, by + ry)  # front-left

    def down(p):
        return (p[0], p[1] + thickness)

    return [
        ([a, b, c, d, e, f], LIGHT),  # top face — catches the light
        ([a, f, down(f), down(a)], DEEP),  # left flank — deepest shadow
        ([f, e, down(e), down(f)], MID),  # front flank
        ([e, d, down(d), down(e)], DARK),  # right flank
    ]


def poly(points, fill):
    pts = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)
    return f'  <polygon points="{pts}" fill="{fill}"/>'


def build(tile=True):
    """`tile=True` sets the mark on a deep-violet rounded square.

    This is not decoration. The mark's tip facet is near-white by design — it is what
    reads as "catches the light" — and near-white on a LIGHT panel is invisible: the
    crystal would ship without a point on half the desktops in the world. A tile makes
    the icon carry its own background, so the highlight is guaranteed a dark field to
    sit on. Zed's own icon and story 001's placeholder both do exactly this; it is the
    convention already in the repo, not a new one.
    """
    faces = []

    # Painter's algorithm: back to front.
    #
    # Two proportions decide whether this reads as a rock or as a CROWN, and both are
    # counter-intuitive. (1) The tip must be SHORT — roughly a third of the shaft, not
    # half. A long tip is a spike, and five spikes on a band is a crown no matter what
    # colour they are. (2) The shafts must be FAT enough to overlap, so the cluster has
    # no gaps for the eye to read as separate points.
    #
    # The small crystal is drawn entirely in the two darkest shades: it sits BEHIND the
    # others and is what gives the cluster a back rather than a silhouette.
    faces += crystal(cx=320, base_y=396, shoulder_y=262, apex_y=200, w=40, tilt=12)
    faces += crystal(
        cx=296, base_y=388, shoulder_y=272, apex_y=214, w=26, tilt=6,
        shades=(DEEP, DEEP, DARK, DARK),
    )
    faces += crystal(cx=200, base_y=402, shoulder_y=218, apex_y=148, w=44, tilt=-11)
    faces += crystal(cx=258, base_y=400, shoulder_y=155, apex_y=76, w=50, tilt=0)

    faces += base_slab(bx=252, by=400, rx=105, ry=40, thickness=44)

    body = "\n".join(poly(p, f) for p, f in faces)

    if tile:
        # the mark is inset so the crystal never crowds the rounded corners
        body = f'  <g transform="translate(258 260) scale(0.88) translate(-256 -256)">\n{body}\n  </g>'
        tile_svg = (
            '  <defs>\n'
            # The field must sit CLEARLY below the crystal's darkest facet (#4C1D95).
            # A tile in the same value range as the shadow faces makes the side shafts
            # dissolve into the background and the tips float free as loose diamonds --
            # the first tile shipped that bug at #3D1F80.
            '    <linearGradient id="field" x1="0" y1="0" x2="0.65" y2="1">\n'
            '      <stop offset="0" stop-color="#251154"/>\n'
            '      <stop offset="1" stop-color="#11052F"/>\n'
            '    </linearGradient>\n'
            '  </defs>\n'
            '  <rect x="0" y="0" width="512" height="512" rx="114" fill="url(#field)"/>\n'
        )
        body = tile_svg + body

    provenance = """<!--
  Zeo brand mark — a faceted amethyst crystal cluster.

  ORIGINAL WORK, authored for the Zeo fork (story 002, sub-task 6.2). Constructed,
  not traced: every polygon is emitted by `scripts/build-icon.py` in the Zeo
  workspace repo, from a parametric crystal model (hexagonal prism + pyramidal tip,
  isometric projection, painter-ordered). The SVG stays hand-editable afterwards.

  The palette is DERIVED from the Zeo accent rather than merely matched to it: the
  two middle steps of the mark's five-step ramp are the brand hexes themselves —
  #BD93F9 (the Zeo Dark accent) and #7C3AED (the Zeo Light accent). The ramp extends
  outward from those two to a near-white tip highlight and two shadow violets.

  TRADEMARK POSTURE (R4.2), stated symmetrically:
  - Not derivative of Zed's mark. Zed's is a letterform — a nested, spiralling Z.
    Zeo's is a crystal. The resemblance is the palette family and nothing else.
  - Not derivative of any Power Rangers / Hasbro property. The mark is evocative of
    amethyst as a mineral. It carries no franchise iconography: no Zeo Crystal shape
    or colourway as depicted in the franchise, no ranger or character motif, no
    lightning-bolt-Z lockup.
-->
"""
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" '
        'width="512" height="512" role="img" aria-label="Zeo">\n'
        f"{provenance}"
        "  <title>Zeo</title>\n"
        f"{body}\n"
        "</svg>\n"
    )


if __name__ == "__main__":
    import sys

    out = sys.argv[1] if len(sys.argv) > 1 else "zeo-icon.svg"
    tile = "--no-tile" not in sys.argv
    with open(out, "w", encoding="utf-8") as handle:
        handle.write(build(tile=tile))
    print(f"wrote {out} (tile={tile})")
