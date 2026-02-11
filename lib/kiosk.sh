#!/usr/bin/env bash
# pi-kiosk launcher with watchdog
# Reads URL from ~/.config/pi-kiosk/config
# Runs Chromium in kiosk mode with auto-restart on crash

set -uo pipefail

CONFIG_FILE="${HOME}/.config/pi-kiosk/config"
LOG_FILE="/tmp/kiosk.log"

# Wayland environment (needed when launched via SSH or early autostart)
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# Load config
load_config() {
    KIOSK_URL=""
    REFRESH_INTERVAL="0"
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi
    if [[ -z "${KIOSK_URL:-}" ]]; then
        log "ERROR: No URL configured. Run: pi-kiosk set-url <URL>"
        exit 1
    fi
}

KIOSK_HTML="${HOME}/.local/share/pi-kiosk/kiosk.html"

# Build the URL Chromium will actually open
build_launch_url() {
    local interval="${REFRESH_INTERVAL:-0}"
    if [[ "$interval" -gt 0 && -f "$KIOSK_HTML" ]]; then
        local encoded_url
        encoded_url=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${KIOSK_URL}', safe=''))" 2>/dev/null) || encoded_url="$KIOSK_URL"
        echo "file://${KIOSK_HTML}?url=${encoded_url}&refresh=${interval}"
    else
        echo "${KIOSK_URL}"
    fi
}

# Detect chromium binary name
detect_chromium() {
    if command -v chromium-browser &>/dev/null; then
        echo "chromium-browser"
    elif command -v chromium &>/dev/null; then
        echo "chromium"
    else
        log "ERROR: Chromium not found"
        exit 1
    fi
}

# Clear crash flags so Chromium doesn't show recovery prompts
clear_crash_flags() {
    local profile_dir="${HOME}/.config/chromium/Default"
    if [[ -f "${profile_dir}/Preferences" ]]; then
        sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "${profile_dir}/Preferences" 2>/dev/null || true
        sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "${profile_dir}/Preferences" 2>/dev/null || true
    fi
}

# Watchdog: checks that Chromium renderer and GPU processes are alive
watchdog() {
    local chrome_bin="$1"
    while true; do
        sleep 120

        # Check if main Chromium process exists
        if ! pgrep -x "$chrome_bin" &>/dev/null; then
            log "WATCHDOG: Chromium not running, loop will restart it"
            continue
        fi

        # Check for renderer process (indicates page is actually loaded)
        if ! pgrep -af "${chrome_bin}.*--type=renderer" &>/dev/null; then
            log "WATCHDOG: No renderer process found — killing stale Chromium"
            pkill -x "$chrome_bin" 2>/dev/null || true
            continue
        fi

        # Check for GPU process
        if ! pgrep -af "${chrome_bin}.*--type=gpu-process" &>/dev/null; then
            log "WATCHDOG: No GPU process found — killing stale Chromium"
            pkill -x "$chrome_bin" 2>/dev/null || true
            continue
        fi
    done
}

# --- Main ---

log "pi-kiosk starting"
load_config
log "URL: ${KIOSK_URL}"
log "Refresh interval: ${REFRESH_INTERVAL:-0}s"

CHROME_BIN=$(detect_chromium)
log "Using: ${CHROME_BIN}"

# Hide cursor
if command -v unclutter &>/dev/null; then
    unclutter -idle 3 &
    UNCLUTTER_PID=$!
fi

# Start watchdog in background
watchdog "$CHROME_BIN" &
WATCHDOG_PID=$!
log "Watchdog started (PID ${WATCHDOG_PID})"

# Main restart loop
while true; do
    load_config
    clear_crash_flags

    LAUNCH_URL=$(build_launch_url)
    log "Launching Chromium: ${LAUNCH_URL}"

    # Extra flags when using the HTML wrapper (iframes need relaxed security)
    EXTRA_FLAGS=()
    if [[ "${REFRESH_INTERVAL:-0}" -gt 0 && -f "$KIOSK_HTML" ]]; then
        EXTRA_FLAGS+=(--disable-web-security --allow-file-access-from-files)
    fi

    # Chromium kiosk flags for Wayland
    "$CHROME_BIN" \
        --kiosk \
        --noerrdialogs \
        --disable-infobars \
        --no-first-run \
        --disable-session-crashed-bubble \
        --disable-component-update \
        --check-for-update-interval=31536000 \
        --disable-pinch \
        --overscroll-history-navigation=0 \
        --autoplay-policy=no-user-gesture-required \
        --password-store=basic \
        --ozone-platform=wayland \
        --enable-gpu-rasterization \
        --use-angle=gles \
        --disable-dev-shm-usage \
        "${EXTRA_FLAGS[@]}" \
        "${LAUNCH_URL}" \
        >> "$LOG_FILE" 2>&1

    log "Chromium exited (code $?), restarting in 5s..."
    sleep 5
done

# Cleanup (unreachable in normal operation, but good practice)
kill "$WATCHDOG_PID" 2>/dev/null || true
kill "${UNCLUTTER_PID:-}" 2>/dev/null || true
