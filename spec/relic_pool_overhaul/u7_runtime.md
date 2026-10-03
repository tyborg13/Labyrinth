# U7 surface, variety and movement runtime

Design authority: `relic_data.py` and
`tmp/relic_overhaul/unit_u7_surfaces_movement.md`. Rules text and art are unchanged.
`surface_variety_relic_rules.gd` owns reusable U7 effects; it accepts effect lists
instead of preloading GameData so card definitions can call it without a cycle.

- Death hooks snapshot whether any footprint tile held Fire at the instant of
  death. Ember and Funeral trigger for any enemy death, including passive and
  summoned deaths, without inheriting the former healing/play-reward limits.
  Funeral spreads Bleed, Expose, Shock, Frozen, Chilled, Immobilize and Petrify
  through cardinal footprint adjacency, with normal immunity checks. Sunder is
  an immediate defense removal, not a persistent status that can be inherited.
- Overflow runs at the shared elemental placement endpoint. Replacing one
  elemental kind with another spreads only into empty elemental layers on legal
  cardinal neighbors, with a non-chaining source stamp. Rubble is independent.
- Black Sun stores each consumed tile/layer in event order, including duplicate
  kinds, up to three. An attack releases the previously held fuel once; fuel
  consumed during that attack is stored for the next attack. Its bonus applies
  only to enemy hits. Riders apply to the aimed primary enemy after the action,
  following its displacement. Shock is the ordinary one-turn Shock. Relic Chill
  has a saved support marker so it survives without Ice until removed or Frozen;
  it is not Ice placement. Invalid attacks spend nothing.
- Knots use combat storage and count the currently played element when building
  that card's forecast; only finishing the card commits the knot. Thus the third,
  fourth and fifth distinct-element cards receive their newly reached threshold.
  Chain uses at least reach one and preserves a greater native reach. The fifth
  threshold adds one three-Block action per card, without amplifying that reward
  through Chorus or Bonded Set.
- Chorus tracks the last actual card this turn, including none cards that break
  the sequence. Chorus/Bonded damage applies to damaging action fields; Block
  actions gain their bonus. A card without a Block action gains one bonus Block
  action. Repeated Blinks replace Gale's pending distance with the latest Blink,
  capped at four, through the existing activation-scoped next-attack buff.
- Bonded Set reads equipment `element` and the cards granted by equipped pieces
  (including equipment grafts). None never matches. **All 72 current production
  equipment entries lack this field**, so the implemented effect is idle with
  current data. No element was inferred or authored for those entries.
- Hero-created Light has `owner: player` in its source. Authored/unowned room
  Light and enemy Light do not qualify. Sources with different owners do not
  merge. Combat storage keeps knots, stored surfaces and Light ownership; turn
  flags keep Chorus, Gale and the two-refund cap across save/resume.
- Move navigation tracks cost, refund count, direction, hazards and legal
  endpoints. Vaulting traverses enemy footprint tiles and delays each distinct
  enemy once per Move using normal Stagger caps. It cannot end on an enemy,
  including a hidden body discovered on commit. Unclouded Sun links only the
  hero's Light sources (relay points): a link step costs one and enters only
  the landing source, and the hero walks to and from the relays. Straight-line card Moves retain their cardinal line;
  Blink retains its ordinary endpoint and range rules. The same navigation and
  step-cost rules serve targets, path previews and commits. Shortcuts resolve
  these effects rather than substituting only the hero's position.

The UI reuses the Hourglass counter, surface icons, damage forecast, next-attack
badges and Stagger rail. Light jumps draw an arc with height 35% of their screen
length, existing path colour/width, eight-pixel dashes and six-pixel gaps. On
commit each jump plays the Blink rift from relay to relay between the walked
runs (`RunScene.player_move_segments`).
`tests/relic_u7_probe.gd` captures the five specified states at 1920×1080/100%.

Neutral card heuristics and scorer assumptions are unchanged: these are
run-scoped relic effects, covered by focused interaction tests rather than
added to intrinsic printed-card scores (see `card_balance_heuristic.md`).
