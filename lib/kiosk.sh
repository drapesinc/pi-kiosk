#!/usr/bin/env bash
# pi-kiosk launcher with watchdog
# Reads URL from ~/.config/pi-kiosk/config
# Runs Chromium in kiosk mode with auto-restart on crash

set -uo pipefail

CONFIG_FILE="${HOME}/.config/pi-kiosk/config"
LOG_FILE="/tmp/kiosk.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# Load URL from config
load_url() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi
    if [[ -z "${KIOSK_URL:-}" ]]; then
        log "ERROR: No URL configured. Run: pi-kiosk set-url <URL>"
        exit 1
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
load_url
log "URL: ${KIOSK_URL}"

CHROME_BIN=$(detect_chromium)
log "Using: ${CHROME_BIN}"

# Hide cursor
unclutter --start-hidden &>/dev/null &
UNCLUTTER_PID=$!

# Start watchdog in background
watchdog "$CHROME_BIN" &
WATCHDOG_PID=$!
log "Watchdog started (PID ${WATCHDOG_PID})"

# Main restart loop
while true; do
    load_url
    clear_crash_flags

    log "Launching Chromium: ${KIOSK_URL}"

    # Chromium kiosk flags for Wayland
    "$CHROME_BIN" \
        --kiosk \
        --noerrdialogs \
        --disable-infobars \
        --no-first-run \
        --enable-features=OverlayScrollbar \
        --start-maximized \
        --autoplay-policy=no-user-gesture-required \
        --disable-session-crashed-bubble \
        --disable-component-update \
        --disable-features=Translate \
        --check-for-update-interval=31536000 \
        --ozone-platform=wayland \
        "${KIOSK_URL}" \
        >> "$LOG_FILE" 2>&1

    log "Chromium exited (code $?), restarting in 3s..."
    sleep 3
done

# Cleanup (unreachable in normal operation, but good practice)
kill "$WATCHDOG_PID" 2>/dev/null || true
kill "$UNCLUTTER_PID" 2>/dev/null || true
