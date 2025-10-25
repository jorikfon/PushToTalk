#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== PushToTalk Code Signing ===${NC}\n"

APP_NAME="PushToTalk"
APP_DIR="build/${APP_NAME}.app"
ENTITLEMENTS="Entitlements.plist"

# Check if app bundle exists
if [ ! -d "${APP_DIR}" ]; then
    echo -e "${RED}❌ App bundle not found at ${APP_DIR}${NC}"
    echo -e "${YELLOW}Run ./build_app.sh first${NC}"
    exit 1
fi

# Check if Entitlements file exists
if [ ! -f "${ENTITLEMENTS}" ]; then
    echo -e "${RED}❌ Entitlements.plist not found${NC}"
    exit 1
fi

# Check if we're on macOS
if [ "$(uname)" != "Darwin" ]; then
    echo -e "${RED}❌ Code signing is only available on macOS${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/5] Checking for available signing identities...${NC}"

# List available signing identities
echo -e "\n${BLUE}Available Developer ID Application certificates:${NC}"
security find-identity -v -p codesigning | grep "Developer ID Application" || true

echo -e "\n${BLUE}Available Apple Development certificates:${NC}"
security find-identity -v -p codesigning | grep "Apple Development" || true

echo ""

# Prompt for signing identity
read -p "Enter signing identity (or press Enter for ad-hoc signing): " SIGNING_IDENTITY

if [ -z "$SIGNING_IDENTITY" ]; then
    echo -e "${YELLOW}⚠️  Using ad-hoc signing (for local testing only)${NC}"
    SIGN_ARGS="--sign -"
else
    echo -e "${GREEN}✅ Using identity: ${SIGNING_IDENTITY}${NC}"
    SIGN_ARGS="--sign \"${SIGNING_IDENTITY}\""
fi

# Sign the app
echo -e "\n${YELLOW}[2/5] Signing the app bundle...${NC}"

# Sign with entitlements
if [ -z "$SIGNING_IDENTITY" ]; then
    # Ad-hoc signing
    codesign \
        --sign - \
        --force \
        --deep \
        --timestamp \
        --options runtime \
        --entitlements "${ENTITLEMENTS}" \
        "${APP_DIR}"
else
    # Developer ID signing
    codesign \
        --sign "${SIGNING_IDENTITY}" \
        --force \
        --deep \
        --timestamp \
        --options runtime \
        --entitlements "${ENTITLEMENTS}" \
        "${APP_DIR}"
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ App signed successfully${NC}"
else
    echo -e "${RED}❌ Signing failed${NC}"
    exit 1
fi

# Verify signature
echo -e "\n${YELLOW}[3/5] Verifying signature...${NC}"
codesign --verify --deep --strict --verbose=2 "${APP_DIR}" 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Signature verification passed${NC}"
else
    echo -e "${RED}❌ Signature verification failed${NC}"
    exit 1
fi

# Display signature info
echo -e "\n${YELLOW}[4/5] Displaying signature information...${NC}"
codesign -dvv "${APP_DIR}" 2>&1 | grep -E "Authority|Identifier|Format|Signature|Timestamp"

# Check Gatekeeper assessment
echo -e "\n${YELLOW}[5/5] Checking Gatekeeper assessment...${NC}"

if [ -z "$SIGNING_IDENTITY" ]; then
    echo -e "${YELLOW}⚠️  Ad-hoc signed apps will not pass Gatekeeper${NC}"
    echo -e "${YELLOW}⚠️  Users will need to: Right-click > Open${NC}"
else
    spctl -a -t exec -vv "${APP_DIR}" 2>&1 || {
        echo -e "${YELLOW}⚠️  Gatekeeper assessment failed${NC}"
        echo -e "${YELLOW}⚠️  App needs to be notarized for distribution${NC}"
    }
fi

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Code signing completed!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Instructions for notarization
if [ ! -z "$SIGNING_IDENTITY" ] && [[ $SIGNING_IDENTITY == *"Developer ID"* ]]; then
    echo -e "\n${BLUE}Next steps for distribution:${NC}"
    echo "  1. Create ZIP for notarization:"
    echo "     ditto -c -k --keepParent ${APP_DIR} build/${APP_NAME}.zip"
    echo ""
    echo "  2. Submit for notarization:"
    echo "     xcrun notarytool submit build/${APP_NAME}.zip \\"
    echo "       --apple-id \"your@email.com\" \\"
    echo "       --password \"app-specific-password\" \\"
    echo "       --team-id \"TEAM_ID\" \\"
    echo "       --wait"
    echo ""
    echo "  3. Staple notarization ticket:"
    echo "     xcrun stapler staple ${APP_DIR}"
    echo ""
    echo "  4. Create DMG:"
    echo "     ./create_dmg.sh"
fi

echo -e "\n${BLUE}Local testing:${NC}"
echo "  open ${APP_DIR}"
