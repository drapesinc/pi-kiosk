#!/usr/bin/env bash
# pi-kiosk installer
# Usage: curl -sSL https://raw.githubusercontent.com/drapesinc/pi-kiosk/main/install.sh | bash -s -- <URL>
#    or: ./install.sh <URL>

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/drapesinc/pi-kiosk/main"
INSTALL_DIR="/usr/local/bin"
URL="${1:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { echo -e "${GREEN}[pi-kiosk]${NC} $*"; }
error() { echo -e "${RED}[pi-kiosk]${NC} $*" >&2; }

# --- Checks ---

if [[ -z "$URL" ]]; then
    echo "pi-kiosk installer"
    echo ""
    echo "Usage:"
    echo "  curl -sSL ${REPO_URL}/install.sh | bash -s -- <URL>"
    echo "  ./install.sh <URL>"
    echo ""
    error "Please provide a dashboard URL"
    exit 1
fi

# Must be on a Pi
if [[ ! -f /proc/device-tree/model ]]; then
    error "This doesn't appear to be a Raspberry Pi."
    exit 1
fi

MODEL=$(tr -d '\0' < /proc/device-tree/model)
info "Detected: ${MODEL}"

# Must have labwc
if ! command -v labwc &>/dev/null; then
    error "labwc not found. Requires Raspberry Pi OS Bookworm or later."
    exit 1
fi

# --- Install ---

info "Downloading pi-kiosk..."

# Create temp dir for downloads
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Check if we're running from a cloned repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
if [[ -n "$SCRIPT_DIR" && -f "${SCRIPT_DIR}/bin/pi-kiosk" ]]; then
    info "Installing from local repo..."
    cp "${SCRIPT_DIR}/bin/pi-kiosk" "${TMPDIR}/pi-kiosk"
    cp "${SCRIPT_DIR}/lib/kiosk.sh" "${TMPDIR}/kiosk.sh"
else
    info "Downloading from GitHub..."
    curl -sSL "${REPO_URL}/bin/pi-kiosk" -o "${TMPDIR}/pi-kiosk"
    curl -sSL "${REPO_URL}/lib/kiosk.sh" -o "${TMPDIR}/kiosk.sh"
fi

# Install CLI
chmod +x "${TMPDIR}/pi-kiosk"
sudo cp "${TMPDIR}/pi-kiosk" "${INSTALL_DIR}/pi-kiosk"
info "Installed pi-kiosk to ${INSTALL_DIR}/pi-kiosk"

# Install kiosk launcher
mkdir -p "${HOME}/.local/bin"
cp "${TMPDIR}/kiosk.sh" "${HOME}/.local/bin/kiosk.sh"
chmod +x "${HOME}/.local/bin/kiosk.sh"

# Run the install command
pi-kiosk install "$URL"
