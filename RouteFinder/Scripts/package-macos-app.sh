#!/bin/bash
set -euo pipefail

# Package the macOS GUI as a signed RouteFinder.app (data-protection Keychain).
#
# Usage:
#   ./Scripts/package-macos-app.sh          # debug build + codesign
#   ./Scripts/package-macos-app.sh release  # release build + codesign
#   ./Scripts/package-macos-app.sh open     # build debug, codesign, and launch
#
# PREFERRED: open RouteFinderApp.xcodeproj → scheme RouteFinderMac → Run.
# Xcode applies hardened runtime + provisioning correctly. This script is a fallback.
#
# Bare `swift run RouteFinderMacApp` has no entitlements — Keychain Always Allow
# will not stick across rebuilds.
#
# If you see "module compiled with Swift X cannot be imported by Swift Y", run:
#   rm -rf .build && ./Scripts/package-macos-app.sh open

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="debug"
LAUNCH=false
if [[ "${1:-}" == "release" ]]; then
    CONFIG="release"
elif [[ "${1:-}" == "open" ]]; then
    LAUNCH=true
fi

BUILD_PRODUCT="RouteFinderMacApp"
TARGET_NAME="RouteFinderMacApp"
BUNDLE_NAME="RouteFinder"
PRODUCT_DIR=".build/arm64-apple-macosx/${CONFIG}"
BUNDLE="${ROOT}/${BUNDLE_NAME}.app"
STALE_BUNDLE="${ROOT}/RouteFinderApp.app"
STALE_MAC_BUNDLE="${ROOT}/RouteFinderMacApp.app"
ENTITLEMENTS_SRC="${ROOT}/RouteFinder.entitlements"
# Team ID from RouteFinderApp.xcodeproj (Automatic signing).
TEAM_ID="${ROUTEFINDER_DEVELOPMENT_TEAM:-GHBHLM9UAX}"

if [[ -f "${PRODUCT_DIR}/${BUILD_PRODUCT}" ]]; then
    BINARY="${PRODUCT_DIR}/${BUILD_PRODUCT}"
    EXEC_NAME="${BUILD_PRODUCT}"
elif [[ -f "${PRODUCT_DIR}/${TARGET_NAME}" ]]; then
    BINARY="${PRODUCT_DIR}/${TARGET_NAME}"
    EXEC_NAME="${TARGET_NAME}"
else
    BINARY="${PRODUCT_DIR}/${TARGET_NAME}"
    EXEC_NAME="${TARGET_NAME}"
fi

echo "Building ${BUILD_PRODUCT} (${CONFIG})..."
BUILD_LOG="$(mktemp)"
if ! swift build --product "${BUILD_PRODUCT}" -c "${CONFIG}" 2>&1 | tee "${BUILD_LOG}"; then
    if grep -q "cannot be imported by the Swift" "${BUILD_LOG}"; then
        echo "" >&2
        echo "Stale Swift build cache detected. Run:" >&2
        echo "  rm -rf .build && ./Scripts/package-macos-app.sh ${1:-}" >&2
    fi
    rm -f "${BUILD_LOG}"
    exit 1
fi
rm -f "${BUILD_LOG}"

if [[ ! -f "${BINARY}" ]]; then
    echo "Error: binary not found at ${BINARY}" >&2
    exit 1
fi

echo "Packaging ${BUNDLE}..."
rm -rf "${BUNDLE}" "${STALE_BUNDLE}" "${STALE_MAC_BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
cp "Sources/RouteFinderMacApp/Info.plist" "${BUNDLE}/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "${EXEC_NAME}" "${BUNDLE}/Contents/Info.plist"
cp "${BINARY}" "${BUNDLE}/Contents/MacOS/${EXEC_NAME}"
chmod +x "${BUNDLE}/Contents/MacOS/${EXEC_NAME}"

# Expand $(AppIdentifierPrefix) for codesign (Xcode does this automatically).
ENTITLEMENTS_EXPANDED="$(mktemp -t routefinder-entitlements).plist"
sed "s/\$(AppIdentifierPrefix)/${TEAM_ID}./g" "${ENTITLEMENTS_SRC}" > "${ENTITLEMENTS_EXPANDED}"

CODESIGN_ID="${ROUTEFINDER_CODESIGN_IDENTITY:-}"
if [[ -z "${CODESIGN_ID}" ]]; then
    CODESIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'\"' '/Apple Development|Developer ID Application/ {print $2; exit}')"
fi

if [[ -z "${CODESIGN_ID}" ]]; then
    echo "Error: no Apple Development or Developer ID signing identity found." >&2
    echo "Sandbox + keychain entitlements cannot be ad-hoc signed. Either:" >&2
    echo "  1. Open RouteFinderApp.xcodeproj → RouteFinderMac scheme → Run (recommended)" >&2
    echo "  2. Set ROUTEFINDER_CODESIGN_IDENTITY to your signing certificate name" >&2
    rm -f "${ENTITLEMENTS_EXPANDED}"
    exit 1
fi

EXEC_PATH="${BUNDLE}/Contents/MacOS/${EXEC_NAME}"
echo "Codesigning executable with identity: ${CODESIGN_ID}"
codesign --force --sign "${CODESIGN_ID}" \
    --options runtime \
    --entitlements "${ENTITLEMENTS_EXPANDED}" \
    --identifier com.routefinder.macos \
    "${EXEC_PATH}"

echo "Codesigning app bundle..."
codesign --force --sign "${CODESIGN_ID}" \
    --options runtime \
    --entitlements "${ENTITLEMENTS_EXPANDED}" \
    --identifier com.routefinder.macos \
    "${BUNDLE}"
rm -f "${ENTITLEMENTS_EXPANDED}"

codesign --verify --verbose=2 "${BUNDLE}"

TEAM_CHECK="$(codesign -dv "${BUNDLE}" 2>&1 | awk -F= '/TeamIdentifier/ {print $2; exit}')"
if [[ -z "${TEAM_CHECK}" || "${TEAM_CHECK}" == "not set" ]]; then
    echo "Error: signed bundle has no TeamIdentifier — launch will fail with Invalid Signature." >&2
    exit 1
fi

echo "Created ${BUNDLE} (TeamIdentifier=${TEAM_CHECK})"
echo "Prefer Xcode: open RouteFinderApp.xcodeproj → scheme RouteFinderMac"
echo "Fallback launch: open \"${BUNDLE}\""

if [[ "${LAUNCH}" == true ]]; then
    open "${BUNDLE}"
fi
