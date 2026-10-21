# spx-01 feedback 1 (director: the bot is too weak to measure anything)

The analytics fix, sweep, determinism and goldens are good. Keep them all. The baseline can't be used yet:

- the bot wins 12.5% of tier-1 Defeat All rooms and 0% at tier 3, with a median HP loss of 24 (it dies);
- the owner's real logs show 28 wins in 32 Defeat All rooms, with a median of 1.5 HP lost.

A baseline that loses almost everything can't measure bands such as "a median deck reaches the captain in 2–3 turns".
The policy misses what real players do most: act, then use the remaining free movement to step out of telegraphed
attacks. The proposal names this as the dominant answer ("the free step solves almost every warning").

1. **End-of-turn dodge.** After the last card, spend the remaining free movement on the reachable tile with the lowest
   incoming-preview damage. Ties go to the tile nearest the objective (enemies, the leader or the exit). Search
   combinations of movement before a card and the dodge after it within your existing bounds.
2. **Value defense properly.** Block and Stoneskin cards should score the incoming damage they prevent this enemy
   phase, through the same preview. Don't play a card whose preview kills you if any other option doesn't.
3. **Target.** Tier-1 Defeat All win rate of at least 70%, and tier-1 median HP lost of 8 or less. If the bounded
   search can't get there, report the best configuration you found and stop. Don't loosen the decks or the HP.
4. **Re-run the 1,800-run baseline** with the new policy. Keep the old one as `baseline_policy_v1` for comparison and
   bump a `policy_version` field.
5. **Repo weight:** keep the gzipped raw records and the summary JSON. Drop the per-process logs from the commit and
   keep them under `/private/tmp`.

Focused tests only. Keep everything else from this round.
