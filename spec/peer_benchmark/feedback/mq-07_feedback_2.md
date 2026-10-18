# mq-07 feedback 2 — plant the far foot, then promote r2 to the delivery

Your r1 (checkpoint 881aae937) is accepted: the raised far shoulder and the 17 px capped tube with the open banded
mouth. mq-06 (merged into your branch by the director; it lands on integration after its review) brings:
- the floor-contact guard and documented exceptions (Thrall listed: far ankle +0.070 m, "mq-07");
- the planted-leg re-pose through real hip/knee/ankle bones, plus the robe-settle tooling;
- the turn regression.

The director has already merged `codex/peer-benchmark` and `codex/mq-06` into your branch, with builder conflicts resolved
(34f3c5e38 and the following merge commit); don't merge again. Unlike the Seer, the Thrall will be repainted in BOTH views from
your clays, so neither view is frozen.

1. **Plant the far foot.**
   - Re-pose the far leg through its real bones so the far ankle stands on the floor plane at the near ankle's height.
   - Keep its ground position as close as practical to the current screen position in the front view.
   - Settle the loincloth if it collides.
   - Remove the Thrall from the floor-guard exception list; it must pass with no exception.
2. **Bridge budget** (same as mq-06):
   - stop only if a job isn't picked up within 120 s;
   - allow up to 900 s once it runs;
   - this replaces the "120 s" line in your brief.
3. **Promote r2 to `delivery/`.**
   - Rebuild the front and rear clay, part maps, solos and `joints_px.json` from the planted r2 body.
   - Labels per your r1 (the tube is `fore_near`; no `hand_near` or `club`).
   - Exact 180° turn; pan-only framing with ≥ 8 px margins; no scaling.
4. **Gates:**
   - the shoulder rule;
   - the floor guard;
   - the turn regression;
   - native collision and ownership;
   - fit IoU against the old approved Thrall paintings ≥ 0.70 front and ≥ 0.65 rear (report the dynamic and fixed
     registrations);
   - per-part coverage;
   - curation ≤ 6 MB;
   - the full Python suite.

Proof: the 1024 sheet with front and rear (old clay | new clay | new part map) with the shoulders marked, plus the
height table.
