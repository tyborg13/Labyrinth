# UI identity gate

Board art has the [visual identity gate](visual_identity_gate.md). This is its UI counterpart: new UI must be built from
the shared visual language in [the visual design system](visual_design_system.md), and drift must fail loudly.

## Why (owner verdicts 2026-10-12/13)

- itb-01's floating intent pills: "basically just default boxes which makes them a bit dull and plain while
  simultaneously sticking out". They used only palette colours — a colour check alone would not have caught them; the
  give-away was the construction: a bordered rounded `StyleBoxFlat` as the final look.
- en-04's Bramble: an empty outlined bar frame above every thicket (`SegmentedHealthBar.draw_bar` with no painted
  frame, drawn for terrain without HP).

Today the UI code has 743 distinct colour literals and 85 `StyleBoxFlat.new()` sites (survey 2026-10-13), so a hard ban
would fail almost everything. The gate is a **ratchet**: today's per-file counts are a baseline that may only shrink;
anything new must use the design system.

## 1. Static lint (`tools/ui_identity_lint.py`, `python3 tests/test_ui_identity_lint.py`)

Scans `scripts/**/*.gd` (and `scenes/**/*.tscn`, `themes/**/*.tres` for rule R1). Per file and rule it counts:

| Rule | Counts | Allowed without baseline |
| --- | --- | --- |
| R1 raw box | `StyleBoxFlat.new()` | `ui_skin.gd`, `ui_tooltip_panel.gd`, `ui_component_surface.gd`, `ui_socket.gd`, `ui_card_strip.gd` |
| R2 colour literal | `Color("…")` / `Color(<numbers>)` | `ui_palette.gd`; neutral modulates `Color(1, 1, 1, a)` and `Color(0, 0, 0, a)`; `Color(<Palette token>, a)` is not a literal |
| R3 outline box | `draw_rect(…, false…)` (outline-only rectangles) | `ui_gilded_frame.gd`, `ui_component_surface.gd` |
| R4 bare bar | `SegmentedHealthBar.draw_bar(` call sites | `segmented_health_bar.gd` |
| R5 ad-hoc font | `preload/load` of `res://fonts/…`, `FontVariation.new()`, `get_theme_default_font()` | `ui_typography.gd`, `asset_loader.gd` |
| R6 tiny caption | literal font sizes below 14 passed to `draw_string`/`add_theme_font_size_override` | — |

`spec/ui_identity/baseline.json` stores the counts. The test fails when any file's count for any rule exceeds its
baseline or a file not in the baseline has a violation; it prints file:line for the new sites and the helper to use
instead. Lower counts pass and the test prints a reminder to run `tools/ui_identity_lint.py --tighten`, which rewrites
the baseline downward only (it never raises a count). Raising a baseline needs a director-signed entry in
`spec/ui_identity/exceptions.json` (file, rule, count, reason).

R2 also reports colour literals that re-type a palette token's hex (use the token instead) — those are counted like
any other literal.

## 2. Visual review (the part a lint cannot judge)

Every UI change ships a real-renderer capture (1920×1080, 100% UI scale) and is judged by a fresh Claude subagent
against [`ui_identity/judge_rubric.md`](ui_identity/judge_rubric.md) with the design-system reference sheet beside it,
before the owner sees it. A "default box" look — a plain bordered rectangle or pill without the gilded hairline,
socket ring, painted frame or ink-glass surface — is a FAIL even when every colour is a token.

## 3. Ratchet down

Hotspots (run_scene.gd 537 literals, combat_board_view.gd 343, labyrinth_map_view.gd 67, …) are migrated to tokens and
helpers by dedicated cleanup units; each tightens the baseline. No cleanup changes how anything looks unless the
director says so (re-typed palette hexes become their tokens; near-palette hexes need a director decision).
