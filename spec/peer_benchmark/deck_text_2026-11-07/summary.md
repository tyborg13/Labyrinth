# sd-18 font-size source inventory

Measurement only. No source, scene, data, asset, test or Git metadata was changed. All outputs are task-local. Source HEAD and SHA-256 manifest: `source-audit.json`.

## Scope and method

Scanned 642 text source files under scripts/, scenes/ and data/; 926 static records in 93 files (including two explicit texture/theme dependencies outside those folders). `inventory.csv` contains file:line, original/expanded size expression, token path, screen families, observed screens, physical px and provenance. Definitions, producers, setters, forwarding inputs and outline passes have distinct kinds; these are records, not a count of unique visible widgets. `lexical-coverage.csv` and `token-users.csv` retain the audit trail.

Physical metric is sd-16’s smallest positive TextServer glyph-ink height among actual letters/digits, multiplied by the actual viewport/canvas y transform. Reused measurements are at 1280×800 / 115%; base transform is 0.76701819896698 (integer 1670×1043 logical fixture). UI scale is not simply ×1.15 on the font size. UiTypography.ui_scale is a second, rounded size adjustment (about 1.0074 on that fixture, often rounding to no change). Card fit and canvas scaling can reduce the ink further.

**A source without an observed text/transform has no honest single physical-px number.** Its numeric cells are empty, metric_status says unobserved, and deck_metric_expression gives the exact glyph-dependent calculation. Same-size empirical corpus ranges are explicitly reference-only. Controls have static provenance rather than instrumented source receipts. Broad/ambiguous joins are marked and are not copied into every candidate source’s metric. No estimated value is claimed as a fresh rendered measurement. RichText inline spans and local draw_set_transform effects remain sd-16 limitations.

## UiTypography tokens and users

| Token | Logical px | References / files | Reachable records | Observed min physical px |
|---|---|---|---|---|
| SIZE_CAPTION | 14 | 59 / 15 | 68 | 6.580486 |
| SIZE_SMALL | 15 | 34 / 9 | 37 | 6.580486 |
| SIZE_BODY | 16 | 73 / 22 | 73 | 6.580486 |
| SIZE_BODY_LARGE | 18 | 35 / 12 | 28 | 6.580486 |
| SIZE_SECTION | 21 | 37 / 16 | 34 | 6.580486 |
| SIZE_SECTION_LARGE | 24 | 3 / 3 | 5 | 6.580486 |
| SIZE_TITLE | 30 | 20 / 7 | 14 | 6.580486 |
| SIZE_HERO | 38 | 7 / 4 | 4 | 6.580486 |
| SIZE_BANNER | 58 | 11 / 5 | 8 | 6.580486 |

All reference locations and code are in token-users.csv; per-token users are also in inventory.csv and token-groups.csv. References include role mappings, comparisons and fitting arrays; reachable-record counts include intermediate producers. No Deck-only token exists in the current code; reach is a dependency map for a future Deck-specific token resolver, not a claim that changing a const is platform-specific. A token change reaches yes-marked paths, subject to later fitting/caps. It does not reach numeric lookalikes, fixed draw sites, baked pixels, or the root theme default. shadowed marks role sizes immediately replaced by a later explicit setter; the role still chooses the font. Forwarded inputs require their caller/producer, listed separately.

## Records grouped by token or resolved literal size

