# Dictation architecture

Status: Proposed

[Overview](README.md) · [Task plan](task-plan.md)

This document describes the maximum product. The first implementation slice may omit components, but it must preserve the same safety and data contracts.

## Quality priorities

In order:

1. Never type into the wrong target.
2. Never lose a recoverable recording or raw transcript.
3. Keep recording controls responsive while models and AI work out of process.
4. Make provisional, raw, edited, and transformed text visibly distinct.
5. Preserve local-first privacy and explicit retention.
6. Provide equivalent core behavior on Hyprland and Niri.
7. Optimize latency only after the first six properties hold.

## Component map

    compositor hotkeys
            │
            ▼
      dictationctl ───── owner-only Unix socket ─────┐
                                                     ▼
                                              dictationd
        ┌────────────────────────────────────────────┼────────────────────────┐
        ▼                                            ▼                        ▼
    PipeWire capture                         session/state store       target monitor
        │                                            │                        │
        ├── VAD                                      ├── SQLite/FTS           ├── Hyprland
        ├── streaming ASR worker                     ├── audio spool           └── Niri
        └── final ASR worker                         └── retention
                                                     │
                           ┌─────────────────────────┼─────────────────────────┐
                           ▼                         ▼                         ▼
                    Quickshell UI              Ollama adapter          delivery broker
                    pill/editor/history         optional/final only     clipboard/input

## Process boundaries

### dictationd

A Python asyncio user service owns:

- The authoritative session state machine.
- Audio capture supervision and atomic spooling.
- Worker lifecycle, timeouts, backpressure, and retry.
- Saved target identity and target-confidence transitions.
- Persistence, migrations, retention, and crash recovery.
- Mode snapshots and transformation orchestration.
- Delivery authorization and audit dispositions.

Native ASR and Ollama inference stay outside the event loop. The daemon is the single database writer and the only authority that can authorize delivery.

### dictationctl

A thin command client supports:

- toggle, start, stop, cancel
- push-to-talk down/up
- private-session toggle
- open/close editor and history
- select mode/language
- copy, paste-here, paste-original, discard

Repeated or out-of-order hotkey events are idempotent. The CLI does not perform capture, inference, persistence, or delivery itself.

### Model workers

Workers are supervised subprocesses with explicit protocol versions, readiness, health, and memory limits. A crash fails only its assigned stage; it does not kill recording or discard a normal-session spool.

Candidate model stack:

- Preview English: sherpa-onnx 1.13.4 with NVIDIA Nemotron Speech Streaming EN 0.6B, 560 ms INT8, CPU-first.
- Canonical final English baseline: the existing Parakeet v2 path until corrected-corpus benchmarks select a winner.
- Optional multilingual: Nemotron 3.5 ASR Streaming 0.6B only after the English spine is stable.
- Endpointing: Silero VAD plus maximum-duration and manual-stop controls.
- Cleanup: qwen3.5:4b through the existing local Ollama service, after canonical final ASR only.
  Note (2026-08-08): qwen3.5:4b was retired from `lib/llm-models.nix` and deleted locally, as
  nothing consumed it. This phase must re-add it to the preload tiers, or pick a different
  model, before cleanup can be built. `gemma4:12b-it-qat` is the only chat-capable model installed.

The preview candidate provides cache-aware streaming, punctuation/capitalization, token timing, and bounded look-ahead. ASR model files are fixed-output Nix derivations with checksums; “acquisition” means Nix-store realization, never an application runtime download. The Ollama model is an external local dependency until its manifest digest and realization strategy are approved.

Primary references:

