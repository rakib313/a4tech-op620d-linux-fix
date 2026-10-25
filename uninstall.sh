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

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || echo 1000)"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "/home/$TARGET_USER")"

# Restore original Right Alt keymap
rm -f "${TARGET_HOME}/.Xmodmap"
rm -f "${TARGET_HOME}/.config/autostart/a4tech-xmodmap.desktop"

if [ -n "$DISPLAY" ] || [ -e "/tmp/.X11-unix/X0" ]; then
  sudo -u "$TARGET_USER" env \
    DISPLAY="${DISPLAY:-:0}" \
    XAUTHORITY="${TARGET_HOME}/.Xauthority" \
    xmodmap -e "keycode 108 = Alt_R Meta_R Alt_R Meta_R" -e "add mod1 = Alt_R" 2>/dev/null || true
fi

# Clean up keyboard shortcuts for the desktop user if XFCE is present
if command -v xfconf-query >/dev/null 2>&1; then
  echo "==> Cleaning up XFCE keyboard shortcuts for user '$TARGET_USER'..."

  run_xfconf() {
    sudo -u "$TARGET_USER" env \
      DISPLAY="${DISPLAY:-:0}" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus" \
      XAUTHORITY="${TARGET_HOME}/.Xauthority" \
      xfconf-query -c xfce4-keyboard-shortcuts "$@" 2>/dev/null || true
  }

  run_xfconf -p "/commands/custom/F13" -r 2>/dev/null || true
  run_xfconf -p "/commands/custom/Alt_R" -r 2>/dev/null || true
  run_xfconf -p "/commands/custom/Pause" -r 2>/dev/null || true
  run_xfconf -p "/commands/custom/KP_Enter" -r 2>/dev/null || true
  echo "    ✓ Removed custom drag shortcuts (F13, Alt_R, Pause, KP_Enter)"
fi

echo ""
echo "==> Uninstallation complete. Original hardware behavior restored."
