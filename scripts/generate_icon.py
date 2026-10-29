#!/usr/bin/env python3
import os
import subprocess
import shutil
import json
from PIL import Image, ImageFilter

def create_icon():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.abspath(os.path.join(script_dir, ".."))
    logo_path = os.path.join(script_dir, "finch_logo.png")
    
    if not os.path.exists(logo_path):
        print(f"Error: {logo_path} not found")
        return

    src = Image.open(logo_path).convert("RGBA")
    size = 1024
    target_dim = 880
    scale = min(target_dim / src.width, target_dim / src.height)
    new_w = int(src.width * scale)
    new_h = int(src.height * scale)
    resized_src = src.resize((new_w, new_h), Image.Resampling.LANCZOS)

    # Soft ambient drop shadow for native macOS look
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pos_x = (size - new_w) // 2
    pos_y = (size - new_h) // 2 + 12
    alpha = resized_src.split()[3]
    shadow_layer = Image.new("RGBA", (new_w, new_h), (0, 0, 0, 95))
    shadow.paste(shadow_layer, (pos_x, pos_y), alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=16))

    master = Image.alpha_composite(Image.new("RGBA", (size, size), (0, 0, 0, 0)), shadow)
    master.paste(resized_src, ((size - new_w) // 2, (size - new_h) // 2), resized_src)

    iconset_dir = os.path.join(root_dir, "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

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
        res = master.resize((sz, sz), Image.Resampling.LANCZOS)
        res.save(os.path.join(iconset_dir, filename))

    icns_path = os.path.join(root_dir, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    shutil.rmtree(iconset_dir)
    print("Created AppIcon.icns successfully from Finch logo!")

    # Now create Assets.xcassets and compile Assets.car for WidgetKit & macOS 14+
    xcassets_dir = os.path.join(root_dir, "Assets.xcassets")
    appiconset_dir = os.path.join(xcassets_dir, "AppIcon.appiconset")
    os.makedirs(appiconset_dir, exist_ok=True)

    contents = {
        "images": [
            {"idiom": "mac", "size": "16x16", "scale": "1x", "filename": "icon_16x16.png"},
            {"idiom": "mac", "size": "16x16", "scale": "2x", "filename": "icon_16x16@2x.png"},
            {"idiom": "mac", "size": "32x32", "scale": "1x", "filename": "icon_32x32.png"},
            {"idiom": "mac", "size": "32x32", "scale": "2x", "filename": "icon_32x32@2x.png"},
            {"idiom": "mac", "size": "128x128", "scale": "1x", "filename": "icon_128x128.png"},
            {"idiom": "mac", "size": "128x128", "scale": "2x", "filename": "icon_128x128@2x.png"},
            {"idiom": "mac", "size": "256x256", "scale": "1x", "filename": "icon_256x256.png"},
            {"idiom": "mac", "size": "256x256", "scale": "2x", "filename": "icon_256x256@2x.png"},
            {"idiom": "mac", "size": "512x512", "scale": "1x", "filename": "icon_512x512.png"},
            {"idiom": "mac", "size": "512x512", "scale": "2x", "filename": "icon_512x512@2x.png"}
        ],
        "info": {"author": "xcode", "version": 1}
    }
    with open(os.path.join(appiconset_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

    for sz, filename in icon_sizes:
        res = master.resize((sz, sz), Image.Resampling.LANCZOS)
        res.save(os.path.join(appiconset_dir, filename))

    env = os.environ.copy()
    env["DEVELOPER_DIR"] = "/Applications/Xcode.app/Contents/Developer"
    
    import tempfile
    temp_actool_dir = tempfile.mkdtemp()
    partial_plist = os.path.join(temp_actool_dir, "partial.plist")
    
    actool_cmd = [
        "xcrun", "actool",
        xcassets_dir,
        "--compile", temp_actool_dir,
        "--platform", "macosx",
        "--target-device", "mac",
        "--minimum-deployment-target", "14.0",
        "--app-icon", "AppIcon",
        "--output-partial-info-plist", partial_plist
    ]
    subprocess.run(actool_cmd, env=env, check=True)
    
    # Copy Assets.car to root_dir
    compiled_assets = os.path.join(temp_actool_dir, "Assets.car")
    if os.path.exists(compiled_assets):
        shutil.copy2(compiled_assets, os.path.join(root_dir, "Assets.car"))
    
    shutil.rmtree(temp_actool_dir)
    shutil.rmtree(xcassets_dir)
    print("Created Assets.car successfully with AppIcon!")

if __name__ == "__main__":
    create_icon()
