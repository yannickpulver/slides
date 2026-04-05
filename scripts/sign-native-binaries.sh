#!/bin/bash
set -euo pipefail

# Signs all native macOS binaries inside JARs in the app bundle,
# then re-signs the app and creates a DMG.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Yannick Pulver (337L47P9N7)}"
ENTITLEMENTS="$PROJECT_DIR/composeApp/default-entitlements.plist"
APP_PATH="$PROJECT_DIR/composeApp/build/compose/binaries/main-release/app/Slides.app"
VERSION=$(cat "$PROJECT_DIR/VERSION")
DMG_PATH="$PROJECT_DIR/composeApp/build/compose/binaries/main-release/dmg/Slides-${VERSION}.dmg"
TEMP_DIR=$(mktemp -d)

echo "=== Signing identity: $IDENTITY"
echo "=== App: $APP_PATH"

# Step 1: Find all JARs containing macOS native binaries
echo ""
echo "=== Finding JARs with native macOS binaries..."
JARS_WITH_NATIVES=()
for jar in "$APP_PATH/Contents/app/"*.jar; do
    if jar tf "$jar" 2>/dev/null | grep -qE 'macosx'; then
        JARS_WITH_NATIVES+=("$jar")
        echo "  Found: $(basename "$jar")"
    fi
done

echo ""
echo "=== Signing binaries inside ${#JARS_WITH_NATIVES[@]} JARs..."

for jar in "${JARS_WITH_NATIVES[@]}"; do
    jar_name=$(basename "$jar")
    work_dir="$TEMP_DIR/$jar_name"
    mkdir -p "$work_dir"

    echo ""
    echo "--- Processing: $jar_name"

    # Extract JAR
    pushd "$work_dir" > /dev/null
    jar xf "$jar"

    # Find and sign ALL Mach-O binaries (dylibs, .so, executables, etc.)
    find . -type f | while read -r binary; do
        if file "$binary" | grep -q "Mach-O"; then
            echo "  Signing: $binary"
            codesign --force --options runtime --timestamp \
                --entitlements "$ENTITLEMENTS" \
                --sign "$IDENTITY" "$binary"
        fi
    done

    # Repackage JAR (preserving original structure)
    jar cf "$jar" .
    popd > /dev/null
done

# Step 2: Also sign any loose dylibs/binaries in the app bundle
echo ""
echo "=== Signing loose native binaries in app bundle..."
find "$APP_PATH/Contents" -type f \( -name "*.dylib" -o -name "*.jnilib" \) | while read -r binary; do
    if file "$binary" | grep -q "Mach-O"; then
        echo "  Signing: $binary"
        codesign --force --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" \
            --sign "$IDENTITY" "$binary"
    fi
done

# Step 3: Re-sign the entire app bundle
echo ""
echo "=== Re-signing app bundle..."
codesign --force --options runtime --timestamp --deep \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" "$APP_PATH"

# Step 4: Verify signing
echo ""
echo "=== Verifying signature..."
codesign --verify --deep --strict "$APP_PATH"
echo "  App signature valid!"

# Step 5: Create DMG with Applications symlink
echo ""
echo "=== Creating DMG..."
mkdir -p "$(dirname "$DMG_PATH")"
rm -f "$DMG_PATH"
DMG_STAGE="$TEMP_DIR/dmg-stage"
mkdir -p "$DMG_STAGE"
cp -R "$APP_PATH" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create -volname "Slides" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"

# Step 6: Sign the DMG itself
echo ""
echo "=== Signing DMG..."
codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "=== Done! DMG at: $DMG_PATH"
echo "=== Ready for notarization."
