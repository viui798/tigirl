#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cmake="${CMAKE_BIN:-/opt/homebrew/opt/cmake/bin/cmake}"
build="$root/build-macos"
dictionary="$root/build/ARM64/Release/tiger-v2.tcd"
destination="$HOME/Library/Input Methods/TigirlInputMethod.app"

if [[ ! -x "$cmake" ]]; then
  echo "CMake not found at $cmake" >&2
  exit 1
fi

mkdir -p "$root/build/ARM64/Release"
if [[ ! -f "$dictionary" ]]; then
  "$cmake" -S "$root/macos" -B "$build" -G 'Unix Makefiles'
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

mkdir -p "$HOME/Library/Input Methods"
if [[ -e "$destination" ]]; then
  mv "$destination" "${destination}.previous"
fi
ditto --norsrc "$build/TigirlInputMethod.app" "$destination"
xattr -cr "$destination"
codesign --force --deep --sign - --identifier com.viui.inputmethod.Tigirl "$destination"
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
codesign --verify --deep --strict "$destination"
echo "Installed: $destination"
echo "Log out and back in before the input source appears in the input menu."
