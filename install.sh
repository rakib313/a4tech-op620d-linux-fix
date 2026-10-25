#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (use sudo ./install.sh)"
  exit 1
fi

echo "==> Installing system dependencies..."
apt-get update -qq
apt-get install -y python3-evdev

echo "==> Deploying mouse filter and drag-lock to /usr/local/bin/..."
cp mouse_fix.py /usr/local/bin/mouse_fix.py
chmod 755 /usr/local/bin/mouse_fix.py

cp mouse_drag_lock.py /usr/local/bin/mouse_drag_lock.py
chmod 755 /usr/local/bin/mouse_drag_lock.py

echo "==> Installing systemd background service..."
cp a4tech-mouse-fix.service /etc/systemd/system/a4tech-mouse-fix.service
chmod 644 /etc/systemd/system/a4tech-mouse-fix.service

echo "==> Reloading and activating service..."
systemctl daemon-reload
systemctl enable a4tech-mouse-fix.service
systemctl restart a4tech-mouse-fix.service

# Configure Desktop Shortcuts for the active user (Right Alt / Alt_R)
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || echo 1000)"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "/home/$TARGET_USER")"
CMD="/usr/local/bin/mouse_drag_lock.py"

if command -v xfconf-query >/dev/null 2>&1; then
  echo "==> Setting up XFCE keyboard shortcuts for user '$TARGET_USER'..."

  run_xfconf() {
    sudo -u "$TARGET_USER" env \
      DISPLAY="${DISPLAY:-:0}" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus" \
      XAUTHORITY="${TARGET_HOME}/.Xauthority" \
      xfconf-query -c xfce4-keyboard-shortcuts "$@" 2>/dev/null || true
  }

  set_shortcut() {
    local key="$1"
    if run_xfconf -p "/commands/custom/$key" >/dev/null 2>&1; then
      run_xfconf -p "/commands/custom/$key" -s "$CMD"
    else
      run_xfconf -p "/commands/custom/$key" -n -t string -s "$CMD"
    fi
  }

  # Clean up any legacy bindings from previous versions
  run_xfconf -p "/commands/custom/Pause" -r 2>/dev/null || true
  run_xfconf -p "/commands/custom/KP_Enter" -r 2>/dev/null || true

  # Set Right Alt (Alt_R)
  set_shortcut "Alt_R"
  echo "    ✓ 'Right Alt' (Alt_R) mapped to mouse_drag_lock.py"
else
  echo "==> Note: Non-XFCE environment detected."
  echo "    Please manually bind 'Right Alt' (Alt_R) to '/usr/local/bin/mouse_drag_lock.py' in your system settings."
fi

echo ""
echo "==> Installation complete!"
echo "    - 2X Button: Instant single-click active in background."
echo "    - Dragging: Tap 'Right Alt' to lock drag; click 2X button to drop!"
