# A4Tech OP-620D 2X Button Fix for Linux

A lightweight userspace input filter that remaps the physical **"2X Click"** button on the **A4Tech OP-620D** USB mouse (`09da:c10a`) to act as a standard single left-click under Linux.

---

## The Hardware Problem

The A4Tech OP-620D mouse includes a small orange/black secondary button labeled **"2X"**. On Windows, proprietary A4Tech drivers interpret this button. On Linux, standard solutions like `libinput` quirks or GUI utilities (`input-remapper`) fail due to how the mouse hardware is hardwired:

1. **Spoofed Clicks:** The button does **not** emit a distinct scan code (like `BTN_EXTRA`). Instead, the firmware spoofs two standard `BTN_LEFT` events spaced ~72ms apart. The OS cannot distinguish this from a user clicking the main button twice.

2. **No Hold-and-Drag Capability:** It is physically impossible to use this button for click-and-drag actions. Holding the button down does not send a continuous hold signal. Instead, the hardware controller forcefully spams a rapid press/release loop every 72ms.

**`evtest` output when holding the 2X button down continuously:**

```text
Event: time 1791289571.103703, type 1 (EV_KEY), code 272 (BTN_LEFT), value 1 (Press)
Event: time 1791289571.175715, type 1 (EV_KEY), code 272 (BTN_LEFT), value 0 (Release)
Event: time 1791289571.247728, type 1 (EV_KEY), code 272 (BTN_LEFT), value 1 (Press)
Event: time 1791289571.319682, type 1 (EV_KEY), code 272 (BTN_LEFT), value 0 (Release)
```

---

## The Solution

This utility uses Python's `evdev` interface to safely intercept and sanitize the hardware signals:

- Obtains an exclusive hardware lock (`grab()`) on the raw A4Tech device.
- Filters incoming `BTN_LEFT` events using a **200ms debounce threshold**, effectively dropping the spoofed redundant hardware signals.
- Emits a clean, single click through a virtual `uinput` mouse device.
- Runs completely invisibly in the background via a persistent `systemd` daemon.

> **Trade-off Note:** Because this filters all `BTN_LEFT` inputs, any manual left clicks made within 200ms of each other (via the main button) will also be suppressed. Your maximum manual click rate will be roughly **5 clicks per second**.

---

## Installation

### Automated Install (Recommended)

Clone the repository and run the install script:

```bash
git clone https://github.com/<your-username>/a4tech-op620d-linux-fix.git
cd a4tech-op620d-linux-fix
chmod +x install.sh uninstall.sh
sudo ./install.sh
```

### Manual Install

If you prefer to configure the system yourself:

1. Install dependencies:
   ```bash
   sudo apt install python3-evdev
   ```

2. Copy `mouse_fix.py` to `/usr/local/bin/` and `chmod 755`.

3. Copy `a4tech-mouse-fix.service` to `/etc/systemd/system/`.

4. Enable the service:
   ```bash
   sudo systemctl enable --now a4tech-mouse-fix.service
   ```

---

## Uninstallation

Run the uninstaller to remove all files and restore the original hardware behavior:

```bash
sudo ./uninstall.sh
```

---

## License

MIT

---
