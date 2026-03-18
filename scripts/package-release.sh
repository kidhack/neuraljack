#!/usr/bin/env bash
# Package NeuralJack for release: build + create DMG
# Run from the project root: ./scripts/package-release.sh [version]
# Example: ./scripts/package-release.sh 1.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# Require full Xcode (not just Command Line Tools)
if ! xcodebuild -version &>/dev/null; then
  echo "Error: xcodebuild requires full Xcode. Switch with:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

# Version: from argument, or parse from project.pbxproj
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION=$(grep -m1 "MARKETING_VERSION" NeuralJack.xcodeproj/project.pbxproj | sed 's/.*= //; s/;//; s/ *$//')
fi

DMG_NAME="NeuralJack-${VERSION}.dmg"
BUILD_DIR="$PROJECT_DIR/build/release"
STAGING_DIR="$PROJECT_DIR/build/dmg-staging"
OUTPUT_DIR="$PROJECT_DIR/dist"

echo "=== NeuralJack Release Packaging ==="
echo "Version: $VERSION"
echo "Output: $OUTPUT_DIR/$DMG_NAME"
echo ""

# Clean previous build
rm -rf "$BUILD_DIR" "$STAGING_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# Build for Release
echo "Building NeuralJack..."
xcodebuild build \
  -project NeuralJack.xcodeproj \
  -scheme NeuralJack \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR/derived" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

APP_PATH="$BUILD_DIR/derived/Build/Products/Release/NeuralJack.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: Built app not found at $APP_PATH"
  exit 1
fi

# Stage DMG contents (app only; create-dmg adds Applications symlink)
echo "Staging DMG contents..."
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"

# Remove existing DMG if present
rm -f "$OUTPUT_DIR/$DMG_NAME"

# Create DMG with professional layout (app + arrow + Applications)
BACKGROUND_PNG="$SCRIPT_DIR/dmg-background.png"
if command -v create-dmg &>/dev/null && [[ -f "$BACKGROUND_PNG" ]]; then
  echo "Creating $DMG_NAME (with drag-to-install layout)..."
  create-dmg \
    --volname "NeuralJack" \
    --background "$BACKGROUND_PNG" \
    --window-pos 200 120 \
    --window-size 540 400 \
    --icon-size 100 \
    --icon "NeuralJack.app" 120 190 \
    --hide-extension "NeuralJack.app" \
    --app-drop-link 400 190 \
    "$OUTPUT_DIR/$DMG_NAME" \
    "$STAGING_DIR"
else
  # Fallback: simple DMG without custom layout
  if ! command -v create-dmg &>/dev/null; then
    echo "Note: Install create-dmg for the arrow layout: brew install create-dmg"
  fi
  ln -sf /Applications "$STAGING_DIR/Applications"
  echo "Creating $DMG_NAME (simple layout)..."
  hdiutil create \
    -volname "NeuralJack" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$OUTPUT_DIR/$DMG_NAME"
fi

# Cleanup
rm -rf "$STAGING_DIR"
echo ""
echo "Done! DMG created at:"
echo "  $OUTPUT_DIR/$DMG_NAME"
echo ""
echo "Next steps:"
echo "  1. Create a GitHub release with tag v$VERSION"
echo "  2. Upload $DMG_NAME as a release asset"
echo "  3. Add release notes (changelog, macOS 15+ requirement)"
