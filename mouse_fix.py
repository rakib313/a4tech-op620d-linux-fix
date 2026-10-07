#!/usr/bin/env python3
"""
A4Tech OP-620D Hardware Double-Click Interceptor for Linux.
Intercepts low-level evdev events, filters out the hardware-spoofed second
click, and exposes a clean virtual uinput pointer.
"""

import sys
import evdev
from evdev import UInput, ecodes

VENDOR_ID = 0x09DA
PRODUCT_ID = 0xC10A
DEBOUNCE_THRESHOLD = 0.20  # 200 ms


def locate_device():
    for path in evdev.list_devices():
        try:
            device = evdev.InputDevice(path)
            is_matching_id = (device.info.vendor == VENDOR_ID and device.info.product == PRODUCT_ID)
            is_matching_name = "A4Tech" in device.name

            if (is_matching_id or is_matching_name) and ecodes.EV_KEY in device.capabilities():
                if ecodes.BTN_LEFT in device.capabilities()[ecodes.EV_KEY]:
                    return device
        except Exception:
            continue
    return None


def main():
    source_mouse = locate_device()
    if not source_mouse:
        print(f"Error: Target A4Tech mouse (Vendor: {hex(VENDOR_ID)}, Product: {hex(PRODUCT_ID)}) not found.", file=sys.stderr)
        sys.exit(1)

    print(f"Interception active on: {source_mouse.name} ({source_mouse.path})")

    source_mouse.grab()
    virtual_mouse = UInput.from_device(source_mouse, name="A4Tech OP-620D (Debounced Virtual)")

    last_click_time = 0.0
    ignore_release = False

    try:
        for event in source_mouse.read_loop():
            if event.type == ecodes.EV_KEY and event.code == ecodes.BTN_LEFT:
                if event.value == 1:  # Button Press
                    delta = event.timestamp() - last_click_time
                    if delta < DEBOUNCE_THRESHOLD:
                        ignore_release = True
                        continue
                    else:
                        last_click_time = event.timestamp()
                        ignore_release = False
                        virtual_mouse.write_event(event)
                elif event.value == 0:  # Button Release
                    if ignore_release:
                        ignore_release = False
                        continue
                    else:
                        virtual_mouse.write_event(event)
            else:
                virtual_mouse.write_event(event)

            virtual_mouse.syn()

    except KeyboardInterrupt:
        pass
    finally:
        try:
            source_mouse.ungrab()
        except Exception:
            pass
        virtual_mouse.close()


if __name__ == "__main__":
    main()