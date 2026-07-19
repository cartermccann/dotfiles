# Projects, cron, and events

## Project operations

Before running a project command:

```bash
git -C /absolute/project status --short
git -C /absolute/project remote -v
rg -n '"(test|build|check|lint)"|\[tool\.|^check:|^test:' /absolute/project/package.json /absolute/project/pyproject.toml /absolute/project/Makefile 2>/dev/null
```

Use the repository's declared command or dev shell. Do not invent a deploy
target. Run long checks with `run-and-notify.sh`, then read the unit result and
journal. A deploy is complete only after the target endpoint or platform state
has been re-fetched.

## Hermes cron

List jobs by name and include disabled jobs when diagnosing:

```bash
hermes cron list --all
scripts/trigger-cron-by-name.sh weekday-document-inbox-triage-and-safe-import
```

The helper resolves the current opaque ID and queues the job. Verify with a
second `hermes cron list --all` and the gateway journal.

## Event contract

`emit-event.sh` writes one mode-0600 JSON document with:

- `timestamp`, `source`, `kind`, `severity`, and `subject`
- optional `unit`, `repo`, `url`, and `details`
- `host` and a stable schema version

Example:

```bash
scripts/emit-event.sh \
  --source systemd \
  --kind unit_failed \
  --severity error \
  --subject 'example.service failed' \
  --unit example.service \
  --details '/home/cjm/.local/state/hermes-ops/details/example.log'
```

Add `--notify` only when the workflow calls for Telegram delivery. Notification
text contains the summary and local details path, never raw journal content.
