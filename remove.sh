#!/bin/bash

WINGSDIR="/srv/wings"
WINGS_BIN="/usr/local/bin/wings"

echo ""
echo "============================================================"
echo "  Node Usage Status Extension - Removal"
echo "============================================================"
echo ""

echo "  [+] Downloading clean Wings source..."
mkdir -p "$WINGSDIR" 2>/dev/null
cd "$WINGSDIR" || exit 0

LOCATION=$(curl -s https://api.github.com/repos/pterodactyl/wings/releases/latest \
  | grep "tag_name" \
  | awk '{print "https://github.com/pterodactyl/wings/archive/" substr($2, 2, length($2)-3) ".zip"}')

if [ -n "$LOCATION" ]; then
    rm -rf wings_source wings_latest.zip
    curl -sL -o wings_latest.zip "$LOCATION"
    unzip -q wings_latest.zip

    SOURCE_DIR=$(find "$WINGSDIR" -maxdepth 1 -type d -name "wings-*" | head -1)

    if [ -n "$SOURCE_DIR" ] && command -v go &>/dev/null; then
        echo "  [+] Rebuilding clean Wings..."
        cd "$SOURCE_DIR" || exit 0
        if CGO_ENABLED=0 go build -ldflags "-s -w" -o wings . 2>/dev/null; then
            systemctl stop wings 2>/dev/null || systemctl stop wings.service 2>/dev/null
            sleep 1
            cp -f wings "$WINGS_BIN"
            chmod 755 "$WINGS_BIN"
            systemctl start wings 2>/dev/null || systemctl start wings.service 2>/dev/null
            echo "  [✓] Wings rebuilt and restarted without patches."
        fi
    else
        echo "  [!] Go not installed or source not found, cannot rebuild."
    fi
else
    echo "  [!] Failed to get latest release URL."
fi

echo "============================================================"
