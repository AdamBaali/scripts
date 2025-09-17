#!/bin/bash

# ============================================
# Tailscale Mac Setup Script for GitHub Sharing
#
# Supports either direct Auth Key or OAuth flow.
# Kills browser to prevent unwanted login UI.
# Clears LaunchServices to avoid needing reboot.
# Tested with Jamf but fully MDM-agnostic.
#
# For context on LaunchServices cache workaround:
# https://tailscale.com/kb/1286/macos-mdm#workarounds-for-macos-networkextension-framework-bugs
# ============================================

# === Configuration ===
AUTH_KEY=""                         # Optionally provide a Tailscale auth key directly (starts with tskey-)
CLIENT_ID=""                        # Or use OAuth credentials
CLIENT_SECRET=""
TAGS="tag:default"                  # Tag to apply to device
HOSTNAME=$(scutil --get ComputerName)
TAILSCALE="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
DEFAULT_BROWSER="Google Chrome"     # Update if using Safari, Firefox, etc.

# === Logging ===
log() { echo "[tailscale-setup] $1"; }

# === Browser Killer ===
# Used to prevent the GUI login window from opening by force-closing the default browser.
kill_browser() {
  while true; do
    if pgrep -x "$DEFAULT_BROWSER" >/dev/null; then
      log "Killing $DEFAULT_BROWSER to suppress auth prompt..."
      pkill -x "$DEFAULT_BROWSER"
    fi
    sleep 2
  done
}

# Start browser killer in the background
kill_browser &
BROWSER_KILLER_PID=$!

# === LaunchServices Cache Cleanup (avoids reboot) ===
log "Clearing LaunchServices cache..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -kill -r -domain local -domain system -domain user
log "LaunchServices cache cleared"

# === Auth Key Retrieval ===
if [[ -n "$AUTH_KEY" ]]; then
  log "Using provided auth key"
else
  if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
    log "Error: Either AUTH_KEY or both CLIENT_ID and CLIENT_SECRET must be set"
    kill $BROWSER_KILLER_PID 2>/dev/null
    exit 1
  fi

  log "Getting OAuth token..."
  ACCESS_TOKEN=$(curl -s --max-time 10 -X POST https://api.tailscale.com/api/v2/oauth/token \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

  if [[ -z "$ACCESS_TOKEN" ]]; then
    log "Failed to get access token"
    kill $BROWSER_KILLER_PID 2>/dev/null
    exit 1
  fi

  log "Generating ephemeral auth key..."
  AUTH_KEY=$(curl -s --max-time 10 -X POST https://api.tailscale.com/api/v2/tailnet/-/keys \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
          "capabilities": {
            "devices": {
              "create": {
                "reusable": false,
                "ephemeral": true,
                "preauthorized": true,
                "tags": ["'"$TAGS"'"]
              }
            }
          },
          "description": "Generic Setup Script"
        }' | sed -n 's/.*"key":"\(tskey-[^"]*\)".*/\1/p')

  if [[ -z "$AUTH_KEY" ]]; then
    log "Failed to generate auth key"
    kill $BROWSER_KILLER_PID 2>/dev/null
    exit 1
  fi
fi

# === Launch App and Authenticate ===
log "Launching Tailscale app..."
open -g -a "/Applications/Tailscale.app"
sleep 2

log "Running 'tailscale up'..."
if $TAILSCALE up --reset \
  --auth-key="$AUTH_KEY" \
  --advertise-tags="$TAGS" \
  --hostname="$HOSTNAME" \
  --accept-routes; then
  log "Tailscale setup complete"
else
  log "Tailscale up failed"
  kill $BROWSER_KILLER_PID 2>/dev/null
  exit 1
fi

kill $BROWSER_KILLER_PID 2>/dev/null
log "Tailscale status:"
$TAILSCALE status

exit 0
