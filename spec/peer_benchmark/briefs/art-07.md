# art-07 — Tone and palette-match tools: max chroma filter, bright cores stay accents

## Header
- Two recurring problems in today's maquette work (judge reports 2026-10-15):
  1. `palette_match` (rear matched to its approved front) treats pale, low-chroma highlights as non-accent pixels and
     pulls them into the body palette: it greyed the lancer's ice blade and the wisp's lavender-white lightning cores
     (front (226,201,253) → rear (199,196,202)). The accent test is "Lab chroma > p90 + 15" of the image's own
     distribution, so pale cores never qualify.
  2. `tone_region` has no maximum-chroma filter, so a pass that dulls a body also catches the accent (amber, violet
     fringe) and every config needs paired inverse "restore" passes (bloomer tone B: 13 passes).
- Base: `codex/peer-benchmark` **after art-06 merges**. Owned: `tools/art_identity_gate.py` (palette_match,
  tone_region, region_mask), `tests/test_art_identity_gate.py`, `spec/visual_identity_gate.md`,
  `spec/art_identity/prototype/tone_region.py` docstring.

## Change
1. `tone_region` region keys gain optional `max_chroma` (0..1, same RGB max−min measure as `min_chroma`) and
   `max_value`; absent = unchanged behaviour, so every existing config and recorded raw step replays byte-identically
   (pixel digests unchanged — test it on all recorded kits).
2. `palette_match` accent mask also keeps (never transfers) pixels with CIE L* ≥ 80 **or** pixels whose hue is within
   ±25° of an accent hue present in the reference front (accent pixels of the reference by the existing rule). Record the
   new parameters in the post-step (`accent_lightness`, `accent_hue_window_deg`); existing sidecars keep their recorded
   parameters and still verify (replay uses the recorded parameters).
3. Tests: a synthetic sprite with a pale low-chroma core stays unchanged by the match; max_chroma excludes an amber patch
   while toning a brown body; all recorded raw_steps kits replay unchanged; registry `check` PASS.

## Proof
Gate tests; `check` PASS (0 failures); replay of every raw_steps kit; before/after of the lancer and wisp rear match on a
test copy showing the accent preserved (numbers in the result).

## Out of scope
Re-processing any approved art (the director does that), new art.
