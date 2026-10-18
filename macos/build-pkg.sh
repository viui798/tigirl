#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cmake="${CMAKE_BIN:-/opt/homebrew/opt/cmake/bin/cmake}"
build="$root/build-macos"
dictionary="$root/build/ARM64/Release/tiger-v2.tcd"
stage="$(mktemp -d /tmp/tigirl-pkg.XXXXXX)"
scripts="$stage/scripts"
version="0.3.4"
output="${1:-$root/build/Tigirl-macOS-$version.pkg}"
component="$build/Tigirl-component.pkg"
distribution="$build/Tigirl-distribution.xml"
# Ad-hoc signing is enough for a locally built input method. Set CODESIGN_ID to
# an "Apple Development: ..." identity when distributing the package.
sign_id="${CODESIGN_ID:--}"

if [[ ! -x "$cmake" ]]; then
  echo "CMake not found at $cmake" >&2
  exit 1
fi

if [[ ! -f "$dictionary" ]]; then
  "$cmake" -S "$root/macos" -B "$build" -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE=Release
  "$cmake" --build "$build" --target TigirlLexiconImport -j2
  "$build/TigirlLexiconImport" \
    "$root/resources/DefaultData/码表/虎码字词" \
    "$root/resources/DefaultData/拼音反查码表" \
    "$dictionary"
fi

"$cmake" -S "$root/macos" -B "$build" -G 'Unix Makefiles' \
  -DCMAKE_BUILD_TYPE=Release -DTIGIRL_DICTIONARY="$dictionary" \
  -DTIGIRL_SENTENCE_MODEL="${TIGIRL_SENTENCE_MODEL:-$root/data/Models/sentence-fivegram-mobile.bin}" \
  -DTIGIRL_SENTENCE_LEXICAL="${TIGIRL_SENTENCE_LEXICAL:-$root/resources/sentence-lexical-v1.bin}"
"$cmake" --build "$build" --target TigirlInputMethod -j2

mkdir -p "$stage" "$scripts" "$(dirname "$output")"
rm -rf "$stage/Tigirl.app"
# Avoid copying Finder/AppleDouble metadata into the install payload.
ditto --norsrc "$build/TigirlInputMethod.app" "$stage/Tigirl.app"
# pkgbuild serializes provenance/resource-fork attributes as ._ files; input
# method bundles must contain only their actual bundle contents.
xattr -cr "$stage/Tigirl.app" 2>/dev/null || true
# Sign after the bundle is complete: a linker-only signature is invalidated as
# soon as Info.plist/resources are added, and macOS then refuses the input
# method.
codesign --force --deep --sign "$sign_id" \
  --identifier com.viui.inputmethod.Tigirl "$stage/Tigirl.app"
codesign --verify --deep --strict "$stage/Tigirl.app"
cp "$root/macos/pkg-postinstall" "$scripts/postinstall"
chmod +x "$scripts/postinstall"
cat > "$scripts/preinstall" <<'PRE'
#!/bin/sh
root="${3:-/}"
# Remove an older build with a different bundle identifier so PackageKit does
# not relocate this payload into a ".localized" sibling directory.
rm -rf "$root/Library/Input Methods/TigirlInputMethod.app"
rm -rf "$root/Library/Input Methods/TigirlInputMethod.localized"
exit 0
PRE
chmod +x "$scripts/preinstall"

pkgbuild \
  --component "$stage/Tigirl.app" \
  --scripts "$scripts" \
  --identifier com.viui.inputmethod.Tigirl \
  --version "$version" \
  --install-location "/Library/Input Methods" \
  "$component"

# Also mark the component's PackageInfo, so Installer shows the logout action
# even when the product-level Distribution is ignored.
component_dir="$build/Tigirl-component-expanded"
rm -rf "$component_dir"
pkgutil --expand "$component" "$component_dir"
sed -i '' 's/postinstall-action="none"/postinstall-action="logout"/' "$component_dir/PackageInfo"
rm -f "$component"
pkgutil --flatten "$component_dir" "$component"

cat > "$distribution" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
  <title>Tigirl macOS</title>
  <options customize="never" allow-external-scripts="yes" postinstall-action="logout"/>
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
  <pkg-ref id="com.viui.inputmethod.Tigirl">#Tigirl-component.pkg</pkg-ref>
  <choices-outline>
    <line choice="default"/>
  </choices-outline>
  <choice id="default" visible="false">
    <pkg-ref id="com.viui.inputmethod.Tigirl"/>
  </choice>
</installer-gui-script>
EOF

rm -f "$output"
# productbuild keeps the Distribution (title, logout action); pkgutil --flatten
# of the component would drop it.
productbuild --distribution "$distribution" --package-path "$build" "$output"
pkgutil --check-signature "$output" || true
echo "Created: $output"
echo "A logout is required before the new input source appears in the input menu."
