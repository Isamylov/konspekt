#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=ru.konspekt.agent
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
APP="$HOME/Applications/Konspekt.app"
CONFIG_DIR="$HOME/.config/konspekt"
LOG="$HOME/Library/Logs/konspekt.log"

if [ "${1:-}" = "--uninstall" ]; then
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    rm -rf "$APP"
    echo "Uninstalled Konspekt."
    echo "Kept: $CONFIG_DIR and recordings (default ~/Documents/Konspekt)."
    exit 0
fi

if [ ! -e "$CONFIG_DIR/.env" ] && [ ! -f .env ]; then
    echo "error: ./.env not found; create it with OPENAI_BASE_URL, OPENAI_API_KEY, OPENAI_MODEL_NAME" >&2
    exit 1
fi

scripts/build-app.sh

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

mkdir -p "$HOME/Applications" "$CONFIG_DIR" "$HOME/Library/Logs"
rm -rf "$APP"
ditto .build/Konspekt.app "$APP"

if [ ! -e "$CONFIG_DIR/.env" ]; then
    cp .env "$CONFIG_DIR/.env"
    chmod 600 "$CONFIG_DIR/.env"
fi

mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$APP/Contents/MacOS/konspekt</string>
		<string>daemon</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$LOG</string>
	<key>StandardErrorPath</key>
	<string>$LOG</string>
	<key>ProcessType</key>
	<string>Interactive</string>
</dict>
</plist>
EOF
plutil -lint "$PLIST"
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Installed $APP and started $LABEL."
echo "Next: when macOS asks, grant Microphone and System Audio Recording to Konspekt."
echo "Logs: $LOG"
