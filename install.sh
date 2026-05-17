#!/bin/bash
set -e

WINGSDIR="/srv/wings"
BINARY="/usr/local/bin/wings"
CUSTOM_ZIP="https://files.catbox.moe/xf9zxo.zip"

show_help() {
    echo "Usage: $0 {auto|manu|uninstall}"
    echo ""
    echo "  auto        Full automated: download, patch, build, install, restart (default)"
    echo "  manu        Manual: download, patch, extract but skip build/install"
    echo "  uninstall   Remove custom Wings binary"
    exit 0
}

auto_install() {
    echo "[*] Auto install: Downloading, patching, building & installing Wings..."
    download_and_patch
    build_and_install
    restart_service
    echo "[+] Done. Wings rebuilt and restarted."
}

manual_install() {
    echo "[*] Manual install: Downloading & patching Wings source..."
    download_and_patch
    echo ""
    echo "[+] Source ready at: $SRC_DIR"
    echo "    Run the following manually:"
    echo "       cd $SRC_DIR"
    echo "       go build -o $BINARY"
    echo "       chmod +x $BINARY"
    echo "       systemctl restart wings"
}

download_and_patch() {
    mkdir -p "$WINGSDIR"
    cd "$WINGSDIR"

    echo "[*] Fetching latest Wings version..."
    VERSION=$(curl -s https://api.github.com/repos/pterodactyl/wings/releases/latest | grep tag_name | cut -d '"' -f4)

    ZIP_URL="https://github.com/pterodactyl/wings/archive/refs/tags/${VERSION}.zip"
    echo "[*] Downloading $ZIP_URL"
    curl -L "$ZIP_URL" -o wings_latest.zip
    unzip -o wings_latest.zip

    SRC_DIR="$WINGSDIR/wings-${VERSION#v}"
    cd "$SRC_DIR"
    echo "[*] Source extracted: $SRC_DIR"

    echo "[*] Downloading custom WingsFiles..."
    TMP_ZIP=$(mktemp /tmp/wings_custom_XXXXXX.zip)
    curl -L "$CUSTOM_ZIP" -o "$TMP_ZIP"
    TMP_EXTRACT=$(mktemp -d /tmp/wings_custom_XXXXXX)
    unzip -o "$TMP_ZIP" -d "$TMP_EXTRACT"

    if [ -d "$TMP_EXTRACT/router" ]; then
        cp -r "$TMP_EXTRACT/router" "$SRC_DIR/"
        echo "[*] Copied router/ files"
    fi
    if [ -d "$TMP_EXTRACT/system" ]; then
        cp -r "$TMP_EXTRACT/system" "$SRC_DIR/"
        echo "[*] Copied system/ files"
    fi

    rm -f "$TMP_ZIP"
    rm -rf "$TMP_EXTRACT"

    ROUTER="$SRC_DIR/router/router.go"
    if ! grep -q 'getNodeStats' "$ROUTER"; then
        sed -i '/protected := router\.Use(middleware\.RequireAuthorization())/i\
router.GET("/api/node/stats", getNodeStats)
' "$ROUTER"
        echo "[*] router.go patched"
    else
        echo "[*] router.go already patched"
    fi

    cd "$SRC_DIR"

    if ! grep -q 'gopsutil' go.mod; then
        echo "[*] Adding gopsutil dependency..."
        go get github.com/shirou/gopsutil@v3.21.10+incompatible 2>/dev/null
        go mod tidy
    fi
}

build_and_install() {
    if ! command -v go &>/dev/null; then
        echo "[*] Go not found, installing..."
        apt update
        apt install -y golang-go
    fi
    go version
    echo "[*] Building Wings..."
    go build -o "$BINARY"
    chmod +x "$BINARY"
    echo "[*] Binary installed: $BINARY"
}

restart_service() {
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable wings 2>/dev/null || true
    systemctl restart wings 2>/dev/null || echo "[!] Could not restart wings service (may not exist)"
    systemctl is-active wings 2>/dev/null && echo "[*] wings service is active"
}

uninstall() {
    echo "[*] Uninstalling custom Wings..."
    systemctl stop wings 2>/dev/null || true

    if [ -f "$BINARY" ]; then
        echo "[*] Removing $BINARY"
        rm -f "$BINARY"
    else
        echo "[!] No Wings binary found at $BINARY"
    fi

    echo "[*] Done. Custom Wings removed."
    echo "    Reinstall the official version from: https://github.com/pterodactyl/wings"
}

case "${1:-auto}" in
    auto|--auto|-a)  auto_install ;;
    manu|manual|--manual|-m) manual_install ;;
    uninstall|--uninstall|-u) uninstall ;;
    help|--help|-h)  show_help ;;
    *)
        echo "[!] Unknown option: $1"
        show_help
        ;;
esac
