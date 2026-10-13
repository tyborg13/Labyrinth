# art-03 — Put the approved section-enemy art in the game (directional static art), portraits, registry, gate steps

## Header
- Owner approved the art-02 re-art of 11 section enemies on 2026-10-13 (all except gust_shrike, whose views are being
  rebuilt from a 3D maquette; leave its current art and its `pending_reart` registry entries untouched).
- Director data (protected): `spec/peer_benchmark/staged/reart/approved_sources.json` (front/rear source folders and
  art_scale per enemy), `portrait_crops.json`, `judge_log.md`; `spec/art_identity/bands.json` (new keys
  `creature.edge_light_share_max`, `rear_consistency`). Sources: each folder's `processed.png` + `processed.json`
  (some rears carry `post_steps`: palette_match / clean_outline, with prototypes in `spec/art_identity/prototype/`).
- Base: `codex/peer-benchmark` (director gives the commit). Owned files: `assets/art/enemies/<id>.png` and new
  `<id>_rear.png` for the 11, their portraits under `assets/art/portraits/`, `data/enemies.json` (only the 11 entries'
  presentation fields), the static-enemy draw path in `scripts/combat_board_view.gd` (plumbing only; put the facing
  choice in a new small helper, e.g. `scripts/static_enemy_facing.gd`), `scripts/cutout_context.gd` only if needed,
  board-density registry/outputs/sources and the shadow cache (additive/replace for these 11), `spec/art_identity/
  registry.json`, `tools/art_identity_gate.py`, `tests/test_art_identity_gate.py`, `tests/run_tests.gd` (suite
  registration, item 6), new tests/probe `tests/static_facing_*`, `spec/visual_identity_gate.md` (Commands section),
  `spec/assets/...` density docs if they enumerate files.
- Rules: presentation only — no gameplay, balance, analytics or rules changes; Windows typed-array rule; real-renderer
  proof via SubViewport 1920×1080 (never `root.get_texture()`); `TODO_DESIGN_<name>` only if something is impossible.

## Change
1. **Art files**: copy each approved front `processed.png` to `assets/art/enemies/<id>.png` (replacing the old
   painting) and each rear to `assets/art/enemies/<id>_rear.png`. Adopt them through the board-density pipeline as
   untouched sources (`process_board_density.py --adopt`, then process, `--record-rests` if applicable, shadow cache,
   `--check`) following the existing rule; they are already at hero density, so expect `clean` mode. Update
   `data/enemies.json`: `art_scale` from approved_sources.json, new `art_rear_path` (omit for storm_capacitor).
2. **Directional static art** (enemies with `art_rear_path`): pick the texture with the same policy as directional
   enemy cutouts (`scripts/enemy_cutout_facing.gd`): idle faces the closest of the four directions toward the player
   (front, front mirrored, rear, rear mirrored; mirrored = horizontal flip about the logical rect's centre), updated
   after movement completes including when only the player moved; moves and attacks face their own direction for the
   action; death keeps the facing it had. Reduced motion uses the same policy with still art. The front art faces the
   board's lower-left, exactly like cutout fronts. storm_capacitor (object, no rear) never turns or flips. Health bars,
   chips, discs, tooltips, obstruction and shadows keep using the logical rect; the cached shadow silhouette follows
   the drawn texture (front/rear, flipped when mirrored) if the cache supports per-facing silhouettes, otherwise the
   front silhouette — state which.
3. **Portraits** (turn-order clock, 128×128): crop each approved front with `portrait_crops.json` ([centre_x,
   centre_y, side] in canvas px), resize to 128 with the existing portrait treatment used by the en-01..06 portraits
   (same processor), replace the 11 portrait files. Output a contact sheet of the 11 new portraits at 2× next to the
   current ones for the director.
4. **Registry**: replace the `pending_reart` entries of the 11 (front and rear paths) with `kit` entries per
   `spec/art_identity/README.md`: job id, kit path, prompt path, `sheet_path` (the job's `sheet_pair.png`, or the
   front `sheet.png` for storm_capacitor), kit_version, raw sha256 (from processed.json), `source_pixel_sha256` (the
   approved processed.png) and `pixel_sha256` (the production file after density treatment), kind/anatomy/size class,
   `judge` {verdict: PASS, date: 2026-10-13, log: judge_log.md}, `owner_approval` "approved 2026-10-13 (art-02
   review)", front `landmarks` (from the job's landmarks.json), and `post_steps` copied from processed.json. `check`
   must verify `source_pixel_sha256` against the approved processed.png and `pixel_sha256` against the production
   file. gust_shrike stays `pending_reart`.
5. **Gate steps and metrics** (`tools/art_identity_gate.py`):
   - `process ... --match-front FRONT_PROCESSED` and `--clean-outline`: port `prototype/match_palette.py` (Reinhard
     mean/std in CIE Lab over opaque non-accent pixels, accent = chroma > p90 + 15, near-black key residue stripped)
     and `prototype/clean_outline.py` (edge pixels above 0.2 luminance take tone (20,16,21); isolated pixels removed)
     as deterministic steps applied after placement, recorded in the sidecar `post_steps` with parameters and the
     pre-step digest. Regression: the prototypes and the new steps produce identical pixels on fixtures.
   - New metric `edge_light_share` (share of silhouette-edge pixels with Rec.601 luminance > 0.2), band
     `creature.edge_light_share_max` for kit entries and sheets.
   - `rear_consistency`: for a kit creature with both views, |Δchroma| and |Δvalue| between front and rear processed
     sprites ≤ the bands; shown on pair sheets and enforced by `check`.
   - `kit --subject-rear FILE`: optional rear-specific subject (recorded in kit.json and the prompt).
6. **Suite registration**: add the en04/en05/en06 enemy suites to the full suite like en01..03; keep the full-suite
   runtime under 900 s and report it.

## Proof
- Tests: gate tests incl. the new steps/metrics; `check` report (expect only gust_shrike's pending entries); density
  `--check`; icon test; en01..06 suites; threats_at_rest; full suite.
- Windowed probes (list the commands; the director runs them): `tests/bestiary_lineup_probe.gd` (all enemies with the
  new art); a new `tests/static_facing_probe.gd` capturing arc_thrall and slag_mortar idle at the hero's four
  diagonal sides (4 captures each: front, front mirrored, rear, rear mirrored) plus one mid-move frame and one
  reduced-motion frame; the turn-order clock with three new portraits visible.
