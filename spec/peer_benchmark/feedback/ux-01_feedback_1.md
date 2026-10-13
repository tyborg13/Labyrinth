# ux-01 feedback 1 (director)
Flow works (narration → map auto-opens → travel). One defect: the close hint is not visible in the native captures
(`04_close_hint.png`, `06_controller_hint.png` show only the Speak button; copies in
/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/ux-01/). The start room has no hand, so
"above the hand area" places it nowhere visible. Place the hint centred horizontally, 16 px above the top of the
bottom action button row (the Speak button) — or 72 px above the bottom edge when no button is shown — in the existing
hint style (Text 17 px TEXT_2 on the existing hint plate), map glyph on controller. Assert in the probe that the hint
node is visible and inside the viewport, then recapture. No other changes.
