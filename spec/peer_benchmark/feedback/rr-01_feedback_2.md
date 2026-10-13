# rr-01 feedback 2 (director, after peer review of b0bcbcb88)

The director already ran the windowed continuation (rebake → record-rests → cache → record/check-crawler → density
check → gate check → prepare-proof → both probes: all PASS), committed it as b0bcbcb88 and merged the integration
branch (4c7ff2d1a). Work on top of HEAD. Do not commit. No windowed runs are needed unless item 6 changes a rest.

Fix all of these:
1. **Enforce the replay check in tests.** Add a real-repo test (not mocked) to `tests/test_recolour_lab.py` that runs
   the same verification as `--check-crawler --baseline-ref 2cf00ab4ece2f27a590f0bde5d5fb2fecacbd283` and fails on any
   mismatch. Make `--in-place` refuse any path in `CRAWLER_DIRECT_PATHS` or under the crawler density sources (they are
   already recoloured; a second pass must be impossible without an explicit `--force-rerecolour` flag that the README
   never shows). Test both refusals.
2. **README (`spec/art_identity/README.md`)**: rewrite the rr-01 section as reference for the finished state: no
   "pending"/"uncertified"/"continuation" language, no worker-to-owner narrative, no absolute paths (`cd` into a
   worktree, `/private/tmp/...`); commands run from the repo root. Mark the transform commands as an applied historical
   record that must not be re-run (and say the tool now refuses). Fix line 4's "do not change game data" so it no
   longer contradicts the section below it. Keep it under ~35 lines.
3. **Regenerate** `spec/assets/board_pixel_density/report.md` with `python3 tools/process_board_density.py --report`.
4. **Registry truthfulness (`spec/art_identity/registry.json`)**: on the two crawler rest entries, replace the
   `post_steps` (which do not replay to their digests) with a `derivation` list recording the real chain: Lab recolour
   of the density sources (L×0.76, ab×0.85) → density regrid at grid 1.73 → native rest rebake (`tools/rebake_cutout_rests.gd`).
   Keep `post_steps` only on the static fallback, which replays exactly. Add a `metrics_note` to all three crawler
   entries: adoption metrics are pre-recolour by design. Write the registry with the gate's `write_json` (sorted keys),
   not `json.dumps`, so key order matches every other entry. Make sure `art_identity_gate.py check` and the replay check
   still pass and the gate tests still pass.
5. **No git-history dependency in the density tool**: commit the two pre-recolour source rests as digest-bound
   calibration fixtures (e.g. `spec/assets/board_pixel_density/calibration/crawler_{front,rear}_pre_recolour.png`) and make
   `calibration_baseline` reference those files plus their decoded pixel digests instead of `git show <commit>:…`.
   Fail closed if a fixture is missing or its digest differs. Keep the commit hash as provenance text only.
6. **Portrait (director decision)**: the turn-order portrait must be the builder's exact crop of the shipped front rest,
   as `tools/build_turn_order_assets.gd` defines it. Regenerate only `assets/art/portraits/tunnel_crawler.png` with that
   builder (crawler only; do not touch other portraits), and change the replay check to verify the portrait against the
   builder's crop of the current rest instead of a recolour of the old portrait. If the builder cannot run headless,
   leave the portrait as is, report it, and list the exact command for the director.
7. **Shadow cache**: drop the added rear-rest entry (runtime shadows use the front rest's alpha only). If the official
   cache generator can produce the cache headless, use it instead of `rr01_refresh_shadow_cache.gd` and delete that
   script; otherwise make the script's PASS line honest (say "unrelated records preserved" only when the comparison
   actually ran) and remove its dependency on untracked `output/rr-01/before`.

Proof: run `test_recolour_lab`, `test_board_pixel_density`, `test_art_identity_gate`, `test_cutout_workflow`,
`test_icon_identity_policy`, `process_board_density.py --check`, `art_identity_gate.py check`, the crawler replay check,
and the Godot crawler cutout test + full suite. Report the exact result lines and list any windowed command the
director must run.
