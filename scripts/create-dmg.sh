#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${1:-release}"
build_dir="$root/.build/$configuration"
app_dir="$root/dist/ADB Remote.app"
dmg_path="$root/dist/ADB-Remote.dmg"

swift build -c "$configuration" --package-path "$root"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$root/dist"
cp "$build_dir/ADBRemote" "$app_dir/Contents/MacOS/ADBRemote"
cp "$root/Resources/Info.plist" "$app_dir/Contents/Info.plist"
codesign --force --deep --sign - "$app_dir"
rm -f "$dmg_path"
hdiutil create -volname "ADB Remote" -srcfolder "$app_dir" -ov -format UDZO "$dmg_path"
print "Created $dmg_path"
