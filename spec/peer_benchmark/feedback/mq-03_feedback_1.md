# mq-03 — round 1 (Blender bridge + fit-to-source proposals)

1. **Blender access (owner-approved):** Blender crashes in your sandbox because seatbelt blocks Metal
   (`gpu::MTLBackend::metal_is_supported` → SIGSEGV; no `--gpu-backend` alternative on macOS). The director now runs a
   bridge outside the sandbox (`tools/blender_bridge/bridge.py` on the integration branch). Protocol:
   - write `/private/tmp/labyrinth_codex/blender_bridge/queue/<unique-id>.json`:
     `{"script": "<abs .py under /Users/borgerding/workspace/Labyrinth.worktrees/mq-03/spec/art_identity/maquettes/>",
       "args": [...], "timeout_s": 900}` (path args must be under that worktree or /private/tmp/labyrinth_codex);
   - poll `/private/tmp/labyrinth_codex/blender_bridge/done/<id>.json` (`exit`, `seconds`, `log`) and read `<id>.log`;
   - one job at a time, max 1800 s; command is `Blender -b --factory-startup --disable-autoexec --python-exit-code 2
     -P script -- args`. Add a small `blender/bridge_client.py` helper and use it for every native test/render.
   - The director's smoke run of `integration.py` failed: `TypeError: synthetic_spec.<locals>.part() got multiple
     values for argument 'kind'` (integration.py:52). Fix, then make the native integration suite pass via the bridge.
2. **Lancer r3 values — fit-to-source proposals.** Do not leave 257 TODO_DESIGN markers. The design intent is fixed by
   the brief's piece list and the identity reference (`.../mq1_front_v3/refs/03_identity_lancer_current.png`), which
   is an objective target. Propose every value yourself by matching the reference (measure positions/sizes from it,
   follow its shapes: trapezoid pauldron lames, pointed diamond poleyns, ridged breastplate, diamond gem, split ragged
   tabard, cloak trailing to the figure's back/right, crystal head continuing the shaft, upright planted stance), mark
   them `"proposed": true`, and iterate with renders through the bridge until the silhouette passes the fit gate and
   the clay render visibly shows those shapes. The director reviews the renders and adjusts taste afterwards.
   Use `realistic_body_male` unless it fails; report which body asset and why.
3. Deliver: native integration PASS, lancer r3 front/rear parts + clay renders, gallery render, fit report/overlay,
   all produced through the bridge, with paths in the result. Do not commit.
