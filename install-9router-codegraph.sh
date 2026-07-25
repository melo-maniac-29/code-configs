#!/usr/bin/env bash
# ============================================================================
# 9router + CodeGraph MCP installer for OpenCode (Linux / macOS / WSL)
# ============================================================================
# If already installed, uninstalls cleanly first, then does a fresh install.
# Sets 9router to start automatically at boot (systemd or launchd).
# ============================================================================

set -euo pipefail

echo ""
echo "============================================================"
echo " 9router + CodeGraph MCP Installer for OpenCode"
echo "============================================================"
echo ""

# --- 0. Uninstall old versions first (unlink agents BEFORE removing binaries) -
echo "[0/5] Checking for existing installations to clean up..."

# Unlink CodeGraph from agents before removing the binary
if command -v codegraph >/dev/null 2>&1; then
  echo "        Unlinking CodeGraph from agents..."
  codegraph uninstall --yes >/dev/null 2>&1
fi

# Remove old boot services first
if command -v systemctl >/dev/null 2>&1; then
  if systemctl --user is-enabled 9router.service >/dev/null 2>&1; then
    echo "        Removing old 9router systemd service..."
    systemctl --user disable --now 9router.service >/dev/null 2>&1
  fi
  rm -f "${HOME}/.config/systemd/user/9router.service"
  systemctl --user daemon-reload >/dev/null 2>&1
elif command -v launchctl >/dev/null 2>&1; then
  if launchctl list com.9router >/dev/null 2>&1; then
    echo "        Removing old 9router launchd agent..."
    launchctl unload "${HOME}/Library/LaunchAgents/com.9router.plist" >/dev/null 2>&1
  fi
  rm -f "${HOME}/Library/LaunchAgents/com.9router.plist"
fi

# Then uninstall npm packages
npm_uninstall() {
  if npm list -g "$1" >/dev/null 2>&1; then
    echo "        Uninstalling $1..."
    npm uninstall -g "$1" >/dev/null 2>&1
  fi
}
npm_uninstall 9router
npm_uninstall @colbymchenry/codegraph

echo "        Cleaning npm cache..."
npm cache clean --force >/dev/null 2>&1

echo "        Cleanup done."

# --- 1. Check Node.js / npm -------------------------------------------------
echo ""
echo "[1/5] Checking Node.js and npm..."
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: Node.js not found. Install from https://nodejs.org/"
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm not found."
  exit 1
fi
echo "        Node: $(node --version)"
echo "        npm:  $(npm --version)"

# --- 2. Install 9router -----------------------------------------------------
echo ""
echo "[2/5] Installing 9router..."
npm install -g 9router
echo "        9router installed."

# --- 3. Install CodeGraph ---------------------------------------------------
echo ""
echo "[3/5] Installing CodeGraph (@colbymchenry/codegraph)..."
npm install -g @colbymchenry/codegraph
echo "        CodeGraph installed."
echo ""
echo "        Wiring CodeGraph MCP into OpenCode..."
"$(npm config get prefix)/bin/codegraph" install --yes

# --- 4. Set 9router to start on boot ----------------------------------------
echo ""
echo "[4/5] Setting 9router to auto-start on boot..."

NODE_BIN="$(which node)"
NPM_PREFIX="$(npm config get prefix)"
NINE_BIN="${NPM_PREFIX}/bin/9router"

if command -v systemctl >/dev/null 2>&1; then
  mkdir -p "${HOME}/.config/systemd/user"
  cat > "${HOME}/.config/systemd/user/9router.service" <<EOF
[Unit]
Description=9router AI Router
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${NINE_BIN}
Restart=on-failure
RestartSec=5
Environment=PATH=${NPM_PREFIX}/bin:/usr/bin:/bin

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now 9router.service 2>/dev/null || true
  echo "        9router auto-start configured (systemd --user)."

elif command -v launchctl >/dev/null 2>&1; then
  mkdir -p "${HOME}/Library/LaunchAgents"
  cat > "${HOME}/Library/LaunchAgents/com.9router.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.9router</string>
    <key>ProgramArguments</key>
    <array>
        <string>${NINE_BIN}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/9router.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/9router.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${NPM_PREFIX}/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
EOF
  launchctl load "${HOME}/Library/LaunchAgents/com.9router.plist" 2>/dev/null || true
  echo "        9router auto-start configured (launchd)."

else
  echo "        WARNING: No systemd or launchctl found. Add 9router to your"
  echo "        shell profile:  echo '${NINE_BIN} &' >> ~/.bashrc"
fi

# --- Done -------------------------------------------------------------------
echo ""
echo "[5/5] Done!"
echo ""
echo "============================================================"
echo " Installation complete!"
echo "============================================================"
echo ""
echo " What was done:"
echo "   - Cleaned up any previous install"
echo "   - 9router installed (global npm)"
echo "   - CodeGraph installed (global npm)"
echo "   - CodeGraph MCP wired into OpenCode"
echo "   - 9router auto-start configured"
echo ""
echo " Next steps:"
echo "   1. Start 9router:         9router"
echo "   2. Configure Kimi provider at http://localhost:20128"
echo "   3. Set provider API key in OpenCode config manually"
echo "   4. Restart OpenCode"
echo "   5. Index your project:    codegraph init ."
echo ""
