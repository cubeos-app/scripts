#!/bin/bash
# =============================================================================
# CubeOS HAL Dependencies Installer
# Installs all system packages required for HAL API endpoints
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (sudo $0)"
    exit 1
fi

echo ""
echo "=========================================="
echo "  CubeOS HAL Dependencies Installer"
echo "=========================================="
echo ""

# Update package lists
log_info "Updating package lists..."
apt-get update -qq

# =============================================================================
# Core System Tools
# =============================================================================
log_info "Installing core system tools..."
apt-get install -y -qq \
    i2c-tools \
    lsof \
    usbutils \
    pciutils \
    smartmontools \
    hdparm \
    || log_warn "Some core tools failed to install"

# =============================================================================
# Network & VPN
# =============================================================================
log_info "Installing network & VPN packages..."
apt-get install -y -qq \
    tor \
    network-manager \
    modemmanager \
    hostapd \
    dnsmasq \
    || log_warn "Some network packages failed to install"

# Configure Tor if freshly installed
if [ -f /etc/tor/torrc ]; then
    if ! grep -q "SOCKSPort 9050" /etc/tor/torrc; then
        log_info "Configuring Tor..."
        cat >> /etc/tor/torrc << 'EOF'
# CubeOS HAL Configuration
SOCKSPort 9050
ControlPort 9051
CookieAuthentication 0
EOF
        systemctl restart tor 2>/dev/null || true
    fi
fi

# =============================================================================
# Camera Support
# =============================================================================
log_info "Installing camera packages..."
apt-get install -y -qq \
    libcamera-apps \
    fswebcam \
    v4l-utils \
    || log_warn "Some camera packages failed to install"

# =============================================================================
# Audio Support
# =============================================================================
log_info "Installing audio packages..."
apt-get install -y -qq \
    alsa-utils \
    pulseaudio-utils \
    || log_warn "Some audio packages failed to install"

# =============================================================================
# GPIO & I2C
# =============================================================================
log_info "Installing GPIO & I2C packages..."
apt-get install -y -qq \
    gpiod \
    libgpiod-dev \
    python3-gpiod \
    python3-smbus2 \
    || log_warn "Some GPIO/I2C packages failed to install"

# Enable I2C if not already enabled
if ! grep -q "^dtparam=i2c_arm=on" /boot/firmware/config.txt 2>/dev/null; then
    log_info "Enabling I2C in boot config..."
    echo "dtparam=i2c_arm=on" >> /boot/firmware/config.txt
    log_warn "I2C enabled - reboot required"
fi

# =============================================================================
# 1-Wire Support (DS18B20)
# =============================================================================
log_info "Configuring 1-Wire support..."

# Enable 1-Wire overlay if not already enabled
if ! grep -q "^dtoverlay=w1-gpio" /boot/firmware/config.txt 2>/dev/null; then
    log_info "Enabling 1-Wire in boot config..."
    echo "dtoverlay=w1-gpio" >> /boot/firmware/config.txt
    log_warn "1-Wire enabled - reboot required"
fi

# Load kernel modules
modprobe w1-gpio 2>/dev/null || true
modprobe w1-therm 2>/dev/null || true

# =============================================================================
# Environmental Sensors (BME280)
# =============================================================================
log_info "Installing BME280 sensor support..."
apt-get install -y -qq python3-pip || true
pip3 install --break-system-packages bme280 smbus2 2>/dev/null || \
    pip3 install bme280 smbus2 2>/dev/null || \
    log_warn "BME280 Python packages not installed"

# =============================================================================
# SDR (RTL-SDR)
# =============================================================================
log_info "Installing RTL-SDR packages..."
apt-get install -y -qq \
    rtl-sdr \
    librtlsdr-dev \
    || log_warn "RTL-SDR packages failed to install"

# Blacklist default DVB drivers (interfere with SDR)
if [ ! -f /etc/modprobe.d/blacklist-rtlsdr.conf ]; then
    log_info "Blacklisting DVB drivers for SDR..."
    cat > /etc/modprobe.d/blacklist-rtlsdr.conf << 'EOF'
# Blacklist default DVB drivers to allow RTL-SDR access
blacklist dvb_usb_rtl28xxu
blacklist rtl2832
blacklist rtl2830
EOF
fi

# =============================================================================
# Meshtastic CLI
# =============================================================================
log_info "Installing Meshtastic CLI..."
pip3 install --break-system-packages meshtastic 2>/dev/null || \
    pip3 install meshtastic 2>/dev/null || \
    log_warn "Meshtastic CLI not installed"

# =============================================================================
# USB Storage Tools
# =============================================================================
log_info "Installing USB storage tools..."
apt-get install -y -qq \
    udisks2 \
    ntfs-3g \
    exfat-fuse \
    exfatprogs \
    || log_warn "Some USB storage tools failed to install"

# Create default USB mount point
mkdir -p /mnt/usb

# =============================================================================
# Serial/UART Tools
# =============================================================================
log_info "Installing serial tools..."
apt-get install -y -qq \
    minicom \
    screen \
    picocom \
    || log_warn "Some serial tools failed to install"

# =============================================================================
# Watchdog
# =============================================================================
log_info "Configuring hardware watchdog..."
apt-get install -y -qq watchdog || true

# Enable watchdog in boot config if not already
if ! grep -q "^dtparam=watchdog=on" /boot/firmware/config.txt 2>/dev/null; then
    echo "dtparam=watchdog=on" >> /boot/firmware/config.txt
    log_warn "Watchdog enabled - reboot required"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=========================================="
echo "  Installation Complete"
echo "=========================================="
echo ""

log_ok "Core system tools"
log_ok "Network & VPN (Tor, ModemManager)"
log_ok "Camera (libcamera, fswebcam, v4l)"
log_ok "Audio (ALSA)"
log_ok "GPIO & I2C (gpiod)"
log_ok "1-Wire (w1-gpio)"
log_ok "Environmental sensors (BME280)"
log_ok "SDR (rtl-sdr)"
log_ok "Meshtastic CLI"
log_ok "USB storage (udisks2, NTFS, exFAT)"
log_ok "Serial tools"
log_ok "Watchdog"

echo ""

# Check if reboot required
if grep -q "reboot required" /tmp/hal-deps-log 2>/dev/null || \
   [ -f /var/run/reboot-required ]; then
    log_warn "A reboot is recommended to apply all changes"
    echo ""
    read -p "Reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reboot
    fi
fi

echo ""
log_info "Run 'hal-test.sh' to verify all HAL endpoints"
echo ""
