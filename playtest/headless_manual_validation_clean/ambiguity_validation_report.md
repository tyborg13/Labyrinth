# Headless Ambiguity Validation

- Seed: 9910
- Outcome: rested at the depth 2 campfire after 7 combat victories
- Banked: 193 embers
- Final HP: 15/36

## Harness Updates Validated

- Enemy intent lines now include the intent name and action payloads.
- Pass previews now show exact incoming HP/block/status deltas and enemy step details.
- Trap listings and movement/shortcut hints now expose trap damage and status risk before committing.
- Card resolution now prints skipped actions, new log lines, draws, restrictions, and play economy.
- Kill-granted plays and card-action plays are surfaced in both card resolution and combat headers.
- Enemy block/stoneskin removal now appears in target hints and resolution summaries.
- Pending enemy targets are labeled as `enemy N`, and `target eN` selects by enemy index to avoid confusing choice indices with enemy indices.
- `card_played` analytics now logs post-resolution play spend, remaining plays, play gains, and health-cost effects.

## Playtest Notes

- No remaining hidden-source ambiguity showed up in the clean run after the block-removal and play-economy fixes. Damage, burn, fatigue, trap stun, illusion damage, block loss, and kill/card play refunds were all traceable from the text UI.
- The one harness-only UX issue found during the run was target index confusion: target-choice indices and enemy indices can diverge. This is now addressed with enemy labels and `target eN`.
- Balance signal from the run: kill-granted plays are a major tempo engine. Whirlwind Slash, Quick Stab, and Bloody Lunge chained especially well with Ember Lens and Pilgrim Boots.
- Low HP pressure was persistent. I skipped five of seven card rewards for healing and still rested at 15/36 HP after the first depth-2 combat.
