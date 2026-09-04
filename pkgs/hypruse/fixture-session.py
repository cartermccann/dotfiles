"""Own disposable GTK processes; attempt and report focus/cursor restoration."""
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

fixture, output = sys.argv[1:]
out = Path(output)
out.mkdir(parents=True, exist_ok=False, mode=0o700)


def query(name):
    return json.loads(subprocess.check_output(["hyprctl", "-j", name], text=True))


def dispatch(expr):
    result = subprocess.check_output(["hyprctl", "dispatch", expr], text=True).strip()
    if result != "ok":
        raise RuntimeError(result)


original = {"address": query("activewindow").get("address"), "cursor": query("cursorpos")}
processes = []
windows = {}


def interrupted(*_):
    raise KeyboardInterrupt


signal.signal(signal.SIGTERM, interrupted)
try:
    for name in ("A", "B"):
        log = (out / (name + ".log")).open("w")
        proc = subprocess.Popen([fixture, name, str(out / (name + ".json"))], stdout=log, stderr=log)
        processes.append(proc)
        for _ in range(80):
            matches = [w for w in query("clients") if w.get("pid") == proc.pid]
            if len(matches) == 1:
                break
            if proc.poll() is not None:
                raise RuntimeError("Disposable GTK app failed; inspect its test log")
            time.sleep(0.1)
        else:
            raise RuntimeError("Could not identify exactly one disposable window")
        w = matches[0]
        if w["class"] != "local.hypruse.Poc" + name or w["title"] != "Hypruse Test " + name:
            raise RuntimeError("Fixture identity mismatch")
        windows[name] = {k: w[k] for k in ("address", "pid", "class", "title")}
    # Isolate the disposable apps from existing windows before any capture.
    for w in windows.values():
        dispatch('hl.dsp.window.move({ window = "address:' + w["address"] + '", workspace = "special:hypruse-poc", follow = false })')
    dispatch('hl.dsp.focus({ window = "address:' + windows["A"]["address"] + '" })')
    time.sleep(0.4)
    for name, expected in windows.items():
        matches = [w for w in query("clients") if w.get("address") == expected["address"]]
        if len(matches) != 1 or matches[0]["pid"] != expected["pid"]:
            raise RuntimeError("Fixture vanished during setup")
        expected["at"] = matches[0]["at"]
        expected["size"] = matches[0]["size"]
        expected["monitor"] = matches[0]["monitor"]
    (out / "session.json").write_text(json.dumps({"original": original, "windows": windows}, indent=2))
    print(json.dumps({"ready": True, "output": str(out), "windows": windows}), flush=True)
    while True:
        if any(proc.poll() is not None for proc in processes):
            raise RuntimeError("Disposable fixture exited; stop trial")
        time.sleep(1)
except KeyboardInterrupt:
    pass
finally:
    for proc in processes:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
    cursor = original["cursor"]
    dispatch(f'hl.dsp.cursor.move({{ x = {cursor["x"]}, y = {cursor["y"]} }})')
    if original["address"]:
        live = {w["address"] for w in query("clients")}
        if original["address"] in live:
            dispatch('hl.dsp.focus({ window = "address:' + original["address"] + '" })')
    restored = query("activewindow").get("address") == original["address"]
    (out / "cleanup.json").write_text(json.dumps({"fixtures_stopped": all(p.poll() is not None for p in processes), "focus_restored": restored, "cursor_restored": query("cursorpos") == cursor}))
    print("Test windows stopped; original focus restoration:", restored, flush=True)
