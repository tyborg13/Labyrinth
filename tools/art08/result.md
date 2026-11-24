# art-08 Burrow Grub mound

Low-risk presentation change on `codex/art-08`. The before run used a read-only Git archive of `3c27b676d`. The after run used this worktree.

## Fix round 1

The dimming between 04 and 01/02 came from the capture probe. After saving 04, `mound_check.gd` set its test tint and `death_progress = 0.25` on the live retained Grub dictionary. The idle stills then used the test's RGB multipliers `(0.6, 0.7, 0.8)` and alpha `0.8 × (1 - 0.25) = 0.60`. The check now uses a copy. The current probe checks for a white, opaque submission before recording each mound sample. Both headless runs reported zero local lights, canvas alpha `1.0000`, and the shared world material at all four samples. Ambient stayed fixed within each fight at `0.7007` in the launcher run and `0.7469` in the final after-only run.

`burrow_view.gd` now passes `CombatArtTreatment.actor_profile` explicitly. The cel inventory already discovered the PNG. It now classifies that entry as `actor` in `actors` scope with `burrow_grub/front` defaults and keeps the mound paint as its own fitting source. The standard builder regenerated the variant. The current Grub and approved sheet use the same default filter settings. The approved PNG, placement, breath and death-alpha math retain their authored values.

```text
ART-08 PROFILE 04_after_burrow mound=ACTOR(4) live_grub=ACTOR(4) lights=0 ambient=0.7007 flicker=[] canvas_alpha=1.0000 shared_material=true
ART-08 PROFILE 01_burrowed_peak mound=ACTOR(4) live_grub=ACTOR(4) lights=0 ambient=0.7007 flicker=[] canvas_alpha=1.0000 shared_material=true
ART-08 PROFILE 02_burrowed_trough mound=ACTOR(4) live_grub=ACTOR(4) lights=0 ambient=0.7007 flicker=[] canvas_alpha=1.0000 shared_material=true
ART-08 PROFILE 06_erupt_contact erupt=ACTOR(4) live_grub=ACTOR(4) lights=0 ambient=0.7007 flicker=[] canvas_alpha=1.0000 shared_material=true
```

The art gate reported `Ran 111 tests in 91.247s` and `OK`. The strict entry check reported `ART IDENTITY CHECK: PASS (0 failures, 0 pending_reart warnings, 0 skipped replays)`. The director's canonical job filenames resolved the original certification failure recorded below. All four changed GDScripts passed task-runner parsing. Focused checks reported `EN01 ENEMIES TEST RESULT: PASS`, `MRK01 MARKED TEST: PASS (69 checks, 0 failures)`, and `MAQUETTE PRODUCTION LOGIC: PASS (1106 frames)`. The headless launcher preserved 301 Burrow and 339 Erupt samples against the pinned base. The luma arithmetic check recovered the known 111.00 sprite and 42.00 floor values from an in-memory fixture with unit and UI exclusions.

