# Dictation maximum-plan task map

Status: Not started; only P0.1A is authorized by this planning document

[Overview](README.md) · [Architecture](architecture.md)

Owner: Carter

Planning horizon: one-week feasibility, two-week integrated proof, twelve-to-eighteen-day daily-driver alpha, five-to-seven-week beta, seven-to-ten-week maximum release candidate

## Authorization boundary

- P0.1A is static discovery and may begin without changing inspected repository, system, or live state. Creation of its redacted evidence record and update of its pre-created index row are authorized.
- P0.1B and P0.2–P0.10 require Carter's explicit spike authorization because they record audio, realize models, exercise clipboard/input, run services, or create prototypes.
- P1 production work requires the P0 gate and architecture decisions to be signed off.
- This plan is not authority to stop an active recorder, mutate credentials, switch default hotkeys, or change production/external systems.
- The existing dictation path remains the default until an Alpha-or-later gate passes and Carter records a separate activation decision.

## Definition of done

The maximum plan is complete only when all non-waivable gates and every applicable release gate have observed evidence:

- Focus/workspace departure permanently forbids automatic input for that session; returning never restores eligibility.
- A later explicit Paste is a new one-shot intent through a target_bound adapter; non-atomic adapters expose Copy/Edit only.
- Automatic delivery is available only through an adapter that atomically binds insertion to the saved target.
- Preview events remain transient across worker, daemon, IPC, and UI buffers; a canary is absent from persistence, logs, clipboard, version lineage, transformation, and delivery.
- Every normal session after its first durably captured frame ends with canonical final text or recoverable audio unless the user explicitly cancels/discards; destruction follows policy and retains at most a redacted normal tombstone. Earlier failures produce an explicit no-artifact error.
- Killing the UI during capture does not stop or lose a normal recording.
- Killing an ASR worker produces a retryable normal session after restart.
- Raw final ASR survives edits, transformations, and transformation failure.
- Private mode follows its disclosed volatile/no-clipboard contract, disables AI unless provider-artifact audit passes, and does not claim daemon-crash recovery.
- Local-only mode produces no non-loopback egress or external DNS; only approved local endpoints are reachable.
- Retention removes every app-managed database, FTS, WAL, audio, export, and diagnostic artifact in scope; user exports and third-party clipboard history are disclosed as out of scope.
- Core workflows pass keyboard-only and screen-reader labeling checks.
- Applicable Hyprland and Niri sessions pass the target-safety suite.
- Unsupported selected-text targets degrade to Edit/Copy as policy permits and never blind replacement.
- Nix package checks, offline closure startup, clean install, migration, activation, rollback, and current-config transition are reproducible.

## Non-waivable invariants

No waiver may permit:

- automatic input after target continuity is lost
- preview persistence, transformation, clipboard staging, or delivery
- destructive overwrite of canonical raw final
- automatic replay of an unknown delivery outcome
- silent loss after a normal session's first durable frame
- blind selected-text replacement

Other requirements may be marked not applicable only in the applicability ledger with evidence and Carter's disposition.

## Execution rules

- Run phases in dependency order; do not build through a failed gate.
- Use dummy text and disposable test applications for every delivery test.
- Preserve unrelated worktree changes.
- Record failure signals and the chosen countermove; never relax a threshold silently.
- Keep corpus audio outside Git in an owner-only path and verify it is ignored before recording.
- Do not mutate credentials, production services, or external systems.
- Do not stop or replace an active recorder without explicit approval.
- Any architecture-changing result returns to the sign-off table before production work.

## Evidence convention

Execution updates the pre-created index at docs/dictation/evidence/README.md and adds one redacted file per task, named TASK-ID-slug.md. Each evidence record contains:

- task ID, author, date/time, and disposition
- host, compositor/session, hardware path, and relevant versions
- exact command or manual procedure
- expected and observed results
- artifact paths, with sensitive audio kept outside the repository
- failure signal, countermove, rerun result, and unresolved risk
- Carter's acceptance, waiver, deferral, or rejection where required

The evidence index also contains the applicability/waiver ledger. Missing evidence means the checkbox remains open.

## Dependency spine

| Dependency | Blocks |
|---|---|
| P0.1A static inventory | All live spikes |
| Explicit spike authorization | P0.1B and P0.2–P0.10 |
| P0.3 packaging + P0.4 corpus | P0.5 model decision |
| P0.7 target/PTT + P0.9 clipboard | P1.6 delivery and P2.6 PTT |
| P0.10 minimal storage result | P1 minimal schema |
| P0 gate | P1 production implementation |
| P1 safe spine | P2 streaming UI |
| Alpha gate | Optional daily-driver activation decision |
| P3 history + P4 deterministic modes | P5 beta workflows |
| P3 gate + P4 gate + P5 tasks | Beta gate |
| Beta + P6 audits | Maximum release |

## Scope traceability

| Product area | Architecture owner | Primary tasks/gates |
|---|---|---|
| Capture, spool, recovery | dictationd/PipeWire | P0.6, P1.2–P1.3, P6.3 |
| Preview and canonical ASR | model workers | P0.3–P0.5, P1.5, P2.1–P2.2 |
| Target safety and delivery | target monitor/delivery broker | P0.7/P0.9, P1.4/P1.6/P1.8, all release gates |
| Pill and editor | Quickshell UI | P0.8, P2.3–P2.7, P6.2/P6.4 |
| Minimal persistence/recovery | SQLite/spool | P0.10, P1.3, P1 and Alpha gates |
| History and retention | SQLite/FTS | P3, P6.6 |
| Modes/app rules/vocabulary/language | deterministic pipeline | P4 |
| AI/diff/commands/selected editing | Ollama/broker | P5 |
| Packaging/diagnostics/a11y/privacy | Nix/service/UI | P1.1, P6 |

