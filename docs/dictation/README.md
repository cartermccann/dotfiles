# Dictation application plan

Status: Planning draft — only the P0.1A read-only preflight is pre-authorized by this document

Controlled baselines, recordings, model realization, clipboard/input tests, disposable prototypes, and production implementation require Carter's explicit approval at the gates in the task plan.

Updated: 2026-07-10

Target: Local-first NixOS desktop application for Hyprland and Niri

> [!NOTE]
> **Design-doc caveat (2026-08-09).** `ux-design-specification.md` and
> `ux-design-directions.html` are written against `qs-shell`, which was removed
> from the flake in `a02bf09`. Caelestia now fills that Quickshell role. The
> interaction design still holds; the theming/component references do not. See
> the warning at the top of the specification. `architecture.md` and
> `task-plan.md` are unaffected.

## Product promise

Capture speech into a recoverable session, show it live, transform it transparently, and deliver it deliberately to a known target.

This replaces the current pipeline:

    global hotkey → pw-record → offline Parakeet transcription → ydotool type

with a small local application whose UI owns the draft. Live text never streams directly into whichever application happens to have focus.

The useful Superwhisper-like behavior is the app-owned draft surface: dictation can continue while desktop focus changes, and delivery is a separate decision. This plan does not depend on assumptions about Superwhisper's private implementation.

## Documents

- [Architecture](architecture.md) defines boundaries, state, data, model choices, target safety, and privacy.
- [Task plan](task-plan.md) is the implementation backlog, phase gates, verification matrix, risks, and decisions requiring sign-off.
- [UX design specification](ux-design-specification.md) defines the core interaction, visual foundation, journeys, components, consistency patterns, responsive behavior, and accessibility contract.
- [Interactive design directions](ux-design-directions.html) compares seven visual compositions across Recording, Held, Editor, and History states.
- [Evidence index](evidence/README.md) is the pre-created execution ledger and record template.

The architecture, task plan, and UX specification are canonical planning contracts. Implementation notes and benchmark evidence should link back to the applicable task ID rather than duplicating those contracts.

## Selected UX direction

Carter approved **Paper & Margin** as the primary visual direction on 2026-07-10:

- Quiet Orbit supplies only the compact, non-focusable Recording and Finalizing pill.
- Paper & Margin governs Held results, editing, versions, transformations, and the history list/detail workspace.
- Paper surfaces adapt to dark, light, and high-contrast themes; the editorial hierarchy is the invariant, not a fixed cream color.
- Command Strip remains an optional keyboard accelerator, never the only navigation or recovery path.

## Goals

- Toggle-to-record and push-to-talk.
- True streaming transcription in a non-focus-stealing mini overlay.
- An expandable editor for review, correction, diffing, copying, and explicit delivery.
- Guarded delivery that never follows the user into another window or workspace.
- Immutable raw transcripts plus versioned edits and transformations.
- Searchable history, configurable retention, retry, and reprocessing.
- Modes for verbatim, clean dictation, messages, email, technical/Markdown, and custom workflows.
- Scoped vocabulary, deterministic replacements, language selection, and optional ASR biasing.
- Optional local AI cleanup through Ollama, with unchanged-input fallback, canonical raw availability, and a visible diff.
- Experimental selected-text editing only where capture and replacement can be proven safe.
- Local-first privacy, private sessions, diagnostics, accessibility, and parity across both compositors.

## Non-goals for the first complete release

- A pixel-for-pixel Superwhisper clone.
- macOS, Windows, mobile, or cross-device sync.
- Claiming a portable field, caret, or selection identity under generic Wayland.
- Sending provisional words into the destination application.
- Always-on wake words, meeting transcription, diarization, or system-audio capture.
- General desktop-control voice commands.
- Silent capture of surrounding window contents as AI context.
- Fully reliable selected-range replacement in every application.

## Non-negotiable invariants

