# meta-01 feedback 1 (director)

Good work. Decisions for every TODO_DESIGN (replace each placeholder with these; rename constants to plain names;
update spec/run_end.md), plus ownership extensions.

## Decisions
1. **Swift detail**: "Escaped in <m> minutes" with m = floor(run_seconds / 60); "1 minute" singular.
2. **Score tick**: no sound per row and no sound for NEW BEST (owner prefers few sound transitions). Remove the
   `row_revealed` audio hook; the reveal is silent apart from the screen's existing music/stingers.
3. **Aggregated feats**: Unscathed and Flawless are ONE row each: "Unscathed ×<n>" / "Flawless ×<n>", points summed,
   detail = names joined with ", " (e.g. "Craghide, Rimejaw"); more than 3 names → first 3 + " +<k>".
4. **Overflow layout**: when the ledger has more than 9 rows, switch to two columns across the full 780 px column width:
   base rows in the left column, feats in the right, each column 380 px with a 20 px gap, same type sizes; a detail
   line that doesn't fit truncates with "…" and shows the full text as a tooltip. ≤ 9 rows: the single 560 px column as
   designed. No scrolling.
5. **Fallback copy** (legacy/incomplete data):
   - Unknown killer: "The Umbra took your last breath."
   - Killer without an intent name: "Felled by a <Enemy>, <N> damage."
   - Surface without a display name: "The ground itself took your last breath."
   - Trap without an element: "A trap took your last breath."
   - Section without a biome name: eyebrow "Section <roman> · Room <step> of <S>"; no section data at all (legacy
     layouts): eyebrow "Depth <global depth>".
   - Missing title list: the first title of the outcome in `data/run_end_text.json`; missing quip: omit the quip line.
   - Legacy recovery without section data: keep today's existing Embers-lost sentence unchanged.
## Ownership extension
6. You may change `scripts/run_scene.gd` (≤ 20 lines: Embrace routing into the new recap, the three button actions —
   "Rise Again" = today's New Run, "Chronicle" disabled with tooltip "Coming soon", "Main Menu") and `tests/run_tests.gd`
   (suite registration only).
## Recap probe
7. Update the six obsolete assertions in `tests/run_end_recap_probe.gd` to the new design (adaptations that check the
   new layout, not deletions). For the two baseline failures (16-frame player death art, recovery-marker staging):
   check whether they also fail on `codex/peer-benchmark` HEAD; if they do and the fix is small and inside the recap
   probe's own expectations of current assets, fix the expectation; if they reveal a real game defect, report it with
   evidence and leave it.
## Proof
- Suites green (run score, full suite), the probe parser check, and the windowed command listed again (I run it).
