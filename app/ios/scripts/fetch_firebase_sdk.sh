#!/usr/bin/env bash
set -euo pipefail

# Vendors the subset of the Firebase iOS SDK needed for FirebaseMessaging.
# This project links Firebase manually via CMake (see app/CMakeLists.txt)
# instead of CocoaPods/SPM, so we fetch Google's official "no dependency
# manager" zip distribution and copy out just the XCFrameworks we need.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$SCRIPT_DIR/../Firebase"
ZIP_URL="https://firebase.google.com/download/ios"

# FirebaseMessaging's own dependency closure (no Analytics/Auth/etc).
# Note: FBLPromises is the actual framework name for the "PromisesObjC" pod.
MODULES=(
    FirebaseCore
    FirebaseCoreInternal
    FirebaseInstallations
    FirebaseMessaging
    GoogleDataTransport
    GoogleUtilities
    nanopb
    FBLPromises
)

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Downloading Firebase iOS SDK zip..."
curl -fL "$ZIP_URL" --output "$WORK_DIR/firebase_ios_sdk.zip"

echo "Unzipping..."
unzip -q "$WORK_DIR/firebase_ios_sdk.zip" -d "$WORK_DIR/unzipped"

mkdir -p "$DEST_DIR"

missing=0
for module in "${MODULES[@]}"; do
    framework_path="$(find "$WORK_DIR/unzipped" -type d -name "${module}.xcframework" -print -quit)"
    if [[ -z "$framework_path" ]]; then
        echo "WARNING: could not find ${module}.xcframework in the downloaded zip." >&2
        echo "  Inspect $WORK_DIR/unzipped and update MODULES in this script." >&2
        missing=1
        continue
    fi
    echo "Vendoring ${module}.xcframework"
    rm -rf "${DEST_DIR:?}/${module}.xcframework"
    cp -R "$framework_path" "$DEST_DIR/"
done

if [[ "$missing" -ne 0 ]]; then
    echo "One or more frameworks were not found - see warnings above." >&2
    exit 1
fi

echo "Done. Vendored frameworks are in $DEST_DIR"
