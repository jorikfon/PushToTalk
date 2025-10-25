#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== PushToTalk DMG Installer Creator ===${NC}\n"

APP_NAME="PushToTalk"
APP_DIR="build/${APP_NAME}.app"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="build/${DMG_NAME}"
VOL_NAME="${APP_NAME} ${VERSION}"

# Check if app bundle exists
if [ ! -d "${APP_DIR}" ]; then
    echo -e "${RED}❌ App bundle not found at ${APP_DIR}${NC}"
    echo -e "${YELLOW}Run ./build_app.sh first${NC}"
    exit 1
fi

# Check if app is signed
echo -e "${YELLOW}[1/5] Checking app signature...${NC}"
if codesign -dv "${APP_DIR}" 2>&1 | grep -q "Signature="; then
    echo -e "${GREEN}✅ App is signed${NC}"
else
    echo -e "${YELLOW}⚠️  App is not signed${NC}"
    echo -e "${YELLOW}⚠️  Run ./sign_app.sh for better distribution${NC}"
fi

# Create temporary directory for DMG contents
echo -e "\n${YELLOW}[2/5] Creating DMG staging directory...${NC}"
TMP_DIR=$(mktemp -d)
echo "  Staging dir: ${TMP_DIR}"

# Copy app to staging directory
cp -R "${APP_DIR}" "${TMP_DIR}/"

# Create Applications symlink
ln -s /Applications "${TMP_DIR}/Applications"

# Create README (optional)
cat > "${TMP_DIR}/README.txt" << 'EOF'
PushToTalk - Voice-to-Text for macOS
=====================================

Installation:
1. Drag PushToTalk.app to Applications folder
2. Launch PushToTalk from Applications or Spotlight
3. Grant permissions when prompted:
   - Microphone access (for voice recording)
   - Accessibility access (for F16 key monitoring and text insertion)

Usage:
- Look for the microphone icon in your menu bar
- Press and hold F16 to record
- Release F16 to transcribe and insert text at cursor

Settings:
- Click the menu bar icon for settings
- Choose Whisper model (tiny, base, small)
- Change hotkey (F13-F19, Right Cmd/Opt/Ctrl)
- View transcription history

Requirements:
- macOS 14.0 or later
- Apple Silicon (M1/M2/M3)

For issues or feedback:
https://github.com/yourusername/pushtotalk

Copyright © 2025. All rights reserved.
EOF

# Remove previous DMG
rm -f "${DMG_PATH}"

echo -e "\n${YELLOW}[3/5] Creating DMG...${NC}"

# Check if create-dmg is installed
if command -v create-dmg &> /dev/null; then
    echo "  Using create-dmg utility..."

    # Use create-dmg for prettier DMG
    create-dmg \
        --volname "${VOL_NAME}" \
        --volicon "${APP_DIR}/Contents/Resources/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 450 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 175 190 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 425 190 \
        --text-size 12 \
        --background-color "#ffffff" \
        --no-internet-enable \
        "${DMG_PATH}" \
        "${TMP_DIR}/" || {
            echo -e "${YELLOW}⚠️  create-dmg failed, falling back to hdiutil...${NC}"
            # Fallback to hdiutil
            hdiutil create -volname "${VOL_NAME}" -srcfolder "${TMP_DIR}" -ov -format UDZO "${DMG_PATH}"
        }
else
    echo "  Using hdiutil (install create-dmg for better DMGs: brew install create-dmg)..."

    # Fallback: create simple DMG with hdiutil
    hdiutil create \
        -volname "${VOL_NAME}" \
        -srcfolder "${TMP_DIR}" \
        -ov \
        -format UDZO \
        "${DMG_PATH}"
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ DMG created successfully${NC}"
else
    echo -e "${RED}❌ DMG creation failed${NC}"
    rm -rf "${TMP_DIR}"
    exit 1
fi

# Clean up staging directory
rm -rf "${TMP_DIR}"

# Verify DMG
echo -e "\n${YELLOW}[4/5] Verifying DMG...${NC}"
hdiutil verify "${DMG_PATH}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ DMG verification passed${NC}"
else
    echo -e "${RED}❌ DMG verification failed${NC}"
    exit 1
fi

# Display DMG info
echo -e "\n${YELLOW}[5/5] DMG Information:${NC}"
DMG_SIZE=$(du -sh "${DMG_PATH}" | cut -f1)
DMG_MD5=$(md5 -q "${DMG_PATH}")
DMG_SHA256=$(shasum -a 256 "${DMG_PATH}" | cut -d' ' -f1)

echo "  Name: ${DMG_NAME}"
echo "  Size: ${DMG_SIZE}"
echo "  Location: $(pwd)/${DMG_PATH}"
echo "  MD5: ${DMG_MD5}"
echo "  SHA256: ${DMG_SHA256}"

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ DMG installer created successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Instructions
echo -e "\n${BLUE}Distribution:${NC}"
echo "  1. Test the DMG: open ${DMG_PATH}"
echo "  2. Upload to GitHub Releases"
echo "  3. Generate release notes"

if codesign -dv "${APP_DIR}" 2>&1 | grep -q "Developer ID"; then
    echo -e "\n${BLUE}For App Store or wider distribution:${NC}"
    echo "  1. Notarize the DMG:"
    echo "     xcrun notarytool submit ${DMG_PATH} \\"
    echo "       --apple-id \"your@email.com\" \\"
    echo "       --password \"app-specific-password\" \\"
    echo "       --team-id \"TEAM_ID\" \\"
    echo "       --wait"
    echo ""
    echo "  2. Staple the DMG:"
    echo "     xcrun stapler staple ${DMG_PATH}"
fi

echo -e "\n${BLUE}Homebrew Cask (optional):${NC}"
echo "  Create a cask at: homebrew-cask/Casks/${APP_NAME}.rb"
echo "  SHA256: ${DMG_SHA256}"
