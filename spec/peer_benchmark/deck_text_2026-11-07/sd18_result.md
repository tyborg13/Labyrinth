# sd-18 result

Static inventory complete; numeric coverage limits are explicit. Nothing shipped. Checkout remains clean on `codex/sd-18`; no commits, Git writes, peer review, tests, engine/native runs or publication.

1. **Sources:** `inventory.csv` — 926 source/flow records across 642 scanned source files; all nine typography tokens, direct setters/overrides, draw calls, fitting formulas, one BBCode span, scene/data audit and inherited theme. Card presentation cache has frame/emblem pixels only. Inspected 109 UI textures; baked startup text and an unreferenced baked title are recorded. **115 records have observed numeric ink measurements or a labelled raster estimate**; other records retain expressions/status rather than guessed px.
2. **Groups/reach:** `summary.md`, `token-groups.csv`, `token-users.csv`, `size-groups.csv`, `expression-groups.csv`. Token paths, later overrides and per-site formulas are distinguished. No Deck-only token currently exists; reach is a dependency map.
3. **Worst 20 / join:** `worst-20.csv`; `sd16-below-9px-joined.csv` preserves **2,116/2,116** original rows, with 44 current draw-line remaps. All ranked groups have source locations. Frequency is observed screen/text instances, with paint passes collapsed; strict minimum-first ordering is also supplied. Card title fit is first by cumulative shortfall: **6.106061 px minimum, 269 observations**.

Observed audit results (not product tests):

```text
SD18 INVENTORY: 926 source/flow records; 642 scanned files; 288 token/role references
SD18 JOIN: 2116/2116 sd16 below-9 rows preserved; 44 draw line remaps
SD18 RANKING: 20 offender groups; 1929 letter/digit observations after paint-pass deduplication
SD18 CONSISTENCY: PASS (926 inventory IDs; 2116/2116 original CSV rows preserved; 44 identical draw remaps; 20 located offender groups; 9 token groups)
SD18 DIRECT-CALL COVERAGE: PASS {"add_theme_font_size_override": 54, "draw_string": 44, "push_font": 1, "set_button_size": 24, "set_label_size": 114, "set_option_button_size": 1, "set_rich_text_size": 10}
SD18 SOURCE INTEGRITY: PASS (642 source files + root theme unchanged; clean codex/sd-18 checkout)
SD18 ASSETS: 109 UI textures; 4 audit sheets; 13 baked splash letters; min 19 source px / 14.545455 Deck px (raster estimate)
SD18 TOOL SYNTAX: PASS (6 Python files; AST parse only)
```

**Files changed:** repository none. Six Python audit tools under `tools/`; CSV/Markdown/JSON reports, receipts/logs, and `ui-assets-1.jpg` through `ui-assets-4.jpg` here. Source/evidence hashes: `source-audit.json`.

**Proof for the design owner:** inspect `summary.md`, `inventory.csv`, the joined CSV and `worst-20.csv`. Exact read-only reproduction commands are in `README.md`. No windowed command, native capture or inspection fixture is applicable to this measurement-only brief. UI sheets are asset-inspection aids, not renderer captures. No Python test module was added, so suite-resource registration/audit does not apply.

**TODO_DESIGN:** none. **Chosen defaults:** report-only ranking/frequency rule, baked-text ROI and RGB threshold, contact-sheet geometry/labels, parser bounds; named fields in `chosen-defaults.json`. No player-visible defaults selected.

**Open limits:** unobserved/dynamic sites lack numeric measurements; 45 control observations have candidate-family rather than precise source joins. RichText spans/local draw transforms inherit sd-16’s measurement limits. Incidental writing inside narrative/world art is not exhaustively OCR-certified. No typography changes or design decisions were made.
