# sd-17 — preparation complete; native proof pending

Nothing shipped. Repository files and tests are unchanged; Git status is clean on `codex/sd-17`. No commit, Git write, peer review, full suite or windowed attempt occurred.

**A / B:** `tools/prepare.py` builds a private project with Deck-only `SD17_DECK_SCALE_125` and `SD17_DECK_TEXT_FLOOR` flags. A changes only the Deck default to 125%. B retains 115%, floors native control/BBCode and custom-drawn font sizes to 16 for the snapshots, and checks that visible container rectangles stay unchanged. No fit repairs. Existing approved cel assets/imports are reused; no assets were created or changed.

**1 — measurements:** sd-16's TextServer smallest-letter/digit metric, eleven fixed sweep states (not its entire 1,871-candidate route inventory):

| Candidate | Text instances | Minimum px | <9 px | <12 px | New geometric candidates |
|---|---:|---:|---:|---:|---:|
| Control, 115% | 567 | 6.110 | 197 | 413 | — |
| A, 125% | 567 | 6.106 | 99 | 381 | 185 |
| B, 115% / floor 16 | 559 | 6.110 | 147 | 406 | 101 |

540 instances match across all three; missing/extra texts are reported separately. Full and matched counts, per-screen tables and every detected new geometry candidate are in `comparison-headless/`. B's candidates: 84 allocation overflows, 5 clipping bounds and 12 text-bound overlaps. A's: 185 text-bound overlaps. These require native inspection; whitespace, intentional scrolling, opaque occlusion, custom draw transforms and RichText inline spans limit automatic classification.

**2 — captures/proof:** all eleven requested screens, including separate hand/hover and Gear/Skills, have native 1280×800 cel-on commands and strict contracts in `native-{control,A,B}/`. **Zero native PNGs or actual contact sheets exist yet** because this worker has no window-server access. The contact-sheet generator is verified with isolated historical-image fixtures. Native runs will produce `native-*/<screen>.png`, `comparison-native/` and eleven `contact-sheets/<screen>.png` triptychs (control / A / B).

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/sd-17 && python3 /private/tmp/labyrinth_codex/sd-17/tools/proof.py all --run
cd /Users/borgerding/workspace/Labyrinth.worktrees/sd-17 && python3 /private/tmp/labyrinth_codex/sd-17/tools/compare.py --mode native --contact-sheets
```

Expanded commands, screen filenames and the inspection-fixture not-applicable reason: `proof-commands.md`. Inspect all native captures and geometry candidates before deciding between fixes.

**Observed checks:**

```text
SD17 PREPARE: PASS (15 private script copies patched; 51 draw sites; 3076 approved cel variants)
SD17 SCREENS: PASS (11 screens; 0 findings; scale 1.15)  [control]
SD17 SCREENS: PASS (11 screens; 0 findings; scale 1.25)  [A]
SD17 SCREENS: PASS (11 screens; 0 findings; scale 1.15)  [B]
SD17 FLAGS: PASS (platform guards; A default; B below/at/above 16)
SD17 PREPARATION CHECK: PASS (559 matched B sizes; 11 unchanged container snapshots; source hashes intact)
SD17 SHEET TOOL CHECK: PASS (11 historical-image fixtures; native pixels preserved; temporary outputs removed)
SD17 PROOF CONTRACTS: PASS (control/A/B; 11 required native images each; 1280x800)
SD17 COMPARE: PASS (headless; 540 common text instances; 286 new geometric candidates)
```

`python3 tests/test_ui_identity_lint.py`: `Ran 25 tests in 6.656s` / `OK`. Resource audit only: `ISOLATION AUDIT: 56 modules`; no new test module or registration change. Headless logs contain the host's `get_system_ca_certificates` notice; all final runners exited 0. Screen-run logs are `headless-*/runner.log`.

**Files:** nine tools under `tools/` (`prepare.py`, `candidate.gd`, `screens.gd`, `text_snapshot.gd`, `draw_metrics.gd`, `proof.py`, `compare.py`, `verify.py`, `check_flags.gd`); private `project/`; generated reports/contracts; this report, `proof-commands.md`, `chosen-defaults.json`.

**TODO_DESIGN:** none. **Chosen defaults:** proof-only 3-frame snapshots, 300-second runner caps, 0.5 px geometry tolerance, 28 px sheet headings and 1280 px overview; inherited sweep seed/state, reduced motion, timing and luma checks are itemized in `chosen-defaults.json`. Native captures retain their original pixels. **Open:** native captures/contact sheets and visible collision classification remain for the design owner; no decision or fix is approved by headless measurements.
