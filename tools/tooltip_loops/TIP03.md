# tip-03 round 3 handoff

Implementation and focused headless proof are complete except the documented
one-tile Lob Slag conflict. All changes are uncommitted. Native recording and
motion acceptance remain with the director; no windowed command was attempted.
The ten prior approved media files and sidecars have not been replaced here.
Splits has a registry entry/fixture and will acquire its asset from the native
recording command below. No art, copy, audio, icons or fonts were created.

## Numbered acceptance criteria

1. **Pacing:** removed the 90-frame floor. The recorder observes actual retained
   production poses, movement, numbers, deaths, surface feedback and VFX every
   frame. It keeps one contiguous window: at most 11 frames before first motion
   (allowing the next renderer submission to remain within 0.4 s), through one
   frame after the last visible action. It never skips internal beats, resamples
   frames or changes production animation timing. Raw trimming preserves every
   retained pixel and updates the frame header. Source and retained frame counts,
   front/tail trim, first motion, final action, observed numbers and crop checks
   are emitted to timing JSON and native provenance. Runtime hold 0.6 s,
   cross-fade 0.25 s and fade-in 0.12 s are unchanged. Re-record all eleven loops:
   Grub qualifies because rehearsal found 36 trailing idle frames (1.2 s).
2. **Lead-in:** the same contiguous trim removes nonmoving enemy lead-in before
   Icefall and Lob Slag's real casts. Both keep their complete cast animations
   at the already approved fast speed. Every rehearsal reports 0.367 s before
   first motion and 0.033 s settled tail; native rendering must confirm motion.
3. **Lob Slag:** starts before the real `lob_mark` beat, then walks and resolves
   the real landing. The recorder masks uncommitted intent forecasts so frame
   zero does not falsely look marked; committed `lob_tiles` remain visible.
   The hero's body bounds stay inside the fixed patch throughout rehearsal.
   **One tile is not achievable together with a real centered mark and no hit:**
   production Lob Slag marks a plus centered on the hero, including every legal
   orthogonal one-tile step. `TODO_DESIGN_lob_slag_one_tile` records this in the
   fixture. The closest no-hit implementation walks two tiles horizontally
   `(0,2) -> (2,2)` inside the patch. No rules or blast footprint were changed.
   The asynchronous design question has no answer at handoff.
4. **Charge:** fixed a production silent-loss path in both the cutout and
   fallback animators. They submitted resolved hop losses to the player-card
   popup queue while the enemy phase had no active player timeline; that queue
   discarded them. The new preloaded `chain_hit_feedback.gd` uses that timeline
   when active, otherwise submits the ordinary damage entries to CombatPacing's
   retained presentation. Rehearsals observe production `player:-6` and
   `enemy_2:-5`, with Charge reset to zero. The recorder blocks automatic
   at-rest forecast reconstruction after discharge while preserving real arcs,
   numbers and rig recovery, so the ending cannot repaint the stale purple 6/5
   over the settled numbers. The Capacitor's actual zero-Charge glow stays dark.
5. **Freeze:** fixture target starts Chilled at 30/30, hand Frozen Bite then
   Quick Stab. Production playback observes `-7`, then full `-18`; the target
   survives at 5 HP. Frozen rendering and all damage rules are unchanged.
6. **Lightning scope:** exact registry source is battlefield_rule /
   lightning_storm; battlefield_rule_hud passes that identity. Semantics cover
   the real HUD and reject enemy Skybreak and anonymous Lightning Strikes.
   All glossary/rule copy is unchanged. The old glossary sentence describes
   mark-then-electrify, whereas this rule strikes existing Electrified tiles
   and preserves them.
7. **Splits:** added a 1 HP Cinder Ooze Quick Stab fixture and source-owned
   registry row, using the existing fire/Cinder Crown floor and production
   death/spawn presentation. Semantic resolution proves two living Droplets on
   neighbouring tiles. Existing pre-battle/Details/intent/status tooltip routes
   use the spl-01 trait source; exact lowercase contextual wording resolves to
   its source-specific loop without broadening glossary case rules. Proof
   covers pre-battle outer, trait popup, interactive Details, intent routing,
   status plate and source glossary;
   native hover capture uses the same term matcher as production.

