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
- Research agents: StS, ITB, Umbra inventory.

## Next actions
1. Gap audit doc + owner-facing artifact.
2. Wave 1 briefs.
