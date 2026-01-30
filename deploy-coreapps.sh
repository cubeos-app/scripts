#!/bin/bash
# Deploy all CubeOS core apps
set -e

echo "Deploying CubeOS Core Apps..."

# Create network if needed
docker network create cubeos-network 2>/dev/null || true

# Deploy in order
APPS="pihole npm dockge homarr dozzle terminal terminal-ro nettools gpio watchdog"
for app in $APPS; do
    config="/cubeos/coreapps/$app/appconfig/docker-compose.yml"
    if [[ -f "$config" ]]; then
        echo "Starting $app..."
        cd "$(dirname "$config")"
        docker compose up -d
    fi
done

echo "Done! Check: docker ps --format 'table {{.Names}}\t{{.Status}}' | grep cubeos"
