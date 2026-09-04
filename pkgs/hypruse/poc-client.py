"""Bounded MCP test client; only calls explicit disposable fixture targets."""
import asyncio
import base64
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

binary, directory, phase = sys.argv[1:]
out = Path(directory)
windows = json.loads((out / "session.json").read_text())["windows"]
fingerprint = hashlib.sha256((out / "session.json").read_bytes()).hexdigest()


def passed(name):
    marker = out / (name + ".passed")
    return marker.is_file() and marker.read_text() == fingerprint


def query(name):
    return json.loads(subprocess.check_output(["hyprctl", "-j", name], text=True))


def verify(name, focused=False):
    expected = windows[name]
    found = [w for w in query("clients") if w.get("address") == expected["address"]]
    if not (len(found) == 1):
        raise RuntimeError("Disposable target disappeared")
    w = found[0]
    if not (all(w[k] == expected[k] for k in ("pid", "class", "title"))):
        raise RuntimeError("Target identity changed")
    if not (w["workspace"]["name"] == "special:hypruse-poc"):
        raise RuntimeError("Target left test workspace")
    if not (w["mapped"] and not w["hidden"]):
        raise RuntimeError("Target not mapped")
    if not (w["at"] == expected["at"] and w["size"] == expected["size"]):
        raise RuntimeError("Target geometry changed")
    if w["monitor"] != expected["monitor"]:
        raise RuntimeError("Target monitor changed")
    monitors = query("monitors")
    monitor = next((m for m in monitors if m["id"] == w["monitor"]), None)
    if not (monitor and monitor.get("specialWorkspace", {}).get("id") == w["workspace"]["id"]):
        raise RuntimeError("Test workspace not visible")
    if focused:
        if not (query("activewindow").get("address") == w["address"]):
            raise RuntimeError("Focus changed; abort")
    return w


async def main():
    if phase not in ("observe", "dryrun", "act"):
        raise ValueError("phase must be observe, dryrun, or act")
    for name in {"observe": ("observe", "dryrun", "act"), "dryrun": ("dryrun", "act"), "act": ("act",)}[phase]:
        (out / (name + ".passed")).unlink(missing_ok=True)
    if phase in ("dryrun", "act") and not passed("observe"):
        raise RuntimeError("Current fixture session has no successful observation")
    if phase == "act" and not passed("dryrun"):
        raise RuntimeError("Current fixture session has no successful rehearsal")
    env = {k: v for k, v in os.environ.items() if k in (
        "PATH", "HOME", "USER", "LANG", "LC_ALL", "XDG_RUNTIME_DIR", "XDG_CURRENT_DESKTOP",
        "XDG_SESSION_TYPE", "WAYLAND_DISPLAY", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "DBUS_SESSION_BUS_ADDRESS",
    )}
    env.update({"HYPRUSE_READONLY": "1" if phase == "observe" else "0", "HYPRUSE_MARK": "0",
                "HYPRUSE_CLIPBOARD": "0", "HYPRUSE_JOURNAL": "0", "HYPRUSE_SCREENSHOT_MODE": "image",
                "HYPRUSE_AUTH_GUARD": "strict", "HYPRUSE_STRICT": "1",
                "HYPRUSE_CONFINE": "class:local.hypruse.PocA,local.hypruse.PocB",
                "HYPRUSE_DRYRUN": "1" if phase == "dryrun" else "0"})
    records = []
    expected_focus = "A"
    async with stdio_client(StdioServerParameters(command=binary, env=env)) as (r, w):
        async with ClientSession(r, w) as session:
            await session.initialize()
            tools = sorted(t.name for t in (await session.list_tools()).tools)
            if phase == "observe":
                if not (tools == ["binds", "desktop", "marks", "screenshot", "ui", "wait_for", "zoom"]):
                    raise RuntimeError('PoC verification failed')
            records.append({"tools": tools, "phase": phase})

            async def call(tool, fixture_name, **args):
                nonlocal expected_focus
                # Targeted upstream focus operations deliberately bypass its seat guard.
                # Check our current owner before switching to another test process.
                if phase in ("act", "dryrun"):
                    verify(expected_focus, focused=True)
                verify(fixture_name, focused=tool in ("screenshot", "click_ui", "keyboard"))
                if tool == "hypr":
                    args["target"] = windows[fixture_name]["address"]
                else:
                    args["window"] = windows[fixture_name]["address"]
                if tool in ("hypr", "click_ui", "keyboard"):
                    args["then"] = "none"
                result = await session.call_tool(tool, args)
                record = {"tool": tool, "fixture": fixture_name, "error": result.isError, "content": []}
                for c in result.content:
                    if c.type == "image":
                        path = out / f"{phase}-{fixture_name}-{len(records)}.png"
                        path.write_bytes(base64.b64decode(c.data))
                        record["content"].append({"image": str(path)})
                    elif c.type == "text":
                        record["content"].append(c.text)
                records.append(record)
                (out / (phase + ".json")).write_text(json.dumps(records, indent=2))
                print(json.dumps(record), flush=True)
                if not (not result.isError):
                    raise RuntimeError("MCP call refused; no further actions")
                if tool == "hypr" and phase == "act":
                    verify(fixture_name, focused=True)
                    expected_focus = fixture_name
                return json.dumps(record)

            if phase == "observe":
                view = await call("ui", "A", actionable=False)
                if not ("Test input A" in view and "Count click A" in view):
                    raise RuntimeError("Expected controls missing")
                await call("screenshot", "A", stable=True, lossless=True)
            elif phase == "dryrun":
                await call("ui", "A", actionable=False)
                await call("keyboard", "A", action="type", text="Hypruse PoC")
                if not (json.loads((out / "A.json").read_text())["text"] == ""):
                    raise RuntimeError('PoC verification failed')
            elif phase == "act":
                if not (passed("observe") and passed("dryrun")):
                    raise RuntimeError('PoC verification failed')
                await call("ui", "A", actionable=False)
                await call("click_ui", "A", name="Count click A")
                if not (json.loads((out / "A.json").read_text())["clicks"] == 1):
                    raise RuntimeError("Button result differs")
                await call("keyboard", "A", action="key", keys="space")
                if not (json.loads((out / "A.json").read_text())["clicks"] == 2):
                    raise RuntimeError("Keyboard result differs")
                await call("click_ui", "A", name="Page 2")
                if not (json.loads((out / "A.json").read_text())["page"] == 1):
                    raise RuntimeError("Tab result differs")
                await call("ui", "A", actionable=False)
                await call("hypr", "B", action="focus_window")
                verify("B", focused=True)
                view = await call("ui", "B", actionable=False)
                if not ("Test input B" in view):
                    raise RuntimeError('PoC verification failed')
                await call("click_ui", "B", name="Count click B")
                if not (json.loads((out / "B.json").read_text())["clicks"] == 1):
                    raise RuntimeError('PoC verification failed')
                await call("keyboard", "B", action="key", keys="space")
                if not (json.loads((out / "B.json").read_text())["clicks"] == 2):
                    raise RuntimeError('PoC verification failed')
                await call("ui", "B", actionable=False)
                await call("screenshot", "B", stable=True, lossless=True)
            else:
                raise ValueError("phase must be observe, dryrun, or act")
    (out / (phase + ".passed")).write_text(fingerprint)
    print("PASS", phase, flush=True)


asyncio.run(main())
