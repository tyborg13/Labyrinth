# deck-01 — round 1 (director decisions for the TODO_DESIGN placeholders)

1. Scavenger price progression counts paid (Scavenger) purges only; Campfire purges never raise it. Keep.
2. Purge presentation (reuse, nothing new):
   - Layout: the existing modal/overlay style of the visual design system, with the same "MAGIC IN DECK" list
     component as the Character panel (sorted, counted, card hover previews), one row selectable, then a confirm step.
   - Copy (exact):
     - Scavenger service row: title "Purge", line "Remove a spell from your deck.", price "<n> Embers".
     - Campfire choice: "Purge" / "Remove a spell from your deck." (beside the existing rest choice, unchanged).
     - Overlay header: "PURGE A SPELL"; confirm: "Purge <Card>?" with buttons "Purge" and "Cancel"; afterwards the
       notice "Purged <Card>."
     - Event requirement when the deck holds no magic: "Requires a spell in your deck."
   - Accent: the existing accent already used for Exhaust/destructive actions in UiPalette (no new colour). If none
     exists, use UiPalette.GOLD_BRIGHT for the selection only.
   - Audio: reuse the existing card-exhaust/burn UI cue for the confirmed purge; no new sound.
   - Icon: none. If the Scavenger service layout requires an icon per service, leave `TODO_DESIGN_purge_icon` and use
     the layout's text-only fallback; do not reuse another concept's icon (icon identity policy).
3. Glossary/Grimoire copy: replace every player-facing mention of attuned/reserve/learned magic or six magic slots.
   Glossary "Magic" (or the closest entry): "Spells go straight into your deck when you gain them. Purge removes one."
   List every changed string in the result (before → after). Legacy trailer tooling: leave it untouched and list it.
Focused tests + the windowed probe command; full suite once at the end. Do not commit.
