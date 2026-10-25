#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (use sudo ./uninstall.sh)"
  exit 1
fi

echo "==> Stopping and disabling systemd service..."
systemctl stop a4tech-mouse-fix.service 2>/dev/null || true
systemctl disable a4tech-mouse-fix.service 2>/dev/null || true

echo "==> Removing deployed scripts and service..."
rm -f /etc/systemd/system/a4tech-mouse-fix.service
rm -f /usr/local/bin/mouse_fix.py
rm -f /usr/local/bin/mouse_drag_lock.py

echo "==> Reloading systemd..."
systemctl daemon-reload

# Clean up keyboard shortcuts for the desktop user if XFCE is present
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || echo 1000)"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "/home/$TARGET_USER")"

if command -v xfconf-query >/dev/null 2>&1; then
  echo "==> Cleaning up XFCE keyboard shortcuts for user '$TARGET_USER'..."

  run_xfconf() {
    sudo -u "$TARGET_USER" env \
      DISPLAY="${DISPLAY:-:0}" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus" \
      XAUTHORITY="${TARGET_HOME}/.Xauthority" \
      xfconf-query -c xfce4-keyboard-shortcuts "$@" 2>/dev/null || true
  }

  run_xfconf -p "/commands/custom/Alt_R" -r 2>/dev/null || true
  run_xfconf -p "/commands/custom/Pause" -r 2>/dev/null || true
  run_xfconf -p "/commands/custom/KP_Enter" -r 2>/dev/null || true
  echo "    ✓ Removed custom drag shortcuts (Alt_R, Pause, KP_Enter)"
fi

echo ""
echo "==> Uninstallation complete. Original hardware behavior restored."
