"""Boot entrypoint for the pinned, filesystem-isolated development server."""

import os
import stat
import sys
from pathlib import Path


def main():
    bwrap, binary, state_arg, secret_arg = sys.argv[1:]
    state = Path(state_arg)
    secret = Path(secret_arg)
    info = secret.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise SystemExit("OpenCode password must be an owner-only regular file")
    password = secret.read_text(encoding="ascii")
    if len(password) < 32 or any(c.isspace() for c in password):
        raise SystemExit("OpenCode password file is invalid")
    for folder in ("home", "data", "cache", "config", "state", "workspace"):
        if not (state / folder).is_dir():
            raise SystemExit("OpenCode state migration is incomplete")
    if not (state / "config/opencode/opencode.json").is_file():
        raise SystemExit("OpenCode configuration is missing")

    # No inherited provider credentials, desktop sockets or real HOME. The
    # password enters only the child environment, never argv or the Nix store.
    env = {
        "PATH": "/run/current-system/sw/bin",
        "HOME": "/state/home",
        "OPENCODE_TEST_HOME": "/state/home",
        "TMPDIR": "/tmp",
        "OPENCODE_SERVER_USERNAME": "opencode",
        "OPENCODE_SERVER_PASSWORD": password,
        "OPENCODE_DISABLE_AUTOUPDATE": "1",
        "OPENCODE_DISABLE_MODELS_FETCH": "1",
        "OPENCODE_PURE": "1",
        "OPENCODE_PRINT_LOGS": "1",
        "NIX_LD": "/run/current-system/sw/share/nix-ld/lib/ld.so",
        "NIX_LD_LIBRARY_PATH": "/run/current-system/sw/share/nix-ld/lib",
        **{"XDG_" + key + "_HOME": "/state/" + value for key, value in (
            ("DATA", "data"), ("CACHE", "cache"), ("CONFIG", "config"), ("STATE", "state")
        )},
    }
    args = [
        bwrap, "--unshare-all", "--share-net", "--die-with-parent",
        "--new-session", "--cap-drop", "ALL",
        "--ro-bind", "/nix/store", "/nix/store",
        "--ro-bind", "/run/current-system/sw", "/run/current-system/sw",
        "--ro-bind", "/lib64", "/lib64",
        "--proc", "/proc", "--dev", "/dev", "--tmpfs", "/tmp",
        "--ro-bind", "/etc/resolv.conf", "/etc/resolv.conf",
        "--ro-bind", "/etc/hosts", "/etc/hosts",
        "--ro-bind", "/etc/ssl/certs", "/etc/ssl/certs",
        "--bind", str(state), "/state",
        # Bound, volatile internal logs; host session data remains durable.
        "--size", "16777216", "--tmpfs", "/state/data/opencode/log",
        "--symlink", "/dev/null", "/state/data/opencode/log/opencode.log",
        "--ro-bind", binary, "/opencode",
        "--dir", "/bin",
        "--symlink", "/run/current-system/sw/bin/bash", "/bin/sh",
        "--symlink", "/run/current-system/sw/bin/bash", "/bin/bash",
        "--chdir", "/state/workspace",
        "--", "/opencode", "serve", "--hostname", "127.0.0.1", "--port", "4096",
    ]
    # OpenCode output may contain private content. Keep it out of journald;
    # systemd still reports exits/restarts and preflight errors stay visible.
    with open(os.devnull, "wb") as sink:
        os.dup2(sink.fileno(), 1)
        os.dup2(sink.fileno(), 2)
    os.execve(bwrap, args, env)


if __name__ == "__main__":
    main()
