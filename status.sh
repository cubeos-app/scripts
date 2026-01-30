#!/bin/bash
# CubeOS status overview
echo "=== CubeOS Status ==="
echo ""
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "cubeos|NAMES"
echo ""
echo "=== Port Check ==="
for port in 6000 6001 6002 6003 6004 6009 6010 8087 9009; do
    nc -zv 192.168.42.1 $port 2>&1 | grep -q succeeded && echo "✓ $port" || echo "✗ $port"
done
