# rr-02 feedback 1 (director) — phase 2a: final pair, all solos, rigid cloth

Phase 1 is committed (137bf9bf5). Merge `codex/peer-benchmark` into this branch first (it brings the renders and the
final art below). Do not commit.

1. **Renders**: Blender crashes inside the Codex sandbox, so the director rendered the maquette (spec rev "r3 solos":
   every one of the 21 parts solo-rendered in both views) into
   `spec/art_identity/jobs/chainbound_gaoler/mq3_maquette_renders/` (`{front,rear}_parts.png`, `{front,rear}_clay.png`,
   `{view}_solo_<part>.png` for all parts, `joints_px.json`). Make `tools/maquette_cutout.py` accept `--renders <dir>`
   (verify the expected files exist; record their digests in the case) and use it instead of invoking Blender.
2. **Final art**: the owner asked for a chain that links up; the approved pair is now
   `spec/art_identity/jobs/chainbound_gaoler/mq3_front_v4/processed.png` and `mq3_rear_v3/processed.png` (only the
   `chain`/`hook` regions and tiny palette-refit drift differ from v3/v2). Rebuild the case from this pair; rest identity
   must stay exact.
3. **TODO_DESIGN_cloth_weights → decision**: keep cloth rigid, like production. Tabard and coat panels are rigid parts
   parented to the same bones as their production counterparts (`assets/units/chainbound_gaoler_cutout/{front,rear}.json`;
   follow the production parenting exactly and record the mapping); no skinning.
4. **Hidden requests**: regenerate all 42 requests with measured exposure for every part (no "unknown"), ordered by
   exposure, and a contact sheet; plus `hidden_requests/paint_plan.md` listing, per request, the part, view, hidden area
   in pixels, the motions that expose it and the neighbouring materials (so the director can paint them).
5. Re-run the motion samples and validation. List the windowed commands (native rest probe, render reel) for the
   director.
