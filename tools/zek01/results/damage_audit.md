# Eight-fight confusing-damage audit

HP62, scatter9 and the five-slot cycle; section 1; archived ladder entry loadouts 1–8; first combat seed for each. Raw accepted-state receipts are in `audit.jsonl.gz`; speculative bot candidates do not enter this report. Each damage call is one receipt, so one Storm may contribute several actor losses.

Actual screen visibility could not be observed: this worker has no macOS window server. Both requested screen fields remain null in the machine-readable report. The production playback routes below describe scheduled presentation only; the design owner must verify them with the windowed command in the handoff. No presentation or forecast fixes are included.

| Target | Cause | Loss events | Total HP | Number scheduled | Cause label scheduled | Reproduction: seed / turn / clock |
|---|---|---:|---:|---|---|---|
| Zekarion | Lightning Storm: on Electrified ground | 3 | 15 | False | False | 1 / 6 / 87 |
| Zekarion | Retaliate | 1 | 3 | True | True | 4 / 7 / 124 |
| hero | Call Wisps bolt | 8 | 30 | True | visible_sources_only | 1 / 8 / 142 |
| hero | Fatigue | 1 | 2 | True | True | 4 / 10 / 161 |
| hero | Overload bolt | 2 | 5 | True | visible_sources_only | 5 / 6 / 87 |
| hero | Skybreak | 2 | 5 | True | visible_sources_only | 5 / 7 / 105 |
| hero | Storm Lash | 5 | 17 | True | visible_sources_only | 1 / 3 / 31 |
| hero | Wisp | 34 | 99 | True | visible_sources_only | 1 / 3 / 32 |

Causes with no qualifying loss in these eight fights: Surface, Chain bounce.

Presentation source audit:

- Ordinary enemy attacks carry target-loss receipts into `_floating_texts_for_target_losses`; their actor/intent captions identify the move when the source is visible; Umbra may anonymize hidden sources. This includes Wisp shots and Skybreak. Fatigue uses the existing reshuffle/turn-start feedback; its stale damage context is not attributed to the previous enemy. The number and named cause are scheduled, with actual visibility unverified.
- Retaliate emits a dedicated `status_damage` step with label/trigger `Retaliate`; its loss number and named beat are scheduled. Fatigue also has a named number beat.
- Lightning Storm resolves at Overload's completion. `hero_loss_playback.gd` reconciles an unreceipted hero loss with the existing number/bar/hit reaction. That helper adds no cause label. The battlefield rule panel names Lightning Storm separately.
- That completion reconciliation is hero-only. Zekarion's own Lightning Storm loss has no equivalent actor-loss popup in the beat dispatcher; the committed state refresh updates his Health. No per-hit cause label is supplied there. This is a source-code finding, not a renderer observation.

The full per-event log records seed, hero turn, initiative clock, target, actual Health/Block loss, phase, route kind and causal context. Player card losses and voluntary movement hazards are excluded from the qualifying audit; enemy-turn surface/status losses and Retaliate remain eligible. No cause is inferred from timing alone.
