# -*- coding: utf-8 -*-
"""Builds the Android launcher icons from the SmartFlow logo.

Two things a phone needs that a single PNG is not:

  * every density, because Android picks the closest one and scaling a
    small icon up on a large screen is visibly soft;
  * a background, because the mark is transparent and a launcher composites
    it over whatever wallpaper is behind it -- a blue-green gradient on a
    blue wallpaper disappears.

The background is white here rather than a colour: the mark already carries
two strong hues, and a third behind it fights them.

Also emits the adaptive-icon layers Android 8+ uses, where the system
decides the outline shape (circle, squircle, teardrop) and needs the mark
to sit inside the safe zone -- 66% of the canvas, per Google's spec.

    python tool/make_launcher_icons.py
"""

import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
SOURCE = r"C:\Users\gameboy\Downloads\SmartFlow.png"
RES = os.path.join(APP, "android", "app", "src", "main", "res")

BACKGROUND = (255, 255, 255, 255)

# Legacy icons: the mark fills most of the tile, with a small margin so it
# does not touch the rounded corners the launcher masks it with.
LEGACY = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
LEGACY_INSET = 0.84

# Adaptive foreground: 108dp canvas of which only the middle 72dp is
# guaranteed visible. Anything outside can be cropped by the mask.
ADAPTIVE = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}
ADAPTIVE_SAFE = 0.62


def trimmed(image):
    """Crops the transparent margin so the mark's own edges set the size."""
    box = image.getbbox()
    return image.crop(box) if box else image


def fitted(mark, canvas_size, fraction, background):
    """Centres the mark inside a square canvas at the given fraction."""
    target = int(canvas_size * fraction)
    scaled = mark.copy()
    scaled.thumbnail((target, target), Image.LANCZOS)

    canvas = Image.new("RGBA", (canvas_size, canvas_size), background)
    canvas.paste(
        scaled,
        ((canvas_size - scaled.width) // 2, (canvas_size - scaled.height) // 2),
        scaled,
    )
    return canvas


def main():
    if not os.path.exists(SOURCE):
        raise SystemExit("Logotip topilmadi: %s" % SOURCE)

    mark = trimmed(Image.open(SOURCE).convert("RGBA"))
    print("logotip: %dx%d (chetlari kesilgandan keyin)" % mark.size)
    print()

    print("ILOVA BELGISI")
    for folder, size in LEGACY.items():
        path = os.path.join(RES, folder, "ic_launcher.png")
        fitted(mark, size, LEGACY_INSET, BACKGROUND).save(path)
        print("  %-18s %dx%d" % (folder, size, size))

    print()
    print("ADAPTIV BELGI (Android 8+)")
    for folder, size in ADAPTIVE.items():
        path = os.path.join(RES, folder, "ic_launcher_foreground.png")
        # Transparent: the background layer is a solid colour resource, and
        # baking white in here would show as a square inside the mask.
        fitted(mark, size, ADAPTIVE_SAFE, (0, 0, 0, 0)).save(path)
        print("  %-18s %dx%d" % (folder, size, size))

    # The mark at full size, for the splash screen and anywhere else in the
    # app that shows the brand.
    assets = os.path.join(APP, "assets", "brand")
    os.makedirs(assets, exist_ok=True)
    logo = trimmed(Image.open(SOURCE).convert("RGBA"))
    logo.thumbnail((512, 512), Image.LANCZOS)
    logo.save(os.path.join(assets, "logo.png"))
    print()
    print("ILOVA ICHIDA: assets/brand/logo.png  (%dx%d)" % logo.size)


if __name__ == "__main__":
    main()
