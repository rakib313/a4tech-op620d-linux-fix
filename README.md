# A4Tech OP-620D Linux Fix & Drag Utility

[![Platform](https://img.shields.io/badge/platform-Linux-blue.svg)](https://www.kernel.org/)
[![Python](https://img.shields.io/badge/python-3.6+-blue.svg)](https://www.python.org/)
[![Init System](https://img.shields.io/badge/init-systemd-red.svg)](https://systemd.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A lightweight Linux driver and utility suite that resolves the hardware limitations of the **A4Tech OP-620D** USB optical mouse (`09da:c10a`):

1. **2X Button Single-Click Fix:** Intercepts the physical "2X" button and filters it into an instant, clean single left-click.
2. **Keyboard-Assisted Drag-Lock:** Lets you drag windows, files, and select text effortlessly using the **`Right Alt`** key, dropping naturally with a standard mouse click.

---

## Table of Contents

- [The Hardware Problem](#the-hardware-problem)
- [How It Works](#how-it-works)
  - [1. Single-Click Interceptor (`mouse_fix.py`)](#1-single-click-interceptor-mouse_fixpy)
  - [2. Drag-Lock Companion (`mouse_drag_lock.py`)](#2-drag-lock-companion-mouse_drag_lockpy)
- [Requirements](#requirements)
- [Installation](#installation)
  - [What `install.sh` Does Automatically](#what-installsh-does-automatically)
- [Desktop Environment Setup](#desktop-environment-setup)
  - [XFCE (Automatic)](#xfce-automatic)
  - [GNOME / KDE / Other Environments (Manual)](#gnome--kde--other-environments-manual)
- [Usage Workflow](#usage-workflow)
- [Verification & Troubleshooting](#verification--troubleshooting)
- [Customization](#customization)
- [Uninstallation](#uninstallation)
- [License](#license)

---

## The Hardware Problem

The A4Tech OP-620D includes a small secondary button labeled **"2X"**. On Linux, standard configuration tools (such as `xinput` or generic remap utilities) cannot properly remap this button due to two hardware firmware limitations:

1. **Spoofed Clicks:** The button does **not** emit a distinct hardware scan code (such as `BTN_EXTRA`). Instead, the on-board controller spoofs two standard `BTN_LEFT` events spaced ~72 ms apart.
2. **Hardcoded Firmware Cutoff (No Hardware Hold):** The mouse controller does not send a continuous hold signal when the 2X button is held down. It emits exactly two pulses (~216 ms total) and **completely terminates USB transmission**, regardless of whether the button remains physically depressed.

```text
evtest output when pressing/holding the 2X button:
Event: time 1791289571.103703, type 1 (EV_KEY), code 272 (BTN_LEFT), value 1 (Press)
Event: time 1791289571.175715, type 1 (EV_KEY), code 272 (BTN_LEFT), value 0 (Release)  [+72ms]
Event: time 1791289571.247728, type 1 (EV_KEY), code 272 (BTN_LEFT), value 1 (Press)    [+72ms]
Event: time 1791289571.319682, type 1 (EV_KEY), code 272 (BTN_LEFT), value 0 (Release)  [+72ms]
--- TRANSMISSION CEASES ---
```

Because the hardware stops transmitting after 216 ms and never reports when you release your finger, the 2X button cannot physically sustain a drag or text selection on its own.

---

## How It Works

This repository provides an integrated two-part solution:

```
[ A4Tech OP-620D Mouse ]
       │
       ▼ (Raw USB evdev events)
[ mouse_fix.py (systemd daemon) ] ── (grabs physical device & applies 200ms debounce)
       │
       ▼ (Clean virtual pointer events)
[ /dev/uinput (Virtual Mouse) ] ────► [ Desktop Session ]
                                              ▲
[ Right Alt Key ]                             │
       │                                      │
       ▼ (Remapped to F13 without Mod1)       │
[ mouse_drag_lock.py ] ───────────────────────┘
  (Toggles Left-Button Lock via X11 XTest;
   clicking mouse drops immediately)
```

### 1. Single-Click Interceptor (`mouse_fix.py`)
* Obtains an exclusive hardware lock (`grab()`) on the raw A4Tech device via Python `evdev`.
* Applies a 200 ms debounce filter to swallow the spoofed second hardware pulse.
* Emits a clean, instant single click through a virtual `uinput` mouse device.
* Runs continuously in the background as a lightweight `systemd` daemon.

### 2. Drag-Lock Companion (`mouse_drag_lock.py`)
Because the mouse cannot maintain a hardware hold, your keyboard provides the drag trigger:
* **Remapped Trigger (`F13`):** `install.sh` maps the physical `Right Alt` key (keycode 108) to `F13` and strips the `mod1` modifier via `~/.Xmodmap`. This prevents window managers or text editors from mistaking it for an `Alt+Click` (which often triggers window movements or block selections).
* **Instant Lock:** Pressing `Right Alt` executes `mouse_drag_lock.py`, holding the primary mouse button down and displaying a desktop notification (*"🔒 Drag Locked"*).
* **Hardware Sync:** Queries `XQueryPointer` state directly so that lock/unlock states never fall out of sync.
* **Natural Drop:** Simply click the mouse button (e.g. the 2X button) at your target destination to release and drop the item immediately.

---

## Requirements

- **Supported OS:** Linux (tested on Debian / Ubuntu / Mint / Xubuntu / Arch-based distributions).
- **Display Server:** X11 (required for `mouse_drag_lock.py`).
- **Python:** Python 3.6+ with `python3-evdev`.
- **System Packages:** `x11-xserver-utils` (for `xmodmap`), `libx11-6`, `libxtst6`, `libnotify-bin` (for desktop alerts).
- **Target Hardware:** A4Tech OP-620D USB mouse (Vendor ID: `0x09DA`, Product ID: `0xC10A`).

---

## Installation

Run the automated installer with root privileges:

```bash
git clone https://github.com/rakib313/a4tech-op620d-linux-fix.git
cd a4tech-op620d-linux-fix
chmod +x install.sh uninstall.sh
sudo ./install.sh
```

### What `install.sh` Does Automatically:

1. **Installs System Dependencies:** Fetches `python3-evdev` and `x11-xserver-utils` via `apt-get` (if available).
2. **Deploys Binaries:** Copies `mouse_fix.py` and `mouse_drag_lock.py` to `/usr/local/bin/` with executable permissions.
3. **Configures Background Service:** Installs and enables `a4tech-mouse-fix.service` under `systemd` to start automatically at boot.
4. **Sets Up Key Remapping:**
   - Creates `~/.Xmodmap` to detach `mod1` from `Alt_R` and bind keycode 108 to `F13`.
   - Adds `~/.config/autostart/a4tech-xmodmap.desktop` to ensure the keymap persists across reboots.
   - Applies the keymap immediately to your active X11 session.
5. **Registers Desktop Shortcuts (XFCE):** Automatically binds `F13` to `/usr/local/bin/mouse_drag_lock.py` in `xfce4-keyboard-shortcuts`.

---

## Desktop Environment Setup

### XFCE (Automatic)
No extra configuration needed. `install.sh` automatically binds `F13` via `xfconf-query`.

### GNOME / KDE / Other Environments (Manual)
If you are running GNOME, KDE Plasma, Cinnamon, MATE, or a window manager (i3, bspwm, Openbox), map the shortcut manually:

<details>
<summary><b>GNOME</b></summary>

1. Open **Settings** → **Keyboard** → **Keyboard Shortcuts** → **View and Customize Shortcuts**.
2. Select **Custom Shortcuts** → **Add Shortcut (+)**.
3. Fill in:
   - **Name:** `A4Tech Drag Lock`
   - **Command:** `/usr/local/bin/mouse_drag_lock.py`
   - **Shortcut:** Press the physical **`Right Alt`** key (detected as `F13`).
</details>

<details>
<summary><b>KDE Plasma</b></summary>

1. Open **System Settings** → **Shortcuts** → **Custom Shortcuts** (or **Command Shortcuts**).
2. Add a new **Global Shortcut** → **Command/URL**.
3. Set the trigger key to **`Right Alt`** and the action to `/usr/local/bin/mouse_drag_lock.py`.
</details>

<details>
<summary><b>i3 / Sway / X11 Window Managers</b></summary>

Add the following binding to your window manager configuration (e.g. `~/.config/i3/config`):

```i3config
bindcode 108 exec --no-startup-id /usr/local/bin/mouse_drag_lock.py
```
</details>

---

## Usage Workflow

| Action | How to Do It | Result |
| :--- | :--- | :--- |
| **Normal Single Click** | Tap the mouse **2X button** | Performs a standard, single left-click (second pulse filtered out). |
| **Start Drag / Selection** | Hover over an item or text and tap **`Right Alt`** | Left mouse button is locked down (*🔒 Drag Locked* notification appears). |
| **Move / Select** | Move your mouse freely | Drags files, repositions windows, or selects text. |
| **Drop Item** | Click the mouse **2X button** (or standard left button) | Releases the left mouse button and drops the item naturally. |
| **Cancel Drag** | Tap **`Right Alt`** again | Releases the lock without clicking (*🔓 Drag Released*). |

---

## Verification & Troubleshooting

### 1. Check Background Daemon Status
Verify that the single-click filter is running:
```bash
sudo systemctl status a4tech-mouse-fix.service
```

To monitor live service logs:
```bash
sudo journalctl -u a4tech-mouse-fix.service -f
```

### 2. Verify Mouse Detection
Ensure your system recognizes the mouse hardware:
```bash
lsusb | grep -i "09da:c10a"
```
Or check event devices:
```bash
python3 -c "import evdev; print([(d.name, d.path) for d in map(evdev.InputDevice, evdev.list_devices()) if 'A4Tech' in d.name])"
```

### 3. Test Drag Lock Manually
You can test the drag-lock script directly from a terminal:
```bash
/usr/local/bin/mouse_drag_lock.py
```
A notification should appear stating `🔒 Drag Locked`. Click anywhere with your mouse to release it.

---

## Customization

### Adjusting Debounce Timing
If your mouse requires a slightly shorter or longer window to filter the double-click pulse, adjust `DEBOUNCE_THRESHOLD` in `/usr/local/bin/mouse_fix.py` (or directly in `mouse_fix.py` before installing):

```python
DEBOUNCE_THRESHOLD = 0.20  # Default is 200 ms (0.20s)
```
After editing, restart the service:
```bash
sudo systemctl restart a4tech-mouse-fix.service
```

---

## Uninstallation

To completely remove the background service, deployed scripts, and desktop keymaps:

```bash
sudo ./uninstall.sh
```

This restores your original `Right Alt` key mapping and removes all custom systemd configurations.

---

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).
