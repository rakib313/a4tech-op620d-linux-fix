#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (use sudo ./install.sh)"
  exit 1
fi

echo "==> Installing system dependencies..."
apt-get update -qq
apt-get install -y python3-evdev x11-xserver-utils

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

# Configure Desktop Settings & Keymap for the active user
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || echo 1000)"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "/home/$TARGET_USER")"
CMD="/usr/local/bin/mouse_drag_lock.py"

echo "==> Configuring Right Alt keymap for text selection & dragging..."
# 1. Write ~/.Xmodmap so Right Alt (keycode 108) emits F13 and is removed from mod1
cat << 'EOF' > "${TARGET_HOME}/.Xmodmap"
! A4Tech OP-620D Drag Lock: Remap Right Alt (keycode 108) to F13 without mod1 modifier
remove mod1 = Alt_R
keycode 108 = F13
EOF
chown "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.Xmodmap"

# 2. Add autostart desktop entry so the keymap persists across reboots
mkdir -p "${TARGET_HOME}/.config/autostart"
cat << 'EOF' > "${TARGET_HOME}/.config/autostart/a4tech-xmodmap.desktop"
[Desktop Entry]
Type=Application
Name=A4Tech Right Alt Keymap Fix
Comment=Remap Right Alt to F13 without Alt modifier for text selection and drag lock
Exec=xmodmap %h/.Xmodmap
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.config/autostart"

# 3. Apply xmodmap immediately in active X11 display
if [ -n "$DISPLAY" ] || [ -e "/tmp/.X11-unix/X0" ]; then
  sudo -u "$TARGET_USER" env \
    DISPLAY="${DISPLAY:-:0}" \
    XAUTHORITY="${TARGET_HOME}/.Xauthority" \
    xmodmap "${TARGET_HOME}/.Xmodmap" 2>/dev/null || true
fi

# 4. Configure XFCE application shortcut
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

  # Clean up any legacy bindings
  run_xfconf -p "/commands/custom/Pause" -r 2>/dev/null || true
  run_xfconf -p "/commands/custom/KP_Enter" -r 2>/dev/null || true
  run_xfconf -p "/commands/custom/Alt_R" -r 2>/dev/null || true

  # Map F13 (physical Right Alt key)
  set_shortcut "F13"
  echo "    ✓ Physical 'Right Alt' (F13 clean trigger) mapped to mouse_drag_lock.py"
fi

echo ""
echo "==> Installation complete!"
echo "    - 2X Button: Instant single-click active in background."
echo "    - Dragging & Text Select: Tap 'Right Alt' to lock drag (works on text selection, files, windows); click 2X button to drop!"
