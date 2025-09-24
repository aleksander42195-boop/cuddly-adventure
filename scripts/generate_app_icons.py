#!/usr/bin/env python3
"""
Generate app icons from a 1024x1024 base artwork for:
- iOS primary (AppIcon.appiconset)
- iOS alternate (AppIcon-Dark.appiconset)
- watchOS app (WatchApp/Assets.xcassets/AppIcon.appiconset)

Usage examples:
    python3 scripts/generate_app_icons.py --primary path/to/primary_1024.png
    python3 scripts/generate_app_icons.py --dark path/to/dark_1024.png
    python3 scripts/generate_app_icons.py --watch path/to/watch_1024.png
    python3 scripts/generate_app_icons.py --primary p.png --dark d.png --watch w.png

Notes:
- Preserves existing Contents.json files, writing the exact filenames listed there.
- Output image format follows each filename's extension in Contents.json (png or jpeg).
- Input may be PNG or JPEG; conversion is handled via macOS 'sips'.
"""
import argparse
import json
import os
import shlex
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPICON = ROOT / "LifehackApp/Assets.xcassets/AppIcon.appiconset"
APPICON_DARK = ROOT / "LifehackApp/Assets.xcassets/AppIcon-Dark.appiconset"
WATCH_APPICON = ROOT / "WatchApp/Assets.xcassets/AppIcon.appiconset"


def run(cmd):
    subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)


def pixels(size_str: str, scale_str: str) -> int:
    w = float(size_str.split("x")[0])
    s = int(scale_str.replace("x", ""))
    return int(round(w * s))


def ext_to_format(ext: str) -> str:
    """Return sips format string from a filename extension."""
    ext = ext.lower()
    if ext in (".jpg", ".jpeg"):
        return "jpeg"
    return "png"


def generate_for_set(base_art: Path, contents_path: Path):
    with open(contents_path, "r") as f:
        data = json.load(f)
    images = data.get("images", [])

    for img in images:
        fn = img.get("filename")
        size = img.get("size")
        scale = img.get("scale")
        if not fn or not size or not scale:
            continue
        out_path = contents_path.parent / fn
        # Resolve desired output format from filename extension
        fmt = ext_to_format(out_path.suffix)
        n = pixels(size, scale)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        # Convert and resize from base artwork
        run(["sips", "-s", "format", fmt, "-z", str(n), str(n), str(base_art), "--out", str(out_path)])
        print(f"wrote {out_path} -> {n}x{n}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--primary", type=Path, required=False, help="Path to 1024x1024 primary artwork")
    ap.add_argument("--dark", type=Path, required=False, help="Path to 1024x1024 dark artwork")
    ap.add_argument("--watch", type=Path, required=False, help="Path to 1024x1024 watchOS artwork")
    args = ap.parse_args()

    if args.primary:
        generate_for_set(args.primary, APPICON / "Contents.json")
    if args.dark:
        generate_for_set(args.dark, APPICON_DARK / "Contents.json")
    if args.watch:
        generate_for_set(args.watch, WATCH_APPICON / "Contents.json")

    if not args.primary and not args.dark and not args.watch:
        ap.error("Provide at least one of --primary, --dark or --watch")


if __name__ == "__main__":
    main()
