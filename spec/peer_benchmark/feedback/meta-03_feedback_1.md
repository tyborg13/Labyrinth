# meta-03 feedback 1 (director)

Native captures match the mockup (picker at 3, two-column 12, combat header tag). Decide the placeholders and close the
shop gap:

1. Guardian extra helper (depth 19): Rimejaw → `rime_whelp`; Storm Cantor → `bell_tender` (use the Guardian's first
   listed helper type for any other Guardian with several).
2. Dense rows (N > 10): row pitch 30 px at the 19 px size, 40 px gap between the two columns, numbers keep the UI 15 px
   TEXT_3 style.
3. Unlock hint under the list: Text 17 px TEXT_3.
4. Saving the last chosen depth fails: start the run at the chosen depth anyway, keep the choice in memory for this
   session, log one error; no player-facing message.
5. **Shop prices**: depth 13's Scavenger price rule must show in the shop UI (displayed buy prices = charged prices).
   You may edit the Scavenger/shop UI script that formats buy prices (minimal, call `DepthRules`). Regression: at
   depth 13 the displayed price equals the charged price for every buyable item; depth 0 unchanged.

Proof: depth suite + full suite green; re-list the windowed command.
