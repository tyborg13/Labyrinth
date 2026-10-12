# Peer-benchmark program — STATUS

Goal (owner, 2026-10-12): raise every facet of Escape the Umbra to the bar of Slay the Spire and
Into the Breach — visual cohesion/identity/fidelity, playability, mechanics, board + UI animation,
sound, content completeness (room types, events, map branching), card/enemy design, level gen.
Experimental: owner may cherry-pick or revert. Bold changes allowed; prior Codex-era approvals are
not binding. Claude directs (all taste), Codex implements (orchestrate-codex skill).

## Layout
- Integration branch: `codex/peer-benchmark` at `../Labyrinth.worktrees/peer-benchmark` (base master 816f5e68a).
  Units branch from it (`CU new <id> --base codex/peer-benchmark`) and merge back after review.
  Nothing is pushed or landed on master without explicit owner approval.
- Capture worktree (detached, local only): `../Labyrinth.worktrees/peer-benchmark-capture`
  = integration + trailer tooling 006c2ccec (unlanded branch), for clips via tools/trailer_director.
- Media for the owner: `Labyrinth/output/peer-benchmark-2026-10-12/` (primary checkout, untracked).
- Research: `Labyrinth/output/benchmark-research-2026-10-12/` (StS, ITB, Umbra inventory).

## Milestone
M0 — research + gap audit (in progress).

## In flight
- Codex: ev-01 (event engine), map-01 (map v2). Watchdog: `cu watch` background.
- Research agents: StS, ITB (pending); SFX sourcing agent → output/sfx-sources-2026-10-12/ (owner approved CC0/free-commercial downloads).
- Done: Umbra inventory (spec/peer_benchmark/umbra_inventory.md).

## Next actions
1. Event art: 27 image runs (pixel-painterly like card art, ragged dark vignette; native ~480x320 shown 2x).
2. ev-02: illustrated event view + omen HUD (needs mockup).
3. feel-01: hit-stop, impact flash, enemy-turn pacing, combat speed setting.
4. sfx-01: data-driven SFX cue bank + call sites (after sourcing).
5. Gap audit artifact for the owner (after research lands).
6. Follow-up after ev-01+map-01 merge: reveal effect = scout mystery rooms in layout rev 4.
- Plan page (artifact): https://claude.ai/artifact/N1G8qgbt58t6CbufwQxq5d — source output/peer-benchmark-2026-10-12/plan_page/ (plan_template.html → index.html via inline-font build snippet)