## Milestones

| Milestone | Target | Included and excluded |
|---|---:|---|
| Feasibility decision | 3–5 working days | P0.1 plus alpha-critical model, target, PTT, overlay, capture, clipboard, and storage proofs; no daily driver |
| Integrated proof | 8–10 working days | Safe final spine, preview pill, editor, Copy/Edit, volatile recent results; disposable, reduced matrix, and unable to pass the Alpha gate |
| Daily-driver alpha | 12–18 working days | Minimal durable schema, retention, recovery, P1 and Alpha gates, core compositor coverage |
| Beta | 25–35 working days | P0–P5, full corrected corpus, modes/history/vocabulary/AI, both host classes |
| Maximum release candidate | 35–50 working days | P0–P6, full app/session matrix, privacy/a11y/failure audits |

These are planning ranges, not commitments. Re-estimate after P0 with measured model, packaging, and compositor results. A final-only fallback may preserve P1 but cannot pass the true-streaming Alpha or Maximum gate.

## Host and parameter ledger

Maximum-release scope is atlas CPU-only and kronos CPU/GPU, covering Niri plus both Hyprland variants where each is installed. The Alpha primary host/session is (needs input: Carter selection). Any unavailable session is documented in the applicability ledger rather than silently skipped.

The following values must be selected from P0 evidence before P1:

- maximum recording duration: (needs input: duration)
- minimum free-space guard and spool quota: (needs input: bytes or policy)
- preview/final worker timeout and memory ceilings per host: (needs input: measured limits)
- ASR non-inferiority margin: (needs input: proposed 3% relative WER)
- core Alpha application subset: (needs input: proposed Ghostty, Firefox, one Electron app, one GTK/Qt app)
- retention/encryption threat boundary: (needs input: owner-only plaintext versus key-managed encryption)

Required before P5 / Beta rather than before P1:

- AI cleanup rubric: (needs input: proposed zero critical semantic/protected-token regressions and at least 80% equal-or-better style judgments by Carter)

## P0 — Capability spikes and contract

Goal: prove the platform assumptions before committing to the production stack.

### P0.1A Static read-only preflight

This is the only pre-authorized execution task. “Read-only” applies to inspected repository, system, and live state; the only authorized writes are docs/dictation/evidence/P0.1A-static-preflight.md and the matching row in the pre-created evidence index.

- [ ] Record worktree state and preserve unrelated changes.
- [ ] Locate current hotkeys, scripts, declarative units/modules, ydotool integration, model declarations, and cache paths without triggering them.
- [ ] Identify installed compositor/session variants and Quickshell ownership from configuration.
- [ ] Inspect declared PipeWire source, host hardware, package versions, disk capacity, and ignored data locations.
- [ ] Inspect process state read-only; if a recorder is active, document it, stop the preflight, request approval, and do not stop or replace the recorder.
- [ ] Create no recording, clipboard mutation, input event, model download, service change, or implementation artifact.

Deliverable: docs/dictation/evidence/P0.1A-static-preflight.md with paths, versions, observed state, blockers, and redactions.

Abort condition: required mutable state cannot be identified safely or an active recorder overlaps a proposed live test.

Countermove: remain read-only and request the specific missing authority or input.

### P0.1B Controlled baseline

Requires explicit spike authorization.

- [ ] Select disposable target applications and dummy text.
- [ ] Capture current cold/warm latency, corrected-text accuracy, memory, process lifecycle, and delivery behavior.
- [ ] Record active PipeWire source and compositor event behavior.
- [ ] Measure free space and propose duration, quota, timeout, and memory limits.
- [ ] Restore clipboard and live state after each test; do not change default bindings.

Deliverable: P0.1B evidence with exact commands, expected/observed behavior, and cleanup confirmation.

Failure signal: a baseline cannot run without affecting user work or stopping an active recorder.

Countermove: defer that measurement and request a maintenance window.

### P0.2 Package and process skeleton decision

- [ ] Prototype an owner-only Unix socket, daemon lifecycle, CLI round trip, and Quickshell event subscription.
- [ ] Measure command acknowledgement under load.
- [ ] Confirm Python asyncio can supervise capture and workers without blocking.
- [ ] Decide whether any worker requires a Rust/C++ shim.

Acceptance:

- Warm command acknowledgement p95 below 100 ms.
- Daemon and UI can restart independently.
- Socket rejects other users.
- Protocol version mismatch fails explicitly.

### P0.3 Pin models and licenses

- [ ] Re-verify the candidate sherpa-onnx 1.13.4 version at execution time.
- [ ] Package sherpa-onnx and Nemotron English 0.6B 560 ms INT8 as fixed-output Nix derivations.
- [ ] Pin the existing Parakeet v2 final model and Silero VAD.
- [ ] Record source URLs, hashes, licenses, exact closure sizes, and redistribution constraints.
- [ ] Prove offline startup from a realized Nix closure with no runtime downloads.
- [ ] Treat qwen3.5:4b as an external local dependency until P5 records and verifies its Ollama manifest digest.
- [ ] Package multilingual files only after the English decision passes.

Abort condition: license, redistribution, closure size, or offline realization is incompatible with the repository.

Countermove: package fetch metadata without redistributing artifacts, choose another model, or defer the capability.

### P0.4 Build a corrected speech corpus

