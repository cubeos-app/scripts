#!/bin/bash
# Stop all CubeOS core apps
for dir in /cubeos/coreapps/*/appconfig; do
    [[ -f "$dir/docker-compose.yml" ]] && (cd "$dir" && docker compose down)
done
echo "All core apps stopped"
