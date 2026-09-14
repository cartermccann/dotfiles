"""Private-bus regression check; never connects to the desktop or real vault."""
import os
from pathlib import Path
import resource
import signal
import subprocess
import sys
import tempfile
import time

daemon_path, bus_path, client_path, expectation = sys.argv[1:]
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

with tempfile.TemporaryDirectory(prefix="keyring-regression-") as directory:
    root = Path(directory)
    env = {"PATH": os.environ["PATH"], "HOME": str(root / "home"), "LANG": "C.UTF-8"}
    for kind in ("DATA", "CONFIG", "CACHE", "RUNTIME"):
        env[f"XDG_{kind}_HOME" if kind != "RUNTIME" else "XDG_RUNTIME_DIR"] = str(root / kind)
    for value in [env["HOME"]] + [env[k] for k in env if k.startswith("XDG_")]:
        Path(value).mkdir(mode=0o700)
    control = root / "control"
    control.mkdir(mode=0o700)
    config = root / "bus.conf"
    config.write_text('''<busconfig>
      <type>session</type><listen>unix:tmpdir=/tmp</listen><auth>EXTERNAL</auth>
      <policy context="default"><allow send_destination="*"/>
      <allow receive_sender="*"/><allow own="*"/></policy>
    </busconfig>''')  # Deliberately no servicedir: a crash cannot activate another daemon.
    bus = subprocess.Popen([bus_path, "--nofork", f"--config-file={config}", "--print-address=1"],
                           env=env, stdout=subprocess.PIPE, text=True)
    daemon = None
    try:
        env["DBUS_SESSION_BUS_ADDRESS"] = bus.stdout.readline().strip()
        assert env["DBUS_SESSION_BUS_ADDRESS"].startswith("unix:"), "Private bus did not start"
        with (root / "daemon.log").open("w") as log:
            daemon = subprocess.Popen([daemon_path, "--foreground", "--components=secrets",
                                       f"--control-directory={control}"], env=env,
                                      stdout=log, stderr=log)

            def owner():
                result = subprocess.run([client_path, "owner"], env=env, capture_output=True,
                                        text=True, timeout=5)
                return int(result.stdout) if result.returncode == 0 else None

            for _ in range(100):
                if owner() == daemon.pid:
                    break
                assert daemon.poll() is None, "Daemon exited during startup"
                time.sleep(0.05)
            else:
                raise RuntimeError("Daemon did not acquire the private service name")

            rounds = 1 if expectation == "crash" else 3
            for _ in range(rounds):
                for algorithm in ("dh-ietf1024-sha256-aes128-cbc-pkcs7", "plain"):
                    result = subprocess.run([client_path, algorithm], env=env, timeout=90)
                    if expectation == "crash":
                        if daemon.poll() is not None:
                            break
                    else:
                        assert result.returncode == 0, "Valid session request failed"
                        assert daemon.poll() is None and owner() == daemon.pid, "Daemon replaced or crashed"
                if expectation == "crash" and daemon.poll() is not None:
                    break
            if expectation == "crash":
                assert daemon.poll() in (-signal.SIGTRAP, -signal.SIGABRT), "Baseline did not reproduce crash"
                assert "expected GVariant of type 'v'" in (root / "daemon.log").read_text()
                print("PASS: unpatched daemon reproduced the recorded OpenSession crash")
            else:
                subprocess.run([client_path, "invalid"], env=env, timeout=5, check=True)
                subprocess.run([client_path, "invalid-type"], env=env, timeout=5, check=True)
                assert owner() == daemon.pid and daemon.poll() is None
                messages = (root / "daemon.log").read_text()
                assert "assertion" not in messages and "CRITICAL" not in messages, messages
                print("PASS: 19200 valid sessions; invalid algorithm/type rejected; original daemon survived")
    finally:
        for process in (daemon, bus):
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
