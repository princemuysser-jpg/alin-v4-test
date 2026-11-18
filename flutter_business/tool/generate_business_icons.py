#!/usr/bin/env python3
"""Create ALIN Business launcher icons from one controlled A-mark design.

Requires Pillow. Used after flutter create for native platform assets and
before flutter build web for PWA icons.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024

def build_icon():
    image = Image.new("RGB", (SIZE, SIZE), "#102B4E")
    draw = ImageDraw.Draw(image)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        draw.line((0, y, SIZE, y), fill=(
            int(16 - 7*t), int(43 + 12*t), int(78 + 35*t)
        ))
    scale = SIZE / 512
    def poly(points, color):
        draw.polygon([(round(x*scale), round(y*scale)) for x, y in points], fill=color)
    # A-shaped business monogram: light left stroke, teal right stroke,
    # and a gold growth arc. Keep large open negative space at small sizes.
    poly([(85,405),(225,105),(250,88),(274,100),(151,405)], "#F8FAFF")
    poly([(269,104),(422,405),(330,405),(224,194)], "#19C8B7")
    poly([(95,405),(131,352),(177,311),(223,282),(272,262),
          (322,250),(370,247),(420,258),(372,255),(326,264),
          (278,281),(228,308),(182,340),(141,374)], "#E2C178")
    return image

def save(image, path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(path, "PNG", optimize=True)
    print(f"icon: {path.relative_to(ROOT)} ({size}px)")

def web(master):
    for size in [192, 512]:
        save(master, ROOT / "web" / "icons" / f"business-icon-{size}.png", size)

def android(master):
    directory = ROOT / "android" / "app" / "src" / "main" / "res"
    for density, size in [
        ("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
        ("xxhdpi", 144), ("xxxhdpi", 192)
    ]:
        save(master, directory / f"mipmap-{density}" / "ic_launcher.png", size)
    # Force Android 8+ launcher to use the same branded icon.
    adaptive = directory / "mipmap-anydpi-v26"
    adaptive.mkdir(parents=True, exist_ok=True)
    (adaptive / "ic_launcher.xml").write_text(
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">'
        '<background android:drawable="@color/alin_business_icon_background"/>'
        '<foreground android:drawable="@mipmap/ic_launcher_foreground"/>'
        '</adaptive-icon>', encoding="utf-8"
    )
    values = directory / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "alin_business_icon_background.xml").write_text(
        '<resources><color name="alin_business_icon_background">#102B4E</color></resources>',
        encoding="utf-8"
    )
    # Transparent foreground with the same monogram, kept in the safe center.
    icon = master.resize((432,432), Image.Resampling.LANCZOS)
    foreground = Image.new("RGBA", (432,432), (0,0,0,0))
    foreground.paste(icon, (0,0))
    save(foreground, directory / "mipmap-xxxhdpi" / "ic_launcher_foreground.png", 432)
    for density in ["mdpi","hdpi","xhdpi","xxhdpi"]:
        side = {"mdpi":108,"hdpi":162,"xhdpi":216,"xxhdpi":324}[density]
        save(foreground, directory / f"mipmap-{density}" / "ic_launcher_foreground.png", side)

def ios(master):
    directory = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    contents = directory / "Contents.json"
    if not contents.exists():
        raise RuntimeError("Flutter iOS AppIcon.appiconset missing")
    data = json.loads(contents.read_text(encoding="utf-8"))
    for entry in data.get("images", []):
        name = entry.get("filename")
        size_string = entry.get("size", "0x0")
        if not name:
            continue
        points = float(size_string.split("x")[0])
        scale = int(entry.get("scale", "1x").rstrip("x"))
        px = int(round(points * scale))
        if px:
            save(master, directory / name, px)
    # Generated Flutter iOS icons may use multiple filenames at the same size.

def main():
    platform = sys.argv[1] if len(sys.argv) > 1 else "web"
    master = build_icon()
    if platform == "web":
        web(master)
    elif platform == "android":
        android(master)
    elif platform == "ios":
        ios(master)
    else:
        raise SystemExit(f"unknown platform: {platform}")

if __name__ == "__main__":
    main()
