"""Generates Android native launch-screen images from the AOJ mark, sized to
match the Flutter splash (mark at 120 dp) so the handover is seamless.

Usage: python -I tool/make_splash_assets.py assets/images/aoj_mark.png android/app/src/main/res

Writes, per density:
  drawable-<d>/splash_mark.png  120 dp mark (pre-Android 12 launch screen)
  drawable-<d>/splash_icon.png  288 dp canvas with the mark centred
                                (Android 12+ splash icon; the system shows it
                                at 288 dp and masks to the centre circle)
"""
import sys
from pathlib import Path

from PIL import Image

SCALES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
MARK_DP = 120
CANVAS_DP = 288


def main(mark_path: str, res_dir: str) -> None:
    mark = Image.open(mark_path).convert("RGBA")
    for density, scale in SCALES.items():
        out = Path(res_dir) / f"drawable-{density}"
        out.mkdir(parents=True, exist_ok=True)

        size = round(MARK_DP * scale)
        sized = mark.resize((size, size), Image.LANCZOS)
        sized.save(out / "splash_mark.png")

        canvas_px = round(CANVAS_DP * scale)
        canvas = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
        offset = (canvas_px - size) // 2
        canvas.paste(sized, (offset, offset), sized)
        canvas.save(out / "splash_icon.png")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
