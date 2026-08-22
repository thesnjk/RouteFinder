#!/bin/bash
set -euo pipefail

# Package the macOS GUI as RouteFinder.app for proper keyboard focus and Dock launch.
#
# Usage:
#   ./Scripts/package-macos-app.sh          # debug build
#   ./Scripts/package-macos-app.sh release  # release build
#   ./Scripts/package-macos-app.sh open     # build debug and launch via open(1)
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

echo "Created ${BUNDLE}"
echo "Launch with: open \"${BUNDLE}\""

if [[ "${LAUNCH}" == true ]]; then
    open "${BUNDLE}"
fi