The launcher command is unchanged. After the native rerun, use the second command to read the PNGs, saved sprite geometry and live Erupt alpha mask.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/art-08 && /private/tmp/labyrinth_codex/art-08/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/art-08 && python3 tools/art08/luma.py
```

The luma report uses Rec. 709 weights on captured 8-bit RGB. It samples opaque sprite pixels and the eight tiles surrounding the subject. It excludes projected unit alpha and HUD bounds from floor samples, with two pixels of padding for existing actor outlines. The director's earlier images predate the measurement masks. New native luma readings and visual acceptance are pending.

## Original implementation handoff

## Requirements

1. `assets/art/enemies/burrow_mound.png` uses the board-density `clean` step at grid `1.0`, with no frames or resampling. The same invocation on the approved Storm Capacitor source reproduced its production pixel hash before it was applied to the mound. The mound retains the approved 255 × 255 canvas and the exact source alpha mask. The lossless Godot import has mipmaps disabled. In Godot 4, filtering is set on the drawn `CanvasTexture`. The mound explicitly selects nearest.
2. The registry binds the director's take 3, its prompt, the reference hashes, the judgment, and the pending owner approval. The sole metric exception is its 53 px drawn height. The certification gate hard-codes `processed.png` and `processed.json` beside the kit. The registry points to the protected `processed_3.png` and reports the mismatch. A scratch diagnostic with canonical filenames passed unchanged gate validation.
3. The board uses the review-sheet registration at source coordinates (128, 246), at the hero's source-pixel density and art scale 1.0. The standard cel builder discovers the production PNG and uses the same default look settings as the object sheet. The existing world-prop draw path takes the unit tint and multiplies its alpha by `1 - death_progress`.
4. At 375 ms, 1125 ms and reduced motion the sprite drew at vertical scales 1.03, 0.97 and 1.00. All three used the same horizontal scale and opaque base line.
5. The body ellipse, rim, specks and eruption dust drawing are gone. `MOUND_TILE_HEIGHT` is still called by the board's HUD placement. `DUST_SECONDS` is still read by the protected rig adapter, and `DUST_PARTICLE_DIAMETER` is still read by the stock EN01 probe. The diameter reports zero. The adapter and existing proof tools still exchange `en01_erupt_dust`.
6. The before and after traces matched for all sampled active poses, timings, tiles, HP, burrowed states and surface feedback. The terminal Burrow sample already carries the burrowed state in the base. The rig reaches alpha zero on that sample. The mound route is active on that frame and the first post-clip sample in both revisions. The fallback Erupt still clips the rising static texture to its original floor line. The pinned revision contains no file named `resolved_contact_bursts.gd`. The existing Erupt surface feedback is present at contact and at contact +233 ms in both traces.

## Verification

| Check | Observed result |
| --- | --- |
| `art_identity_gate.py check --id burrow_mound --strict` | `ART IDENTITY CHECK: FAIL (1 failures, 0 pending_reart warnings, 0 skipped replays)` |
| `art_identity_gate.py check` | `ART IDENTITY CHECK: FAIL (1 failures, 0 pending_reart warnings, 0 skipped replays)` |
| `python3 tests/test_art_identity_gate.py` | `Ran 111 tests in 86.805s` and `FAILED (failures=1)`. The registry integration test found the same source filename mismatch. |
| Scratch canonical filenames | `ART-08 CANONICAL-FILENAME DIAGNOSTIC: PASS (0 failures, 0 warnings; approved bytes copied only to scratch)` |
| Godot parser | Exit 0 for `burrow_view.gd`, `combat_board_view.gd`, the three proof scripts, the rig adapter, and the stock EN01 visual probe |
| `tests/en01_enemies_test.gd` | `EN01 HEADLESS DRAW BRANCHES: executed; no renderer capture` and `EN01 ENEMIES TEST RESULT: PASS`. The dummy-renderer `Parameter "t" is null.` diagnostic also appeared on the base. |
| `tests/mrk01_marked_test.gd` | `MRK01 MARKED TEST: PASS (69 checks, 0 failures)` |
| `tests/rr12/production_capture.gd -- --type burrow_grub --logic-only` | `MAQUETTE PRODUCTION LOGIC: PASS (1106 frames)` |
| Headless native-launcher dry-run | `ART-08 HEADLESS: PASS` on both still runs and the reel run. `ART-08 BASE PARITY burrow: PASS (301 samples, including root alpha, poses, timing and combat state)`. `ART-08 BASE PARITY erupt: PASS (339 samples, including root alpha, poses, timing and combat state)`. `ART-08 REEL: 360 frames scheduled at 60 fps`. |
| Python default group | `Ran 196 tests in 30.367s` and `FAILED (failures=2)`. The tests named the pending production asset in `tests/approved_asset_pins.json` and 12 previously missing tracked sidecars. Nine are from the director's job commit and three are `tools/qa131` UIDs inherited from the base. The optional timing cache write was denied by the Git sandbox. |
| Shell and diff | `bash -n tools/art08/native.sh` and `git diff --check` exited 0. |

Both gate commands reported the following line. The protected job files and certification rules retain their supplied values.

```text
FAIL assets/art/enemies/burrow_mound.png: source path is not the job processed sprite; recipe: [Errno 2] No such file or directory: '/Users/borgerding/workspace/Labyrinth.worktrees/art-08/spec/art_identity/jobs/burrow_mound/front/processed.json'
```

Headless draw output from the real fight:

```text
ART-08 MOUND t=375ms reduced=false rect=[P: (774.0947, 229.6096), S: (188.417, 194.0695)] base_y=416.8296 scale=1.0300 hero_px=0.7389
ART-08 MOUND t=1125ms reduced=false rect=[P: (774.0947, 240.5156), S: (188.417, 182.7645)] base_y=416.8296 scale=0.9700 hero_px=0.7389
ART-08 MOUND t=375ms reduced=true rect=[P: (774.0947, 235.0626), S: (188.417, 188.417)] base_y=416.8296 scale=1.0000 hero_px=0.7389
ART-08 DRAW: mound and erupt each submit one texture. No circle, polyline, ellipse or dust calls in the body draw path.
```

Full logs are in [art-08](/private/tmp/labyrinth_codex/art-08). The [before](/private/tmp/labyrinth_codex/art-08/dry-run/before/frames.json), [after](/private/tmp/labyrinth_codex/art-08/dry-run/after/frames.json) and [reel](/private/tmp/labyrinth_codex/art-08/dry-run/reel/frames.json) trace files were written headlessly.

## Frame table

Time is relative to the current clip except for the idle breath samples. These are the windowed filenames printed by the dry-run.

| Frame stem | Time or phase | Tile | Image |
| --- | --- | --- | --- |
| `01_burrowed_peak` | 375 ms of the breath cycle | (3, 4) | 640 × 640 |
| `02_burrowed_trough` | 1125 ms of the breath cycle | (3, 4) | 640 × 640 |
| `03_burrow_last` | 0.986667 s, phase 1.0, alpha 0 | (3, 4) | 640 × 640 |
| `04_after_burrow` | 1.003333 s, first submission after the clip | (3, 4) | 640 × 640 |
| `05_erupt_start` | 0.000000 s, phase 0.0 | (4, 4) | 640 × 640 |
| `06_erupt_contact` | 0.350000 s, phase 0.35 | (4, 4) | 640 × 640 |
| `07_erupt_contact_plus_233ms` | 0.583333 s, first 300 Hz sample at or after contact +233 ms | (4, 4) | 640 × 640 |
| `08_burrowed_full` | Same peak as frame 01 | (3, 4) | 1920 × 1080 |

## Proof for the design owner

Run the native launcher on the windowed Mac from the art-08 worktree.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/art-08 && /private/tmp/labyrinth_codex/art-08/native.sh
```

