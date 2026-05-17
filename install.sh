#!/bin/bash

auto_patch_wings() {
    WINGSDIR="/srv/wings"
    WINGS_BIN="/usr/local/bin/wings"
    PATCH_DIR="$PTERODACTYL_DIRECTORY/.blueprint/extensions/$EXTENSION_IDENTIFIER/private/wings-patch"

    echo "  [*] Attempting auto Wings patching..."

    mkdir -p "$WINGSDIR" || { echo "  [!] Failed to create $WINGSDIR"; return 1; }
    cd "$WINGSDIR" || return 1

    echo "  [+] Downloading latest Wings source..."
    LOCATION=$(curl -s https://api.github.com/repos/pterodactyl/wings/releases/latest \
      | grep "tag_name" \
      | awk '{print "https://github.com/pterodactyl/wings/archive/" substr($2, 2, length($2)-3) ".zip"}')

    if [ -z "$LOCATION" ]; then
        echo "  [!] Failed to get latest release URL."
        return 1
    fi

    rm -rf wings_source wings_latest.zip
    curl -sL -o wings_latest.zip "$LOCATION" || { echo "  [!] Download failed."; return 1; }
    unzip -q wings_latest.zip || { echo "  [!] Unzip failed."; return 1; }

    SOURCE_DIR=$(find "$WINGSDIR" -maxdepth 1 -type d -name "wings-*" | head -1)
    if [ -z "$SOURCE_DIR" ]; then
        echo "  [!] Could not find extracted source directory."
        return 1
    fi

    echo "  [+] Applying patches..."
    cp "$PATCH_DIR/system/metrics.go" "$SOURCE_DIR/system/metrics.go"
    cp "$PATCH_DIR/router/router_node_stats.go" "$SOURCE_DIR/router/router_node_stats.go"
    cp "$PATCH_DIR/router/router.go" "$SOURCE_DIR/router/router.go"

    # Install Go if needed
    if ! command -v go &>/dev/null; then
        echo "  [+] Installing Go..."
        GO_TAR="go1.21.13.linux-amd64.tar.gz"
        if curl -sLO --connect-timeout 10 "https://go.dev/dl/$GO_TAR" 2>/dev/null; then
            SUDO=""
            if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then SUDO="sudo"; fi
            $SUDO rm -rf /usr/local/go
            $SUDO tar -C /usr/local -xzf "$GO_TAR" 2>/dev/null
            export PATH="/usr/local/go/bin:$PATH"
            rm -f "$GO_TAR"
        else
            echo "  [!] Failed to download Go."
            return 1
        fi
    fi

    export PATH="/usr/local/go/bin:$PATH"
    export GOPATH="$WINGSDIR/gopath"
    mkdir -p "$GOPATH"

    echo "  [+] Rebuilding Wings..."
    cd "$SOURCE_DIR" || return 1
    if ! CGO_ENABLED=0 GOPATH="$GOPATH" GOMODCACHE="$GOPATH/mod" go build -ldflags "-s -w" -o wings . 2>&1; then
        echo "  [!] Wings build failed."
        return 1
    fi

    echo "  [+] Installing updated Wings binary..."
    if command -v systemctl &>/dev/null; then
        systemctl stop wings 2>/dev/null || systemctl stop wings.service 2>/dev/null
        sleep 1
    fi

    cp -f wings "$WINGS_BIN"
    chmod 755 "$WINGS_BIN"

    if command -v systemctl &>/dev/null; then
        echo "  [+] Starting Wings service..."
        systemctl start wings 2>/dev/null || systemctl start wings.service 2>/dev/null
    fi

    rm -rf "$WINGSDIR/wings_latest.zip" "$WINGSDIR/gopath"
    echo "  [✓] Wings patched and restarted successfully!"
    return 0
}

echo ""
echo "============================================================"
echo "  Node Usage Status Extension - Auto Setup"
echo "============================================================"
echo ""

if ! auto_patch_wings; then
    echo ""
    echo "  [!] Auto patching failed. Check errors above."
    echo "============================================================"
else
    echo ""
    echo "  [✓] Extension fully installed and ready!"
    echo "============================================================"
fi