- [ ] Before recording, choose an owner-only path outside Git and prove git check-ignore or repository exclusion.
- [ ] Record at least 10 representative smoke clips for the Alpha decision and expand to at least 30 before Beta model lock.
- [ ] Cover short commands, long prose, technical terms, punctuation, corrections, silence, noise, and accented speech.
- [ ] Manually correct reference transcripts and label punctuation/case expectations separately.
- [ ] Split tuning and held-out evaluation clips before comparing models.
- [ ] Define corpus retention, deletion, and backup policy.
- [ ] Commit only privacy-safe metadata/scoring code; never stage voice audio without explicit approval.

Acceptance: smoke results are exploratory. A model-lock decision requires at least 3,000 held-out reference words across at least 20 clips; otherwise retain the current finalizer. The 95% bootstrap interval for the pairwise WER difference must resolve the approved non-inferiority boundary.

### P0.5 Benchmark preview and canonical ASR

- [ ] Compare Nemotron preview/canonical output against the current Parakeet path.
- [ ] Measure cold load, warm first preview, canonical-final latency, real-time factor, normalized WER, punctuation/case score, memory, and CPU/GPU use.
- [ ] Run at least five warm latency trials per held-out clip and report p50/p95 with sample count.
- [ ] Bootstrap a 95% confidence interval over held-out clips.
- [ ] Test preview stability and endpoint behavior over long utterances.
- [ ] Test atlas CPU and kronos CPU/GPU paths as applicable.
- [ ] Run sustained capture to detect unbounded queues or memory growth.

Candidate thresholds:

- Preview real-time factor at or below 0.5.
- Warm visible preview p95 at or below 900 ms after speech begins.
- Canonical final p95 at or below 2 seconds after stopping a 30-second utterance on the approved host class.
- No unbounded queue or memory growth in a 30-minute run.
- A challenger must improve relative WER by at least 5%, or fall within the approved relative-WER non-inferiority margin while materially improving an approved latency/resource budget.

Failure countermoves:

- Nemotron is too heavy: test a smaller streaming Zipformer for preview while retaining Parakeet finalization.
- CUDA contention hurts latency: default the preview worker to CPU.
- ASR bias is unreliable: rely on deterministic scoped replacements.
- Previews are unstable: increase stabilization delay within the visible-latency budget.
- No preview model passes: preserve the safe P1 final-only path, but do not claim the Alpha/Maximum streaming gate.

### P0.6 PipeWire lifecycle spike

- [ ] Select the proposed maximum duration, free-space guard, spool quota, worker timeout, and memory ceilings from P0.1B evidence.
- [ ] Test 50 start/stop cycles with no orphaned process or file handle before Beta; use 20 for the Alpha decision.
- [ ] Test source change, unplug, suspend/resume, silence, very short speech, maximum duration, and cancellation.
- [ ] Test disk full and spool-write failure using an isolated quota or temporary filesystem.
- [ ] Verify normal capture continues when the UI is killed.
- [ ] Verify a partial normal spool is discoverable after daemon termination.
- [ ] Verify Private capture is volatile and explicitly unrecoverable after daemon termination.

Acceptance: after the first durable frame, normal audio is finalized or explicitly recoverable unless the user explicitly cancels/discards; destruction then follows policy. Earlier failures are explicit, Private behavior matches its disclosed waiver, and no orphan capture remains.

### P0.7 Compositor, hotkey, target, and delivery matrix

Test Hyprland and Niri for:

- [ ] top-level surface identity, app ID, close, restart, and identifier reuse
- [ ] focus/workspace event ordering and leave-and-return behavior
- [ ] compositor IPC disconnect/reconnect, daemon restart, suspend/lock, and sequence gaps forcing stale
- [ ] press/release/repeat semantics for PTT, compositor reload mid-hold, missed release, and stuck-key timeout
- [ ] global overlay/editor actions while the pill remains non-focusable
- [ ] original-target activation capability and failure behavior
- [ ] target_bound, copy_only, and unavailable adapter classification
- [ ] delivery immediately before, during, and after focus transitions
- [ ] Alpha core apps first; full terminal/browser/Electron/GTK/Qt/JetBrains/XWayland matrix in P6

Acceptance:

- Finalization emits no input after target continuity is lost.
- Returning or reconnecting never restores continuous trust.
- Automatic delivery exists only for a proven target_bound adapter.
- An explicit Paste here exists only through a target_bound adapter; non-atomic adapters expose Copy/Edit.
- Unsupported PTT degrades to toggle; unsupported target activation degrades to Copy/Edit.

Abort condition: no adapter can meet the automatic-delivery contract.

Countermove: ship explicit Copy/Edit; do not weaken the contract.

### P0.8 Quickshell focus and accessibility proof

- [ ] Build a non-focusable layer-shell pill on the active output.
- [ ] Expand into a focusable editor intentionally.
- [ ] Confirm the pill does not change keyboard focus on either compositor.
- [ ] Confirm editor acquisition marks target stale.
- [ ] Prove all mini-overlay actions use global bindings; the non-focusable pill receives no keyboard events.
- [ ] Test multi-monitor placement, scaling, reduced motion, keyboard navigation, and AT-SPI labels.

Failure countermove: use a notification-style overlay plus a separate normal editor window.

### P0.9 Clipboard, delivery, and Private artifact spike

