# Unit 2: Turn-order HUD

Read [spec/turn_clock.md](../../turn_clock.md), [the README](README.md) and
[spec/visual_design_system.md](../../visual_design_system.md). Unit 1 has
landed the rule and these engine helpers:
- `CombatEngine.WAIT_TIME_PER_UNUSED_PLAY`, `base_plays_waited(state, extra := 0)` and `pending_wait_time(state, extra := 0)`
- on the projected hero entry: `projected_time_delta` and `projected_wait_time`

Target mockups: `02_fast_card.png`, `03_heavy_card.png`, `04_act_again.png`,
`05_details.png` and `proposed_*.png` (absolute folder in the README). The
baselines are in `mockups/baseline/`.

Files involved:
- `scripts/run_scene.gd`:
  - rail pill: `_turn_order_projection_badge*` ~12745–12800
  - rail slot tooltip: `_turn_order_tooltip` ~12864
  - Pass plate: `_build_pass_preview_chip` forecast line ~14950, `_refresh_selected_card_forecast` ~14995
  - Pass tooltip: `_pass_preview_tooltip` ~15523
  - context risk text: `_update_action_context_risk` ~14036
  - preview source: `_turn_order_card_time_preview` ~12319
- new `scripts/turn_order_landing_strip.gd`; keep the strip's logic out of `run_scene.gd` apart from wiring
- `scripts/turn_order_ink.gd`: reuse it; add shared helpers here only if needed
- `scripts/card_widget.gd`: Time badge tooltip ~1366
- new probe `tests/turn_clock_hud_probe.gd`; update `tests/turn_order_projection_probe.gd` and any HUD test that asserts the old pill or plate text

## Change

1. **Rail delta pill.** It shows the change against ending now, not the raw Time.
   - Text: `<Card> −N` (U+2212), `<Card> ±0`, `<Card> +N`, from `projected_time_delta`. Without a card name use `−N Time` / `±0 Time` / `+N Time`.
   - The delta is never trimmed. If the text overflows, trim the card name with an ellipsis first.
   - Keep size 9, the text colour `fff6ce`, outline `120b07`/1, and the corner, shadow and position.
   - Style by sign:
     - **< 0:** bg `Color("27465a")` alpha 0.94, border `Color("a8e4ff")` (the Quicken badge colours).
     - **= 0:** the current gold style.
     - **> 0:** bg `Color("4a2410")` alpha 0.94, border `UiPalette.EMBER`.
   - Leave the Stagger and Petrified pills unchanged.
2. **Rail slot tooltip (projected hero).**
   - Preview line: `Preview: <Card> (<delta> vs ending now)`.
   - Breakdown: `Base B + cards C + unused plays W`, where C = Time spent plus the previewed card's Time and W = `projected_wait_time`.
   - If the ETA differs from that sum (Borrowed Hourglass debt, Pocket Sundial), add one line: `Carried +N` or `Relics −N`.
   - With no preview, show the same breakdown without the preview line.
3. **Landing strip** (`TurnOrderLandingStrip`, a new Control owned by `run_scene`).
   - **When shown:** exactly when the rail shows a card preview (`_turn_order_card_time_preview()` is non-empty) and that card's hand control is visible. That covers mouse hover, a selected card, and controller bumper focus. Hide it while a card is being dragged, outside the player's turn, and during the animation lock.
   - **Data:** reuse the entries `_refresh_turn_order_bar` already computes, including overflow entries; do not run a second projection.
     - *before*: the entries after the active entry and before the hero's projected entry, in rail order.
     - *hero*: the projected hero entry.
     - *after*: the next entry after the hero, if any.
     - Umbra-hidden actors use the rail's Unknown Presence portrait and enemy ink.
   - **Mini slot** (one per actor), matching the rail's construction at 0.74 scale:
     - slot 86×64;
     - the brush stroke from `TurnOrderInk.brush_texture`, `brush_tilt_degrees` and `brush_flipped`, keyed by the same actor key as the rail, with the rail's brush-rect geometry scaled by 0.74, tinted with `TurnOrderInk.ink_color(team, false, projected)`;
     - the portrait in `TurnOrderInk.PortraitMask` (skew 0.14), keep-aspect-covered, zoom 1.04;
     - the ETA numeral on the stroke's left end: display font 17, outline 3 (`Color(0.05,0.03,0.02,0.95)`), ivory `UiPalette.TEXT` for others and `Color("f4c968")` for the hero;
     - no health bar.
   - **Layout, left to right:**
     - up to 4 *before* slots; if there are more, show the first 4 and then a `+N` label (display font 15, `UiPalette.TEXT`);
     - a gold chevron (16 px tall, `UiPalette.GOLD`) when at least one *before* slot exists;
     - the hero slot;
     - the *after* slot, dimmed (modulate about `Color(0.62,0.58,0.55,0.42)`).
     - Consecutive slots overlap by 18 px.
   - **ACT AGAIN** (no *before* slots):
     - the hero slot comes first, with a soft warm glow behind it (`UiPalette.GOLD_BRIGHT` at about 0.43 alpha, about 13 px blur radius);
     - then a two-line label `ACT` / `AGAIN` (display font 16, `UiPalette.GOLD_BRIGHT`, outline 3, dark);
     - then a dim chevron (13 px, `UiPalette.GOLD_DIM`);
     - then the dimmed *after* slot.
   - **Backing:** a soft, dark, borderless wash behind the whole strip, about `Color(0.024,0.016,0.012,0.84)` with a 12 px blur feel and no hard edges, so it reads over lit floor tiles. Match the mockup crops.
   - **Placement:**
     - The strip's bottom edge sits 4 px above the focused card's frame top. The watch badge may overlap the strip's lower corner as it does in the mockup.
     - Right-align the strip to the card's right edge + 8, so it grows left, away from the focus tooltip stack.
     - If that stack is on the card's left, left-align to the card's left edge − 8 instead.
     - Clamp inside the viewport with a 16 px gutter.
     - It must never overlap the focus tooltip stack. Assert that in the probe.
   - **Behaviour:**
     - It ignores the mouse and sits above the board and hand, below the tooltip stack.
     - It fades in over 0.12 s, instantly under reduced motion.
     - Rebuild only when its content signature changes (entry keys, ETAs, roles, focused index). Load textures through `AssetLoader`.
   - Node names: `TurnOrderLandingStrip`, `LandingStripSlot_<i>`, `LandingStripHero`, `LandingStripAfter`, `LandingStripAgainLabel`, `LandingStripOverflow`.
