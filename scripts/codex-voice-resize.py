#!/usr/bin/env python3
"""Guarded, one-shot workaround for the oversized Codex voice overlay.

Dry-run by default. Supply a freshly inspected window address, never a title
selector. This does not disable automatic popout or start/end a voice call.
Lua syntax verified against Hyprland v0.56.1 LuaBindingsDispatchers.cpp and
the installed share/hypr/stubs/hl.meta.lua. No third-party Python dependencies.
"""

import argparse
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time


class Refusal(ValueError):
    pass


def address_value(value):
    if not re.fullmatch(r"0x[0-9a-fA-F]+", value):
        raise Refusal("Address must be an explicit hexadecimal Hyprland address")
    return value.lower()


def query(kind):
    return json.loads(subprocess.check_output(["hyprctl", "-j", kind], text=True))


def select(clients, address):
    address = address_value(address)
    matches = [c for c in clients if c.get("address", "").lower() == address]
    if len(matches) != 1:
        raise Refusal("Exact window address is absent or ambiguous")
    c = matches[0]
    if not (c.get("class") == "codex-desktop"
            and c.get("initialClass") == "codex-desktop"
            and c.get("title") == "ChatGPT"
            and c.get("initialTitle") == "ChatGPT"
            and c.get("floating") is True and c.get("xwayland") is False
            and c.get("mapped") is True and c.get("hidden") is False
            and not c.get("fullscreen") and not c.get("grouped")
            and isinstance(c.get("pid"), int) and c["pid"] > 0
            and re.fullmatch(r"[0-9a-fA-F]+", str(c.get("stableId", "")))):
        raise Refusal("Target is not the observed standalone native Codex overlay; main windows are refused")
    return c


def workarea(monitor):
    scale = float(monitor["scale"])
    if scale <= 0:
        raise Refusal("Invalid monitor scale")
    w, h = monitor["width"], monitor["height"]
    if monitor["transform"] % 2:
        w, h = h, w
    w, h = math.floor(w / scale), math.floor(h / scale)
    left, top, right, bottom = monitor["reserved"]
    return [monitor["x"] + left, monitor["y"] + top,
            w - left - right, h - top - bottom]


def plan(c, monitors):
    matches = [m for m in monitors if m["id"] == c["monitor"]]
    if len(matches) != 1:
        raise Refusal("Target monitor is missing or ambiguous")
    x, y, w, h = workarea(matches[0])
    cw, ch = c["size"]
    if not (200 <= cw <= 1200 and ch >= 1400 and ch > 2.5 * cw and ch > h):
        raise Refusal("Window does not match the observed abnormally tall overlay geometry")
    margin = 24
    width, height = min(460, w - 2 * margin), min(680, h - 2 * margin)
    if width < 320 or height < 400:
        raise Refusal("Monitor workarea is too small for the proposed controls")
    return {"at": [x + w - width - margin, y + margin], "size": [width, height]}


def identity(c):
    return {k: c[k] for k in ("address", "pid", "stableId", "class", "initialClass", "title", "initialTitle")}


def geometry(c):
    result = {k: c[k] for k in ("at", "size")}
    for k, pair in result.items():
        if not (isinstance(pair, list) and len(pair) == 2
                and all(type(v) is int and abs(v) < 100000 for v in pair)):
            raise Refusal("Invalid geometry")
        if k == "size" and min(pair) <= 0:
            raise Refusal("Invalid window size")
    return result


def lua_command(c, target):
    address = address_value(c["address"])
    x, y = geometry(target)["at"]
    width, height = target["size"]
    pid, stable = c["pid"], int(c["stableId"], 16)
    if type(pid) is not int or pid <= 0:
        raise Refusal("Invalid process identity")
    # Only validated numeric literals and fixed strings enter Lua; no shell.
    code = (
        f'local w=hl.get_window("address:{address}"); '
        f'assert(w and w.pid=={pid} and w.stable_id=={stable}, "Window identity changed"); '
        'assert(w["class"]=="codex-desktop" and w.initial_class=="codex-desktop" '
        'and w.title=="ChatGPT" and w.initial_title=="ChatGPT" '
        'and w.floating and not w.xwayland and w.mapped and not w.hidden '
        'and w.fullscreen==0, "Overlay identity changed"); '
        f'hl.dispatch(hl.dsp.window.resize({{x={width}, y={height}, relative=false, window=w}})); '
        f'hl.dispatch(hl.dsp.window.move({{x={x}, y={y}, relative=false, window=w}}))'
    )
    return ["hyprctl", "eval", code]


def snapshot(data):
    # mkstemp creates a private 0600 file; never overwrite existing rollback data.
    fd, name = tempfile.mkstemp(prefix="codex-voice-geometry-", suffix=".json")
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2)
        f.flush()
        os.fsync(f.fileno())
    return name


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--address", required=True, help="Freshly inspected exact overlay address")
    parser.add_argument("--apply", action="store_true", help="Resize/move; default only prints plan")
    parser.add_argument("--restore", type=Path, help="Restore geometry from this helper's private snapshot")
    args = parser.parse_args(argv)
    session = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not session:
        raise Refusal("Run inside the intended Hyprland session")
    c = select(query("clients"), args.address)
    if args.restore:
        stat = args.restore.stat()
        if stat.st_uid != os.getuid() or stat.st_mode & 0o077:
            raise Refusal("Rollback file must be owned by you and private (0600)")
        data = json.loads(args.restore.read_text())
        if data.get("version") != 1 or data.get("session") != session or data.get("identity") != identity(c):
            raise Refusal("Rollback belongs to a different session or window identity")
        target = geometry(data["original"])
    else:
        target = plan(c, query("monitors"))
    print(json.dumps({"mode": "apply" if args.apply else "dry-run", "address": c["address"],
                      "original": geometry(c), "target": target}, indent=2))
    command = lua_command(c, target)
    if not args.apply:
        return 0
    # Recheck immediately before dispatch; compositor also checks identity atomically.
    fresh = select(query("clients"), args.address)
    if identity(fresh) != identity(c) or geometry(fresh) != geometry(c):
        raise Refusal("Window changed after inspection; rerun the dry-run")
    rollback = snapshot({"version": 1, "session": session, "identity": identity(c),
                         "original": geometry(c), "target": target})
    print(f"Rollback snapshot: {rollback}", flush=True)
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode or result.stdout.strip() != "ok":
        raise Refusal(f"Compositor did not confirm the command; inspect state and use {rollback} to restore")
    # Two bounded observations catch common animation delay and immediate app override.
    for delay in (0.5, 1.0):
        time.sleep(delay)
        observed = select(query("clients"), args.address)
        if identity(observed) != identity(c) or geometry(observed) != target:
            raise Refusal(f"Geometry did not hold; no retries. Restore using {rollback}")
    print("Verified target geometry twice. Visual usability still requires user inspection.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (Refusal, KeyError, TypeError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Refused: {error}", file=sys.stderr)
        sys.exit(1)