- [ ] Measure clipboard staging/restoration across representative targets.
- [ ] Determine whether dictation data can be excluded reliably from cliphist.
- [ ] Test ownership races and clipboard-manager restart.
- [ ] Prove or reject a no-clipboard delivery backend.
- [ ] Build the Normal versus Private artifact matrix for spool, raw text, history, logs, clipboard, loopback AI, and crash recovery.
- [ ] Verify Private mode uses volatile content and waives daemon-crash/logout recovery.
- [ ] If clipboard isolation is unproven, expose Edit/Discard only; Exit Private and Copy requires an explicit disclosure.
- [ ] Route every selection capture and clipboard operation through the delivery broker.

Acceptance: evidence states exactly which artifacts and transports remain for each policy and which adapter class is enabled.

Countermove: disable clipboard actions in Private mode and use Edit/Discard until isolation is proven.

### P0.10 Storage, AI, and selection spikes

Alpha-critical storage work:

- [ ] Validate a minimal SQLite schema for sessions, immutable transcript versions, delivery attempts, recovery items, migrations, retention snapshots, WAL, and crash recovery.
- [ ] Demonstrate canonical version-ID enforcement for transformation and delivery.
- [ ] Demonstrate app-managed deletion across base tables, FTS placeholder, WAL/checkpoint, and normal audio.
- [ ] Decide owner-only plaintext versus key-managed encryption from the documented threat boundary.

Required before P3/P5, not before the two-week candidate:

- [ ] Demonstrate 10,000-session FTS search p95 below 100 ms on target hardware.
- [ ] Build a golden corpus for qwen3.5:4b cleanup, label protected tokens and critical semantic facts, set the approved scoring/adjudication rubric, and verify unchanged-input fallback plus canonical raw availability.
- [ ] Record and validate the local Ollama model manifest digest and no-non-loopback-egress boundary.
- [ ] Test broker-mediated selected-text capture, focus retention, diff preview, and replacement across the full app matrix.
- [ ] Treat selection text as untrusted data with no tool authority.

Selection abort condition: target/selection continuity cannot be guarded across representative apps.

Countermove: defer generic replacement or ship Edit/Copy result only.

### P0 gate

Before P1 production implementation:

- [ ] Every alpha-critical spike has an evidence record.
- [ ] The architecture has no unresolved non-waivable safety contradiction.
- [ ] Carter signs off on process/UI stack, model roles, adapter classes, PTT fallback, storage schema, Private artifact matrix, retention, host scope, and parameter ledger.
- [ ] Automatic delivery is disabled unless a target_bound adapter passed.
- [ ] The schedule is re-estimated from observed results.
- [ ] Selection, multilingual, AI, encryption, and full-matrix items are explicitly approved, deferred, or assigned to their later prerequisite gate.

Disposable spike code is either deleted or clearly isolated; it does not silently become production code.

## P1 — Safe dictation spine

Goal: replace the fragile direct-to-focused-window path with recoverable sessions and guarded final delivery.

### P1.1 Package daemon and CLI

- [ ] Create the repository layout from the architecture.
- [ ] Add flake packages and a development shell.
- [ ] Add systemd user service, socket permissions, restart policy, and resource limits.
- [ ] Implement versioned IPC and idempotent CLI commands.
- [ ] Add structured redacted logs and health reporting.

### P1.2 Implement authoritative state machine

- [ ] Encode the global capture slot separately from per-session state.
- [ ] Encode every legal transition, retry exit, delivery-attempt failure/unknown acknowledgment, terminal disposition, explicit destruction, and artifact cleanup rule.
- [ ] Reject duplicate capture ownership and illegal transitions.
- [ ] Keep the initial alpha serial through canonical finalization; overlap requires a later measured capability flag.
- [ ] Snapshot target, mode, privacy, model, and retention at session start.
- [ ] Unit-test every state edge, cancel path, timeout, retry, and restart recovery.

### P1.3 Implement minimal persistence, spool, and recovery

- [ ] Create minimal sessions, immutable transcript_versions, delivery_attempts, recovery_items, model_metadata, migrations, and retention snapshots.
- [ ] Capture normal PipeWire audio under daemon supervision.
- [ ] Write owner-only temporary normal spools and atomically finalize them.
- [ ] Keep Private audio/text volatile and surface its daemon-crash recovery waiver.
- [ ] Reconcile incomplete normal sessions before cleanup on startup.
- [ ] Enforce approved duration, disk-space, quota, timeout, and memory guardrails.
- [ ] Implement Alpha retention cleanup and canonical raw lineage.
- [ ] Keep capture independent from UI lifecycle.

### P1.4 Implement target monitor

- [ ] Add Hyprland and Niri adapters.
- [ ] Store top-level target identity without window title.
- [ ] Make continuous-to-stale a one-way transition.
- [ ] Force stale after compositor IPC loss, daemon restart, suspend/lock, or any sequence gap.
- [ ] Detect target loss and identifier reuse where possible.
- [ ] Keep target confidence separate from one-shot delivery intent.
- [ ] Publish target-confidence events.

### P1.5 Implement canonical final ASR

- [ ] Supervise the benchmark-selected canonical finalizer.
- [ ] Consume sealed audio and emit raw.final through the canonical protocol role.
- [ ] Persist immutable raw final before deterministic cleanup, transformation, or delivery.
- [ ] Persist engine/model/checksum/timing metadata.
- [ ] Handle timeout, crash, OOM, malformed output, and retry.
- [ ] Preserve normal audio until successful policy-driven cleanup.

### P1.6 Implement delivery and selection broker

