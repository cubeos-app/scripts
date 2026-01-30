#!/bin/bash
# CubeOS Access Point Setup Script
# Updates WiFi AP with unique SSID based on MAC address
set -e

WLAN_IFACE="${WLAN_IFACE:-wlan0}"
HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
AP_IP="192.168.42.1"

echo "========================================"
echo "  CubeOS Access Point Setup"
echo "========================================"

# Get MAC address and generate SSID
if [[ ! -e /sys/class/net/${WLAN_IFACE}/address ]]; then
    echo "ERROR: Interface ${WLAN_IFACE} not found"
    exit 1
fi

MAC_ADDR=$(cat /sys/class/net/${WLAN_IFACE}/address)
MAC_SUFFIX=$(echo "$MAC_ADDR" | tr -d ':' | tail -c 7 | tr 'a-f' 'A-F')
SSID="CubeOS_${MAC_SUFFIX}"
WPA_PASSPHRASE="CubeOS${MAC_SUFFIX}"

echo "Interface: ${WLAN_IFACE}"
echo "MAC Address: ${MAC_ADDR}"
echo "SSID: ${SSID}"
echo "WPA2 Key: ${WPA_PASSPHRASE}"
echo ""

# Update existing hostapd config (preserve other settings)
if [[ -f "$HOSTAPD_CONF" ]]; then
    sed -i "s/^ssid=.*/ssid=${SSID}/" "$HOSTAPD_CONF"
    sed -i "s/^wpa_passphrase=.*/wpa_passphrase=${WPA_PASSPHRASE}/" "$HOSTAPD_CONF"
else
    echo "ERROR: hostapd.conf not found"
    exit 1
fi

# Restart hostapd
systemctl restart hostapd || { echo "ERROR: hostapd failed to start"; exit 1; }

# Save credentials
mkdir -p /cubeos/config
cat > /cubeos/config/ap-credentials.txt << CREDS
# CubeOS Access Point Credentials
# Generated: $(date)
SSID=${SSID}
WPA2_KEY=${WPA_PASSPHRASE}
AP_IP=${AP_IP}
CREDS
chmod 600 /cubeos/config/ap-credentials.txt

echo ""
echo "========================================"
echo "  Access Point Setup Complete!"
echo "========================================"
echo ""
echo "  SSID:     ${SSID}"
echo "  Password: ${WPA_PASSPHRASE}"
echo "  AP IP:    ${AP_IP}"
echo ""
echo "  Dashboard: http://${AP_IP}:8087"
echo "             http://cubeos.net"
echo ""
