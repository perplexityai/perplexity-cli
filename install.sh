#!/bin/sh
# pplx CLI installer.
#
# Usage:
#   curl -fsSL https://github.com/perplexityai/perplexity-cli/releases/latest/download/install.sh | sh
#
# Env overrides:
#   PPLX_INSTALL_BASE_URL  release repository base URL
#                          (default: https://github.com/perplexityai/perplexity-cli)
#   PPLX_INSTALL_PATH      install target (default: $HOME/.local/bin/pplx)

set -eu

BASE_URL="${PPLX_INSTALL_BASE_URL:-https://github.com/perplexityai/perplexity-cli}"
INSTALL_PATH="${PPLX_INSTALL_PATH:-$HOME/.local/bin/pplx}"

err() { echo "error: $*" >&2; exit 1; }
info() { echo ">> $*"; }
fetch() { curl -fsSL --retry 3 "$1" -o "$2"; }

command -v curl >/dev/null 2>&1 || err "curl is required"

# sha256sum (coreutils) covers most Linux images; shasum (Perl) covers macOS.
if command -v sha256sum >/dev/null 2>&1; then
    checksum() { sha256sum -c -; }
elif command -v shasum >/dev/null 2>&1; then
    checksum() { shasum -a 256 -c -; }
else
    err "sha256sum or shasum is required"
fi

OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS-$ARCH" in
    Darwin-arm64)              ASSET="pplx-aarch64-apple-darwin.bin" ;;
    Linux-x86_64|Linux-amd64)  ASSET="pplx-x86_64-linux-gnu.bin" ;;
    Linux-aarch64|Linux-arm64) ASSET="pplx-aarch64-linux-gnu.bin" ;;
    *) err "unsupported platform: $OS $ARCH (supported: macOS arm64, Linux x86_64, Linux arm64)" ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

info "Resolving latest release"
fetch "$BASE_URL/releases/latest/download/manifest.json" "$TMP/manifest.json" \
    || err "failed to download $BASE_URL/releases/latest/download/manifest.json"

# manifest.json is pretty-printed with one key per line.
TAG="$(sed -n 's/^[[:space:]]*"tag":[[:space:]]*"\([^"]*\)".*/\1/p' "$TMP/manifest.json" | head -n 1)"
VERSION="$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$TMP/manifest.json" | head -n 1)"

# Both values feed URLs and terminal output; reject anything unexpected.
case "$TAG" in
    ''|*[!A-Za-z0-9._-]*) err "malformed release tag in manifest.json" ;;
esac
case "$VERSION" in
    ''|*[!0-9A-Za-z.+-]*) err "malformed version in manifest.json" ;;
esac

# Pin the remaining downloads to the tag to avoid racing a concurrent publish.
info "Downloading $ASSET ($VERSION)"
fetch "$BASE_URL/releases/download/$TAG/SHA256SUMS" "$TMP/SHA256SUMS" \
    || err "failed to download SHA256SUMS for release $TAG"
fetch "$BASE_URL/releases/download/$TAG/$ASSET" "$TMP/$ASSET" \
    || err "failed to download $ASSET for release $TAG"

info "Verifying checksum"
(cd "$TMP" && grep "  $ASSET\$" SHA256SUMS | checksum) \
    || err "checksum verification failed for $ASSET"

INSTALL_DIR="$(dirname "$INSTALL_PATH")"
mkdir -p "$INSTALL_DIR" 2>/dev/null \
    || err "cannot create $INSTALL_DIR; set PPLX_INSTALL_PATH to a writable location"
[ -w "$INSTALL_DIR" ] \
    || err "cannot write to $INSTALL_DIR; set PPLX_INSTALL_PATH to a writable location"

if command -v install >/dev/null 2>&1; then
    install -m 0755 "$TMP/$ASSET" "$INSTALL_PATH"
else
    cp "$TMP/$ASSET" "$INSTALL_PATH"
    chmod 0755 "$INSTALL_PATH"
fi

INSTALLED_VERSION="$("$INSTALL_PATH" --version)" \
    || err "$INSTALL_PATH --version failed"

# pplx update requires this receipt and matches on the canonical install dir.
# Written only after the binary is verified to run.
INSTALL_PREFIX="$(cd "$INSTALL_DIR" && pwd -P)"
case "$INSTALL_PREFIX" in
    *\"*|*\\*) err "install directory must not contain quotes or backslashes" ;;
esac
CONFIG_ROOT="$HOME/.config"
case "${XDG_CONFIG_HOME:-}" in
    /*) CONFIG_ROOT="$XDG_CONFIG_HOME" ;;
esac
mkdir -p "$CONFIG_ROOT/pplx" \
    || err "cannot create $CONFIG_ROOT/pplx"
printf '{"binary":"pplx","install_prefix":"%s","version":"%s","provider":"install.sh","source":"github:perplexityai/perplexity-cli"}\n' \
    "$INSTALL_PREFIX" "$VERSION" > "$CONFIG_ROOT/pplx/pplx-receipt.json"

info "Installed $INSTALLED_VERSION to $INSTALL_PATH"

case ":$PATH:" in
    *":$INSTALL_DIR:"*|*":$INSTALL_PREFIX:"*) ;;
    *)
        info "note: $INSTALL_DIR is not on PATH"
        info "      add to your shell profile: export PATH=\"$INSTALL_DIR:\$PATH\""
        ;;
esac