## Action seconds before -> after

Before is native sidecar duration, frozen with SHA256 in round3_baseline.json.
After is the final **headless rehearsal**, not a claim of new native media.
Wall-clock rehearsal can differ by a few frames; native fixed-FPS recording
writes authoritative durations and motion timing into each sidecar.

| Registry loop | Before s | Rehearsal after s | Speed |
| --- | ---: | ---: | --- |
| burst_ember_tick | 3.000 | 2.000 | normal |
| marked_burrow_grub | 4.833 | 3.267 | fast |
| chain_card | 3.000 | 2.067 | normal |
| collision_push | 3.000 | 1.433 | normal |
| retaliate_hollow_mimic | 3.000 | 1.233 | normal |
| charge_storm_capacitor | 3.000 | 2.300 | normal |
| lightning_strikes | 3.000 | 1.567 | normal |
| marked_icefall_seer | 3.267 | 2.967 | fast |
| marked_lob_slag | 3.367 | 3.100 | fast |
| freeze_status | 3.167 | 2.167 | normal |
| splits_cinder_ooze | new | 2.100 | normal |

The final rehearsal timing JSON files are under
`/private/tmp/labyrinth_codex/tip-03/round3-headless/<id>_timing.json`.

## Focused results observed

- `TIP01 SEMANTICS RESULT: PASS (0 failures)` (all registry fixtures; also
  repeated per loop in the final rehearsal).
- `TIP01 REHEARSAL RESULT: PASS (0 failures)` (all eleven, CEL_LOOK=all).
- `TIP01 TOOLTIP SEMANTICS: PASS (0 failures)` (including negative Skybreak,
  exact contextual Splits sentence, status plates, media control and cache).
- `SPL01 SEMANTICS: PASS (17 checks, 0 failures)` (`LABYRINTH_CEL_LOOK=all`).
- UI lint: `Ran 25 tests in 4.323s` / `OK`.
- Icon identity: `Ran 10 tests in 0.081s` / `OK`.
- Approved-content manifest: `Ran 1 test in 10.701s` / `OK`.
- `GLOSSARY TEST RESULT: PASS (6525 checks, 0 failures)`.
- `SHORT CARD TOOLTIPS TEST RESULT: PASS (767 checks, 0 failures)`.
- `FLOATING COMBAT TEXT TEST RESULT: PASS`.
- `COMBAT FEEL TEST RESULT: PASS`.
- `TIP03 CONTIGUOUS TRIM: PASS (all retained bytes; header/count; multi-chunk overlap; invalid bounds unchanged)`.
- `TIP03 PRIOR FOOTAGE: PASS (ten asset hashes preserved; native rerecord pending)`.
- `record.py --check-only`, `capture.py --check-only`: exit 0.
- Python AST/JSON parsing and `git diff --check`: exit 0.

Headless commands (all Godot calls use the mandatory task runner):

```sh
LABYRINTH_CEL_LOOK=all TIP01_OUT=/private/tmp/labyrinth_codex/tip-03/round3-headless python3 tools/godot_task_runner.py --task-id tip-03 --stream -- godot --headless --path . --script tools/tooltip_loops/record.gd -- --rehearsal
LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id tip-03 --stream -- godot --headless --path . --script tools/tooltip_loops/capture.gd -- --semantics-only
LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id tip-03 --stream -- godot --headless --path . --script tools/spl01/capture.gd
python3 tests/test_ui_identity_lint.py
python3 tests/test_approved_content_manifest.py
python3 tests/test_icon_identity_policy.py
python3 tools/godot_task_runner.py --task-id tip-03 --stream -- godot --headless --path . --script tests/glossary_test.gd
python3 tools/godot_task_runner.py --task-id tip-03 --stream -- godot --headless --path . --script tests/short_card_tooltips_test.gd
LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id tip-03 --stream -- godot --headless --path . --script tests/combat_feel_test.gd
python3 tools/godot_task_runner.py --task-id tip-03 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/tip-03/round3_codec_proof.gd
```

