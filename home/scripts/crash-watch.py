#!/usr/bin/env python3
"""Watch systemd-coredump and toast/mute — never launch an agent.

Omarchy's crash-watch follows MESSAGE_ID fc2e22bc6ee647b6b90729ab34a250b1,
filters in code (UID, ignore list, self-name, 60s per-program dedupe, mute
flag), then toasts. We steal that watch + mute + toast, not omarchy-agent-crash.

When TYPESAFE_API_KEY is set, Jev (Choice / Noul / Score, one request) judges
announce vs queue vs drop and sticky mute. Otherwise a deterministic fallback
still toasts and mutes usefully. Code owns control flow either way.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping
from urllib.parse import urljoin

COREDUMP_MESSAGE_ID = "fc2e22bc6ee647b6b90729ab34a250b1"
CRASH_GLYPH = "\U000f16a1"  # nf-md-robot_dead
DEDUPE_SECONDS = int(os.environ.get("CRASH_WATCH_DEDUPE_SECONDS", "60"))
APP_NAME = "crash-watch"
TYPESAFE_API_KEY_ENV = "TYPESAFE_API_KEY"
TYPESAFE_BASE_URL_ENV = "TYPESAFE_BASE_URL"
TYPESAFE_MODEL_ENV = "TYPESAFE_DEFAULT_MODEL"
DEFAULT_BASE_URL = "https://api.typesafe.ai"
DEFAULT_MODEL = "jev-latest"
JEV_TIMEOUT_SEC = 8

# earlyoom / systemd-oomd kill with SIGKILL; that is not a program bug.
OOM_SIGNALS = frozenset({"9", "sigkill", "kill"})

# Omarchy's diagnose-crash skill: the mute key is the basename, so muting
# python3/node silences every script on the machine. Encode that as a denylist.
INTERPRETER_RE = re.compile(
    r"^(python(\d+(\.\d+)*)?|node|nodejs|ruby(\d+(\.\d+)*)?|perl(\d+(\.\d+)*)?|"
    r"bash|sh|zsh|fish|dash|lua(\d+(\.\d+)*)?|php(\d+(\.\d+)*)?|java|deno|bun|pwsh)$",
    re.IGNORECASE,
)

DEFAULT_IGNORE_RE = re.compile(
    r"^(chrome_crashpad_handler|crashpad_handler|chrome-sandbox|nacl_helper|"
    r"WebKitNetworkProcess|WebKitWebProcess|xdg-document-portal|"
    r"xdg-permission-store)$"
)

SELF_RE = re.compile(r"^(crash-watch|crash-mute)(-.*)?$")

NOUL_SEE = 0.5
NOUL_INTERRUPT = 0.5
NOUL_MUTE = 0.7
NOUL_MUTE_KEEP = 0.5
CHOICE_CONFIDENCE = 0.5
SCORE_STICKY = 1.5
REPEAT_MUTE_COUNT = 3

MEETING_TITLE_RE = re.compile(
    r"\b(meet|google meet|zoom|huddle|webex|teams meeting)\b",
    re.IGNORECASE,
)


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------


def state_root() -> Path:
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(
        os.environ.get("HOME", "/tmp"), ".local", "state"
    )
    return Path(base) / "crash-watch"


def ignore_dir() -> Path:
    return state_root() / "ignore"


def capture_off_path() -> Path:
    return state_root() / "off"


def queue_path() -> Path:
    return state_root() / "queue.jsonl"


def mute_path(name: str) -> Path:
    return ignore_dir() / name


# ---------------------------------------------------------------------------
# Crash identity (Omarchy's field handling)
# ---------------------------------------------------------------------------


def field(value: Any) -> str:
    if value is None or value == "":
        return "-"
    return str(value)


def program_name(comm: str, exe: str) -> str:
    """Prefer the executable basename; never let comm become a path."""
    name = comm
    if exe.startswith("/"):
        name = os.path.basename(exe)
    name = os.path.basename(name)
    if name in ("", "-", ".", ".."):
        return "unknown"
    return name


def is_interpreter(name: str) -> bool:
    return bool(INTERPRETER_RE.match(name))


def is_self(name: str) -> bool:
    return bool(SELF_RE.match(name))


def is_ignored(name: str, pattern: str | None = None) -> bool:
    if is_self(name) or DEFAULT_IGNORE_RE.match(name):
        return True
    extra = pattern if pattern is not None else os.environ.get("CRASH_WATCH_IGNORE", "")
    if extra:
        try:
            return re.search(extra, name) is not None
        except re.error:
            return False
    return False


def signal_is_oom(signal: str) -> bool:
    return signal.strip().lower() in OOM_SIGNALS


def parse_uid(raw: str) -> int | None:
    try:
        uid = int(raw)
    except (TypeError, ValueError):
        return None
    return uid if uid >= 0 else None


# ---------------------------------------------------------------------------
# Mute flags (Omarchy crash-ignore/<name>, sticky like WirePlumber defaults)
# ---------------------------------------------------------------------------


def read_mute(name: str) -> dict[str, Any] | None:
    path = mute_path(name)
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            return data
    except (OSError, json.JSONDecodeError):
        pass
    return {"name": name, "exe": None, "signal": None}


def write_mute(name: str, exe: str, signal: str) -> None:
    ignore_dir().mkdir(parents=True, exist_ok=True)
    payload = {
        "name": name,
        "exe": exe,
        "signal": signal,
        "muted_at": datetime.now(timezone.utc).isoformat(),
    }
    mute_path(name).write_text(json.dumps(payload) + "\n", encoding="utf-8")


def lift_mute(name: str) -> bool:
    path = mute_path(name)
    if not path.is_file():
        return False
    path.unlink()
    return True


def list_mutes() -> list[str]:
    d = ignore_dir()
    if not d.is_dir():
        return []
    names = []
    for entry in sorted(d.iterdir()):
        if entry.is_file() and not entry.name.startswith("."):
            names.append(entry.name)
    return names


def set_capture_off(off: bool) -> None:
    path = capture_off_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    if off:
        path.write_text("off\n", encoding="utf-8")
    elif path.exists():
        path.unlink()


def capture_is_off() -> bool:
    return capture_off_path().is_file()


def restart_capture_unit(enable: bool) -> None:
    action = "start" if enable else "stop"
    subprocess.run(
        ["systemctl", "--user", action, "crash-watch.service"],
        check=False,
        capture_output=True,
    )


# ---------------------------------------------------------------------------
# Session flags (DND, fullscreen, granola_mt, focused window)
# ---------------------------------------------------------------------------


def _run(argv: list[str], timeout: float = 2.0) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        argv,
        check=False,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def swaync_dnd() -> bool:
    try:
        proc = _run(["swaync-client", "-D"], timeout=2)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False
    if proc.returncode != 0:
        return False
    return proc.stdout.strip().lower() in {"true", "yes", "1", "on"}


def granola_mt_linked() -> bool:
    try:
        proc = _run(["pw-dump"], timeout=5)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False
    if proc.returncode != 0 or not proc.stdout:
        return False
    try:
        dump = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return False
    granola_ids: set[int] = set()
    for node in dump:
        if node.get("type") != "PipeWire:Interface:Node":
            continue
        props = (node.get("info") or {}).get("props") or {}
        name = str(props.get("node.name") or "")
        if name == "granola_mt" or name.startswith("granola_mt."):
            nid = node.get("id")
            if isinstance(nid, int):
                granola_ids.add(nid)
    if not granola_ids:
        return False
    for node in dump:
        if node.get("type") != "PipeWire:Interface:Link":
            continue
        props = (node.get("info") or {}).get("props") or {}
        out_n = props.get("link.output.node")
        in_n = props.get("link.input.node")
        if out_n in granola_ids or in_n in granola_ids:
            return True
    return False


def hypr_focus() -> tuple[bool, str, str]:
    try:
        proc = _run(["hyprctl", "activewindow", "-j"], timeout=2)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False, "", ""
    if proc.returncode != 0 or not proc.stdout.strip():
        return False, "", ""
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return False, "", ""
    fullscreen = bool(data.get("fullscreen"))
    klass = str(data.get("class") or data.get("initialClass") or "")
    title = str(data.get("title") or data.get("initialTitle") or "")
    return fullscreen, klass, title


def niri_focus() -> tuple[bool, str, str]:
    try:
        proc = _run(["niri", "msg", "-j", "focused-window"], timeout=2)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False, "", ""
    if proc.returncode != 0 or not proc.stdout.strip() or proc.stdout.strip() == "null":
        return False, "", ""
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return False, "", ""
    if not isinstance(data, dict):
        return False, "", ""
    layout = data.get("layout") or {}
    fullscreen = bool(data.get("is_fullscreen") or layout.get("is_fullscreen"))
    klass = str(data.get("app_id") or "")
    title = str(data.get("title") or "")
    return fullscreen, klass, title


def collect_session() -> dict[str, Any]:
    fullscreen, klass, title = hypr_focus()
    if not klass and not title:
        fullscreen, klass, title = niri_focus()
    return {
        "dnd": swaync_dnd(),
        "fullscreen": fullscreen,
        "granola_mt_linked": granola_mt_linked(),
        "focused_class": klass,
        "focused_title": title,
    }


def looks_like_meeting(session: Mapping[str, Any]) -> bool:
    if session.get("granola_mt_linked"):
        return True
    title = str(session.get("focused_title") or "")
    klass = str(session.get("focused_class") or "")
    return bool(MEETING_TITLE_RE.search(title) or MEETING_TITLE_RE.search(klass))


# ---------------------------------------------------------------------------
# Jev (HTTP) + deterministic fallback
# ---------------------------------------------------------------------------


QUESTIONS: dict[str, Any] = {
    "should_see": {
        "type": "noul",
        "instructions": (
            "Is `crash` a user-session crash a person should see (not OOM, not a "
            "known noisy helper, not crash-watch itself)? Use `crash.name`, "
            "`crash.signal`, `crash.exe`, and `policy`."
        ),
        "criteria": {
            "true": "A real user-facing program dumped core and a person would want to know.",
            "false": "OOM/SIGKILL, a noisy helper, the watcher itself, or not worth a person's attention.",
        },
    },
    "do_not_interrupt": {
        "type": "noul",
        "instructions": (
            "Is the session in a meeting, fullscreen, DND, or other do-not-interrupt "
            "context? Use `session.granola_mt_linked`, `session.fullscreen`, "
            "`session.dnd`, and `session.focused_title`."
        ),
        "criteria": {
            "true": "A banner would interrupt a meeting, fullscreen app, or DND.",
            "false": "A banner would not interrupt focused real-time activity.",
        },
    },
    "action": {
        "type": "choice",
        "instructions": (
            "What should happen to this crash right now? Never launch an agent or "
            "diagnosis tool. Pick `unknown` if the evidence is not enough."
        ),
        "criteria": {
            "banner": "Show a desktop toast now.",
            "silent-queue": "Record it for later; no banner (history / low-urgency only).",
            "drop": "Do not notify and do not queue.",
            "unknown": "Not enough to choose; code will silent-queue.",
        },
    },
    "warrant": {
        "type": "score",
        "instructions": (
            "How strongly does this crash plus current activity warrant a sticky "
            "critical toast? Higher means a sticky toast is appropriate. Low if a "
            "meeting, fullscreen, or DND is active."
        ),
        "criteria": [
            "A sticky critical toast would be inappropriate given current activity.",
            "A brief notice is reasonable; sticky critical would be somewhat much.",
            "The user should see this crash now; a sticky critical toast is warranted.",
        ],
    },
    "should_mute": {
        "type": "noul",
        "instructions": (
            "Should further crashes of this program stay silenced (write a sticky "
            "mute flag keyed on `crash.name`)? Never mute interpreters such as "
            "python3 or node from a single crash — those names are every script on "
            "the machine (`policy.interpreter_denylist`, `mute.name_is_interpreter`). "
            "Prefer muting a repeating flaky GUI or native binary."
        ),
        "criteria": {
            "true": "Further crashes of this same basename should be silenced; it is a repeating flaky native program, not an interpreter.",
            "false": "Do not write a mute; one-off, interpreter, or still worth seeing.",
        },
    },
    "mute_justified": {
        "type": "noul",
        "instructions": (
            "If `mute.exists` is true, is that mute still justified (repeat flaky vs "
            "a new binary or signal)? Compare `crash.exe` / `crash.signal` with "
            "`mute.exe` / `mute.signal`. If there is no existing mute, answer no."
        ),
        "criteria": {
            "true": "Same program still looping with the same binary and signal.",
            "false": "No mute, or the binary/signal changed and the next crash should be allowed to announce.",
        },
    },
}


@dataclass(frozen=True)
class Judgment:
    should_see: float
    do_not_interrupt: float
    action: str
    action_confidence: float
    warrant: float
    should_mute: float
    mute_justified: float
    source: str


@dataclass(frozen=True)
class Decision:
    action: str
    sticky: bool
    punch_through_dnd: bool
    write_mute: bool
    lift_mute: bool
    reason: str
    source: str


def build_state(
    crash: Mapping[str, Any],
    session: Mapping[str, Any],
    history: Mapping[str, Any],
    mute: Mapping[str, Any],
) -> dict[str, Any]:
    return {
        "crash": {
            "comm": crash.get("comm"),
            "exe": crash.get("exe"),
            "signal": crash.get("signal"),
            "name": crash.get("name"),
            "pid": crash.get("pid"),
        },
        "history": {
            "recent_same_name_count": history.get("recent_same_name_count", 0),
        },
        "session": {
            "dnd": bool(session.get("dnd")),
            "fullscreen": bool(session.get("fullscreen")),
            "granola_mt_linked": bool(session.get("granola_mt_linked")),
            "focused_class": session.get("focused_class") or "",
            "focused_title": session.get("focused_title") or "",
        },
        "mute": {
            "exists": bool(mute.get("exists")),
            "exe": mute.get("exe"),
            "signal": mute.get("signal"),
            "name_is_interpreter": is_interpreter(str(crash.get("name") or "")),
        },
        "policy": {
            "never_exec_agent": True,
            "interpreter_denylist": [
                "python3",
                "python",
                "node",
                "ruby",
                "perl",
                "bash",
                "sh",
            ],
            "oom_signals": sorted(OOM_SIGNALS),
        },
    }


def fallback_judge(
    crash: Mapping[str, Any],
    session: Mapping[str, Any],
    history: Mapping[str, Any],
    mute: Mapping[str, Any],
) -> Judgment:
    name = str(crash.get("name") or "")
    signal = str(crash.get("signal") or "")
    noisy = is_ignored(name) or signal_is_oom(signal)
    interrupt = bool(
        session.get("fullscreen")
        or session.get("dnd")
        or looks_like_meeting(session)
    )
    count = int(history.get("recent_same_name_count") or 0)
    interpreter = is_interpreter(name)

    if noisy:
        action, conf = "drop", 0.9
        should_see = 0.05
    elif interrupt:
        action, conf = "silent-queue", 0.85
        should_see = 0.85
    else:
        action, conf = "banner", 0.85
        should_see = 0.9

    warrant = 0.2 if interrupt else 1.8
    should_mute = 0.05 if interpreter else (0.85 if count >= REPEAT_MUTE_COUNT else 0.1)

    if mute.get("exists"):
        changed = (mute.get("exe") and mute.get("exe") != crash.get("exe")) or (
            mute.get("signal") and mute.get("signal") != crash.get("signal")
        )
        mute_justified = 0.2 if changed else 0.85
    else:
        mute_justified = 0.2

    return Judgment(
        should_see=should_see,
        do_not_interrupt=0.9 if interrupt else 0.1,
        action=action,
        action_confidence=conf,
        warrant=warrant,
        should_mute=should_mute,
        mute_justified=mute_justified,
        source="fallback",
    )


def _noul(answer: Mapping[str, Any] | None, default: float) -> float:
    if not answer:
        return default
    value = answer.get("noul")
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _choice(answer: Mapping[str, Any] | None) -> tuple[str, float]:
    if not answer:
        return "unknown", 0.0
    choice = str(answer.get("choice") or "unknown")
    try:
        conf = float(answer.get("confidence") or 0.0)
    except (TypeError, ValueError):
        conf = 0.0
    return choice, conf


def _score(answer: Mapping[str, Any] | None, default: float) -> float:
    if not answer:
        return default
    value = answer.get("score")
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def jev_available() -> bool:
    return bool(os.environ.get(TYPESAFE_API_KEY_ENV, "").strip())


def ask_jev(state: Mapping[str, Any]) -> Judgment | None:
    key = os.environ.get(TYPESAFE_API_KEY_ENV, "").strip()
    if not key:
        return None
    base = os.environ.get(TYPESAFE_BASE_URL_ENV, DEFAULT_BASE_URL).rstrip("/")
    model = os.environ.get(TYPESAFE_MODEL_ENV, DEFAULT_MODEL)
    url = urljoin(base + "/", "v1/systemone")
    payload = json.dumps(
        {"state": state, "model": model, "questions": QUESTIONS}
    ).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        method="POST",
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=JEV_TIMEOUT_SEC) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if exc.code in {429, 529}:
            time.sleep(1.0)
            try:
                with urllib.request.urlopen(req, timeout=JEV_TIMEOUT_SEC) as resp:
                    body = json.loads(resp.read().decode("utf-8"))
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
                return None
        else:
            return None
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return None

    answers = body.get("answers") or {}
    action, conf = _choice(answers.get("action"))
    return Judgment(
        should_see=_noul(answers.get("should_see"), 0.5),
        do_not_interrupt=_noul(answers.get("do_not_interrupt"), 0.5),
        action=action,
        action_confidence=conf,
        warrant=_score(answers.get("warrant"), 1.0),
        should_mute=_noul(answers.get("should_mute"), 0.0),
        mute_justified=_noul(answers.get("mute_justified"), 0.5),
        source="jev",
    )


def compose(crash: Mapping[str, Any], judgment: Judgment, interpreter: bool) -> Decision:
    """Thresholds in code. Low Choice confidence → silent-queue. Never exec an agent."""
    if judgment.mute_justified < NOUL_MUTE_KEEP:
        lift = True
    else:
        lift = False

    # Existing mute still justified → drop this crash (flag outlives the situation).
    if crash.get("existing_mute") and not lift:
        return Decision(
            action="drop",
            sticky=False,
            punch_through_dnd=False,
            write_mute=False,
            lift_mute=False,
            reason="muted",
            source=judgment.source,
        )

    if judgment.should_see < NOUL_SEE:
        return Decision(
            action="drop",
            sticky=False,
            punch_through_dnd=False,
            write_mute=False,
            lift_mute=lift,
            reason="should_see",
            source=judgment.source,
        )

    action = judgment.action
    if action not in {"banner", "silent-queue", "drop"} or judgment.action_confidence < CHOICE_CONFIDENCE:
        action = "silent-queue"

    interrupt = judgment.do_not_interrupt >= NOUL_INTERRUPT
    if action == "banner" and interrupt:
        action = "silent-queue"

    sticky = action == "banner" and judgment.warrant >= SCORE_STICKY and not interrupt
    punch = sticky and not interrupt
    write = (not interpreter) and judgment.should_mute >= NOUL_MUTE

    return Decision(
        action=action,
        sticky=sticky,
        punch_through_dnd=punch,
        write_mute=write,
        lift_mute=lift,
        reason="judged",
        source=judgment.source,
    )


def judge_crash(
    crash: Mapping[str, Any],
    session: Mapping[str, Any],
    history: Mapping[str, Any],
    mute: Mapping[str, Any],
) -> Decision:
    state = build_state(crash, session, history, mute)
    judgment = ask_jev(state)
    if judgment is None:
        judgment = fallback_judge(crash, session, history, mute)
    crash_for_compose = {**crash, "existing_mute": bool(mute.get("exists"))}
    return compose(crash_for_compose, judgment, is_interpreter(str(crash.get("name") or "")))


# ---------------------------------------------------------------------------
# Toast (Omarchy busctl Notify — never notify-send, never --exec)
# ---------------------------------------------------------------------------


def wait_for_notifications(timeout: float = 10.0) -> bool:
    attempts = int(timeout * 10)
    for _ in range(max(attempts, 1)):
        try:
            proc = _run(
                [
                    "busctl",
                    "--user",
                    "call",
                    "org.freedesktop.Notifications",
                    "/org/freedesktop/Notifications",
                    "org.freedesktop.Notifications",
                    "GetServerInformation",
                ],
                timeout=1,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False
        if proc.returncode == 0:
            return True
        time.sleep(0.1)
    return False


def _set_dnd(on: bool) -> None:
    flag = "--dnd-on" if on else "--dnd-off"
    try:
        _run(["swaync-client", flag], timeout=2)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass


def notify(
    summary: str,
    body: str,
    *,
    urgency: str,
    expire_ms: int,
    punch_through_dnd: bool,
) -> bool:
    urgency_byte = {"low": 0, "normal": 1, "critical": 2}.get(urgency, 1)
    hints = ["urgency", "y", str(urgency_byte)]
    hint_count = len(hints) // 3
    cmd = [
        "busctl",
        "--user",
        "--",
        "call",
        "org.freedesktop.Notifications",
        "/org/freedesktop/Notifications",
        "org.freedesktop.Notifications",
        "Notify",
        "susssasa{sv}i",
        APP_NAME,
        "0",
        "",
        summary,
        body,
        "0",
        str(hint_count),
        *hints,
        str(expire_ms),
    ]
    was_dnd = swaync_dnd()
    if punch_through_dnd and was_dnd:
        _set_dnd(False)
    try:
        proc = _run(cmd, timeout=3)
        ok = proc.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        ok = False
    if punch_through_dnd and was_dnd:
        _set_dnd(True)
    return ok


def enqueue(record: Mapping[str, Any]) -> None:
    path = queue_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, default=str) + "\n")


def announce(crash: Mapping[str, Any], decision: Decision) -> bool:
    name = str(crash.get("name") or "unknown")
    signal = str(crash.get("signal") or "-")
    exe = str(crash.get("exe") or "-")
    summary = f"{CRASH_GLYPH} Process crashed: {name}"
    body = f"{signal} · {exe}"
    if decision.action == "drop":
        return False
    record = {
        "at": datetime.now(timezone.utc).isoformat(),
        "name": name,
        "signal": signal,
        "exe": exe,
        "action": decision.action,
        "sticky": decision.sticky,
        "source": decision.source,
    }
    enqueue(record)
    if not wait_for_notifications():
        return False
    if decision.action == "silent-queue":
        return notify(
            summary,
            body,
            urgency="low",
            expire_ms=1,
            punch_through_dnd=False,
        )
    expire = 0 if decision.sticky else 8000
    urgency = "critical" if decision.sticky else "normal"
    return notify(
        summary,
        body,
        urgency=urgency,
        expire_ms=expire,
        punch_through_dnd=decision.punch_through_dnd,
    )


# ---------------------------------------------------------------------------
# Watch loop
# ---------------------------------------------------------------------------


def parse_coredump_entry(entry: Mapping[str, Any]) -> dict[str, Any] | None:
    uid_raw = field(entry.get("_UID"))
    comm = field(entry.get("COREDUMP_COMM"))
    pid_raw = field(entry.get("COREDUMP_PID"))
    exe = field(entry.get("COREDUMP_EXE"))
    signal = field(entry.get("COREDUMP_SIGNAL_NAME"))
    if signal in ("", "-"):
        signal = field(entry.get("COREDUMP_SIGNAL"))
    if not re.fullmatch(r"[0-9]+", pid_raw):
        return None
    uid = parse_uid(uid_raw)
    if uid is None:
        return None
    return {
        "uid": uid,
        "comm": comm,
        "pid": int(pid_raw),
        "exe": exe,
        "signal": signal,
        "name": program_name(comm, exe),
    }


def should_code_drop(crash: Mapping[str, Any], uid: int) -> str | None:
    if crash["uid"] != uid:
        return "uid"
    if signal_is_oom(str(crash["signal"])):
        return "oom"
    if is_ignored(str(crash["name"])):
        return "ignore"
    return None


def handle_crash(
    crash: Mapping[str, Any],
    *,
    last_notified: dict[str, int],
    recent: list[tuple[str, int]],
    now: int | None = None,
) -> Decision | None:
    now = int(time.time() if now is None else now)
    name = str(crash["name"])
    recent[:] = [(n, t) for n, t in recent if now - t < 600]
    recent.append((name, now))
    same = sum(1 for n, _ in recent if n == name)

    if capture_is_off():
        return None
    if (now - last_notified.get(name, 0)) < DEDUPE_SECONDS:
        return None

    mute_info = read_mute(name)
    mute = {
        "exists": mute_info is not None,
        "exe": (mute_info or {}).get("exe"),
        "signal": (mute_info or {}).get("signal"),
    }
    session = collect_session()
    history = {"recent_same_name_count": same}
    decision = judge_crash(crash, session, history, mute)

    if decision.lift_mute:
        lift_mute(name)
    if decision.write_mute:
        write_mute(name, str(crash.get("exe") or ""), str(crash.get("signal") or ""))

    if decision.action == "drop":
        return decision

    if announce(crash, decision):
        last_notified[name] = now
    return decision


def follow_journal(uid: int) -> None:
    cmd = [
        "journalctl",
        "--system",
        "-f",
        "-n",
        "0",
        "-o",
        "json",
        f"MESSAGE_ID={COREDUMP_MESSAGE_ID}",
    ]
    last_notified: dict[str, int] = {}
    recent: list[tuple[str, int]] = []
    while True:
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
        except FileNotFoundError:
            print("crash-watch: journalctl not found", file=sys.stderr)
            time.sleep(30)
            continue
        assert proc.stdout is not None
        for line in proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            crash = parse_coredump_entry(entry)
            if crash is None:
                continue
            why = should_code_drop(crash, uid)
            if why:
                continue
            try:
                handle_crash(crash, last_notified=last_notified, recent=recent)
            except Exception as exc:  # noqa: BLE001 — watcher must not die on one crash
                print(f"crash-watch: {exc}", file=sys.stderr)
        rc = proc.wait()
        err = proc.stderr.read() if proc.stderr else ""
        print(f"crash-watch: journalctl exited {rc} {err}", file=sys.stderr)
        time.sleep(5)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def cmd_watch(_args: list[str]) -> int:
    if capture_is_off():
        print("crash-watch: capture off", file=sys.stderr)
        return 0
    follow_journal(os.getuid())
    return 0


def cmd_mute(args: list[str]) -> int:
    rest = args[:]
    if rest and rest[0] == "--":
        rest = rest[1:]
    if rest and rest[0] in {"--capture", "capture"}:
        rest = rest[1:]
        action = rest[0] if rest else "toggle"
        currently_off = capture_is_off()
        if action == "on":
            want_off = False
        elif action == "off":
            want_off = True
        elif action == "toggle":
            want_off = not currently_off
        else:
            print("Usage: crash-mute --capture [on|off|toggle]", file=sys.stderr)
            return 1
        set_capture_off(want_off)
        restart_capture_unit(enable=not want_off)
        print("Crash capture off." if want_off else "Crash capture on.")
        return 0

    if not rest:
        names = list_mutes()
        if not names:
            print("No programs muted. Crashes all notify.")
            return 0
        print("\n".join(names))
        return 0

    program = os.path.basename(rest[0])
    action = rest[1] if len(rest) > 1 else "on"
    if program in ("", ".", ".."):
        print(f"Not a program name: {rest[0]}", file=sys.stderr)
        return 1
    if is_interpreter(program):
        print(
            f"Refusing to mute interpreter {program}; that would silence every script.",
            file=sys.stderr,
        )
        return 1
    if action not in {"on", "off", "toggle"}:
        print("Usage: crash-mute [--] <program> [on|off|toggle]", file=sys.stderr)
        return 1

    exists = mute_path(program).is_file()
    if action == "toggle":
        action = "off" if exists else "on"
    if action == "on":
        write_mute(program, "", "")
        print(f"Muted crash notifications for {program}.")
    else:
        lift_mute(program)
        print(f"Crash notifications for {program} are back on.")
    return 0


def cmd_decide(args: list[str]) -> int:
    """Read a {crash,session,history,mute} JSON object from stdin; print the Decision."""
    raw = sys.stdin.read()
    data = json.loads(raw) if raw.strip() else {}
    crash = data.get("crash") or data
    session = data.get("session") or {}
    history = data.get("history") or {}
    mute = data.get("mute") or {"exists": False}
    if args and args[0] == "--fallback":
        os.environ.pop(TYPESAFE_API_KEY_ENV, None)
    if "name" not in crash:
        crash = {
            **crash,
            "name": program_name(str(crash.get("comm") or ""), str(crash.get("exe") or "")),
        }
    decision = judge_crash(crash, session, history, mute)
    print(
        json.dumps(
            {
                "action": decision.action,
                "sticky": decision.sticky,
                "punch_through_dnd": decision.punch_through_dnd,
                "write_mute": decision.write_mute,
                "lift_mute": decision.lift_mute,
                "reason": decision.reason,
                "source": decision.source,
                "name": crash.get("name"),
            }
        )
    )
    return 0


def main(argv: Iterable[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    invoked = os.path.basename(sys.argv[0])
    if invoked == "crash-mute":
        return cmd_mute(argv)
    if not argv or argv[0] in {"watch", "--watch"}:
        return cmd_watch(argv[1:] if argv else [])
    cmd = argv[0]
    rest = argv[1:]
    if cmd in {"mute", "crash-mute"}:
        return cmd_mute(rest)
    if cmd == "decide":
        return cmd_decide(rest)
    if cmd in {"-h", "--help", "help"}:
        print("Usage: crash-watch [watch|decide|mute ...] | crash-mute ...")
        return 0
    print(f"Unknown command: {cmd}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
