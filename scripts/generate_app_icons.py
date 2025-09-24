#!/usr/bin/env python3
"""
Generate iOS app icons for primary (AppIcon.appiconset) and alternate (AppIcon-Dark.appiconset)
from 1024x1024 base artwork files.

Usage:
  python3 scripts/generate_app_icons.py --primary path/to/primary_1024.png --dark path/to/dark_1024.png

Notes:
- Preserves existing Contents.json files, only writes the filenames specified therein.
- Supports PNG or JPEG input; outputs JPEG by default if input is JPEG, otherwise PNG.
- Requires macOS 'sips' tool.
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


def run(cmd):
    subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)


def pixels(size_str: str, scale_str: str) -> int:
    w = float(size_str.split("x")[0])
    s = int(scale_str.replace("x", ""))
    return int(round(w * s))


def choose_ext(path: Path) -> str:
    ext = path.suffix.lower()
    if ext in {".jpg", ".jpeg"}:
        return ".jpeg"
    return ".png"


def generate_for_set(base_art: Path, contents_path: Path):
    with open(contents_path, "r") as f:
        data = json.load(f)
    images = data.get("images", [])
    out_ext = choose_ext(base_art)

    for img in images:
        fn = img.get("filename")
        size = img.get("size")
        scale = img.get("scale")
        if not fn or not size or not scale:
            continue
        out_path = contents_path.parent / fn
        n = pixels(size, scale)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        # Convert and resize from base artwork
        run(["sips", "-s", "format", out_ext.lstrip("."), "-z", str(n), str(n), str(base_art), "--out", str(out_path)])
        print(f"wrote {out_path} -> {n}x{n}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--primary", type=Path, required=False, help="Path to 1024x1024 primary artwork")
    ap.add_argument("--dark", type=Path, required=False, help="Path to 1024x1024 dark artwork")
    args = ap.parse_args()

    if args.primary:
        generate_for_set(args.primary, APPICON / "Contents.json")
    if args.dark:
        generate_for_set(args.dark, APPICON_DARK / "Contents.json")

    if not args.primary and not args.dark:
        ap.error("Provide at least one of --primary or --dark")


if __name__ == "__main__":
    main()
