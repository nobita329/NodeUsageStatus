#!/usr/bin/env bash
set -e

# Remove old Go installation
rm -rf /usr/local/go
apt remove -y golang-go

# Download new Go
wget https://go.dev/dl/go1.24.1.linux-amd64.tar.gz

# Install Go
tar -C /usr/local -xzf go1.24.1.linux-amd64.tar.gz

# Set PATH
export PATH=/usr/local/go/bin:$PATH

# Check Go version
go version

# Clone Wings
cd /srv
rm -rf wings
git clone https://github.com/pterodactyl/wings.git
cd wings

# Clone NodeUsageStat
cd /srv
rm -rf NodeUsageStatus
git clone https://github.com/nobita329/NodeUsageStat.git
cd NodeUsageStatus

# Move router_node_stats.go and metrics.go
if [ -f "router_node_stats.go" ]; then
    mv router_node_stats.go /srv/wings/router/
    echo "✅ router_node_stats.go moved to /srv/wings/router/"
else
    echo "❌ router_node_stats.go not found"
fi

if [ -f "metrics.go" ]; then
    mv metrics.go /srv/wings/system/
    echo "✅ metrics.go moved to /srv/wings/system/"
else
    echo "❌ metrics.go not found"
fi

# Inject new API route into router.go (proper indentation)
ROUTER_FILE="/srv/wings/router/router.go"
if grep -q "return router" "$ROUTER_FILE"; then
    sed -i '/return router/i \        router.GET("/api/node/stats", getNodeStats)' "$ROUTER_FILE"
    echo "✅ router.go updated (with correct indentation)"
else
    echo "❌ 'return router' not found in router.go"
fi

# Install Go dependencies
cd /srv/wings
go get github.com/shirou/gopsutil/v3/cpu
go get github.com/shirou/gopsutil/v3/disk
go get github.com/shirou/gopsutil/v3/mem
go get github.com/shirou/gopsutil/v3/net

# Rebuild and restart Wings
systemctl stop wings && \
go build -o /usr/local/bin/wings && \
chmod +x /usr/local/bin/wings && \
systemctl start wings
