#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (use sudo ./uninstall.sh)"
  exit 1
fi

echo "==> Stopping and disabling service..."
systemctl stop a4tech-mouse-fix.service 2>/dev/null || true
systemctl disable a4tech-mouse-fix.service 2>/dev/null || true

echo "==> Removing installed files..."
rm -f /etc/systemd/system/a4tech-mouse-fix.service
rm -f /usr/local/bin/mouse_fix.py

echo "==> Reloading systemd..."
systemctl daemon-reload

echo "==> Uninstallation complete. Original hardware behavior restored."