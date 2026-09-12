# ADB Remote for macOS

Native SwiftUI remote for Android Debug Bridge on macOS 26+. It uses the existing `/usr/local/bin/adb` installation and never bundles a second copy.

## Requirements

- macOS 26 or later
- ADB 1.0.41+ at `/usr/local/bin/adb`
- `scrcpy` is optional, required only for screen mirroring: `brew install scrcpy`
- Full Xcode is required to create a signed `.app` / `.dmg`; Command Line Tools are enough for `swift build` and tests.

## Build and install

```zsh
swift test
chmod +x scripts/create-dmg.sh
scripts/create-dmg.sh
```

The installer image is created as `dist/ADB-Remote.dmg`. The script uses an ad-hoc signature; distribute outside your Mac only after signing with a Developer ID certificate and notarizing it.
