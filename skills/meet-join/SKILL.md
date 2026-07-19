---
name: meet-join
description: Join, monitor, and leave a Google Meet as Carter's voice bot (the hermes-integrations Meet lane). Use when Carter sends a meet.google.com link and asks Hermes to join, asks whether the bot is in a meeting, or asks it to leave. Carter-only, one meeting at a time.
---

# Meet Join

Operate the Hermes Meet voice lane on kronos: the bot joins a Google Meet
Carter names, holds a voice conversation there, and (once the task lane is
qualified) accepts explicit spoken delegation. Everything runs locally from
`/home/cjm/projects/Personal/hermes-integrations` under Carter's user.

## Hard rules

- **Only join when Carter explicitly sends a meeting link and asks to join it
  in the same conversation.** Never join on inference, schedule, or calendar
  sighting. Never fabricate or reuse an old link.
- **Consent is Carter's attestation, not yours.** Meetings with other people
  are allowed — but before the first join of a conversation, confirm:
  "Everyone in this meeting knows the bot is joining and consents to voice
  processing — correct?" Only after an affirmative reply pass `--consented`
  to the script. If Carter says someone present has not consented, refuse.
- **Delegation authority is Carter-only and currently solo-only.** With other
  humans in the meeting, voice conversation works but spoken task delegation
  and cancellation deliberately fail closed (owner-only authority requires a
  single-human roster until the multi-participant milestone lands). If Carter
  reports delegation "not working" in a multi-person meeting, explain this —
  it is the designed behavior, not a fault.
- **One meeting at a time.** The script enforces a singleton; if it reports
  `already_in_meeting`, tell Carter which meeting is active (status) instead of
  retrying.
- Never edit the runner, its environment file, or the task ledger from this
  skill. Operational problems beyond join/status/leave route to the
  `hermes-ops` skill.

## Commands

Join (after consent confirmation):

    scripts/meet-join.sh "https://meet.google.com/xxx-xxxx-xxx" --consented

The script starts the three lane services if needed (Attendee stack, Hermes
backend, local voice), waits for voice readiness, verifies task-lane
readiness, then launches the meeting runner as the transient user unit
`hermes-meet-runner`. On success it prints `joined_pending_admission` —
tell Carter the bot is requesting to join and he must admit it from the
Meet UI. Report any other stable code it prints verbatim.

Status:

    scripts/meet-status.sh

Prints the runner unit state plus the last content-free runner log lines.

Leave / end:

    scripts/meet-leave.sh

Stops the runner cleanly (SIGTERM → the runner closes into a
ledger-resumable state; in-flight Hermes tasks are NOT cancelled — results
still deliver over Telegram). Confirm to Carter that the bot left and any
running delegated work continues.

## Reporting

- Relay only the stable codes and content-free log lines the scripts print;
  never paste raw transcripts, audio details, tokens, or URLs other than the
  meeting link Carter himself provided.
- If join fails at readiness, name the missing capability exactly as printed
  (e.g. `local_voice`, `hermes_gateway_ready`) and suggest `hermes-ops` for
  service repair.
