#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ICON_DIR="LifehackWatchApp Watch App/Assets.xcassets/AppIcon.appiconset"
# Keep only Contents.json and marketing icon
find "$ICON_DIR" -type f ! -name 'Contents.json' ! -name 'watch_marketing_1024x1024@1x.png' -print -delete