- [ ] Centralize selection capture, input emission, and clipboard staging.
- [ ] Require immutable version ID, adapter class, expected target, and one-shot intent ID.
- [ ] Permit automatic delivery only through a proven target_bound adapter.
- [ ] Expose Paste here only through target_bound delivery; every non-atomic adapter is Copy/Edit only.
- [ ] Persist a prepared attempt before side effects and then sent, failed, or unknown.
- [ ] Never automatically replay an unknown outcome.
- [ ] Restore clipboard best effort and report only observable disposition.
- [ ] Store paste sent, never inserted, unless an app adapter proves insertion.

### P1.7 Add side-by-side compositor bindings

- [ ] Add opt-in toggle, push-to-talk where proven, cancel, editor, and history bindings.
- [ ] Prevent key-repeat duplication and enforce missed-release timeout.
- [ ] Unsupported PTT degrades to toggle.
- [ ] Keep the current binding and a documented rollback.
- [ ] Do not replace default hotkeys in P1.

### P1.8 P1 integration tests

- [ ] Run 20 short sessions and three long sessions for Alpha; complete 100 short and ten long before Beta.
- [ ] Inject UI, worker, compositor IPC, target-monitor, and daemon failures.
- [ ] Kill the daemon before prepare, after durable prepare, around emission, and before disposition; unknown delivery is never replayed.
- [ ] Race focus changes against finalization and every delivery adapter.
- [ ] Inject a recognizable preview canary, release transient buffers, and prove it is absent from persistence, logs, clipboard, version lineage, transformation, and broker output.
- [ ] Confirm every failed normal session after its first durable frame exposes canonical text or recovery.
- [ ] Confirm pre-frame failures end as FailedNoArtifact.

### P1 gate

- [ ] Non-waivable target, preview, lineage, delivery-replay, and recovery tests pass.
- [ ] Minimal schema, migration, retention, and Private volatile behavior pass.
- [ ] Canonical-final and audio-spool recovery tests pass.
- [ ] Current toggle behavior remains untouched with a documented rollback.
- [ ] No sensitive content appears in default logs.
- [ ] Evidence records identify the tested host/session and adapter classes.

## P2 — True streaming overlay and editor

Goal: make dictation visible and editable without coupling UI focus to the destination app.

### P2.1 Streaming preview worker

- [ ] Implement worker protocol, warm startup, readiness, backpressure, timeout, and restart.
- [ ] Emit preview.partial, preview.segment_stable, and preview.complete only.
- [ ] Define stable as stable in the preview pass, not canonical.
- [ ] Coalesce stale previews for slow consumers.
- [ ] Expose load, device, memory, and latency diagnostics.
- [ ] Prove worker failure cannot contaminate or block canonical finalization.

### P2.2 VAD and canonical reconciliation

- [ ] Integrate Silero VAD, manual stop, maximum duration, and silence handling.
- [ ] Render stable preview segments without persisting them.
- [ ] After stop, replace the read-only preview with persisted raw.final.
- [ ] Enable editing only after raw.final exists.
- [ ] Require every downstream action to reference a canonical/derived version ID.
- [ ] Never persist, transform, copy, or deliver a preview event.

### P2.3 Quickshell state store

- [ ] Subscribe to daemon events with reconnect and state resync.
- [ ] Render daemon state rather than inventing UI-local session state.
- [ ] Handle daemon restart, stale events, and protocol mismatch.
- [ ] Bound transcript and audio-level update rates.

### P2.4 Mini overlay

- [ ] Show state, timer, level, stable/partial text, mode/language, target confidence, local/private badge, and recovery actions.
- [ ] Keep it non-focusable in mini mode.
- [ ] Route all actions through compositor-global bindings; the pill receives no keyboard input.
- [ ] Support active-output placement, scaling, theme, reduced motion, and high contrast.
- [ ] Announce meaningful state changes accessibly without reading every partial.

### P2.5 Expanded editor

- [ ] Keep preview read-only and enable edits only after canonical raw final.
- [ ] Implement editable accepted text and immutable raw view.
- [ ] Add diff, undo/redo, policy-allowed copy, explicit delivery, delete, and retained-audio playback.
- [ ] Mark target stale when expanded.
- [ ] Persist normal edits through the minimal P1 schema; keep Private edits volatile.
- [ ] Make Escape behavior explicit and non-destructive.

### P2.6 Push-to-talk and recovery UX

- [ ] Start only from a proven down event and finalize on the matching release.
- [ ] Bound missed release with the approved timeout and compositor-reload policy.
- [ ] Fall back to toggle on sessions without reliable release bindings.
- [ ] Escape cancels recording or closes UI according to documented context.
- [ ] Surface microphone/model failures with retry, alternate model, policy-allowed copy, edit, or discard.
- [ ] Prevent duplicate sessions from key repeat.

### P2.7 Alpha conformance

- [ ] Run the approved Alpha core-app subset on the selected primary host/session, then both compositor families before daily-driver Alpha.
- [ ] Test focus departure, leave-and-return, target close, monitoring gap, and explicit-delivery intent separately.
- [ ] Measure acknowledgement, preview, and canonical-final latency against approved thresholds.
- [ ] Kill UI and preview/final workers during active normal capture.
- [ ] Verify keyboard-only core journeys and Private disclosures.
- [ ] Add history-lite from the minimal schema: recent normal sessions, edit, policy-allowed copy, retry, and delete.

### P2 / Alpha gate

This gate applies only to the twelve-to-eighteen-day daily-driver Alpha. The two-week integrated proof remains disposable and cannot trigger default activation.

