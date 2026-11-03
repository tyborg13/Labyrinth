# bos-02 feedback 1 handoff

The director's cumulative ladders are applied and measured; all feedback changes remain uncommitted on `codex/bos-02`. Starting HEAD is `a9bb898ed3e3e4d8d6772c67701e2d7b34b1aebf`, containing committed Round 0 and int-06's baseline repairs. No Git publication, peer review or queue changes were performed.

## Results and scope

[Five ladder tables and the final six-dragon before/after table](measurement.md) include median turns/HP lost with P10–P90 and totals for beats, beat damage, half switches and lieutenant kills. Sixteen new cohorts / 800 fights use the unchanged meas-02 policy v2, revision 7, tier-3 deck and seeds 1–50. Each raw cohort is checked against its accepted Round 0 sample identities, decks and defaults. Iskaldra reuses its accepted unchanged 50-fight cohort.

| Dragon | Retained rung | Before → after | Retained cumulative changes |
|---|---:|---:|---|
| Tharokh | 3 | 72% → 58% | Claw 14; HP 72; Stonewake 6. Upheaval Health stays 4. |
| Vyraketh | 4 | 18% → 34% | Maw melee 8; Breath 6; HP 52; one boss-only Cinder Droplet. |
| Vaeloryx | 4 | 12% → 36% | Gale own Push 1; Dive 6; HP 50; one boss-only Gust Shrike. Eye ring stays 8. Rule wind stays 1→2. |
| Zekarion | 3 (last) | 22% → 28% | Skybreak 5; HP 54; Storm Lash 4. OUTSIDE 30–60%; no further authorized rung. |
| Noctyrax | 2 | 12% → 32% | Void Claw 10; HP 64. Starless Breath stays 8. |
| Iskaldra | 0 (decided) | 36% → 36% | Unchanged. |

Each ladder stops at its first in-band rung. Zekarion retains its last authorized rung. Normal helper definitions, all initiatives/times/openings, the six rule instances/panels and Iskaldra are unchanged. One-helper rosters use the existing first helper slot `(2,3)`; no placement code changed. `scope-validation.json` also proves each retained boss definition matches its measured input snapshot. `setup.json`, four wave snapshots and sixteen `rungs/*.json.gz` files preserve the inputs and full results. Beat damage uses the existing event's immediate HP delta; later Fire ticks remain outside that metric.

## Grimoire and copy checks

All nine owned `data/grimoire.json` bodies match the director's paragraphs exactly. Titles, ids, sections, icons and every unowned entry are preserved. Meteorfall's last two card paragraphs are unchanged. `tests/fixtures/bos02_feedback1_grimoire.json` records the verbatim approval; `copy-validation.json` maps each entry to rule/production witnesses. Every enemy entry contains its base in-fight panel sentence word for word. Existing ordinary immunity and movement limits remain, including Iskaldra's accepted Freeze immunity. No contradiction in the supplied nine bodies was observed under those accepted mechanics.

`TODO_DESIGN_DRAGON_GRIMOIRE_COPY` is resolved. A separate unowned definition, `data/glossary.json` / `gale_force`, still says **“Pushes everything within 2 tiles, then erupts along its last dive.”** Actual Hollow Gale has its radius-two body hit and Push 1; the Dive wake is removed. `TODO_DESIGN_HOLLOW_GALE_GLOSSARY_COPY` in `copy-findings.json` records this false old tooltip for the director. Its protected wording was not rewritten.

## Implementation and verification

- `data/enemies.json`: only selected director rungs on the five tuning dragons; boss-only helper-count overrides.
- `data/grimoire.json`: only the nine authorized bodies.
- `tools/dragon_rule_measurement.py`: optional per-boss cohorts, strict matched-sample validation and first-in-band ladder reporting. Policy/sampler/observer behavior is unchanged.
- Dragon tests protect the new damage, Push, helper counts and retained stats. New feedback tests cover exact copy/panels, base numbers, Outcrop occupancy and persistence, Gale's badge/unchanged wind, weaker Eye bite and Light protection.
- Grimoire probe covers exactly the nine revised pages, with a nine-image 1920×1080 contract; the stale removed-sweep copy assertion is deleted.
- `spec/card_balance_heuristic.md` and scorer descriptive metadata track the retained boss assumptions. All 309 full score rows and coefficients are unchanged.
- New Python tests write only unique test temporary directories; their `[]` resource declaration passes the 234-module audit.

[Exact result lines and log paths](verification.txt) cover all requested focused checks. All completed checks pass. Both full suites are deferred to the director's final round, as requested. The old Round 0 failure reports remain historical; int-06 is part of this round's starting HEAD.

## Proof for the design owner

No windowed runs or captures were attempted; this sandbox has no window server. The fight probe's 13 production states pass headless construction. The copy probe passes headless parsing. Run these at 1920×1080, 100% UI scale in the final round:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/visual_probe_runner.py --task-id bos-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/proof_contracts/dragon_element_rules.json --result-manifest /private/tmp/bos-02-feedback1-fights-proof.json tests/dragon_element_rules_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/visual_probe_runner.py --task-id bos-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/proof_contracts/dragon_feedback1_grimoire.json --result-manifest /private/tmp/bos-02-feedback1-grimoire-proof.json tests/dragon_pressure_grimoire_probe.gd
```

Expected fight images: `user://dragon_element_rules_probe/<dragon>_beat_warning.png`, `<dragon>_beat_result.png`, and `vaeloryx_half_health.png`. Grimoire pages: `user://probes/dragon_pressure_warnings/grimoire_<entry_id_with_underscore>.png`. The runners print the actual isolated absolute paths.

Playable normal-health inspection fixtures (no debug health or staged hand):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02
for dragon_id in vyraketh tharokh iskaldra vaeloryx zekarion
do
  python3 tools/inspection_fixture.py --task-id bos-02 --run-id "bos-02-feedback1-${dragon_id}" --scenario dragon --dragon-id "$dragon_id" --dragon-depth 4 --manifest "/private/tmp/bos-02-feedback1-${dragon_id}-fixture.json" --launch
done
python3 tools/inspection_fixture.py --task-id bos-02 --run-id bos-02-feedback1-noctyrax --scenario dragon --dragon-id noctyrax --dragon-depth 24 --manifest /private/tmp/bos-02-feedback1-noctyrax-fixture.json --launch
```

## Chosen defaults and open work

No gameplay default was chosen. Sampling worker counts 5/5/4/2 match the active ladders; the existing 7,200-second measurement timeout stays unchanged. The new copy-only occupancy witness uses named `COPY_STONE_ANCHOR=(3,3)` on the existing debug floor. Synthetic report tests use 15/30 wins out of 50 to check the supplied inclusive 30%/60% edges and write only temporary files. Existing proof defaults (seed 74123, 2,000-HP debug hero, 24-turn cap, 12 capture frames, elemental depth 4 / Noctyrax depth 24, 120-second capture timeout) are retained.

Open work is the director's Zekarion decision at 28%, the separate Hollow Gale glossary copy, final full suites and windowed inspection. No art, icons, fonts or audio were generated or changed.
