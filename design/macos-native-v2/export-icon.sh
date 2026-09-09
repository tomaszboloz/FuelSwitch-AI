#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p FuelSwitch.iconset png
sips -z 1024 1024 icon-source.png --out icon-1024.png >/dev/null
for size in 16 32 64 128 256 512; do
  sips -z "$size" "$size" icon-1024.png --out "png/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" icon-1024.png --out "png/icon_${size}x${size}@2x.png" >/dev/null
done
# Apple's iconset schema represents 64 px as 32@2x, not icon_64x64.
for size in 16 32 128 256 512; do
  cp "png/icon_${size}x${size}.png" "FuelSwitch.iconset/icon_${size}x${size}.png"
  cp "png/icon_${size}x${size}@2x.png" "FuelSwitch.iconset/icon_${size}x${size}@2x.png"
done
iconutil -c icns FuelSwitch.iconset -o FuelSwitch.icns
