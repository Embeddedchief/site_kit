"""Draws the SiteKit app icon: a white set-square with ruler notches and a
small ring (a nod to the AOJ roundel) on AOJ red.

Usage: python make_icon.py <out_dir>
Writes icon.png (full-bleed, 1024), foreground.png (adaptive foreground,
transparent, mark scaled into the safe zone) and mark.png (in-app logo).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SS = 4  # supersampling factor for smooth edges
N = 1024 * SS
RED_TOP = (232, 12, 6)
RED_BOTTOM = (176, 5, 0)


def rounded(mask: Image.Image, radius: int) -> Image.Image:
    """Rounds the corners of a binary mask (blur, then re-threshold)."""
    return mask.filter(ImageFilter.GaussianBlur(radius)).point(
        lambda v: 255 if v > 128 else 0
    )


def mark_mask(scale: float = 1.0) -> Image.Image:
    """White-mark alpha mask, centred, at `scale` of the full design."""
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    s = SS

    # Set-square: right angle bottom-left.
    ax, ay = 292 * s, 238 * s   # top
    bx, by = 292 * s, 770 * s   # right angle
    cx, cy = 824 * s, 770 * s   # bottom-right
    d.polygon([(ax, ay), (bx, by), (cx, cy)], fill=255)
    m = rounded(m, 22 * s)

    # Triangular cut-out, inset from each side.
    hole = Image.new("L", (N, N), 0)
    hd = ImageDraw.Draw(hole)
    hd.polygon(
        [(400 * s, 498 * s), (400 * s, 662 * s), (564 * s, 662 * s)], fill=255
    )
    hole = rounded(hole, 14 * s)
    m.paste(0, mask=hole)

    # Ruler notches along the vertical edge, long every third.
    d = ImageDraw.Draw(m)
    for i, y in enumerate(range(330, 720, 48)):
        length = 74 if i % 3 == 0 else 44
        d.rounded_rectangle(
            [(bx - 1 * s, y * s), (bx + length * s, y * s + 14 * s)],
            radius=7 * s,
            fill=0,
        )

    # Ring, echoing the AOJ roundel.
    rx, ry, r, w = 700 * s, 340 * s, 92 * s, 30 * s
    d.ellipse([(rx - r, ry - r), (rx + r, ry + r)], fill=255)
    d.ellipse([(rx - r + w, ry - r + w), (rx + r - w, ry + r - w)], fill=0)

    if scale != 1.0:
        size = int(N * scale)
        small = m.resize((size, size), Image.LANCZOS)
        m = Image.new("L", (N, N), 0)
        m.paste(small, ((N - size) // 2, (N - size) // 2))
    return m


def red_background() -> Image.Image:
    grad = Image.new("RGB", (1, N))
    for y in range(N):
        t = y / (N - 1)
        grad.putpixel(
            (0, y),
            tuple(round(a + (b - a) * t) for a, b in zip(RED_TOP, RED_BOTTOM)),
        )
    return grad.resize((N, N))


def finish(img: Image.Image, size: int = 1024) -> Image.Image:
    return img.resize((size, size), Image.LANCZOS)


def main(out_dir: str) -> None:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    # Full-bleed icon (iOS, legacy Android, web).
    icon = red_background()
    icon.paste((255, 255, 255), mask=mark_mask())
    finish(icon).save(out / "icon.png")

    # Adaptive foreground: launchers crop to the centre ~66%, so shrink.
    fg = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    fg.paste((255, 255, 255, 255), mask=mark_mask(scale=0.66))
    finish(fg).save(out / "foreground.png")

    # In-app logo: rounded-square icon with transparent corners.
    corners = Image.new("L", (N, N), 0)
    ImageDraw.Draw(corners).rounded_rectangle(
        [(0, 0), (N - 1, N - 1)], radius=int(N * 0.225), fill=255
    )
    logo = icon.convert("RGBA")
    logo.putalpha(corners)
    finish(logo, 512).save(out / "mark.png")


if __name__ == "__main__":
    main(sys.argv[1])