| Group | Records | Files | Token reachable | Observed min px |
|---|---|---|---|---|
| expression / forwarded / raster | 318 | 56 | 0 | 6.106061 |
| logical 0 | 5 | 3 | 0 |  |
| logical 1 | 5 | 3 | 0 |  |
| logical 10 | 6 | 2 | 0 |  |
| logical 11 | 3 | 2 | 0 | 7.666667 |
| logical 112 | 2 | 1 | 0 | 54.000002 |
| logical 114 | 3 | 1 | 0 |  |
| logical 12 | 7 | 4 | 0 | 8.433333 |
| logical 13 | 9 | 5 | 0 | 6.876712 |
| logical 132 | 2 | 1 | 0 |  |
| logical 14 | 36 | 16 | 0 | 7.640792 |
| logical 15 | 31 | 17 | 0 | 7.338606 |
| logical 16 | 14 | 12 | 0 | 7.333334 |
| logical 17 | 29 | 13 | 0 | 7.333334 |
| logical 18 | 24 | 11 | 0 | 8.005752 |
| logical 19 | 20 | 12 | 0 | 7.338606 |
| logical 2 | 4 | 2 | 0 |  |
| logical 20 | 18 | 11 | 0 | 8.666667 |
| logical 21 | 7 | 5 | 0 |  |
| logical 22 | 22 | 12 | 0 | 7.338606 |
| logical 23 | 5 | 3 | 0 |  |
| logical 24 | 15 | 9 | 0 | 7.338606 |
| logical 26 | 6 | 4 | 0 | 7.915721 |
| logical 27 | 2 | 2 | 0 |  |
| logical 28 | 4 | 4 | 0 |  |
| logical 29 | 7 | 2 | 0 |  |
| logical 30 | 7 | 5 | 0 |  |
| logical 32 | 4 | 2 | 0 | 15.333333 |
| logical 34 | 2 | 1 | 0 |  |
| logical 38 | 3 | 2 | 0 |  |
| logical 4 | 2 | 2 | 0 |  |
| logical 40 | 5 | 5 | 0 |  |
| logical 42 | 3 | 2 | 0 |  |
| logical 44 | 4 | 2 | 0 | 7.338606 |
| logical 46 | 4 | 3 | 0 |  |
| logical 48 | 2 | 2 | 0 |  |
| logical 5 | 1 | 1 | 0 |  |
| logical 52 | 1 | 1 | 0 |  |
| logical 540 | 1 | 1 | 0 |  |
| logical 56 | 1 | 1 | 0 |  |
| logical 58 | 1 | 1 | 0 |  |
| logical 64 | 4 | 2 | 0 |  |
| logical 7 | 2 | 1 | 0 |  |
| logical 75 | 1 | 1 | 0 |  |
| logical 8 | 3 | 2 | 0 |  |
| logical 82 | 1 | 1 | 0 |  |
| logical 9 | 5 | 2 | 0 |  |
| logical 92 | 1 | 1 | 0 |  |
| token definition SIZE_BANNER | 1 | 1 | 0 |  |
| token definition SIZE_BODY | 1 | 1 | 0 |  |
| token definition SIZE_BODY_LARGE | 1 | 1 | 0 |  |
| token definition SIZE_CAPTION | 1 | 1 | 0 |  |
| token definition SIZE_HERO | 1 | 1 | 0 |  |
| token definition SIZE_SECTION | 1 | 1 | 0 |  |
| token definition SIZE_SECTION_LARGE | 1 | 1 | 0 |  |
| token definition SIZE_SMALL | 1 | 1 | 0 |  |
| token definition SIZE_TITLE | 1 | 1 | 0 |  |
| tokens SIZE_BANNER | 9 | 3 | 5 |  |
| tokens SIZE_BODY | 70 | 19 | 66 | 7.670182 |
| tokens SIZE_BODY;SIZE_BODY_LARGE | 1 | 1 | 1 | 9.2 |
| tokens SIZE_BODY;SIZE_CAPTION | 1 | 1 | 1 | 7.670182 |
| tokens SIZE_BODY;SIZE_SECTION | 3 | 2 | 2 |  |
| tokens SIZE_BODY_LARGE | 22 | 6 | 22 | 9.2 |
| tokens SIZE_BODY_LARGE;SIZE_SECTION | 2 | 2 | 2 | 10.733333 |
| tokens SIZE_BODY_LARGE;SIZE_SECTION;SIZE_TITLE | 2 | 2 | 0 |  |
| tokens SIZE_CAPTION | 63 | 13 | 63 | 7.666667 |
| tokens SIZE_CAPTION;SIZE_SMALL | 1 | 1 | 1 |  |
| tokens SIZE_CAPTION;SIZE_SMALL;SIZE_BODY;SIZE_BODY_LARGE;SIZE_SECTION;SIZE_SECTION_LARGE;SIZE_TITLE;SIZE_HERO;SIZE_BANNER | 3 | 1 | 3 | 6.580486 |
| tokens SIZE_HERO | 1 | 1 | 1 |  |
| tokens SIZE_SECTION | 30 | 10 | 26 | 10.733333 |
| tokens SIZE_SECTION;SIZE_SMALL | 1 | 1 | 1 |  |
| tokens SIZE_SECTION_LARGE | 2 | 2 | 2 |  |
| tokens SIZE_SMALL | 32 | 8 | 32 | 7.670182 |
| tokens SIZE_TITLE | 12 | 3 | 11 |  |

Each group’s kinds and every location: size-groups.csv. Every distinct size expression is separately grouped in expression-groups.csv (no dynamic sites are lost in the aggregate expression bucket). Dynamic expressions remain intact rather than being rounded to a guessed nominal size. 0/−1 may be sentinels or hidden backing values; definitions and consumers are not all final rendered sizes.

Most frequent expression groups:

