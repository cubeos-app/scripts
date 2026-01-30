#!/bin/bash
# CubeOS Self-Healing Watchdog
set -o pipefail

LOG="/var/log/cubeos-watchdog.log"
ALERT_DIR="/cubeos/alerts"
STATE_DIR="/cubeos/data/watchdog"

mkdir -p "$ALERT_DIR" "$STATE_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

# Rotate log if > 10MB
LOG_SIZE=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
if [ "$LOG_SIZE" -gt 10485760 ]; then
    mv "$LOG" "$LOG.old"
fi

log "━━━ Health check starting ━━━"

# Function to ensure container is running (handles missing containers)
ensure_container() {
    local name=$1
    local compose_dir=$2
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        log "$name not running, recreating..."
        if [ -d "$compose_dir" ] && [ -f "$compose_dir/docker-compose.yml" ]; then
            (cd "$compose_dir" && docker compose up -d 2>&1) | while read line; do log "  $line"; done
        else
            docker start "$name" 2>/dev/null || log "  Failed to start $name"
        fi
    fi
}

# 1. Check Pi-hole (critical - do first)
ensure_container "cubeos-pihole" "/cubeos/coreapps/pihole/appconfig"
sleep 2

# Verify Pi-hole DHCP after ensuring it's running
if docker ps --format '{{.Names}}' | grep -q "cubeos-pihole"; then
    if ! docker exec cubeos-pihole pihole-FTL --config dhcp.active 2>/dev/null | grep -q "true"; then
        log "Pi-hole DHCP not active, restarting..."
        docker restart cubeos-pihole
        sleep 15
    fi
fi

# 2. Check NPM
ensure_container "cubeos-npm" "/cubeos/coreapps/npm/appconfig"

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

# 5. Check other critical containers
ensure_container "cubeos-api" "/cubeos/coreapps/orchestrator/appconfig"
ensure_container "cubeos-dashboard" "/cubeos/coreapps/orchestrator/appconfig"

log "━━━ Health check complete ━━━"