- [sherpa-onnx Nemotron streaming documentation](https://k2-fsa.github.io/sherpa/onnx/nemo/nemotron-streaming.html)
- [NVIDIA Nemotron Speech Streaming EN 0.6B model card](https://huggingface.co/nvidia/nemotron-speech-streaming-en-0.6b)
- [sherpa-onnx package releases](https://pypi.org/project/sherpa-onnx/)

P0.3 re-verifies the candidate version and licenses at execution time. P0.5 scores normalized WER, punctuation/case separately, latency, and resources on a held-out corrected corpus with a 95% bootstrap confidence interval. The current finalizer remains unless a challenger either improves relative WER by at least 5% or stays within the approved non-inferiority margin while materially improving an approved latency/resource budget.

### Quickshell UI

The UI renders daemon state; it does not own recording or inference.

The mini overlay is a layer-shell surface on the active output:

- non-focusable while recording or processing
- bottom-center by default
- timer, level, state, mode/language, privacy badge, target confidence
- stable text visually separated from replaceable provisional text
- keyboard-accessible global bindings for actions; the non-focusable pill itself receives no keys
- fast-in/soft-out motion using cubic-bezier(.2,.8,.2,1), with reduced-motion support

Expanding the editor intentionally acquires focus and marks the original target stale. The editor provides raw/final/diff views, undo/redo, reprocessing, copy, explicit delivery, and retained-audio playback.

## Session state and artifacts

The global capture slot is separate from per-session processing state. It is Free or Owned(session_id). The initial alpha permits one session from Arming through raw finalization; overlap may be enabled later only after worker-capacity and backpressure tests pass.

    Idle
      └─ start → Arming

    Arming
      ├─ cancel → Cancelled
      ├─ first durable frame → Recording
      └─ setup failure → FailedNoArtifact

    Recording
      ├─ preview update → Recording (transient buffers only)
      ├─ stop/PTT release/endpoint → Finalizing
      └─ cancel → Cancelled

    Finalizing
      ├─ canonical raw final + transform → Transforming
      ├─ canonical raw final → Ready
      ├─ recoverable failure → RecoverableError
      └─ discard request → Discarded

    Transforming
      ├─ success → Ready
      ├─ failure → Ready(unchanged input-version fallback)
      └─ cancel transform → Ready(unchanged input-version fallback)

    Ready
      ├─ eligible atomic auto-delivery → Delivering
      └─ review required or target unsafe → Held

    Delivering
      ├─ observable send success → PasteSent
      ├─ known failure → Held
      └─ process death/unknown outcome → Held(attempt outcome unknown)

    Held
      ├─ explicit one-shot delivery intent → Delivering
      ├─ edit/reprocess → Held
      ├─ copy → Copied
      └─ discard → Discarded

    RecoverableError
      ├─ sealed audio + finalizer failure → Finalizing
      ├─ immutable input version + transform retry → Transforming
      ├─ raw final + declined downstream retry → Held
      └─ discard → Discarded

FailedNoArtifact, Cancelled, PasteSent, Copied, and Discarded are terminal session outcomes. Cancel/Discard immediately removes content according to the retention snapshot; a normal session may retain only a redacted audit tombstone, while Private retains none. An unknown delivery attempt leaves the session Held until the user acknowledges possible duplication and creates a new intent or discards it.

| Milestone | Normal-session artifact | Private-session artifact |
|---|---|---|
| Before first durable frame | None; explicit error only | None; explicit error only |
| Recording/finalizing | Owner-only atomic spool | Volatile daemon memory; no daemon-crash recovery |
| Canonical final | Immutable persisted raw version | Volatile raw version |
| UI or worker failure | Retry from spool/raw | Recover while daemon lives |
| Daemon exit/logout | Startup recovery | Content is lost by design |
| Successful completion | Policy-driven cleanup | Immediate memory cleanup |

Editing is disabled until canonical raw final exists. The UI may be hidden, mini, expanded, or in recovery independently of session state.

## Streaming and canonical text semantics

- The streaming role emits preview.partial, preview.segment_stable, and preview.complete. “Stable” means stable within the preview pass, not canonical.
- Preview events are ephemeral and replaceable across worker, daemon, IPC, and UI buffers. They are never written to durable or user-visible sinks: persistence, content logs, clipboard, version lineage, transformation, or delivery.
- After stop, the selected finalizer consumes the sealed audio and emits raw.final. The same worker implementation may fill both roles, but it must use the separate canonical event and final flush.
- raw.final is persisted as an immutable version for normal sessions before downstream processing.
- Transformation and delivery APIs accept a canonical/derived version ID, never arbitrary text or a preview event.
- Deterministic cleanup, user edits, and AI output create descendant versions.
- The editor is read-only before raw.final; therefore finalization never overwrites an in-progress user edit.
- An end-to-end canary test injects recognizable preview text, releases transient buffers, and proves it appears in no forbidden sink.

## Target safety

Generic Wayland supplies a top-level surface, not a portable field or caret identity. Target confidence and user delivery intent are separate concepts.

| Target confidence | Meaning | Automatic delivery |
|---|---|---|
| continuous | The saved surface has been observed continuously focused since capture began | Only through an atomic target-bound adapter |
| stale | Focus/workspace changed, the editor gained focus, or monitoring continuity broke | Never |
| lost | The surface closed or cannot be uniquely identified | Never |
| none | No usable target existed at start | Never |

Focus/workspace departure is a one-way transition to stale. Compositor IPC loss, daemon restart, suspend/lock, sequence gaps, or any other observation gap also force stale; current focus can never reconstruct continuous trust. Surface ID reuse is treated as lost unless an adapter proves identity.

Adapter classes:

1. target_bound: atomically binds insertion to the intended surface; may support automatic and explicit Paste after conformance tests.
2. copy_only: stages text only when normal clipboard policy allows it; it emits no paste shortcut or text input.
3. unavailable: Edit/Discard only.

Every input-emitting intent requires a target_bound adapter and carries session ID, immutable version ID, expected target, and a one-use intent ID. Return to original and paste is exposed only when that adapter can also identify and activate the saved target; otherwise Copy/Edit is the fallback. Non-atomic focus checking never upgrades an adapter to input-emitting capability.

ydotool is never called directly by the UI, hotkey script, or model worker. History records paste sent, failed, or outcome unknown—not inserted—unless an application adapter can prove insertion.

## IPC and side-effect contract

The owner-only Unix socket exposes versioned requests and events.

Requests include:

- session.start, session.stop, session.cancel
- session.edit, session.reprocess, session.delete
- ui.expand, ui.collapse
- mode.select, language.select, private.set
- delivery.prepare, delivery.commit, delivery.copy
- history.search, settings.update, diagnostics.run

Text-mutating, transformation, and delivery requests reference an immutable version ID. Delivery commit also requires its prepared one-shot intent ID and expected target identity.

Events include:

- state.changed
- audio.level
- preview.partial
- preview.segment_stable
- preview.complete
- raw.final
- transform.completed or transform.failed
- target.changed
- delivery.disposition
- recovery.available
- health.changed

Every request carries an ID. Pure state changes are idempotent, but external input emission is not assumed idempotent. Before any delivery side effect, the daemon durably records a prepared attempt. It then records sent, failed, or unknown. An unknown attempt is never replayed automatically; the user must create a new intent after reviewing the possible duplicate.

Slow consumers receive coalesced audio levels and previews, never unbounded queues. Protocol mismatch and reconnect require a full authoritative-state resync.

## Deterministic processing pipeline

The versioned pipeline order is:

1. Resolve and snapshot configuration: explicit session override > exact app rule > app-pattern rule > selected mode > global default. Within a rule class, higher explicit priority wins; equal-priority ties are rejected at validation rather than resolved by write order.
2. Apply ASR configuration, language, and supported vocabulary bias during recognition.
3. Persist canonical raw.final unchanged.
4. Apply bounded transcript commands and deterministic replacements as derived versions.
5. Apply user edits as derived versions.
6. Optionally run AI cleanup from a selected version.
7. Review/accept a version.
8. Deliver only the accepted immutable version ID.

Rule conflicts, precedence, engine/model versions, prompts, and retention policy are part of the session snapshot. Reprocessing branches from an existing version and never rewrites lineage.

## Persistence

P1 creates the minimal durable schema required by recovery and the alpha: sessions, immutable transcript_versions, delivery_attempts, recovery_items, model_metadata, migrations, and retention snapshots. P3 extends it with FTS, finalized segment detail, modes, app rules, vocabulary, filters, exports, and richer lineage.

SQLite runs in WAL mode with migrations and a single writer. Core records include:

- sessions: timestamps, duration, state, target app ID, disposition, privacy and retention snapshot
- transcript_versions: immutable raw plus deterministic, edited, and transformed descendants
- segments: finalized text/timing for the selected canonical pass
- modes and app_rules: versioned behavior snapshots
- vocabulary and replacements: scoped entries and precedence
- delivery_attempts: prepared intent, version, safety decision, backend, and sent/failed/unknown outcome
- model_metadata: engine, model version, checksum/digest, device, and latency
- recovery_items: spool path, failure stage, retry state, and expiry

Normal audio remains outside SQLite in owner-only files. Spools are created atomically, finalized with rename, and reconciled before cleanup on daemon startup. A delivery attempt is committed before its side effect. Database corruption enters read-only recovery/export; it never silently creates a replacement database over the original.

Managed deletion covers base tables, FTS indexes, checkpointed WAL content, app-owned audio, app-owned exports, and diagnostic bundles. User-copied or user-exported files are outside app-managed retention and must be disclosed as such.

## Privacy, retention, and transport boundary

| Artifact/transport | Normal default | Private default |
|---|---|---|
| Audio during capture | Owner-only spool | Volatile daemon memory |
| Audio after success | Delete immediately | Clear immediately |
| Failed/incomplete audio | Retain 24 hours | No daemon-crash recovery |
| Transcript | Retain 30 days unless pinned | Volatile only |
| Clipboard | Allowed through approved policy | Disabled; Exit Private and Copy is explicit disclosure |
| AI transport | Approved loopback Ollama | Disabled unless provider-artifact audit passes and the mode explicitly permits it |
| External egress/DNS | Disabled | Disabled |

Local-only means no non-loopback egress and no external DNS. An approved loopback or local Unix-socket transport may reach the configured local Ollama service for normal sessions. Private AI stays disabled until an audit proves the Ollama service/container does not retain prompt text in logs, crash data, caches, or persistent state; the Private mode must then opt in explicitly. Remote providers remain disabled until separately designed and approved.

Preview text is never persisted. Window titles and surrounding window contents are not collected by default. Logs contain session IDs, state transitions, timing, and redacted errors only. Owner-only permissions are mandatory.

Clipboard restoration is best effort. cliphist exclusion must be proven before Private mode exposes an in-guarantee clipboard action. A user may explicitly Exit Private and Copy, after a disclosure that clipboard managers can retain the text.

Retention guarantees logical deletion of app-managed artifacts on the supported filesystem. SSD remanence, snapshots outside app control, user exports, and third-party clipboard history are outside that claim. Encryption at rest is a separate threat-model and key-management decision.

## Failure behavior

- Failure before the first durable audio frame ends as FailedNoArtifact with an explicit cause.
- Microphone loss after durable capture finalizes the valid normal spool and presents recovery.
- Disk-full or spool-write failure stops normal capture immediately and preserves any already valid artifact.
- Preview-worker failure does not block canonical finalization.
- Finalizer timeout, crash, or OOM preserves normal audio and exposes retry or alternate model.
- Ollama failure returns the unchanged input version without blocking the session; canonical raw final remains available.
- UI failure does not stop daemon-owned recording.
- Daemon restart reconciles normal spools before retention cleanup; Private content is intentionally unrecoverable.
- Any target-monitor continuity gap forces stale.
- Clipboard/input failure records failed; process death around emission records unknown and is never auto-retried.
- Compositor reload or a missed PTT release triggers a bounded stop/cancel policy and never leaves unbounded capture.
- Database corruption starts read-only recovery/export rather than replacing the database.
- Repeated hotkey events do not create concurrent capture ownership.

## Proposed repository layout

    pkgs/dictation/
      pyproject.toml
      src/dictationd/
      workers/
      ui/
      tests/
      model-packages.nix
      package.nix
    home/dictation.nix
    modules/dictation.nix
    docs/dictation/
      evidence/          # task evidence created during execution

The package runs in the project dev shell and builds declaratively through the flake. ASR artifacts are fixed-output Nix derivations. The Ollama model remains an external dependency until its manifest digest and realization policy are recorded. No global imperative installs or runtime model downloads are part of the design.
