<p align="center">
  <a href="https://lnreader.app">
    <img src="./.github/readme-images/icon_new.png" align="center" width="128" />
  </a>
</p>

<h1 align="center">LNReader for iOS & iPadOS</h1>

<p align="center">
  LNReader is a free and open-source light novel reader for iOS, iPadOS, and Android, inspired by Tachiyomi.
  This repository provides official iOS and iPadOS compatibility with native modules, iPad multitasking, and automated IPA generation.
</p>

<div align="center">
  <a href="https://discord.gg/QdcWN4MD63">
    <img alt="Discord Chat" src="https://img.shields.io/discord/835746409357246465.svg?logo=discord&logoColor=white&logoWidth=20&labelColor=5865F2&color=4752C4&label=discord&style=flat">
  </a>
  <a href="https://github.com/SniperScript/LNReader-IOS/releases">
    <img alt="GitHub Releases" src="https://img.shields.io/github/v/release/SniperScript/LNReader-IOS?label=Release&labelColor=0d7377&color=084c4e&style=flat">
  </a>
  <a href="https://github.com/SniperScript/LNReader-IOS/actions/workflows/build-ios.yml">
    <img alt="iOS Build" src="https://img.shields.io/github/actions/workflow/status/SniperScript/LNReader-IOS/build-ios.yml?label=iOS%20IPA%20Build&labelColor=27303D&style=flat">
  </a>
</div>

---

## 📱 iPad & iOS Features

- **Native iPad Interface**: Full tablet resolution with responsive layouts, portrait & landscape orientation, and iPadOS Split View & Slide Over multitasking.
- **Identical UI & Experience**: Preserves the complete LNReader design, novel reader themes, custom fonts, CSS/JS injection, and plugin ecosystem.
- **Files App Integration**: Documents and backups are accessible directly inside the iPad's native **Files** app (`On My iPad > LNReader`).
- **Background Text-to-Speech (TTS)**: Native Apple Speech synthesis (`AVSpeechSynthesizer`) with lock screen media controls and background audio.
- **Full File & EPUB Support**: Import and export light novels in EPUB format with fast native C++ extraction and compilation.

---

## 📥 Installing on iPad / iPhone

### Method 1: Sideload via AltStore / SideStore (Recommended)
1. Download the latest **`LNReader-iOS.ipa`** from the [GitHub Actions Artifacts](https://github.com/SniperScript/LNReader-IOS/actions/workflows/build-ios.yml) or [Releases](https://github.com/SniperScript/LNReader-IOS/releases).
2. Open **AltStore** or **SideStore** on your iPad.
3. Tap the **+** icon in the My Apps tab and select `LNReader-iOS.ipa`.
4. Once installed, launch LNReader and enjoy reading!

### Method 2: Sideload via Sideloadly (PC / Mac)
1. Connect your iPad to your computer.
2. Drag and drop `LNReader-iOS.ipa` into [Sideloadly](https://sideloadly.io/).
3. Enter your Apple ID and click **Start** to install the app.

### Method 3: TrollStore (For supported iPadOS versions)
1. Download `LNReader-iOS.ipa` directly on your iPad.
2. Share the file to TrollStore to install without revokes.

---

## 🛠️ Building From Source

### Prerequisites
- Node.js 22+
- `pnpm` (run `corepack enable` or `npm install -g pnpm`)
- macOS with Xcode 15+ & CocoaPods (for local iOS builds)

### Build Commands
```bash
# Install dependencies
pnpm install

# Generate release environment
pnpm run generate:env:release

# Prebuild iOS Xcode project
npx expo prebuild --platform ios --clean

# Build with Xcode
pnpm run build:release:ios

# Package into .ipa
pnpm run build:package:ipa
```

Alternatively, push a commit or trigger the **Build iOS (IPA)** GitHub Actions workflow on your repository to automatically compile and generate the IPA in the cloud.

---

## 🧩 Plugins

LNReader does not have any affiliation with the content providers available.
Plugin requests should be created at [lnreader-plugins](https://github.com/lnreader/lnreader-plugins).

## 📄 License

[MIT](https://github.com/SniperScript/LNReader-IOS/blob/master/LICENSE)
