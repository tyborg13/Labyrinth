# deck-01 — round 2 (director's renderer review)

Director edits already in your worktree (keep): `data/glossary.json` Character ("loadout") definition is now
"The menu for your gear, magic, items and skills. Your gear, magic and items make up your deck; spells go straight
into it when you gain them." (your replacement had dropped what the menu is), and the matching assertion in
`tests/suites/magic_deck_suite.gd:103`. Full suite otherwise PASS (811 s) with that one assertion failing before my fix.

Purge confirmation looks unfinished (scavenger_purge_confirm.png): left-aligned copy with no padding against the panel
edge, full-width bar buttons with right-aligned labels, and the list overlay so translucent that the Scavenger's quote
box shows through. Fix:
1. Use the game's existing confirmation dialog component if one exists (find the one used by other confirmations,
   e.g. selling, abandoning a run); otherwise: centred modal 560×240 in the standard modal panel style, backdrop dim
   black at 70% over everything (nothing underneath readable), 32 px inner padding.
2. Content, centred: title "Purge <Card>?" (heading style), under it the price line "<n> Embers" with the same Ember
   glyph/style as shop prices (Scavenger only; Campfire omits the line).
3. Buttons side by side, centred, 200×52 each, 24 px gap: "Cancel" (secondary) left, "Purge" (UiPalette.DANGER)
   right; keyboard/controller focus starts on Cancel; Esc = Cancel.
4. The "PURGE A SPELL" list overlay itself also gets the 70% backdrop so the Scavenger UI underneath is not readable.
Re-run the deck-01 probe command list and the full suite once. Do not commit.