1. Preview hypotheses remain transient across worker, daemon, IPC, and UI buffers; they never enter persistence, logs, clipboard, transformation, version lineage, or delivery.
2. A focus or workspace departure permanently forbids automatic input for that session. Returning to the original window does not restore trust.
3. Any target-monitor continuity gap—including IPC loss, daemon restart, suspend, or lock—changes continuous trust to stale.
4. A later Paste action is a new, explicit, one-shot delivery intent; it is not a continuation of finalization.
5. Raw final ASR is immutable. Edits and transformations create descendant versions.
6. The delivery broker is the only component allowed to capture selections, emit input, or stage clipboard data.
7. After the first audio frame is durably captured, any normal session not explicitly cancelled or discarded must end with final text or recoverable audio. Explicit destruction follows the session policy and retains at most a redacted normal-session tombstone.
8. Local processing is the default. Remote processing is disabled until explicitly configured per mode.
9. Logs exclude transcript text, selected text, audio, and window titles by default.
10. Unsupported capabilities degrade to Edit, Copy, or Discard; they never trigger a blind paste or replacement.

## Held result actions

A held result never emits input merely because processing completed. The user may create a new one-shot delivery intent:

- Paste here
- Return to the original window and paste
- Copy
- Edit
- Discard

Paste here is shown only for a target_bound adapter that atomically binds insertion to the expected target. Return and paste requires the same guarantee plus validated target activation; otherwise it is absent. Non-atomic clipboard or synthesized-key adapters expose Copy/Edit, never Paste.

In Private mode, Edit and Discard are the default safe actions until clipboard-manager exclusion or a no-clipboard adapter is proven. A separately confirmed Exit Private and Copy action may disclose text to the clipboard.

“Paste sent” is the strongest generic delivery claim. Wayland cannot prove that the receiving application inserted the text.

## Delivery horizons

| Horizon | Scope | Exit outcome |
|---|---|---|
| One-week feasibility | P0.1, critical target/overlay/model spikes, and a disposable streaming proof | Evidence and a go/no-go architecture decision; not a daily driver |
| Two-week integrated proof | Safe final-result spine, streaming pill, editor, Copy/Edit delivery, and volatile recent results | Opt-in disposable trial; it does not pass the Alpha gate or switch defaults |
| Twelve-to-eighteen-day daily-driver alpha | Minimal durable schema, recovery, retention, core compositor tests, and guarded delivery | Credible opt-in replacement for the current script |
| Five-to-seven-week beta | Full history, modes, vocabulary, language workflows, and local AI cleanup | Feature-complete beta with recoverability and review workflows |
| Seven-to-ten-week maximum | Privacy hardening, accessibility, diagnostics, failure injection, full app conformance, and selected experiment | Release candidate suitable to become the default dictation path |

The one-week feasibility slice and two-week integrated proof are scope boxes, not promises made before P0 measurements. The schedule is re-estimated at the P0 gate. Capability spikes may remove or defer unsafe features; they never weaken the invariants.

## Proposed defaults requiring sign-off

1. Repository-local Python asyncio orchestrator, isolated model workers, and Quickshell UI.
2. sherpa-onnx streaming Nemotron for preview hypotheses, with the benchmark winner producing the canonical raw final.
3. Automatic or explicit Paste only through an adapter that atomically binds insertion to the saved target; non-atomic generic adapters are Copy/Edit only.
4. Local ASR and local transformation by default; no external provider in the initial release.
5. Normal transcript retention of 30 days; successful audio deleted immediately; failed or incomplete audio retained for 24 hours.
6. Private sessions use volatile audio/text, waive daemon-crash recovery, disable AI by default, and expose no clipboard action unless the user explicitly exits Private or isolation is proven.
7. Generic selected-text editing ships as Experimental only if the broker-mediated spike passes; otherwise it is deferred.
8. The existing hotkey path remains the default until an Alpha-or-later gate passes and Carter records a separate activation decision.

## Sign-off checkpoint

P0.1A may begin as static, read-only discovery. Before any live baseline or prototype, approve or amend the authorization boundary, proposed defaults, unresolved parameter ledger, and phase-zero thresholds in [the task plan](task-plan.md).
