# meta-01 feedback 2 (director)

Native captures reviewed (copies: `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/meta-01/`,
compare with `mockups/run_end.png`). Close to the mockup. Fix:

1. **Quip italic**: the quip must be italic (Text 24 px TEXT_2). If the Crumble Text font has no italic face, use a
   `FontVariation` with `variation_transform` skew of 0.2 (synthetic oblique), not a different font.
2. **Title shadow**: defeat titles get the umbra violet glow (`#2b1d3d` drop shadow offset 0,3 plus an 18 px violet
   `#9a7cf0` glow at 25% alpha behind the glyphs); victory/embrace use the ember glow (`#e8893a` at 25%) with the same
   geometry. Match the mockup.
3. **Gilded rule**: draw the rule fully: 9 px gold diamond at the left, then a 1 px line from GOLD_DIM to transparent
   across 560 px (it is nearly invisible now).
4. **Single-name aggregated feats**: when Unscathed/Flawless has n = 1, the label is "Unscathed" / "Flawless" (no ×1)
   with the original detail "<Name> without losing Health"; n ≥ 2 keeps "×n" with the names list.
5. **Detail truncation**: in every row, the detail text is clipped to the space between the label and the value
   (column width − label width − value width − 12 px) with "…" and the full text in the tooltip. In the overflow
   capture the details currently run into "1050", "300" and the Chain Reaction label — no overlap allowed anywhere.
6. **Embrace backdrop**: the WITHDRAWN screen must use the same darkened backdrop treatment as victory (board dimmed and
   the top-right HUD hidden) — it currently shows the fully lit room and HUD.
7. **Probe**: your windowed run fails "Recap right column must use the approved 1920x1080 coordinates" — the right
   column must start at x = 1010 with width 780; fix the layout (not the assertion) unless the assertion itself reads
   the wrong node — state which.
8. **Ownership**: you may update `tests/suites/ember_hearth_suite.gd` to assert the WITHDRAWN recap instead of the
   immediate Main Menu (adaptation only).

Proof: full suite PASS; run score suite; the windowed probe passes; list the command again.
