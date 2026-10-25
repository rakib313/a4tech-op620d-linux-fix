#!/usr/bin/env python3
"""
A4Tech OP-620D Companion: Drag-Lock Utility for Linux.
Part of https://github.com/rakib313/a4tech-op620d-linux-fix

Locks Left Mouse Button (Button 1) down when triggered via Right Alt (Alt_R).
To drop the item, simply click the mouse button (2X button) naturally!
Uses X11 XQueryPointer to verify physical pointer state so it never desyncs.
"""

import ctypes
import os
import subprocess
import sys


def get_x11():
    if not os.environ.get("DISPLAY"):
        os.environ["DISPLAY"] = ":0"
    try:
        x11 = ctypes.CDLL("libX11.so.6")
        xtst = ctypes.CDLL("libXtst.so.6")
    except Exception as e:
        sys.exit(f"Error: Unable to load X11 libraries: {e}")

    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XDefaultRootWindow.restype = ctypes.c_ulong
    x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]

    x11.XQueryPointer.argtypes = [
        ctypes.c_void_p,
        ctypes.c_ulong,
        ctypes.POINTER(ctypes.c_ulong),
        ctypes.POINTER(ctypes.c_ulong),
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_uint),
    ]

    xtst.XTestFakeButtonEvent.argtypes = [
        ctypes.c_void_p,
        ctypes.c_uint,
        ctypes.c_int,
        ctypes.c_ulong,
    ]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]

    display = x11.XOpenDisplay(None)
    if not display:
        display = x11.XOpenDisplay(b":0")
    return x11, xtst, display


def notify(title, msg, icon="input-mouse"):
    try:
        subprocess.run(
            ["notify-send", "-t", "900", "-i", icon, title, msg],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass


def main():
    x11, xtst, display = get_x11()
    if not display:
        sys.exit("Error: Could not connect to X11 display.")

    root = x11.XDefaultRootWindow(display)
    dummy_root = ctypes.c_ulong()
    dummy_child = ctypes.c_ulong()
    rx, ry, wx, wy = ctypes.c_int(), ctypes.c_int(), ctypes.c_int(), ctypes.c_int()
    mask = ctypes.c_uint()

    x11.XQueryPointer(
        display,
        root,
        ctypes.byref(dummy_root),
        ctypes.byref(dummy_child),
        ctypes.byref(rx),
        ctypes.byref(ry),
        ctypes.byref(wx),
        ctypes.byref(wy),
        ctypes.byref(mask),
    )

    # Button1Mask in X11 is (1 << 8) = 256
    is_btn1_down = bool(mask.value & 256)

    if not is_btn1_down:
        # Press Left Mouse Button down (Drag start)
        xtst.XTestFakeButtonEvent(display, 1, 1, 0)
        x11.XFlush(display)
        notify("Mouse Drag", "🔒 Drag Locked (Click mouse to drop)")
    else:
        # Safety toggle: If already locked and Right Alt is pressed again, release it
        xtst.XTestFakeButtonEvent(display, 1, 0, 0)
        x11.XFlush(display)
        notify("Mouse Drag", "🔓 Drag Released")

    x11.XCloseDisplay(display)


if __name__ == "__main__":
    main()