- [ ] The P1 gate and every P2.1–P2.7 task pass with linked evidence.
- [ ] Automatic delivery is absent unless a target_bound adapter passed.
- [ ] Preview canary, target-monitor-gap, delivery-unknown, recovery, migration, retention, and Private-policy tests pass.
- [ ] The selected primary host/session and core apps pass; daily-driver Alpha also covers both compositor families.
- [ ] Performance thresholds pass; otherwise this gate fails and the build remains an integrated proof.
- [ ] Carter records whether the Alpha remains opt-in or replaces the default binding.
- [ ] The old path and rollback remain available through at least one later stable release.

The two-week candidate cannot become the default merely because the calendar expired.

## P3 — History, versions, retention, and recovery

### P3.1 Expand schema and migrations

- [ ] Extend the minimal P1 schema with finalized segments, FTS, modes, app rules, vocabulary, filters, exports, and richer lineage.
- [ ] Add forward migrations, backup, failure rollback, and schema-version diagnostics.
- [ ] Preserve immutable raw lineage and existing Alpha data.
- [ ] Test upgrade from every released Alpha schema.

### P3.2 Retention and Private policy

- [ ] Implement per-session retention snapshots, pinning, expiry, and interrupted-cleanup recovery.
- [ ] Delete successful normal audio immediately by default and failed normal audio after 24 hours.
- [ ] Expire normal transcript history after 30 days by default.
- [ ] Keep Private content volatile and document its loss on daemon exit/logout.
- [ ] Expose no Private clipboard action unless isolation is proven; Exit Private and Copy is an explicit disclosure.
- [ ] Verify base tables, FTS, WAL, app-owned exports/diagnostics, and normal audio are removed.
- [ ] Disclose user-owned exports, snapshots, SSD remanence, and third-party clipboard history as outside managed retention.

### P3.3 Search and history UI

- [ ] Add FTS, date/mode/language/app/state filters, pin, copy, export, delete, retry, and reprocess.
- [ ] Keep search p95 below 100 ms at 10,000 sessions.
- [ ] Distinguish raw, edited, transformed, and delivered versions.
- [ ] Explain when retained audio no longer exists.

### P3.4 Reprocessing and recovery

- [ ] Re-run transforms from an explicitly selected immutable version.
- [ ] Re-run ASR only when retained normal audio exists.
- [ ] Compare branches without destructive overwrite.
- [ ] Recover locked/corrupt storage through read-only export before repair.

### P3 gate

- [ ] Alpha-to-P3 migrations and rollback pass.
- [ ] 10,000-session search p95 is below 100 ms on both host classes or has an approved host-specific budget.
- [ ] Retention deletion passes for every app-managed artifact in scope.
- [ ] Private volatile/no-clipboard behavior matches the artifact matrix.
- [ ] Raw lineage and reprocessing branch tests pass.

## P4 — Modes, vocabulary, replacements, and language

### P4.1 Mode, app-rule, and deterministic-stage semantics

- [ ] Add Verbatim, Clean Dictation, Message, Email, Technical/Markdown, Selected Text Edit, and Custom.
- [ ] Define ASR, language, vocabulary scope, replacements, transform, review, delivery, retention, and transcript-command policy.
- [ ] Implement precedence: explicit session override > exact app rule > app-pattern rule > selected mode > global default.
- [ ] Implement the P4 deterministic stages and typed version boundaries; reserve the documented command and AI stages for P5 without implementing them here.
- [ ] Snapshot effective rules and versions into each session.
- [ ] Make Clean Dictation deterministic and non-generative by default.
- [ ] Test conflicting rules, explicit priority, equal-priority rejection, app-ID normalization, restart, and historical reproducibility.

### P4.2 Vocabulary and replacements

- [ ] Support global, language, mode, and app-specific scopes with the documented precedence.
- [ ] Add exact phrase and case-aware matching by default.
- [ ] Gate regex behind an advanced setting.
- [ ] Add conflict warnings, preview, JSON/CSV import/export, and optional suggested corrections.
- [ ] Validate model hotword/bias support separately from deterministic replacements.
- [ ] Store deterministic replacements as derived versions with lineage assertions.
- [ ] Prove reprocessing with an old mode snapshot reproduces the same deterministic result.

### P4.3 Language workflows

- [ ] Add explicit per-mode default, recent-language switch, and optional auto-detection.
- [ ] Package multilingual model only after benchmark approval.
- [ ] Test mixed-language behavior and document model limitations.
- [ ] Keep language/model state visible in the overlay and history.

### P4.4 Management UI and conformance

- [ ] Build keyboard-accessible mode, app-rule, vocabulary, replacement, and language screens.
- [ ] Preview effective configuration, pipeline order, and precedence.
- [ ] Prevent deletion of a configuration snapshot referenced by history.
- [ ] Run app-rule conformance across normalized app IDs and both compositors.

### P4 gate

- [ ] Built-in modes and app-rule precedence are deterministic and snapshot-reproducible.
- [ ] Vocabulary/replacement conflicts, imports, and lineage tests pass.
- [ ] Language behavior and mixed-language limitations are documented.
- [ ] Management UI passes keyboard and migration tests.

## P5 — AI cleanup, transcript commands, and selected editing

### P5.1 Ollama adapter

- [ ] Add a local provider boundary with timeout, cancellation, model readiness, and redacted errors.
- [ ] Verify the configured qwen3.5:4b Ollama manifest digest and declare it an external local dependency.
- [ ] Permit only the approved loopback/local transport and prove no non-loopback egress or external DNS.
- [ ] Keep AI disabled in Private until provider-side logs, crash data, caches, and persistent state pass artifact inspection.
- [ ] Transform an immutable canonical/derived version only.
- [ ] Record prompt-template and model-version snapshots without logging user text.
- [ ] Return the unchanged selected input version on provider failure; canonical raw final remains available.
- [ ] Keep remote-provider interfaces disabled unless separately approved.

