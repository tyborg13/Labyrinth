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

## Commands

Run from the task worktree with Python 3.9 or newer (standard library only):

```bash
python3 tools/ui_identity_lint.py scan --json
python3 tools/ui_identity_lint.py check
python3 tests/test_ui_identity_lint.py
python3 tools/ui_identity_lint.py --tighten
```

The JSON scan includes every `file`/`line`/`rule` site, per-file counts, rule totals, the top 15 files per rule
(count descending, path ascending for ties), and separate informational `palette_matches` with token names.
Comments and strings are masked before matching code; literal arguments of colour constructors and font loads
are inspected separately. Multiline calls are reported at their first line. R1 also counts serialized
`StyleBoxFlat` definitions (`sub_resource` in scenes and `gd_resource` in themes); external references do not count.
Resource comments beginning with `;` are ignored as well as `#` comments.

`baseline.json` contains `version: 1` and a `counts` object keyed by repository-relative path, then rule.
Only nonzero counts are generated. Bootstrap it once with:

```bash
python3 tools/ui_identity_lint.py --write-baseline
```

This refuses to replace an existing file; `--force` explicitly replaces it. Ordinary cleanup uses `--tighten`,
which removes zero entries and takes the smaller of each baseline and current count. It never adds a new file,
rule or larger count. The initial ui-01 baseline uses the scanned files from `6e214d7a4` (identical to the task's
starting tree).

Each director-signed exception is an object with `file`, `rule`, positive integer `count`, and nonempty `reason`.
Exception counts add to the baseline allowance for that file and rule. `check` exits 1 for a count increase,
0 for a pass, and 2 for invalid policy or I/O errors. Because the baseline stores counts, an increase reports
every current site in the offending file/rule pair so additions at any position are visible, with the required
shared helper. Dropped counts pass with a reminder to tighten. `--root <copy>` lets the same commands inspect
a temporary repository copy; the synthetic-new-box regression test exercises this without modifying game code.

This tooling-only unit does not change a rendered surface, so renderer captures and a playable inspection fixture
are not applicable. UI implementation units still require the visual review above.
