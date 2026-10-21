"""Draws the Android status-bar icon (white set-square on transparent) at
every density, from the same mark as the app icon.

Usage: python -I tool/make_notification_icon.py android/app/src/main/res
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from make_icon import mark_mask  # noqa: E402

DENSITIES = {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}


def main(res_dir: str) -> None:
    mask = mark_mask()
    # Crop to the mark with a little padding, as Android expects.
    box = mask.getbbox()
    pad = (box[2] - box[0]) // 12
    side = max(box[2] - box[0], box[3] - box[1]) + 2 * pad
    cx, cy = (box[0] + box[2]) // 2, (box[1] + box[3]) // 2
    mask = mask.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2))

    for density, size in DENSITIES.items():
        alpha = mask.resize((size, size), Image.LANCZOS)
        icon = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        icon.putalpha(alpha)
        out = Path(res_dir) / f"drawable-{density}"
        out.mkdir(parents=True, exist_ok=True)
        icon.save(out / "ic_stat_sitekit.png")


if __name__ == "__main__":
    main(sys.argv[1])