| Expression | Tokens | Records | Files |
|---|---|---|---|
| font_size |  | 53 | 24 |
| 14 |  | 32 | 16 |
| 15 |  | 28 | 16 |
| UiTypography.ROLE_CAPTION | SIZE_CAPTION | 27 | 5 |
| 17 |  | 26 | 13 |
| label_size |  | 26 | 1 |
| UiTypography.SIZE_SMALL | SIZE_SMALL | 26 | 5 |
| UiTypography.ROLE_BODY | SIZE_BODY | 25 | 8 |
| UiTypography.SIZE_BODY | SIZE_BODY | 23 | 7 |
| 18 |  | 22 | 11 |
| 22 |  | 18 | 12 |
| 20 |  | 16 | 11 |
| UiTypography.SIZE_CAPTION | SIZE_CAPTION | 16 | 5 |
| 19 |  | 14 | 11 |
| 16 |  | 13 | 12 |
| 24 |  | 13 | 8 |
| UiTypography.SIZE_BODY_LARGE | SIZE_BODY_LARGE | 13 | 3 |
| size |  | 12 | 5 |
| UiTypography.ROLE_TITLE | SIZE_TITLE | 9 | 2 |
| Typography.ROLE_BODY | SIZE_BODY | 8 | 4 |

## All source kinds

| Kind | Records |
|---|---|
| baked_texture | 1 |
| baked_texture_unused | 1 |
| bbcode | 1 |
| draw_outline | 7 |
| draw_text | 44 |
| fit_steps | 3 |
| helper_input | 240 |
| helper_selector | 17 |
| parameter_default | 10 |
| scene_or_theme_size | 1 |
| size_assignment | 15 |
| size_data | 23 |
| size_definition | 102 |
| size_dependency | 54 |
| size_formula_input | 58 |
| size_return | 18 |
| size_transform | 3 |
| theme_override | 54 |
| typography_eyebrow | 19 |
| typography_role | 96 |
| typography_setter | 150 |
| typography_token | 9 |

## Twenty highest cumulative shortfall × observed frequency groups

Ranking formula (analysis-only): sum(max(0,9-smallest_letter_digit_px)) over distinct (screen,node,text,font_size,origin_group) observations; paint passes deduplicated. Also included are the literal frequency×minimum-px product and (9−minimum)×frequency in worst-20.csv. The cumulative sum uses each observation’s actual px, so one tiny glyph does not assign that minimum to all uses. Frequency means distinct observations in the demo sweep/route, not exposure time or play telemetry. `smallest-first-20.csv` supplies an alternate strict minimum-px-first ordering.

| # | Source/group | Min px | Frequency | Screen states | Σ deficit px | Current source(s) | Tokens |
|---|---|---|---|---|---|---|---|
| 1 | Card face title fit | 6.106061 | 269 | 32 | 306.877747 | scripts/card_widget.gd:2331;scripts/card_widget.gd:2333;scripts/card_widget.gd:2343;scripts/card_widget.gd:2345;scripts/card_widget.gd:2348;scripts/card_widget.gd:2350 |  |
| 2 | Shared controller prompt label | 8.433333 | 334 | 107 | 188.740809 | scripts/input_prompt.gd:28 | SIZE_BODY |
| 3 | Card strip name fit (15/14/13) | 7.640792 | 116 | 8 | 155.908951 | scripts/character_card_strip.gd:17;scripts/ui_card_strip.gd:117;scripts/ui_card_strip.gd:120 | SIZE_CAPTION |
| 4 | Large map legend labels | 7.666667 | 94 | 8 | 125.256008 | scripts/section_map_panel.gd:300 | SIZE_CAPTION |
| 5 | Scavenger ware name 17 | 7.333334 | 58 | 10 | 96.392471 | scripts/scavenger_shop_view.gd:1111 |  |
| 6 | scripts/combat_board_view.gd::_draw_health_bar_text | 8.433333 | 122 | 21 | 69.005743 | scripts/combat_board_view.gd:9860 |  |
| 7 | Room subtitle inherited theme 16 | 8.433333 | 103 | 91 | 58.212003 | themes/default_theme.tres:7 |  |
| 8 | Settings detail/subtitle small token | 7.670182 | 36 | 4 | 47.873448 | scripts/settings_panel.gd:430 | SIZE_SMALL |
| 9 | Grimoire navigation body/caption | 7.670182 | 74 | 2 | 47.016313 | scripts/run_scene.gd:6963 | SIZE_BODY;SIZE_CAPTION |
| 10 | Pre-battle move tags | 7.640792 | 36 | 6 | 46.981121 | scripts/pre_battle_view.gd:408 |  |
| 11 | Combat objective live detail fixed 14 | 7.666667 | 33 | 7 | 44.000005 | scripts/combat_objective_hud.gd:153 |  |
| 12 | Scavenger miniature readable title fit | 6.580486 | 14 | 7 | 33.873201 | scripts/scavenger_miniature_card.gd:20 | SIZE_BANNER;SIZE_BODY;SIZE_BODY_LARGE;SIZE_CAPTION;SIZE_HERO;SIZE_SECTION;SIZE_SECTION_LARGE;SIZE_SMALL;SIZE_TITLE |
| 13 | Skills SkillDetailRequirements | 7.666667 | 25 | 6 | 33.248966 | scripts/skill_tree_view.gd:1138 | SIZE_CAPTION |
| 14 | scripts/card_widget.gd::_draw | 6.544512 | 28 | 6 | 31.106117 | scripts/card_widget.gd:351 |  |
| 15 | Skills SkillDetailUnlocks | 7.666667 | 23 | 6 | 30.58933 | scripts/skill_tree_view.gd:1145 | SIZE_CAPTION |
| 16 | Skills FULL GAME fixed 14 | 7.83463 | 30 | 6 | 30.561408 | scripts/skill_tree_view.gd:1052 |  |
| 17 | Event choice/outcome/body text | 7.333334 | 29 | 5 | 30.31607 | scripts/event_view_text.gd:48;scripts/event_view_text.gd:49 |  |
| 18 | scripts/combat_board_view.gd::_draw_movement_risk_chip | 6.133333 | 11 | 1 | 24.633335 | scripts/combat_board_view.gd:14797 |  |
| 19 | Combat Details title | 7.666667 | 17 | 17 | 22.638546 | scripts/combat_hud_intents.gd:48 |  |
| 20 | scripts/threat_tiles.gd::draw_zone_tag | 8.433333 | 38 | 1 | 21.53334 | scripts/threat_tiles.gd:73 |  |

