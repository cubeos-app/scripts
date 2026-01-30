#!/bin/bash
cp /cubeos/scripts/cubeos-watchdog.* /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now cubeos-watchdog.timer
echo "✅ Watchdog timer installed"
