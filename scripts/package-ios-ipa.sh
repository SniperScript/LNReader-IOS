#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

OUTPUT_DIR="$PROJECT_ROOT/ios/build/outputs"
IPA_PATH="$OUTPUT_DIR/LNReader-iOS.ipa"

# Find LNReader.app
APP_DIR=""
POSSIBLE_PATHS=(
  "$PROJECT_ROOT/ios/build/Build/Products/Release-iphoneos/LNReader.app"
  "$PROJECT_ROOT/ios/build/Release-iphoneos/LNReader.app"
)

for p in "${POSSIBLE_PATHS[@]}"; do
  if [ -d "$p" ]; then
    APP_DIR="$p"
    break
  fi
done

if [ -z "$APP_DIR" ]; then
  APP_DIR=$(find "$PROJECT_ROOT/ios" -name "LNReader.app" -type d 2>/dev/null | head -n 1)
fi

if [ -z "$APP_DIR" ] || [ ! -d "$APP_DIR" ]; then
  echo "Error: LNReader.app not found in ios build directory. Run build:release:ios first."
  exit 1
fi

echo "Packaging $APP_DIR into IPA..."
mkdir -p "$OUTPUT_DIR"
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/Payload"
cp -R "$APP_DIR" "$TMP_DIR/Payload/"
cd "$TMP_DIR"
zip -r -q "LNReader-iOS.ipa" Payload
cd "$PROJECT_ROOT"
mv "$TMP_DIR/LNReader-iOS.ipa" "$IPA_PATH"
rm -rf "$TMP_DIR"

echo "Successfully packaged IPA: $IPA_PATH"
