#!/bin/bash
set -euo pipefail
native_root="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(dirname "$native_root")"
engine_root="${CONVERTY_ENGINE_DIR:-}"
engine="${CONVERTY_FFMPEG:-${engine_root:+$engine_root/prefix/bin/ffmpeg}}"
engine="${engine:-$HOME/.local/bin/ffmpeg}"
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
shasum -a 256 "$engine" | awk '{print $1 "  ffmpeg (build input)"}' >> "$native_root/Resources/FFmpeg-build.txt"
if [[ -n "$engine_root" ]]; then
    python3 - "$engine_root" "$engine" <<'PY'
import hashlib, json, pathlib, sys
root, engine = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
record = json.loads((root / 'provenance.json').read_text())
if hashlib.sha256(engine.read_bytes()).hexdigest() != record['ffmpeg_sha256']:
    raise SystemExit('Engine does not match its source-build provenance.')
PY
    cp "$engine_root/notices/All-Licenses.txt" "$native_root/Resources/MediaEngineNotices.txt"
    cp "$engine_root/notices/sources.json" "$native_root/Resources/MediaEngineSources.json"
    cp "$engine_root/provenance.json" "$native_root/Resources/MediaEngineProvenance.json"
else
    # These are generated resources, removed to avoid attributing an unrelated engine.
    rm -f "$native_root/Resources/MediaEngineNotices.txt" "$native_root/Resources/MediaEngineSources.json" "$native_root/Resources/MediaEngineProvenance.json"
fi
xcodegen generate --spec "$native_root/project.yml"
xcodebuild -project "$native_root/Converty.xcodeproj" -scheme Converty -configuration Release -derivedDataPath "$native_root/.build/xcode" ARCHS="$(lipo -archs "$engine")" build
mkdir -p "$repo_root/dist-native"
# ditto updates the generated app only; source and user output files are never removed.
ditto "$native_root/.build/xcode/Build/Products/Release/Converty.app" "$repo_root/dist-native/Converty.app"
identity="${CONVERTY_SIGNING_IDENTITY:--}"
sign_options=(--force --sign "$identity")
if [[ "$identity" != '-' ]]; then
    sign_options+=(--options runtime --timestamp)
fi
codesign "${sign_options[@]}" "$repo_root/dist-native/Converty.app/Contents/Resources/bin/ffmpeg"
codesign "${sign_options[@]}" "$repo_root/dist-native/Converty.app"
codesign --verify --deep --strict "$repo_root/dist-native/Converty.app"
echo "Built $repo_root/dist-native/Converty.app"
