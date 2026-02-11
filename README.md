# pi-kiosk

Turn a Raspberry Pi into a fullscreen kiosk display with a single command. Built for dashboards, signage, and info screens.

Runs Chromium in kiosk mode on Wayland/labwc with a watchdog that auto-recovers from crashes and white screens.

## Requirements

- Raspberry Pi (any model with desktop capability)
- Raspberry Pi OS **Bookworm** or later (uses labwc/Wayland)

## Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/drapesinc/pi-kiosk/main/install.sh | bash -s -- https://example.com/dashboard
sudo reboot
```

Or clone and install:

```bash
git clone https://github.com/drapesinc/pi-kiosk.git
cd pi-kiosk
./install.sh https://example.com/dashboard
sudo reboot
```

## Commands

```
pi-kiosk install <URL>    Full setup — installs deps, configures autostart, sets URL
pi-kiosk set-url <URL>    Change the displayed URL (restarts Chromium)
pi-kiosk status           Show kiosk status, PID, uptime, URL
pi-kiosk restart          Restart Chromium (watchdog auto-recovers)
pi-kiosk logs [-f]        Show kiosk logs (-f to follow)
pi-kiosk uninstall        Remove kiosk mode, restore normal desktop
```

## What It Does

The installer:
- Installs `chromium`, `unclutter` (hidden cursor), and `grim` (screenshots)
- Configures labwc autostart to launch the kiosk on boot
- Sets up autologin for the current user
- Disables screen blanking and DPMS
- Stores config in `~/.config/pi-kiosk/config`

The kiosk launcher (`kiosk.sh`):
- Runs Chromium in `--kiosk` mode with Wayland flags
- Clears crash flags before each launch (no "restore pages" prompts)
- Auto-restarts Chromium if it exits
- Watchdog checks every 2 minutes that renderer and GPU processes are alive
- Kills and restarts Chromium if it's in a broken state (white screen)

## File Locations

| File | Path |
|------|------|
| CLI | `/usr/local/bin/pi-kiosk` |
| Kiosk launcher | `~/.local/bin/kiosk.sh` |
| Config | `~/.config/pi-kiosk/config` |
| Autostart | `~/.config/labwc/autostart` |
| Logs | `/tmp/kiosk.log` |

## Troubleshooting

**White screen / frozen page:**
```bash
pi-kiosk restart
```
The watchdog should catch this automatically within 2 minutes, but you can force it.

**Check what's happening:**
```bash
pi-kiosk logs -f
```

**Remove kiosk mode entirely:**
```bash
pi-kiosk uninstall
sudo reboot
```

## License

MIT — Drapes Digital Inc.
