#!/usr/bin/env python3
import os
import subprocess
from PIL import Image, ImageDraw

def create_icon():
    os.makedirs("AppIcon.iconset", exist_ok=True)
    
    # 1024x1024 master icon
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Outer squircle / rounded rectangle (Apple macOS style icon shape)
    margin = 80
    radius = 210
    box = [margin, margin, size - margin, size - margin]

    # Gradient background: YouTube Red (#FF0000 -> #B30000)
    # We create a gradient image and mask it with the rounded rect
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(box, radius=radius, fill=255)

    grad = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad_draw = ImageDraw.Draw(grad)
    for y in range(margin, size - margin):
        ratio = (y - margin) / (size - 2 * margin)
        # Red gradient
        r = int(255 - ratio * 45)
        g = int(20 - ratio * 20)
        b = int(20 - ratio * 20)
        grad_draw.line([(margin, y), (size - margin, y)], fill=(r, g, b, 255))

    img.paste(grad, (0, 0), mask)

    # Subtle inner border for glassmorphism
    border_draw = ImageDraw.Draw(img)
    border_draw.rounded_rectangle(box, radius=radius, outline=(255, 255, 255, 70), width=8)

    # Play button triangle in center
    cx, cy = size // 2, size // 2 - 20
    tri_w, tri_h = 160, 200
    points = [
        (cx - tri_w // 2, cy - tri_h // 2),
        (cx - tri_w // 2, cy + tri_h // 2),
        (cx + tri_w // 2 + 20, cy)
    ]
    border_draw.polygon(points, fill=(255, 255, 255, 250))

    # Widget mini bars / stats indicator at the bottom
    bar_y = cy + 180
    bar_w = 40
    gap = 25
    bars = [60, 110, 85, 140]
    total_w = len(bars) * bar_w + (len(bars) - 1) * gap
    start_x = cx - total_w // 2

    for i, h in enumerate(bars):
        bx = start_x + i * (bar_w + gap)
        by = bar_y - h
        border_draw.rounded_rectangle([bx, by, bx + bar_w, bar_y], radius=12, fill=(255, 255, 255, 220))

    # Save sizes for iconset
    icon_sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    for sz, filename in icon_sizes:
        resized = img.resize((sz, sz), Image.Resampling.LANCZOS)
        resized.save(os.path.join("AppIcon.iconset", filename))

    # Run iconutil to create AppIcon.icns
    subprocess.run(["iconutil", "-c", "icns", "AppIcon.iconset", "-o", "AppIcon.icns"], check=True)
    # Cleanup iconset
    import shutil
    shutil.rmtree("AppIcon.iconset")
    print("Created AppIcon.icns successfully!")

if __name__ == "__main__":
    create_icon()
