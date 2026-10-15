# sfx-04 — round 3 (director decisions for the two TODO_DESIGN items)

Work on top of the current uncommitted state. Do not commit.

## Decision: per-call peak alignment for shared samples (resolves both TODOs)
A shared sample keeps one verified asset. Each **call** may align it to its own visual climax:
- Target: the pitch-adjusted RMS peak (`peak_ms / pitch_scale` for the pitch the router actually picks) lands at
  **climax + 15 ms**; the existing window (0 to +30 ms after climax) is the assertion.
- If the needed start is ≥ 0 ms after the anchor: **delay** the call by that amount.
- If it would be negative: **skip the head** (`from_position`), retaining at least 15 ms before the peak, with a 3 ms
  linear fade-in (no click: assert the first 3 ms ramp in the harness). Implementation choice is yours (e.g. a cached
  in-memory trimmed AudioStreamWAV per offset, or a volume ramp) — no new or edited asset files.
- Peak-aligned calls are judged by the peak window only; their onset cap is measured from the scheduled start, not from
  the wind-up anchor.

Apply it to:
1. **Swap** (climax 0 ms): blink sample head-skipped to ~253.8 ms nominal (peak 268.792 − 15), so swap peaks at +15 ms.
   Ordinary blink stays as now (peak lands +18.8 ms after its 250.005 ms departure; within window).
2. **Roar**: breath (release 316.673 ms) and ground (566.678 ms) each get their own delay/head-skip from the same roar
   sample, computed per call from the chosen pitch — this also removes the ±3% pitch spread problem.

Record the rule in `spec/audio.md` (one short paragraph) and in the sync audit as the policy for any future shared-sample
conflicts. Remove both TODO_DESIGN markers.

## Proof
Sync harness assertions all pass (including swap and the four roar rows), sync Python tests, sound lab, full Godot suite
(the sync sub-suite included), cue coverage. List any remaining violations in the audit table that are outside this
unit's scope (the table shows many legacy rows, e.g. card.exhaust, death.stone): do not fix them here, but give me a
ranked list of the ten most noticeable ones by peak − climax with the cue's use frequency, so I can brief a follow-up.
