#!/bin/bash
# Download prebuilt libcronet shared library from SagerNet releases.
# macOS is not published — see scripts/build-libcronet-macos.sh instead.

set -euo pipefail

CRONET_VERSION="143.0.7499.109-2"
RELEASE_URL="https://github.com/SagerNet/cronet-go/releases/download/${CRONET_VERSION}"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l)  ARCH="arm" ;;
esac

case "$OS" in
    linux)
        LIB="libcronet-linux-${ARCH}.so"
        TARGET="libcronet.so"
        ;;
    mingw*|msys*|cygwin*)
        LIB="libcronet-windows-${ARCH}.dll"
        TARGET="libcronet.dll"
        ;;
    darwin)
        echo "Error: SagerNet does not publish prebuilt macOS Cronet libraries."
        echo ""
        echo "Options:"
        echo "  1. Run: scripts/build-libcronet-macos.sh (builds from Chromium source)"
        echo "  2. Use Docker for Linux testing: docker run -v \$(pwd):/src -w /src golang:1.23 make build-linux"
        exit 1
        ;;
    *)
        echo "Error: unsupported OS: $OS"
        exit 1
        ;;
esac

DEST="${1:-.}"

echo "Downloading ${LIB}..."
curl -L -o "${DEST}/${TARGET}" "${RELEASE_URL}/${LIB}"
echo "Saved to ${DEST}/${TARGET}"
echo ""
echo "To build wick: go build -tags with_purego -o wick ./cmd/wick"
echo "Place ${TARGET} next to the wick binary at runtime."
