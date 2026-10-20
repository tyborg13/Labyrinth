# ui-03 feedback 3 (director; windowed proof review of 0fcaae41b)

Round 2 works: the seal tooltip shows in both states, and the clip is clean of desktop input. One fix remains.
Focused tests only.

1. **While the pointer is on the seal, the seal tooltip is the only tooltip.**
   - Evidence:
     - `charged_seal_tooltip.png`: the seal tooltip sits on top of the card's keyword stack, covering "Modified by"
       and the "EMPOWER · ACTIVE" title.
     - The clip, frame ~225 onward: right after the charge click, the stack re-opens with the pointer still on the seal.
   - In the unlit state the stack already stays hidden while the seal is hovered. Make the charged state match: a
     charge toggle that re-lays out the hand must not re-open the card's keyword stack while the pointer is on the
     seal.
   - When the pointer moves from the seal back onto the card body, the stack returns: "EMPOWER · ACTIVE" when charged,
     with the modified entries.
   - Controller focus is unchanged.
   - Add a regression with routed pointer motion: hover the card, move onto the seal, click to charge, hold. Exactly one
     tooltip is visible (the seal's). Move back onto the card body: the stack is visible with "EMPOWER · ACTIVE".
     It fails before the change.
2. Re-list the same two windowed commands.
