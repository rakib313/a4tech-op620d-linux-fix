#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (use sudo ./install.sh)"
  exit 1
fi

echo "==> Installing dependencies..."
apt-get update -qq
apt-get install -y python3-evdev

echo "==> Deploying interceptor script to /usr/local/bin/..."
cp mouse_fix.py /usr/local/bin/mouse_fix.py
chmod 755 /usr/local/bin/mouse_fix.py

echo "==> Installing systemd service..."
cp a4tech-mouse-fix.service /etc/systemd/system/a4tech-mouse-fix.service
chmod 644 /etc/systemd/system/a4tech-mouse-fix.service

echo "==> Reloading and activating service..."
systemctl daemon-reload
systemctl enable --now a4tech-mouse-fix.service

echo "==> Installation complete! The 2X button now acts as a single click."