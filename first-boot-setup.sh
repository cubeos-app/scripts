#!/bin/bash
# CubeOS First Boot Setup
# Generates unique AP credentials and configures system
# Run once on first boot

set -e

CONFIG_DIR="/cubeos/config"
CREDENTIALS_FILE="$CONFIG_DIR/ap-credentials.txt"
MARKER_FILE="$CONFIG_DIR/.first-boot-done"

# Exit if already run
if [ -f "$MARKER_FILE" ]; then
    echo "First boot setup already completed"
    exit 0
fi

echo "=== CubeOS First Boot Setup ==="

# Create config dir
mkdir -p "$CONFIG_DIR"

# Get MAC address for unique identifier (last 3 octets)
MAC=$(cat /sys/class/net/wlan0/address 2>/dev/null || cat /sys/class/net/eth0/address)
MAC_SUFFIX=$(echo "$MAC" | tr -d ':' | tail -c 7 | tr '[:lower:]' '[:upper:]')

# Generate credentials
SSID="CubeOS_${MAC_SUFFIX}"
WPA_KEY="CubeOS${MAC_SUFFIX}"
AP_IP="192.168.42.1"

echo "Generating AP credentials..."
echo "  SSID: $SSID"
echo "  IP: $AP_IP"

# Save credentials
cat > "$CREDENTIALS_FILE" << CREDS
# CubeOS Access Point Credentials
# Generated: $(date)
SSID=$SSID
WPA2_KEY=$WPA_KEY
AP_IP=$AP_IP
CREDS

# Generate hostapd.conf
cat > /etc/hostapd/hostapd.conf << HOSTAPD
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=1
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$WPA_KEY
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
HOSTAPD

# Generate netplan for AP
cat > /etc/netplan/50-cubeos-ap.yaml << NETPLAN
network:
  version: 2
  wifis:
    wlan0:
      addresses:
        - ${AP_IP}/24
      dhcp4: false
NETPLAN

# Generate netplan for eth0 (DHCP with Pi-hole DNS)
cat > /etc/netplan/01-eth0.yaml << NETPLAN
network:
  version: 2
  ethernets:
    eth0:
      optional: true
      dhcp4: true
      dhcp-identifier: mac
      dhcp4-overrides:
        use-dns: false
      nameservers:
        addresses:
          - ${AP_IP}
NETPLAN

# Remove old/duplicate configs
rm -f /etc/netplan/02-wlan0.yaml
rm -f /etc/netplan/60-custom-routes.yaml

# Apply netplan
netplan apply

# Enable and restart hostapd
systemctl unmask hostapd
systemctl enable hostapd
systemctl restart hostapd

# Mark first boot complete
touch "$MARKER_FILE"

echo "=== First Boot Setup Complete ==="
echo "Connect to WiFi: $SSID"
echo "Password: $WPA_KEY"
echo "Dashboard: http://cubeos.cube"
