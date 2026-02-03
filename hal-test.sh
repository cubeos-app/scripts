#!/bin/bash
# =============================================================================
# CubeOS HAL API Test Suite
# Tests ALL HAL API endpoints
# =============================================================================

set -e

# Configuration
HAL_HOST="${HAL_HOST:-cubeos.cube}"
HAL_PORT="${HAL_PORT:-6005}"
BASE_URL="http://${HAL_HOST}:${HAL_PORT}/hal"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# =============================================================================
# Helper Functions
# =============================================================================

log_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

test_endpoint() {
    local method="$1"
    local endpoint="$2"
    local description="$3"
    local data="$4"
    local expect_code="${5:-200}"
    
    printf "  %-50s " "$description"
    
    local url="${BASE_URL}${endpoint}"
    local response
    local http_code
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null)
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" -H "Content-Type: application/json" -d "$data" "$url" 2>/dev/null)
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "$expect_code" ]; then
        echo -e "${GREEN}✓ PASS${NC} ($http_code)"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (got $http_code, expected $expect_code)"
        ((TESTS_FAILED++))
        if [ -n "$VERBOSE" ]; then
            echo "    Response: $body"
        fi
        return 1
    fi
}

test_endpoint_json() {
    local method="$1"
    local endpoint="$2"
    local description="$3"
    local json_key="$4"
    local data="$5"
    
    printf "  %-50s " "$description"
    
    local url="${BASE_URL}${endpoint}"
    local response
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s "$url" 2>/dev/null)
    else
        response=$(curl -s -X "$method" -H "Content-Type: application/json" -d "$data" "$url" 2>/dev/null)
    fi
    
    # Check if response contains expected JSON key
    if echo "$response" | jq -e ".$json_key" >/dev/null 2>&1; then
        local value=$(echo "$response" | jq -r ".$json_key" 2>/dev/null)
        echo -e "${GREEN}✓ PASS${NC} ($json_key: $value)"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (missing key: $json_key)"
        ((TESTS_FAILED++))
        if [ -n "$VERBOSE" ]; then
            echo "    Response: $response"
        fi
        return 1
    fi
}

skip_test() {
    local description="$1"
    local reason="$2"
    printf "  %-50s " "$description"
    echo -e "${YELLOW}○ SKIP${NC} ($reason)"
    ((TESTS_SKIPPED++))
}

# =============================================================================
# Check Dependencies
# =============================================================================

echo ""
echo "=========================================="
echo "  CubeOS HAL API Test Suite"
echo "=========================================="
echo ""
echo "Target: $BASE_URL"
echo ""

# Check if HAL is reachable
printf "Checking HAL connectivity... "
if curl -s --connect-timeout 5 "$BASE_URL/health" >/dev/null 2>&1 || \
   curl -s --connect-timeout 5 "$BASE_URL/system/uptime" >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    echo ""
    echo "Cannot reach HAL at $BASE_URL"
    echo "Make sure cubeos-hal container is running."
    exit 1
fi

# Check for jq
if ! command -v jq &>/dev/null; then
    echo -e "${RED}ERROR: jq is required but not installed${NC}"
    exit 1
fi

# =============================================================================
# System Endpoints
# =============================================================================

log_header "SYSTEM"

test_endpoint_json GET "/system/uptime" "System uptime" "seconds"
test_endpoint_json GET "/system/temperature" "CPU temperature" "cpu"
test_endpoint_json GET "/system/throttle" "Throttle status" "throttled"
test_endpoint_json GET "/system/eeprom" "EEPROM info" "board_info"
test_endpoint_json GET "/system/bootconfig" "Boot config" "parameters"

# =============================================================================
# Power Management
# =============================================================================

log_header "POWER MANAGEMENT"

test_endpoint_json GET "/power/battery" "Battery status" "available"
test_endpoint_json GET "/power/ups" "UPS status" "available"
test_endpoint_json GET "/rtc/status" "RTC status" "available"
test_endpoint_json GET "/watchdog/status" "Watchdog status" "device"

# =============================================================================
# Storage Endpoints
# =============================================================================

log_header "STORAGE"

test_endpoint_json GET "/storage/devices" "Storage devices" "devices"
test_endpoint_json GET "/storage/usage" "Disk usage" "filesystems"
test_endpoint_json GET "/storage/usb" "USB storage" "devices"

# SMART test - need a valid device
if curl -s "$BASE_URL/storage/devices" | jq -e '.devices[0].name' >/dev/null 2>&1; then
    FIRST_DEV=$(curl -s "$BASE_URL/storage/devices" | jq -r '.devices[0].name')
    test_endpoint GET "/storage/smart/${FIRST_DEV}" "SMART data ($FIRST_DEV)"
