"""Generates the Android launcher icons and the 512px Play Store icon.

Brown background with the cburnett white knight (from the chessground package,
GPL-2+, same set the board uses). Run from apps/mobile:  python tool/make_icons.py
"""
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw

BG = (138, 90, 43, 255)  # #8A5A2B, the app's seed colour
ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android" / "app" / "src" / "main" / "res"
PUB = Path(os.environ["LOCALAPPDATA"]) / "Pub" / "Cache" / "hosted" / "pub.dev"
KNIGHT = PUB / "chessground-10.3.0" / "assets" / "piece_sets" / "cburnett" / "4.0x" / "wN.webp"

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def knight(size: int) -> Image.Image:
    return Image.open(KNIGHT).convert("RGBA").resize((size, size), Image.LANCZOS)


def legacy_icon(px: int) -> Image.Image:
    """Rounded square with the knight, for launchers without adaptive icons."""
    scale = 4  # draw big, then downsample for smooth corners
    big = px * scale
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * 0.22), fill=BG)
    k = knight(int(big * 0.78))
    off = (big - k.width) // 2
    img.alpha_composite(k, (off, off))
    return img.resize((px, px), Image.LANCZOS)


def adaptive_foreground(px: int) -> Image.Image:
    """108dp canvas; the launcher mask shows the centre ~66dp, so keep the knight inside it."""
    img = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    k = knight(int(px * 0.56))
    off = (px - k.width) // 2
    img.alpha_composite(k, (off, off))
    return img


def main() -> None:
    if not KNIGHT.exists():
        sys.exit(f"Knight image not found: {KNIGHT} (run flutter pub get first)")
    for name, d in DENSITIES.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        legacy_icon(round(48 * d)).save(folder / "ic_launcher.png")
        adaptive_foreground(round(108 * d)).save(folder / "ic_launcher_foreground.png")

    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )
    (RES / "values" / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#8A5A2B</color>\n</resources>\n',
        encoding="utf-8",
    )

    # Play Store listing icon: 512x512, full square (Play applies its own mask).
    store = Image.new("RGBA", (512, 512), BG)
    k = knight(400)
    store.alpha_composite(k, ((512 - 400) // 2, (512 - 400) // 2))
    out = ROOT / "store"
    out.mkdir(exist_ok=True)
    store.convert("RGB").save(out / "icon-512.png")
    print("icons written")


if __name__ == "__main__":
    main()
