#!/bin/bash
# CubeOS Self-Healing Watchdog
set -o pipefail

LOG="/var/log/cubeos-watchdog.log"
ALERT_DIR="/cubeos/alerts"
STATE_DIR="/cubeos/data/watchdog"

mkdir -p "$ALERT_DIR" "$STATE_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

log "━━━ Health check starting ━━━"

# 1. Check Pi-hole
if ! docker exec cubeos-pihole pihole-FTL --config dhcp.active 2>/dev/null | grep -q "true"; then
    log "Pi-hole DHCP not active, restarting..."
    docker restart cubeos-pihole
    sleep 15
fi

# 2. Check NPM proxy hosts
NPM_HOSTS=$(curl -sf http://localhost:6000/api/ 2>/dev/null | grep -c "OK" || echo "0")
if [ "$NPM_HOSTS" = "0" ]; then
    log "NPM not responding, checking container..."
    docker restart cubeos-npm 2>/dev/null
fi

# 3. Check hostapd
if ! systemctl is-active --quiet hostapd; then
    log "hostapd down, restarting..."
    systemctl restart hostapd
fi

# 4. Check disk space
DISK_USED=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK_USED" -gt 90 ]; then
    log "Disk usage ${DISK_USED}%, cleaning..."
    docker system prune -f >> "$LOG" 2>&1
fi

# 5. Check critical containers
for container in cubeos-pihole cubeos-npm cubeos-api cubeos-dashboard; do
    if ! docker ps --format '{{.Names}}' | grep -q "$container"; then
        log "$container not running, starting..."
        docker start "$container" 2>/dev/null
    fi
done

log "━━━ Health check complete ━━━"
