# ADB Remote for macOS

Native SwiftUI remote for Android Debug Bridge on macOS 26+. It uses the existing `/usr/local/bin/adb` installation and never bundles a second copy.

## Requirements

- macOS 26 or later
- Android SDK Platform-Tools 37.0.1 (`adb` 1.0.41) validated; newer stable versions are recommended.
- scrcpy 4.1 is the reference version for screen mirroring.

Install both dependencies with Homebrew:

```zsh
brew install --cask android-platform-tools
brew install scrcpy
```

At launch, the app checks `/opt/homebrew/bin`, `/usr/local/bin`, and `PATH`, then shows the detected versions and installation instructions when a dependency is missing.
- Full Xcode is required to create a signed `.app` / `.dmg`; Command Line Tools are enough for `swift build` and tests.

## Build and install

```zsh
swift test
chmod +x scripts/create-dmg.sh
scripts/create-dmg.sh
```

The installer image is created as `dist/ADB-Remote.dmg`. The script uses an ad-hoc signature; distribute outside your Mac only after signing with a Developer ID certificate and notarizing it.