Every row of sd-16 text-below-9px.csv is preserved in sd16-below-9px-joined.csv with current locations, inventory IDs and join confidence; all 6,853 source observations are in sd16-all-text-joined.csv. sd-16’s candidate list uses reference-height OR smallest-letter failure, so symbol-only rows are retained in the join but excluded from letter/digit rankings. Shadow/outline duplicates collapse only in ranking; join rows remain unchanged. `draw-line-remap.json` binds old line numbers to byte-identical (whitespace-normalized) current draw calls.

| Join confidence | Rows |
|---|---|
| candidate source family | 45 |
| identical draw call | 431 |
| static control provenance | 1640 |

## Card faces, scenes/data, and textures

- CardWidget watch: value_font_size() begins at scaled 21/24 and shrinks toward the rules-text minimum by available width. The three draw passes are the same numeral. Card title: _base_title_size() selects scaled 17/18/20; _fit_title_label() applies relief, 14 floor and scaled 19 cap. Body/footer/rules: _scaled_card_font_size(14 compact /16 normal, floor 9), then UiTypography scaling. Summary values, continuation and modifier markers have separate size paths. RetainedCardMetrics forwards the same values. ScavengerMiniatureCard adds handheld readability steps only for flame_jet/arc_flash titles and flame_jet summary values, and only when the canonical nameplate still fits. Other shop cards retain the canonical fit. Its existing threshold compares font size×scale, while this audit compares letter/digit ink×scale; those are different measurements. These paths are per-site/formula edits, except explicit token floors/steps.

- scripts/card_presentation_cache.gd caches lossless transformed frame/emblem PNGs only (CardWidget frame/emblem call sites); it contains no rendered text, font size, glyph atlas or card-face text cache. Changing text size does not require regenerating that artifact.

- All four .tscn files have zero font-size overrides, and all data/*.json files have zero font-size values or font_size BBCode. Scene labels without runtime sizes inherit themes/default_theme.tres:7 (16). The recap’s Embers amount has the one [font_size=22] BBCode source; base RichText metrics do not resolve that span.

- Visually inspected all 109 assets/art/ui PNGs using ui-assets-1.jpg … ui-assets-4.jpg, plus full-resolution startup/title rasters. The startup Maker’s Seal bakes “Made with Godot”: 19 source-px minimum core letter ink at the recorded audit threshold; KEEP_ASPECT_CENTERED yields 14.545455 physical px at 1280×800. This is an offline raster estimate, separate from TextServer. RUN ENDED is baked in assets/art/ui/run_end_last_light_title.png but has no references in scripts/scenes/data. Shelf/banner/frame/card art examined in the UI sheets carries no other readable type. Decorative symbols/ticks are not letter/digit font-size sources. Incidental writing inside narrative/world art is not exhaustively OCR-certified.

## Verification and limits

Numeric letter/digit physical values (or the separately labelled baked raster estimate) exist for 115/926 records; remaining records are unobserved, forwarding/definition-only, or symbol-only. This is a numeric-coverage limit, not a newly selected size.

Inventory generator completed; 2116/2116 below-9 rows preserved; 44 draw-line remaps; 20 ranked groups. See audit-summary.json. No product tests, Godot/native runs, windowed commands or captures are required by the brief. Existing sd-16/headless metric limitations are retained. Unobserved sites need a future content/transform measurement if exact numeric px is required; this inventory supplies the source and formula without selecting a new type scale.

TODO_DESIGN placeholders: none (no design decisions or player-facing values introduced). Chosen defaults are report-only in chosen-defaults.json.
