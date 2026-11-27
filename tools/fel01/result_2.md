# fel-01 round 2

Repackaged 12 checkpoints from the same 72 retained states. The cohort contains nine normal fights, one objective fight, and two dragon fights. Tharokh and Zekarion each appear once. The highest Guardian score was 16 and the lowest selected score was 18. [Full census and rule checks](census.md)

## Scoring and selection

The packager recalculated the stack count from recorded tile contents. A tile counts when it has at least two contents and at least one of them is a unit or board object. Floor-only stacks accounted for 194 discarded stack points across the retained states. The original covered-tile and covered-unit counts feed the new formula of three points per covered unit, one per covered tile, and one per qualifying stack. Each fixture records adjacent `old_score` and `new_score` fields.

The selector maximizes the summed new score under the round-2 caps. Equal totals favor more living enemies on the board, then more visible pillars. The candidate probe read the living enemy count and the encounter's boss or Guardian ID after production Continue. It counted visible pillars from the board's resting draw sources. The source campaign reached all four fight kinds. Three retained turns still lacked a playable targeted card, leaving 69 eligible checkpoints. [Seed 1 screen](/private/tmp/labyrinth_codex/fel01-round2-screen-1.log) · [Seed 8 screen](/private/tmp/labyrinth_codex/fel01-round2-screen-2.log) · [Seed 12 screen](/private/tmp/labyrinth_codex/fel01-round2-screen-3.log)

The section distribution in campaign order is 3, 2, 3, 2, 2, and 0. Save, profile, and witness files matched their source bytes for all 12. The round-1 cohort and census are backed up in `/private/tmp/labyrinth_codex/fel01-round2-round1-backup/`. The 48 round-1 PNGs remain in `tools/fel01/captures/native.Fb0fcp/`.

## Proof

The rank check exercised piece versus floor-only stacks, the three-point unit weight, both tie-breaks, and a brute-force comparison on a small overlapping set of fights and bosses. It then checked the actual cohort against the limits and source files. [Rank and package audit](/private/tmp/labyrinth_codex/fel01-round2-rank.log)

```text
FEL01 RANK PASS piece stacks, three-point covered units, enemy and pillar ties, exhaustive cap check
FEL01 COHORT PASS candidates=72 eligible=69 selected=12 unique_fights=12 bosses=2 normal_or_objective=10 max_per_section=3 source_matches=12
FEL01 SCORE PASS new_total=258 old_total=257 excluded_floor_stacks=194 boss_ids=tharokh,zekarion
```

The dry run passed all 12 rest, hover fade, and card targeting phases. Four recorded hover tiles were outside the selected card's legal target set. The separate witness run compared all 12 saves after Continue. [Dry-run log](/private/tmp/labyrinth_codex/fel01-round2-dry.log) · [Witness log](/private/tmp/labyrinth_codex/fel01-round2-witness.log)

```text
FEL01 DRY RUN PASS states=12
FEL01 WITNESS PASS states=12
```

The Python default group returned `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 37.876s`, and `OK`. Rules text returned `PASS: Rules text lint (16 existing hits)`. The runner reported `Operation not permitted` on its Git timing-cache write after the tests. Godot reported the macOS system CA startup error and both proof runs exited 0. [Python default log](/private/tmp/labyrinth_codex/fel01-round2-python-default.log)

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-01 && tools/fel01/native.sh
```

The existing native wait remains in place. Round-2 native captures are pending. All changes are uncommitted under `tools/fel01/`.
