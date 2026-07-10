# Dictation evidence index

Status: Scaffolded; no execution evidence recorded

[Overview](../README.md) · [Architecture](../architecture.md) · [Task plan](../task-plan.md)

## Purpose

This directory holds redacted execution evidence for the task map. Evidence proves a checkbox or gate; discussion alone does not.

Sensitive audio, transcript content, credentials, window titles, and raw diagnostic bundles stay outside the repository. Records link to safe artifact locations or hashes instead.

## Record index

| Task | Evidence file | Host/session | Disposition | Carter decision |
|---|---|---|---|---|
| P0.1A | Not created | Not run | Not started | — |

Add one row per executed task. A missing record means the task remains open.

## Applicability and waiver ledger

| Requirement/task | Applicable scope | Evidence | Disposition | Carter decision |
|---|---|---|---|---|
| None recorded | — | — | — | — |

Non-waivable invariants in the task plan can never be waived. Marking something not applicable requires evidence and Carter's recorded disposition.

## Evidence record template

    # TASK-ID — Short title

    Status: pass | fail | blocked | deferred
    Date/time:
    Author:
    Authority/maintenance window:
    Host and hardware:
    Compositor/session:
    Relevant versions:

    ## Expected observation

    ## Procedure

    Exact commands or manual steps, with sensitive values redacted.

    ## Observed result

    ## Artifacts

    Safe repository paths, external local paths, hashes, screenshots, or logs.
    Do not include transcript/audio content or credentials.

    ## Failure signal and countermove

    ## Cleanup and restored state

    ## Verification rerun

    ## Remaining risk

    ## Disposition

    Carter acceptance, rejection, waiver, or deferral when required.

## P0.1A write boundary

P0.1A may create P0.1A-static-preflight.md and update only its index row. It does not authorize recordings, model realization, clipboard/input tests, service changes, stopping a recorder, or other implementation work.