4. **Pass plate wait cost.**
   - When `pending_wait_time(state) > 0`, the forecast line's lead cell `TURN END` becomes the Time icon (`ActionIcons.icon_texture("time")`, 14–16 px) followed by `+N` in `UiPalette.GOLD_BRIGHT`. The forecast parts after the bullet keep their colours.
   - When no Wait is pending, the lead stays `TURN END`.
   - Keep the line centred in `PassPreviewDamageRow`, size `SIZE_SMALL`.
   - Keep the node `PassPreviewForecastLine` and its `pass_preview_values` meta; add meta `pass_preview_wait_time`. Update `_refresh_selected_card_forecast` the same way.
   - `_update_action_context_risk`: use the lead `WAIT +N` instead of `TURN END` when a Wait is pending.
   - `_pass_preview_tooltip`: prepend `Ending now leaves N card play(s) unused: +M Time.` when a Wait is pending, keeping the existing lines after it.
4b. **Known damage survives an unrevealed lap.** A +19 pass now often includes
   an enemy's second, not-yet-revealed activation. Today `_pass_preview_forecast_entries`
   then replaces everything with `UNKNOWN`, hiding damage that is already known.
   - When `unrevealed_before_player` is true, `umbra_unknown_before_player` is false, and the summary has known losses: show the usual defense/HP cells, then append a trailing `+?` cell in the UNKNOWN colour `Color("c89be3")`, e.g. `+10  •  −5 +?`. The `+?` follows the last cell after a single space, not after a bullet.
   - With no known losses, it stays `UNKNOWN`.
   - DEFEAT and Umbra-unknown keep their current behaviour.
   - Apply the same suffix in `_update_action_context_risk` (`… −5 HP +?`).
   - Keep the tone and accent rules.
   - Unit 1 left an isolated test case for this lap. Update it to the new text.
5. **Card Time badge tooltip** (`card_widget.gd`): `Time\nDelays your next turn by N. An unused play takes 5.` Keep the modifier lines.

## Keep

- Rail layout, slot sizes, numerals, ink, animation, the Stagger preview, Late Bell marks and hover-to-board highlighting.
- Every input path: mouse hover, click-select, drag, and controller bumpers, accept and pass (Y).
- The Pass chip's art, states and forecast semantics.
- The tooltip stack placement rules.
- No HUD element added beyond these.
- No new icons. The Time icon is the existing concept.

## Proof

- New `tests/turn_clock_hud_probe.gd`: a 1920×1080, 100% scale, real-renderer capture through `tools/visual_probe_runner.py --no-headless --expect-size 1920x1080`.
  - Fixture: Fevered Vault, depth 1, player at 2:4; Harrier 3:4, Acolyte 5:2, Warden 5:5 with natural initiative; hand `pale_spark, quick_stab, sidestep_slash, bloody_lunge, brace`; tutorials completed.
  - Each capture also asserts its semantics (pill text and style, strip roles and order, plate lead, no overlap):
    1. `idle`: the ghost's end-now ETA includes +10, the plate shows `+10` with the icon, and there is no strip.
    2. `hover_fast` (Quick Stab): `−3`, quick style; the strip is Harrier › hero, then the Acolyte dimmed.
    3. `hover_heavy` (Bloody Lunge): `+1`, ember style; the strip has two before-slots, the hero, and the Warden dimmed.
    4. `mid_turn_act_again`: Brace actually played through the engine, then hover Quick Stab; ACT AGAIN, and the plate shows `+5`.
    5. `both_plays_used`: the plate shows `TURN END`.
    6. `controller_focus_fast`: bumper focus onto Quick Stab shows the strip.
    7. `reduced_motion_fast`.
    8. `pass_lap_known_damage`: a fixture where the +19 pass spans an enemy's unrevealed second activation, with revealed damage before it. The plate reads `+10  •  −N +?`.
- Update `tests/turn_order_projection_probe.gd` and any pass-preview or HUD probe or test whose old text changed. List each one.
- Run the full suite and `python3 tests/test_icon_identity_policy.py`.
- Report the capture paths. The design owner reviews them against the mockups.
