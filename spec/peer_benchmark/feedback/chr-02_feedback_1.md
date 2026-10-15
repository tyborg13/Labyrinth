# chr-02 feedback 1 (director)

The director ran the windowed chronicle probe (log: `output/chr02_windowed_probe.log` in this worktree). It failed before
any capture:
```
ERROR: Native hover creates a custom tooltip: Spell_chain_bolt
ERROR: Native hover creates a custom tooltip: Relic_iron_lung
ERROR: Native hover creates a custom tooltip: ChronicleSpellsOverflow
CHRONICLE PROBE RESULT: FAIL
```
1. Find out whether this is a probe artifact (e.g. tooltip delay, synthetic mouse motion not reaching the control in a
   windowed SubViewport, mouse_filter on a parent) or a **real bug** where hovering a chronicle tile in the game shows no
   tooltip. State the root cause with evidence. If it is real, fix it in `chronicle_panel.gd` (mouse, keyboard and
   controller focus must all show the tooltip). If it is the probe, make the probe drive hover the way a real mouse does
   (parsed `InputEventMouseMotion` at the tile centre in the same viewport, waiting the project's tooltip delay plus
   settle frames) and keep the assertion strict.
2. TODO_DESIGN_MISSING_CARD_DEFINITION: the fixture's card names (Cinderburst, Frost Lance, Glacier Step) are stale —
   replace them in the fixture with current cards that have definitions and art (pick any three existing cards of
   different elements); never invent cards.
3. Missing baseline PNGs: regenerate them from the current tree in the probe's own output; no committed baselines needed.
Do not commit. List the windowed command again.
