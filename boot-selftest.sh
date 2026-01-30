#!/bin/bash
# CubeOS Boot-Time Self-Test
LOG="/var/log/cubeos-boot-selftest.log"
ERRORS=0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"; }
pass() { log "✅ PASS: $1"; }
fail() { log "❌ FAIL: $1"; ((ERRORS++)); }

log "━━━ CubeOS Boot Self-Test ━━━"

# Filesystem
[ -d /cubeos ] && pass "/cubeos exists" || fail "/cubeos missing"
FREE_MB=$(df / | tail -1 | awk '{print int($4/1024)}')
[ "$FREE_MB" -gt 500 ] && pass "Disk OK (${FREE_MB}MB)" || fail "Disk low"

# Network
[ -e /sys/class/net/wlan0 ] && pass "wlan0 exists" || fail "wlan0 missing"

# Config
[ -f /etc/hostapd/hostapd.conf ] && pass "hostapd.conf exists" || fail "hostapd.conf missing"

# Docker
systemctl is-active --quiet docker && pass "Docker running" || fail "Docker not running"

log "━━━ Self-Test Complete (Errors: $ERRORS) ━━━"
exit $ERRORS
