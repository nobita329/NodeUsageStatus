#!/usr/bin/env bash
set -e

# पुराना Go हटाओ
rm -rf /usr/local/go
apt remove -y golang-go

# नया Go डाउनलोड करो
wget https://go.dev/dl/go1.24.1.linux-amd64.tar.gz

# इंस्टॉल करो
tar -C /usr/local -xzf go1.24.1.linux-amd64.tar.gz

# PATH सेट करो
export PATH=/usr/local/go/bin:$PATH

# वर्ज़न चेक करो
go version

# Wings सेटअप
cd /srv
rm -rf wings
git clone https://github.com/pterodactyl/wings.git
cd wings

# NodeUsageStatus क्लोन करो
cd /srv
rm -rf NodeUsageStatus
git clone https://github.com/nobita329/NodeUsageStatus.git
cd NodeUsageStatus

# router.go में नई API लाइन ऐड करो
ROUTER_FILE="/srv/wings/router/router.go"
if grep -q "return router" "$ROUTER_FILE"; then
    sed -i '/return router/i router.GET("/api/node/stats", getNodeStats)' "$ROUTER_FILE"
    echo "✅ router.go अपडेट हो गया"
else
    echo "❌ router.go में 'return router' नहीं मिला"
fi

# अगर 1.zip वर्तमान डायरेक्टरी में है तो उसे मूव और अनज़िप करो
if [ -f ~/1.zip ]; then
    mv ~/1.zip /srv/wings/
fi

if [ -f /srv/wings/1.zip ]; then
    cd /srv/wings
    unzip -o 1.zip
    rm -f 1.zip
else
    echo "⚠️ 1.zip नहीं मिला, स्किप किया जा रहा है"
fi

# Go dependencies इंस्टॉल करो
cd /srv/wings
go get github.com/shirou/gopsutil/v3/cpu
go get github.com/shirou/gopsutil/v3/disk
go get github.com/shirou/gopsutil/v3/mem
go get github.com/shirou/gopsutil/v3/net

# Wings को rebuild और restart करो
systemctl stop wings && \
go build -o /usr/local/bin/wings && \
chmod +x /usr/local/bin/wings && \
systemctl start wings