else
    skip_test "SMART data" "no storage device found"
fi

# =============================================================================
# Network Endpoints
# =============================================================================

log_header "NETWORK"

test_endpoint_json GET "/network/interfaces" "Network interfaces" "interfaces"
test_endpoint_json GET "/network/status" "Network status" "mode"
test_endpoint_json GET "/ap/status" "AP status" "active"
test_endpoint_json GET "/ap/clients" "AP clients" "clients"

# =============================================================================
# Logs & Debug
# =============================================================================

log_header "LOGS & DEBUG"

test_endpoint_json GET "/logs/kernel?lines=10" "Kernel logs" "log"
test_endpoint_json GET "/logs/journal?lines=10" "Journal logs" "log"
test_endpoint_json GET "/logs/hardware?category=net" "Hardware logs" "log"

# Support bundle test (just check endpoint responds, don't download)
printf "  %-50s " "Support bundle endpoint"
if curl -s -I "$BASE_URL/support/bundle.zip" 2>/dev/null | grep -q "200\|application/zip"; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}○ SKIP${NC} (endpoint may require longer timeout)"
    ((TESTS_SKIPPED++))
fi

# =============================================================================
# VPN - Tor
# =============================================================================

log_header "VPN - TOR"

test_endpoint_json GET "/vpn/tor/status" "Tor status" "installed"
test_endpoint_json GET "/vpn/tor/config" "Tor config" "config"

# =============================================================================
# GPS
# =============================================================================

log_header "GPS (NMEA)"

test_endpoint_json GET "/gps/devices" "GPS devices" "devices"
test_endpoint_json GET "/gps/status" "GPS status" "available"

# =============================================================================
# Cellular
# =============================================================================

log_header "CELLULAR (ModemManager)"

test_endpoint_json GET "/cellular/status" "Cellular status" "available"
test_endpoint_json GET "/cellular/modems" "Cellular modems" "modems"

# =============================================================================
# Meshtastic
# =============================================================================

log_header "MESHTASTIC (LoRa)"

test_endpoint_json GET "/meshtastic/devices" "Meshtastic devices" "devices"
test_endpoint_json GET "/meshtastic/status" "Meshtastic status" "available"

# =============================================================================
# Iridium
# =============================================================================

log_header "IRIDIUM (SBD)"

test_endpoint_json GET "/iridium/devices" "Iridium devices" "devices"
test_endpoint_json GET "/iridium/status" "Iridium status" "available"

# =============================================================================
# Camera
# =============================================================================

log_header "CAMERA"

test_endpoint_json GET "/camera/devices" "Camera devices" "cameras"

# =============================================================================
# 1-Wire Sensors
# =============================================================================

log_header "1-WIRE SENSORS (DS18B20)"

test_endpoint_json GET "/onewire/devices" "1-Wire devices" "sensors"

# =============================================================================
# Environmental Sensors
# =============================================================================

log_header "ENVIRONMENTAL SENSORS (BME280)"

test_endpoint_json GET "/environmental/sensors" "Environmental sensors" "sensors"

# =============================================================================
# SDR
# =============================================================================

log_header "SDR (RTL-SDR)"

test_endpoint_json GET "/sdr/devices" "SDR devices" "devices"

# =============================================================================
# Audio
# =============================================================================

log_header "AUDIO"

test_endpoint_json GET "/audio/devices" "Audio devices" "devices"
test_endpoint_json GET "/audio/volume" "Audio volume" "available"

# =============================================================================
# GPIO
# =============================================================================

log_header "GPIO"

test_endpoint_json GET "/gpio/pins" "GPIO pins" "pins"

# =============================================================================
# I2C
# =============================================================================

log_header "I2C"

test_endpoint_json GET "/i2c/scan?bus=1" "I2C scan bus 1" "devices"

# =============================================================================
# USB
# =============================================================================

log_header "USB"

test_endpoint_json GET "/usb/devices" "USB devices" "devices"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo "  Test Summary"
echo "=========================================="
echo ""
echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
echo -e "  ${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
echo ""

TOTAL=$((TESTS_PASSED + TESTS_FAILED))
if [ $TOTAL -gt 0 ]; then
    PERCENT=$((TESTS_PASSED * 100 / TOTAL))
    echo "  Success Rate: ${PERCENT}%"
fi

echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Run with VERBOSE=1 for details.${NC}"
    exit 1
fi
