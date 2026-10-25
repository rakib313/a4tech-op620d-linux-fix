# A4Tech OP-620D Linux Fix & Drag Utility

A lightweight Linux driver and utility suite that solves the hardware limitations of the **A4Tech OP-620D** USB mouse (`09da:c10a`):

1. **2X Button Single-Click Fix:** Intercepts the physical "2X" button and filters it into an instant, clean single left-click.
2. **Keyboard-Assisted Drag-Lock:** Lets you drag windows, files, and text effortlessly using the **`Right Alt`** key, dropping naturally with a normal mouse click!

---

## The Hardware Problem

The A4Tech OP-620D includes a secondary button labeled **"2X"**. On Linux, standard configuration tools fail due to how the mouse firmware is hardwired:

1. **Spoofed Clicks:** The button does **not** emit a distinct scan code (like `BTN_EXTRA`). Instead, the hardware controller spoofs two standard `BTN_LEFT` events spaced ~72ms apart.
2. **Hardcoded Firmware Cutoff (No Hardware Hold):** The mouse controller does not send a continuous hold signal when the 2X button is pressed. Instead, it emits exactly two pulses (~216ms total) and **completely cuts off USB transmission**, regardless of how long the button is held down.

```text
evtest output when pressing/holding the 2X button:
Event: time 1791289571.103703, type 1 (EV_KEY), code 272 (BTN_LEFT), value 1 (Press)
Event: time 1791289571.175715, type 1 (EV_KEY), code 272 (BTN_LEFT), value 0 (Release)  [+72ms]
Event: time 1791289571.247728, type 1 (EV_KEY), code 272 (BTN_LEFT), value 1 (Press)    [+72ms]
Event: time 1791289571.319682, type 1 (EV_KEY), code 272 (BTN_LEFT), value 0 (Release)  [+72ms]
--- TRANSMISSION CEASES ---
```

Because the hardware stops transmitting after 216ms and never reports when you lift your finger, the 2X button cannot physically sustain a drag on its own.

---

## The Complete Solution

This repository provides an integrated, two-part system:

### 1. Single-Click Interceptor (`mouse_fix.py`)
* Obtains an exclusive hardware lock (`grab()`) on the raw A4Tech device via Python `evdev`.
* Applies a 200ms debounce filter to eliminate the spoofed second hardware pulse.
* Emits a clean, instant single click through a virtual `uinput` mouse device.
* Runs continuously in the background via a persistent `systemd` daemon.

### 2. Drag-Lock Companion (`mouse_drag_lock.py`)
Because the mouse cannot hardware-hold, your keyboard provides the drag trigger:
* **To Drag:** Tap the **`Right Alt`** key on your keyboard. Left-click is locked down immediately (*🔒 Drag Locked*).
* **To Move:** Move your mouse freely anywhere (move windows, select text, drag files).
* **To Drop:** Simply **click your mouse button (the 2X button)** at your destination! The mouse click emits a standard release, dropping the item naturally.
* Uses direct X11 `XQueryPointer` hardware checking, ensuring state never desyncs.

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
* Installs required dependencies (`python3-evdev`).
* Deploys `mouse_fix.py` and `mouse_drag_lock.py` to `/usr/local/bin/`.
* Installs, enables, and restarts the `a4tech-mouse-fix.service` systemd daemon.
* Configures global XFCE desktop application shortcuts:
  * **`Right Alt`** (`Alt_R`) $\rightarrow$ `/usr/local/bin/mouse_drag_lock.py`

---

## Usage Workflow

| Action | How to Do It |
| :--- | :--- |
| **Normal Single Click** | Tap the mouse **2X button**. |
| **Start Dragging** | Hover over item and tap **`Right Alt`**. |
| **Drop Item** | Click the mouse **2X button** at your destination. |
| **Cancel Drag** | Tap **`Right Alt`** again if you change your mind without clicking. |

---

## Uninstallation

To completely remove the background service, scripts, and shortcuts:

```bash
sudo ./uninstall.sh
```

---

## License

MIT
