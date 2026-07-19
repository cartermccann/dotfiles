# Services, timers, and durable jobs

## Diagnose a unit

Choose user or system scope explicitly:

```bash
systemctl --user status UNIT --no-pager
systemctl --user show UNIT -p ActiveState -p SubState -p Result -p NRestarts -p ConditionResult -p ConditionTimestamp
journalctl --user -u UNIT -n 160 --no-pager

systemctl status UNIT --no-pager
systemctl show UNIT -p ActiveState -p SubState -p Result -p NRestarts -p ConditionResult -p ConditionTimestamp
journalctl -u UNIT -n 160 --no-pager
```

Check `ConditionResult` for timers and oneshots. `Result=success` does not prove
the command ran when a condition skipped it.

## Timers

```bash
systemctl --user list-timers --all --no-pager
systemctl --user show TIMER -p NextElapseUSecRealtime -p LastTriggerUSec
systemctl --user start SERVICE
```

Start the service, not the timer, for an intentional one-off execution. Then
read the service result and bounded journal.

## Hermes gateway

```bash
systemctl --user is-active hermes-gateway.service
systemctl --user show hermes-gateway.service -p MainPID -p NRestarts -p ExecMainStatus
journalctl --user -u hermes-gateway.service -n 160 --no-pager
hermes cron status
```

The NixOS drop-in supplies the developer PATH and a valid Nix-store
`ExecReload`. Prefer `systemctl --user reload-or-restart hermes-gateway.service`
after a configuration change, then verify the process and journal.

## Durable commands

Launch builds, test suites, migrations, and deploys through the supplied helper:

```bash
scripts/run-and-notify.sh --name project-test -- npm test
scripts/run-and-notify.sh --name nix-build --notify -- nh os build /home/cjm/dotfiles
```

The helper prints a transient user unit. Inspect or cancel it with:

```bash
systemctl --user status UNIT --no-pager
journalctl --user -u UNIT -n 160 --no-pager
systemctl --user stop UNIT
```

`--notify` sends one completion/failure message through the existing Hermes
Telegram target. Without it, the event remains local.