It uses `visual_probe_runner.py` to write the eight PNGs and a proof manifest to each of `/private/tmp/labyrinth_codex/art-08/native/before` and `/private/tmp/labyrinth_codex/art-08/native/after`. The reel path is `/private/tmp/labyrinth_codex/art-08/native/burrow-erupt.mp4`. The reel uses 1920 × 1080 SubViewport frames and MovieWriter audio. The sandbox supports the headless dry-run. Native pixels, the muxed reel and owner approval are pending.

## Chosen defaults

- Proof encounter uses the existing EN01 seed and hero tile (4, 4). The Grub starts at (3, 4) to place it next to the hero.
- The stills inherit the existing proof clock at 300 Hz. The two breath samples target the cycle extrema. Windowed idle capture takes the first refresh at or after each target.
- The six-second reel requests Burrow on frame 24 and Erupt on frame 216. A 64 × 64 MovieWriter window supplies the capture clock and audio.
- The draw probe uses modulate `Color(0.6, 0.7, 0.8, 0.8)`, death progress 0.25 and the static rise midpoint. Its static texture substitute allows floor measurement through the dummy renderer.
- Native runner timeouts are 180 seconds per still sequence and 360 seconds for capture of the reel.

## Registry entry

```json
{
  "anatomy": "plinth",
  "art_scale": 1.0,
  "entry_kind": "kit",
  "exceptions": [
    {
      "metric": "height_drawn",
      "reason": "Low ground mound by design. The standing-prop band is 120–180.",
      "value": 53.0
    }
  ],
  "facing": "front",
  "id": "burrow_mound",
  "job_id": "id-burrow_mound-object_plinth",
  "judge": {
    "date": "2026-11-23",
    "log": "spec/art_identity/jobs/burrow_mound/front/judge_3.md",
    "verdict": "PASS"
  },
  "kind": "object",
  "kit_path": "spec/art_identity/jobs/burrow_mound/front/kit.json",
  "kit_version": "6a6788b05d32baefca5dd16e119b2b0792f6730f1538393355da1e994ba96d3c",
  "owner_approval": "pending (art-08 inbox capture)",
  "path": "assets/art/enemies/burrow_mound.png",
  "pixel_sha256": "7570b45fdb45f03498bc3102e8d799c71dae977967bcf6a09c86ef9f2fccccc8",
  "post_steps": [],
  "prompt_path": "spec/art_identity/jobs/burrow_mound/front/prompt.md",
  "prompt_sha256": "1d5e649112570bdd47f504e33ac348c58fc5e64a71427c3a73c03b41f85dd03f",
  "raw_path": "spec/art_identity/jobs/burrow_mound/front/raw_3.png",
  "raw_pixel_sha256": "0901a4bd293f4dd1d56a3936392391f71020aaa9791b9680ce6a6101bcbf8af7",
  "raw_sha256": "b25a3f399c1494dada26297904fcdc57f425a0b1e74e37f8da9e2e9d45f7efbb",
  "ref_pixel_sha256": {
    "refs/01_hero_front.png": "8780544b7e60c42bd96c63aea71d22fc400dd9e159316be54cc994cc1a31fa2f",
    "refs/02_crag_outcrop.png": "ce89fbecf29db98f5e6aee90a50bdca51ee205f455d9963356b96e67218d2838",
    "refs/03_raised_cover.png": "3a9ab5a799e75f41031833ac9a4d88d57a67e09d3455c72a37ed249c356741ae",
    "refs/footprint_guide.png": "b3795573189691d7e095915504fb1e3f95bffbee4e524f65a569cbab345ffc0f"
  },
  "sheet_path": "spec/art_identity/jobs/burrow_mound/front/sheet_3.png",
  "size_class": "small",
  "source_path": "spec/art_identity/jobs/burrow_mound/front/processed_3.png",
  "source_pixel_sha256": "faeb74f8568aa74de3c528ce578aef50c35c44f0045aedd5420dba7dfd799bfa"
}
```

No `TODO_DESIGN_*` placeholders. All changes are uncommitted.
