# Tigirl / 虎娘 for macOS

Native macOS port of Tigirl. The input state machine and dictionary engine stay
in `native/`; the Windows TSF layer is replaced by an InputMethodKit adapter
(`TigirlInputController.mm`) and a non-activating Cocoa candidate panel
(`TigirlCandidateWindow.mm`).

Current bundle: `com.viui.inputmethod.Tigirl`, installed as
`/Library/Input Methods/Tigirl.app` (display name 虎娘 / Tigirl).

## Build

```sh
cmake -S macos -B build-macos -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE=Release
cmake --build build-macos --target TigirlInputMethod -j4
```

The dictionary (`build/ARM64/Release/tiger-v2.tcd`) is generated from
`resources/DefaultData/码表` by `TigirlLexiconImport`; `build-pkg.sh` creates it
automatically when missing.

Install for the current user:

```sh
macos/install.sh
```

Create a system-wide installer:

```sh
macos/build-pkg.sh
```

The package installs to `/Library/Input Methods/Tigirl.app`. Both scripts sign
the finished bundle (after `Info.plist` and resources are in place) and refresh
the input-source registration.

## macOS integration notes

These are the non-obvious requirements discovered while bringing the port up.

- **Bundle identifier shape matters.** macOS only treats `*.<vendor>.inputmethod.<Name>`
  as an input method. `com.viui.tigirl.inputmethod` (with `inputmethod` as the
  last component) is silently ignored; `com.viui.inputmethod.Tigirl` works.
- **Sign after the bundle is complete.** A linker-only signature is invalidated
  by `Info.plist`/resources added later, and the system then refuses the input
  method. Sign the staged `.app`, not the build output.
- **`InputMethodConnectionName` follows the bundle id:** use
  `com.viui.inputmethod.Tigirl_Connection`.
- **`NSPanel` hides on deactivation by default.** A candidate panel created as
  `NSPanel` must set `hidesOnDeactivate = NO` and use
  `NSWindowStyleMaskNonactivatingPanel`, otherwise it is dismissed immediately
  and never becomes visible.
- **InputMethodKit routes ordinary typing to `inputText:key:modifiers:client:`**
  on current macOS, not to `handleEvent:`. Both entry points must update marked
  text, commits *and* the candidate panel.
- **Punctuation needs Windows virtual-key codes.** The engine's selection keys
  compare against `VK_OEM_1` (186) and `VK_OEM_7` (222); passing the ASCII
  characters `';'`/`'\''` breaks semicolon/quote candidate selection.
- **Installer relocation.** PackageKit installs to `.localized/` when another
  bundle with the same name/identifier exists. Remove old copies before
  installing, and keep the payload bundle name unique (`Tigirl.app`).
- **LaunchServices and TIS caches.** A stale LaunchServices record pointing at
  a deleted build product makes the input source grey and unselectable. Clean
  it with `lsregister -u <path>` and re-register the installed bundle.
  Input-source registration is refreshed at login; log out/in after changing
  the identifier or the installed location.

## Known limitations

- **Candidate anchoring.** The panel follows the caret through
  `attributesForCharacterIndex:lineHeightRectangle:` (the same IMKTextInput call
  Squirrel uses), with `firstRectForCharacterRange:actualRange:` as a
  secondary probe and the pointer position as the last resort. Web views that
  implement none of the geometry APIs still get the pointer fallback.
- **First keystroke after activation.** The input method process is started on
  demand; the keystroke that triggers the launch can be consumed by the system.
  Squirrel has no special handling for this either: it relies on the process
  already running because IMKServer is created at launch. Pre-launching the
  binary (`open` or a login item) gives the same behaviour as Squirrel; a
  LaunchAgent would remove the remaining gap.
- **Distribution signing.** Packages and the app are ad-hoc signed. Installer
  therefore shows the "will run a program" script warning twice and does not
  offer the automatic logout action; both disappear with an Apple Developer ID
  signature.
- User-data paths, configuration, skin and sentence decoding are not ported yet.
