# art-04 — Put the approved perched gust shrike in the game (art-03 pipeline, one enemy) and make it canon

## Header
- Owner approved the maquette-painted, perched gust shrike on 2026-10-13 ("good enough to go with for now"; the
  raised-wing pose may be revisited later, so a future re-run with new sources must just work through the same data).
- Director data (protected; do not edit): `spec/peer_benchmark/staged/reart/approved_sources.json` (new `gust_shrike`
  entry: front `spec/art_identity/jobs/gust_shrike/mq2_front`, rear `.../mq2_rear`, `art_scale` 0.75, `sheet`
  `spec/art_identity/jobs/gust_shrike/sheet_pair_mq2.png`), `portrait_crops.json` (`gust_shrike: [70, 158, 84]`),
  `judge_log.md` (shrike section). Sources: each folder's `processed.png` + `processed.json` (both carry
  `post_steps`: palette_match + clean_outline) and `kit.json` (prompt paths point at
  `spec/art_identity/maquettes/gust_shrike_prompt_{front,rear}.md`; method = maquette paint-over); front landmarks in
  `mq2_front/landmarks_pair.json`.
- Base: `codex/peer-benchmark` (this worktree). Owned files: `assets/art/enemies/gust_shrike.png`, new
  `assets/art/enemies/gust_shrike_rear.png`, the shrike's turn-order portrait under `assets/art/portraits/`,
  `data/enemies.json` (gust_shrike presentation fields only), board-density registry/outputs/sources and the shadow cache
  (additive/replace for the shrike only), `spec/art_identity/registry.json`, `spec/art_identity/canon.json`,
  `tests/test_art_identity_gate.py` (only counts/ids that change because of the two new canon entries), any test that
  pins the shrike's old art digest, `tests/static_facing_probe.gd` only if it needs an enemy-id argument.
- Rules: presentation only — no gameplay, balance, analytics or rules changes; Windows typed-array rule; real-renderer
  proof via SubViewport 1920×1080 (never `root.get_texture()`); `TODO_DESIGN_<name>` only if something is impossible.
  Reuse art-03's tools and helpers; add no new pipeline code unless something in it hard-codes the 11 ids (then
  make it read `approved_sources.json`).

## Change
1. **Art + data**: exactly art-03 item 1 for gust_shrike: copy the approved front/rear `processed.png` to
   `assets/art/enemies/gust_shrike.png` / `gust_shrike_rear.png`, adopt through the board-density pipeline as untouched
   sources (expect `clean` mode), shadow cache, `--check`. `data/enemies.json` gust_shrike: `art_scale` 0.75 and
   `art_rear_path` `res://assets/art/enemies/gust_shrike_rear.png`. The directional static art policy from art-03 then
   applies unchanged (idle faces the player; front/front mirrored/rear/rear mirrored). Flying presentation (hover
   offset, shadow) stays exactly as it is today.
2. **Portrait**: art-03 item 3 for gust_shrike with crop `[70, 158, 84]`, same processor and 128×128 treatment.
3. **Registry**: replace the shrike's `pending_reart` entries with `kit` entries per art-03 item 4: kind creature,
   anatomy flyer, size_class small, art_scale 0.75, `sheet_path` `spec/art_identity/jobs/gust_shrike/sheet_pair_mq2.png`,
   `judge` {verdict PASS, date 2026-10-13, log judge_log.md}, `owner_approval` "approved 2026-10-13 (perched maquette
   review)", front `landmarks` from `mq2_front/landmarks_pair.json`, `post_steps` copied from processed.json, and a
   `method` note "maquette paint-over (spec/art_identity/maquettes/gust_shrike.py, perched)". `check` must then report
   `0 pending_reart warnings`.
4. **Canon**: add to `spec/art_identity/canon.json` `entries`, after the art-02 creatures:
   `{"id": "gust_shrike_front", "path": "assets/art/enemies/gust_shrike.png", "kind": "creature", "anatomy": "flyer",
   "size_class": "small", "view": "front", "note": "maquette paint-over, owner-approved 2026-10-13; the flyer reference"}`
   and the matching `gust_shrike_rear` (`assets/art/enemies/gust_shrike_rear.png`, `"view": "rear"`), plus a `revisions`
   entry `{"date": "2026-10-13", "change": "added gust_shrike front/rear (art-04) as the flyer reference", "added":
   ["gust_shrike_front", "gust_shrike_rear"]}`. Update test expectations that count canon ids (16 → 18) and confirm
   `kit` and `canon-sheet` accept the new entries.

## Proof
- Tests: `tests/test_art_identity_gate.py`; `art_identity_gate.py check`; density `--check`; `test_icon_identity_policy`;
  the en suites that include `air_shrikes` / gust_shrike; threats_at_rest; full suite (report runtime).
- Windowed (list exact commands; the director runs them): `tests/bestiary_lineup_probe.gd`; the static facing probe
  capturing gust_shrike idle at the hero's four diagonal sides (front, front mirrored, rear, rear mirrored); the
  turn-order clock with the shrike portrait visible; `art_identity_gate.py canon-sheet` for front and rear.
- Report changed files, result lines, and any test whose expectations changed with the reason.

## Out of scope
Any other enemy; the shrike's gameplay data; new wing poses; the gaoler maquette pilot (rr-02).