No new permanent tests or dependencies; no full suite or peer review. The
existing macOS sandbox CA-certificate message and glossary missing-definition /
intentional overflow warnings appeared, with the focused checks exiting zero.

## Proof for the design owner

Run in this order from this worktree:

```sh
python3 tools/tooltip_loops/record.py
python3 tools/tooltip_loops/capture.py
```

`record.py` forces CEL_LOOK=all, records all eleven through visual_probe_runner
at 1920x1080 / 100% UI scale, then applies the existing gated compressor and
installs media/sidecars only if all loops pass. It emits source-start,
source-first-motion and source-end PNGs, raw footage, per-loop timing JSON,
manifest and compression-report.json to
`/private/tmp/labyrinth_codex/tip-03/record/`. These source PNGs are explicitly
labelled as pre-trim source; compressed tooltip proof uses the retained footage.
All eleven registry rows enforce <=1,500,000 bytes.

`capture.py` uses two fresh native engines/HOMEs/caches: Freeze first, then last,
opening all eleven in their contexts and taking each middle-frame capture. It
requires new motion timing provenance, lead <=0.4 s, tail <=0.2 s, size cap,
matched no-loop vs cold-loop opening <=4 ms, playback >=20 fps, resident-memory
bound and ten-second monotonic release. It retains tip-01 start/end,
reduced-motion and outer-popup proof. It does not predecode or warm any stream.
The director's round-2 native acceptance (<=0.34 ms, ~30 fps, all freed) remains
historical; new acceptance must use the rerecorded files.

Outputs:

```text
/private/tmp/labyrinth_codex/tip-03/capture-round3/freeze-first/
/private/tmp/labyrinth_codex/tip-03/capture-round3/freeze-last/
```

Each has `<id>_middle_1920x1080.png`, measurements.json and
capture-manifest.json. No inspection_fixture command was requested this round.

## Files changed

- `assets/units/storm_capacitor_cutout/actions.gd`,
  `scripts/enemy_mechanics/capacitor_view.gd`, new
  `scripts/enemy_mechanics/chain_hit_feedback.gd` and UID: production hop numbers.
- `data/tooltip_loops.json`, `scripts/battlefield_rule_hud.gd`: Lightning source,
  Splits row, media caps.
- `scripts/pre_battle_inspection_view.gd`, `scripts/tooltip_loop_context.gd`:
  retain the Splits trait source and recognize its unchanged contextual wording.
- `tools/tooltip_loops/record.gd`, `record_board.gd`, `tip03_fixture.gd`:
  trim, frame observation, real marking/ending mask, fixtures and number/crop gates.
- `tools/tooltip_loops/capture.gd`, `capture.py`, `capture_checks.gd`,
  `tip03_context.gd`, `tip03_capture_contract.json`: all-eleven matched capture,
  source semantics, capture text matching, updated counts and provenance gates.
- `tools/tooltip_loops/compress.py`: docstring describing the retained window;
  codec, compression quality and error limits are unchanged.
- New `tools/tooltip_loops/round3_baseline.json`: immutable before audit.
- This handoff (`tools/tooltip_loops/TIP03.md`).

## TODO_DESIGN, chosen defaults and open issues

`TODO_DESIGN_lob_slag_one_tile` is the sole new design placeholder; its reason
and closest-intent two-tile script are described in criterion 3. Upheaval remains
deferred from prior rounds; no throw animation was invented.

No new player-facing values were chosen. Offline IO uses named `COPY_BYTES =
1 MiB`; the native watchdog is `CAPTURE_TIMEOUT_SECONDS = 180` for eleven
matched opens plus existing extra captures and expiry. The settled frame is
one 30-fps frame, inside the director's 0.2 s maximum; the lead frame limit is
derived from the director's 0.4 s maximum and one renderer boundary. The temporary
trim fixture uses named `SOURCE_FRAMES=12`, `FIRST=2`, `COUNT=9` and a task-local
output path. Lob's fallback destination is fixture-only and explicitly flagged
for the director. Native pixel/motion/compression/open/release proof is pending
because this worker has no window-server access.