### P5.2 Review and diff

- [ ] Store AI output as a derived version.
- [ ] Show raw versus transformed diff and explicit accept/reject.
- [ ] Implement the approved golden-corpus rubric, protected-token checks, and critical semantic-regression classification.
- [ ] Require review for generative modes by default.
- [ ] Make provider/locality visible during processing and review.

### P5.3 Deterministic transcript commands

- [ ] Implement a bounded grammar such as new paragraph and scratch that.
- [ ] Apply commands only to the draft.
- [ ] Provide undo and a literal-speech escape.
- [ ] Do not execute shell commands or general application actions.

### P5.4 Broker-mediated selected-text experiment

- [ ] Route selection capture, clipboard staging/restoration, target checks, and replacement only through the delivery broker and validated app adapters.
- [ ] Capture selection without moving focus only where the adapter proves it.
- [ ] Record spoken instruction and show a diff.
- [ ] Require an explicit global commit with a one-shot intent.
- [ ] Re-check original target continuity and adapter capability immediately before replacement.
- [ ] Disable Replace after any continuity loss; retain Edit or policy-allowed Copy result.
- [ ] Test selection text as inert untrusted data with no tool authority.
- [ ] Record outcome unknown around replacement and never auto-retry.

### P5 / Beta gate

- [ ] P3 and P4 gates pass.
- [ ] The 30-plus-clip held-out corpus and full 100-short/ten-long session runs pass.
- [ ] The cleanup model meets the approved rubric: zero critical semantic/protected-token regressions and the approved equal-or-better style threshold.
- [ ] Ollama digest and no-non-loopback-egress checks pass; Private AI remains disabled unless the provider-artifact audit also passes.
- [ ] Provider failure returns the unchanged selected input version and keeps canonical raw final available.
- [ ] Transcript commands are bounded, undoable, and incapable of shell/application execution.
- [ ] Selected editing ships Experimental only if every broker/adapter safety criterion passes; otherwise it is Deferred with evidence.
- [ ] Both host classes and both compositor families pass the Beta subset.
- [ ] Migrations, retention, rollback, and evidence/waiver ledger are current.

## P6 — Product hardening and maximum release

### P6.1 Settings and diagnostics

- [ ] Add hotkey, audio/VAD, model, mode, language, vocabulary, UI, delivery, history, privacy, accessibility, and diagnostics settings.
- [ ] Expose microphone meter, source, model checksum/readiness/device, cold/warm latency, compositor adapter, and delivery capability.
- [ ] Add a short record/transcribe smoke test and redacted diagnostic export.
- [ ] Test interrupted Nix-store realization, checksum failure, and missing/corrupt model recovery without runtime download.

### P6.2 Accessibility and motion

- [ ] Complete keyboard operation for record, cancel, edit, accept, copy, delivery, history, and settings.
- [ ] Add visible focus, semantic labels, state announcements, scalable text, high contrast, reduced motion, and visual equivalents for sound.
- [ ] Avoid status communicated by color or waveform alone.
- [ ] Verify the documented Escape behavior in every context.

### P6.3 Failure injection

- [ ] Inject microphone loss, suspend, disk full, ASR crash/OOM/timeout, Ollama failure, target close/ID reuse, clipboard race, compositor IPC restart/gap, UI crash, duplicate hotkey, missed PTT release, database lock/corruption, and interrupted retention.
- [ ] Kill the daemon at every delivery boundary and assert prepared/sent/failed/unknown without automatic replay.
- [ ] Assert the expected state, target confidence, preserved artifact, user action, and redacted log for each.
- [ ] Repeat normal recovery tests after daemon restart and verify Private loss matches its waiver.

### P6.4 App and compositor conformance

- [ ] Run the full matrix on Hyprland Waybar, Hyprland Quickshell, and Niri.
- [ ] Cover Ghostty/TUI, Firefox, Chromium, Electron, GTK, Qt, JetBrains, and representative XWayland apps.
- [ ] Test stop/finalize/delivery at focus-transition boundaries.
- [ ] Test multiple outputs, fractional scaling, workspace changes, target close, and app restart.

### P6.5 Performance and resource budgets

- [ ] Re-run cold/warm latency and corrected-corpus accuracy.
- [ ] Run 30-minute and 8-hour soak tests.
- [ ] Bound daemon, UI, worker, database, and model memory.
- [ ] Verify no orphan process, descriptor, spool, or unbounded queue.
- [ ] Document host-specific CPU/GPU defaults.

### P6.6 Privacy audit

- [ ] Monitor egress and DNS: local-only and Private permit only approved loopback/local endpoints.
- [ ] Inspect database, FTS, WAL, normal audio, app-owned exports, application and Ollama/container logs, crash data, provider caches/state, clipboard manager, and temporary files.
- [ ] Verify owner-only permissions and retention deadlines.
- [ ] Confirm preview text, window titles, and surrounding contents are absent from managed artifacts.
- [ ] Test Exit Private and Copy disclosure separately from the Private guarantee.
- [ ] Document logical-deletion scope and residual risks from SSD remanence, snapshots, user exports, and third-party clipboard history.

### P6.7 Packaging, migration, rollback, and docs

