#!/bin/bash
set -euo pipefail
native_root="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(dirname "$native_root")"
engine="${CONVERTY_FFMPEG:-$HOME/.local/bin/ffmpeg}"
if [[ ! -x "$engine" ]]; then
    echo 'Set CONVERTY_FFMPEG to a self-contained FFmpeg executable.' >&2
    exit 1
fi
if otool -L "$engine" | tail -n +2 | awk '{print $1}' | /usr/bin/grep -Ev '^(/usr/lib/|/System/Library/)' >/dev/null; then
    echo 'FFmpeg depends on non-system libraries. Use a self-contained build.' >&2
    exit 1
fi
mkdir -p "$native_root/Resources/bin"
cp "$engine" "$native_root/Resources/bin/ffmpeg"
chmod +x "$native_root/Resources/bin/ffmpeg"
# Xcode compiles Artwork/AppIcon.icon into layered Tahoe assets and a legacy ICNS.
cp "$repo_root/LICENSE" "$native_root/Resources/LICENSE.txt"
"$engine" -version > "$native_root/Resources/FFmpeg-build.txt"
shasum -a 256 "$engine" >> "$native_root/Resources/FFmpeg-build.txt"
xcodegen generate --spec "$native_root/project.yml"
xcodebuild -project "$native_root/Converty.xcodeproj" -scheme Converty -configuration Release -derivedDataPath "$native_root/.build/xcode" ARCHS="$(lipo -archs "$engine")" build
mkdir -p "$repo_root/dist-native"
# ditto updates the generated app only; source and user output files are never removed.
ditto "$native_root/.build/xcode/Build/Products/Release/Converty.app" "$repo_root/dist-native/Converty.app"
codesign --force --sign - "$repo_root/dist-native/Converty.app/Contents/Resources/bin/ffmpeg"
codesign --force --sign - "$repo_root/dist-native/Converty.app"
codesign --verify --deep --strict "$repo_root/dist-native/Converty.app"
echo "Built $repo_root/dist-native/Converty.app"
