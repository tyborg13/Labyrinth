# Turn Clock

The initiative clock orders the hero and every enemy by scheduled Time. This
document owns the player-side scheduling rule and how the HUD presents it.
Card scoring assumptions live in [card_balance_heuristic.md](card_balance_heuristic.md);
analytics fields live in [analytics.md](analytics.md).

## Scheduling the hero's next turn

When the hero's activation ends, the next hero turn is scheduled at:

```
now + 9 (base initiative)
    + Time paid for cards played this activation
    + 5 × base plays left unused (Wait)
    + carried Borrowed Hourglass debt
    − relic reductions (Pocket Sundial)
```

- **Wait.** Each of the first two card plays of an activation
  (`BASE_CARDS_PER_TURN`) that the hero does not make takes
  `WAIT_TIME_PER_UNUSED_PLAY = 5` Time. A pass with both plays unused returns at
  `now + 19`; a full two-card turn is scheduled exactly as before the rule.
- **Plays made** are play slots spent on cards this activation. A Flurry spends
  every snapped play, so it never waits. Items that use no card play
  (Quick-Draw Bandolier) and free Rites are not plays.
- **Bonus plays never wait:** kill refunds, card-granted plays (Guarded Step),
  relic plays (Whirling Sash's third play) and banked plays. Using a bonus play
  still counts toward the two plays made, so "play two cards" always clears the
  Wait.
- **Forfeited plays wait.** Plays removed by Freeze count as unused, so a frozen
  activation returns at `now + 19` like a pass.
- **Measured Breath** does not refund Wait: the play left unused still takes 5
  now, and the banked copy is a bonus play next activation.
- **Borrowed Hourglass** takes an immediate extra turn; everything the ending
  activation cost, including Wait, is carried into the next scheduled turn.
- **Pocket Sundial:** if the hero made both base plays this activation, the next
  turn comes 2 Time sooner.

Why: per-activation income (draw 2, move 2, refreshed plays and start-of-turn
effects) made the cheapest activation an empty one, so passing and skipping a
second card were often optimal. Charging the average card's Time for an
unused play makes any card of Time 5 or less at least as fast as not playing it,
leaves heavy cards (6+) a real cost, and makes fast play — not passing — the way
to earn more turns. Time 5 is also the neutral point of the card scorer's tempo
term.

## Presentation

- **Rail ghost.** During the hero's activation, its next projected slot is the "end now" projection,
  including Wait (`projection_kind: end_now`). At turn start it sits at `+19`.
  Only this projection gets the current activation's cost breakdown. A later
  `follow_up` projection says "If that turn ends without a card". An immediate
  Borrowed Hourglass projection is flagged `projected_extra_turn` and reports
  `projected_carried_time`: "Borrowed Hourglass: another turn at once (+N carried)".
- **Delta pill.** While a card is hovered, selected, or controller-focused, the
  ghost moves to the projection after that card and its pill reads
  `<Card> −N` / `±0` / `+N`: the change versus ending now. Faster is Quicken
  blue, even is gold, slower is ember.
- **Landing strip.** Above the focused hand card, a short horizontal excerpt of
  the rail shows every actor that acts before the projected hero turn, the hero
  ghost, and the first actor after it (dimmed). When nobody acts first it reads
  ACT AGAIN. It uses the complete projected order while the rail retains its
  ten-entry disclosure cap. Blocking overlays hide the strip; it stays below
  contextual tutorial callouts and clears both the callout and focus tooltip.
  Closing an overlay immediately restores the strip for a retained selected
  or focused card, without requiring another input.
- **Turn banner.** ENEMY TURN appears only when the scheduled state's real
  activation selection chooses a live enemy before the next hero activation,
  including stale-entry skipping and due reinforcements. Back-to-back hero
  turns retain the next YOUR TURN banner without an intervening ENEMY TURN.
- **Pass plate.** While base plays remain, the plate's lead cell shows the Time
  icon and `+N` (the Wait the pass would pay) instead of TURN END.
  Because a pass can now span an enemy's unrevealed second activation, the
  forecast keeps the known damage and appends `+?` instead of collapsing to
  UNKNOWN.
- Copy: the TIME keyword reads "Delays your next turn. Each unused play takes 5."

Held for playtest: an ACT AGAIN turn banner replacing YOUR TURN. Rejected: a
faster/slower ring on the card's Time badge (it repeats the pill).

Design record and mockups: `output/time-turn-order-design-2026-10-08/` in the
primary checkout.
