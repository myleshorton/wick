#!/bin/bash
# Download prebuilt libcronet.a for macOS from the sagernet/cronet-go 'go' branch.
# This is a ~40MB static library built from Chromium 143.

set -euo pipefail

ARCH=$(uname -m)
case "$ARCH" in
    arm64)  DIR="darwin_arm64" ;;
    x86_64) DIR="darwin_amd64" ;;
    *)      echo "Error: unsupported architecture: $ARCH"; exit 1 ;;
esac

DEST="lib/${DIR}"
mkdir -p "$DEST"

if [ -f "$DEST/libcronet.a" ]; then
    echo "libcronet.a already exists at $DEST/libcronet.a"
    exit 0
fi

echo "Downloading libcronet.a for macOS ${ARCH} (~40MB)..."
curl -fL --progress-bar -o "$DEST/libcronet.a" \
    "https://raw.githubusercontent.com/SagerNet/cronet-go/go/lib/${DIR}/libcronet.a"

echo "Saved to $DEST/libcronet.a"
echo ""
echo "Build with: make build"
