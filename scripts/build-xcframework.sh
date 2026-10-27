#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BRIDGE_DIR="$ROOT_DIR/anki-bridge-rs"
OUTPUT_DIR="$ROOT_DIR/AnkiRust.xcframework"
HEADER_DIR="$BRIDGE_DIR/include"

export PROTOC="${PROTOC:-$(which protoc 2>/dev/null || echo /opt/homebrew/bin/protoc)}"
export IPHONEOS_DEPLOYMENT_TARGET="17.0"

echo "==> Using protoc: $PROTOC"
echo "==> Deployment target: iOS $IPHONEOS_DEPLOYMENT_TARGET"

# Pin Cargo.lock from anki-upstream and lock libc to 0.2.175 (libc 0.2.191+ removed RTM_IFINFO2 on iOS, breaking sysinfo 0.33.1)
if [ -f "$ROOT_DIR/anki-upstream/Cargo.lock" ] && [ ! -f "$BRIDGE_DIR/Cargo.lock" ]; then
    cp "$ROOT_DIR/anki-upstream/Cargo.lock" "$BRIDGE_DIR/Cargo.lock"
fi
cargo update --manifest-path "$BRIDGE_DIR/Cargo.toml" -p libc --precise 0.2.175

echo "==> Building for iOS device (aarch64-apple-ios)..."
cargo build \
    --manifest-path "$BRIDGE_DIR/Cargo.toml" \
    --target aarch64-apple-ios \
    --release

DEVICE_LIB="$BRIDGE_DIR/target/aarch64-apple-ios/release/libanki_bridge_ios.a"
[ -f "$DEVICE_LIB" ] || { echo "ERROR: device lib not found at $DEVICE_LIB"; exit 1; }
echo "==> Device lib: $(du -h "$DEVICE_LIB" | cut -f1)"

TEMP_LIB_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_LIB_DIR"' EXIT

RENAMED_DEVICE_LIB="$TEMP_LIB_DIR/device/libAnkiRustLib.a"
mkdir -p "$(dirname "$RENAMED_DEVICE_LIB")"
cp "$DEVICE_LIB" "$RENAMED_DEVICE_LIB"

echo "==> Packaging XCFramework..."
rm -rf "$OUTPUT_DIR"

if [ "${SKIP_SIMULATOR_BUILD:-0}" = "1" ]; then
    echo "==> Skipping simulator build (SKIP_SIMULATOR_BUILD=1)..."
    xcodebuild -create-xcframework \
        -library "$RENAMED_DEVICE_LIB" -headers "$HEADER_DIR" \
        -output "$OUTPUT_DIR"
else
    echo "==> Building for iOS simulator (aarch64-apple-ios-sim)..."
    cargo build \
        --manifest-path "$BRIDGE_DIR/Cargo.toml" \
        --target aarch64-apple-ios-sim \
        --release

    SIM_LIB="$BRIDGE_DIR/target/aarch64-apple-ios-sim/release/libanki_bridge_ios.a"
    [ -f "$SIM_LIB" ] || { echo "ERROR: simulator lib not found at $SIM_LIB"; exit 1; }
    echo "==> Simulator lib: $(du -h "$SIM_LIB" | cut -f1)"

    RENAMED_SIM_LIB="$TEMP_LIB_DIR/simulator/libAnkiRustLib.a"
    mkdir -p "$(dirname "$RENAMED_SIM_LIB")"
    cp "$SIM_LIB" "$RENAMED_SIM_LIB"

    xcodebuild -create-xcframework \
        -library "$RENAMED_DEVICE_LIB" -headers "$HEADER_DIR" \
        -library "$RENAMED_SIM_LIB" -headers "$HEADER_DIR" \
        -output "$OUTPUT_DIR"
fi

echo "==> Adding module maps..."
for HEADERS in "$OUTPUT_DIR"/*/Headers; do
    cat > "$HEADERS/module.modulemap" <<'MODULEMAP'
module AnkiRustLib {
    header "anki_bridge.h"
    export *
}
MODULEMAP
done

echo "==> Done! XCFramework at: $OUTPUT_DIR"
echo "==> Contents:"
find "$OUTPUT_DIR" -type f | head -15
