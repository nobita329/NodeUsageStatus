#!/usr/bin/env bash
set -e

echo "==> Checking and fixing Go environment..."

# 1. Check if Go is installed in /usr/local/go
if [ ! -x "/usr/local/go/bin/go" ]; then
    echo "❌ Go not found. Installing Go 1.24.1..."
    rm -rf /usr/local/go
    apt remove -y golang-go || true
    wget https://go.dev/dl/go1.24.1.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.24.1.linux-amd64.tar.gz
    rm -f go1.24.1.linux-amd64.tar.gz
else
    echo "✅ Go is already installed at /usr/local/go"
fi

# 2. Ensure PATH is set permanently
if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
    echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc
    echo "✅ PATH added permanently to ~/.bashrc"
else
    echo "ℹ️ PATH already present in ~/.bashrc"
fi

# 3. Export PATH for current session
export PATH=/usr/local/go/bin:$PATH

# 4. Verify Go installation
if ! command -v go &> /dev/null; then
    echo "❌ Go command still not found. Try reloading your shell: source ~/.bashrc"
    exit 1
fi

go version

# 5. Install required gopsutil modules (non-v3)
echo "==> Installing required Go modules..."
cd /srv/wings || { echo "❌ /srv/wings not found"; exit 1; }

go get github.com/shirou/gopsutil/cpu
go get github.com/shirou/gopsutil/disk
go get github.com/shirou/gopsutil/mem
go get github.com/shirou/gopsutil/net

echo "✅ Go modules installed successfully."

# 6. Optional: Rebuild and restart wings
if systemctl list-unit-files | grep -q wings.service; then
    echo "==> Rebuilding and restarting Wings..."
    systemctl stop wings || true
    go build -o /usr/local/bin/wings
    chmod +x /usr/local/bin/wings
    systemctl start wings
    echo "✅ Wings rebuilt and restarted successfully."
else
    echo "ℹ️ Wings service not found. Skipping restart."
fi

echo "✅ All done. Go environment fixed and Wings updated."