- [ ] Run nix flake check and validate module evaluation for both hosts.
- [ ] Build with nh os build ~/dotfiles and start from an offline realized closure.
- [ ] Test clean install, activation, upgrade, every released schema migration, model checksum failure, uninstall, and rollback.
- [ ] Verify ASR models never download at application runtime.
- [ ] Verify the external Ollama dependency fails closed on a missing or mismatched digest.
- [ ] Keep a rollback path to the prior dictation script through one stable release.
- [ ] Add operator, privacy, troubleshooting, mode/vocabulary, recovery, evidence, and known-limitation documentation.

### Maximum release gate

- [ ] Every non-waivable Definition of Done item passes with evidence.
- [ ] Every applicable P0–P6 item is complete; every non-applicable item has evidence and Carter's recorded disposition.
- [ ] No open P0/P1 safety blocker or delivery-unknown replay path.
- [ ] Alpha and Beta migration/rollback paths pass.
- [ ] Both host classes and all installed target sessions pass their required matrices.
- [ ] Privacy and accessibility audits pass; exceptions cannot waive non-waivable invariants.
- [ ] Selected-text editing is proven Experimental or clearly Deferred.
- [ ] Carter signs off before this path becomes the default if no earlier recorded activation decision exists.

## Verification matrix

| Dimension | Integrated proof / daily-driver Alpha | Maximum |
|---|---|---|
| Host | Selected primary host (needs input) | atlas CPU and kronos CPU/GPU |
| Compositor/session | Selected primary plus second compositor before daily-driver Alpha | Niri, Hyprland Waybar, Hyprland Quickshell where installed |
| Application | Approved core subset | Ghostty/TUI, Firefox, Chromium, Electron, GTK, Qt, JetBrains, XWayland |
| Target continuity | unchanged, leave, return, monitor gap | plus suspend/lock, target close/restart, ID reuse, daemon restart |
| Delivery | target_bound automatic/explicit if proven; otherwise Copy/Edit | every supported adapter and every side-effect boundary |
| Speech | silence, short, long, technical, punctuation, correction | plus noise, accented, multilingual, soak |
| Failure | microphone, preview/final worker, UI, target monitor, disk | plus daemon, Ollama, clipboard, database, retention, model realization |
| Privacy | normal, Private, preview canary, deletion | plus egress/DNS, WAL/FTS, exports, cliphist, diagnostic bundle |
| Access | keyboard-only, labels, reduced motion | plus high contrast, scaling, screen reader, multiple outputs |

## Primary risks and countermoves

| Risk | Failure signal | Countermove |
|---|---|---|
| Generic Wayland cannot preserve a caret | Saved surface exists but insertion point is unknowable | Hold for explicit Paste here where policy allows, or Copy/Edit |
| Generic input has a target race | Adapter cannot atomically bind insertion | Classify it Copy-only; expose no Paste action |
| Target monitoring has a gap | IPC/restart/suspend loses event continuity | Force stale permanently for that session |
| Preview escapes UI memory | Canary appears in any downstream artifact | Block release; enforce canonical version-ID APIs |
| Streaming model is too heavy or unstable | Latency/memory budgets fail | Smaller preview model or P1 final-only fallback; no streaming claim |
| Vocabulary bias is weak | Corrected-corpus terms remain wrong | Deterministic scoped replacements with lineage |
| cliphist captures sensitive text | Clipboard manager retains staged dictation | Disable Private clipboard; require Exit Private disclosure |
| AI mutates technical meaning | Golden-corpus regression | Review/diff, unchanged-input fallback, and canonical raw availability |
| Selection cannot be safely replaced | Continuity cannot be proven | Defer Replace; keep Edit/Copy result |
| UI lifecycle affects recording | Killing Quickshell loses normal capture | Daemon-owned capture and spool |
| SQLite deletion leaves managed artifacts | FTS/WAL/audio inspection finds content | Transactional cleanup, checkpoint policy, verified deletion |
| Delivery outcome is unknown | Crash occurs after emission before disposition | Never auto-retry; require a new reviewed intent |
| Packaging grows host-specific | One host/session needs ad hoc setup | Capability adapters, ledger, flake/module tests |
| Schedule compresses safety work | Two-week date arrives with open gate | Keep candidate opt-in and re-estimate; do not redefine done |

## Open sign-offs

| Decision | Proposed default | Status |
|---|---|---|
| UX direction | Paper & Margin primary; Quiet Orbit capture pill; Command Strip optional accelerator | Approved by Carter, 2026-07-10 |
| Spike authorization | P0.1B and P0.2–P0.10 run only in an approved maintenance window | (needs input: Carter approval) |
| Persistent stack | Python asyncio daemon + isolated workers + Quickshell | (needs input: Carter decision after P0) |
| Model roles | Nemotron preview + benchmark-selected canonical final | (needs input: P0.5 evidence) |
| Delivery | Atomic target_bound automatic/explicit Paste only; non-atomic adapters Copy/Edit | (needs input: P0.7 evidence) |
| Alpha primary host/session | Choose one, then both compositor families before daily-driver use | (needs input: Carter selection) |
| Private mode | Volatile, no daemon-crash recovery, no clipboard without explicit exit, and AI disabled pending provider audit | (needs input: Carter acceptance) |
| Retention/encryption | 30-day normal transcript, immediate successful-audio delete, owner-only plaintext unless threat model demands encryption | (needs input: Carter decision) |
| Ollama | Local approved endpoint with verified manifest digest; no remote interface initially | (needs input: Carter decision) |
| Selected editing | Experimental only if broker/adapter tests pass; otherwise Deferred | (needs input: P5 evidence) |
| Default activation | Separate recorded decision after an Alpha-or-later gate; old path retained through one stable release | (needs input: Carter decision) |
