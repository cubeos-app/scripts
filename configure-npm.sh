#!/bin/bash
# CubeOS NPM Auto-Configuration Script
# Configures Nginx Proxy Manager with all core app proxy hosts

set -e

NPM_HOST="${NPM_HOST:-192.168.42.1}"
NPM_PORT="${NPM_PORT:-6000}"
NPM_API="http://${NPM_HOST}:${NPM_PORT}/api"
NPM_EMAIL="${NPM_EMAIL:-cubeos@cubeos.app}"
NPM_PASSWORD="${NPM_PASSWORD:-cubeos123}"
BASE_DOMAIN="${BASE_DOMAIN:-cubeos.cube}"
LOCAL_IP="192.168.42.1"

echo "CubeOS NPM Auto-Configuration"
echo "=============================="
echo "NPM API: $NPM_API"
echo "Domain: $BASE_DOMAIN"

# Wait for NPM
echo -n "Waiting for NPM..."
for i in {1..30}; do
    curl -sf "$NPM_API/" >/dev/null 2>&1 && break
    echo -n "."
    sleep 2
done
echo " Ready!"

# Authenticate
TOKEN=$(curl -sf -X POST "$NPM_API/tokens" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$NPM_EMAIL\",\"secret\":\"$NPM_PASSWORD\"}" | jq -r '.token')

if [[ -z "$TOKEN" ]] || [[ "$TOKEN" == "null" ]]; then
    echo "Auth failed. Check credentials."
    exit 1
fi
echo "Authenticated"

# Function to create proxy host
create_proxy() {
    local subdomain="$1" port="$2"
    local domain="$([[ "$subdomain" == "@" ]] && echo "$BASE_DOMAIN" || echo "${subdomain}.${BASE_DOMAIN}")"
    
    echo -n "  $domain -> :$port..."
    
    # Check if exists
    EXISTS=$(curl -sf "$NPM_API/nginx/proxy-hosts" -H "Authorization: Bearer $TOKEN" | \
        jq -r ".[] | select(.domain_names[] == \"$domain\") | .id")
    
    if [[ -n "$EXISTS" ]]; then
        echo " exists"
        return
    fi
    
    curl -sf -X POST "$NPM_API/nginx/proxy-hosts" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"domain_names\": [\"$domain\"],
            \"forward_scheme\": \"http\",
            \"forward_host\": \"$LOCAL_IP\",
            \"forward_port\": $port,
            \"access_list_id\": 0,
            \"certificate_id\": 0,
            \"ssl_forced\": false,
            \"block_exploits\": true,
            \"allow_websocket_upgrade\": true,
            \"enabled\": true,
            \"locations\": []
        }" >/dev/null && echo " created" || echo " failed"
}

echo ""
echo "Creating proxy hosts..."
create_proxy "@" 8087
create_proxy "dashboard" 8087
create_proxy "api" 9009
create_proxy "dns" 6001
create_proxy "pihole" 6001
create_proxy "stacks" 6002
create_proxy "dockge" 6002
create_proxy "home" 6003
create_proxy "homarr" 6003
create_proxy "logs" 6004
create_proxy "terminal" 6009

echo ""
echo "Done! Access: https://$BASE_DOMAIN"
