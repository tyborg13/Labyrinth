# Hollow Mimic `hollow_mimic`

Design authority: `../peer_benchmark/briefs/en-06.md`, protected staged wave E2.
The unit brief's **this combat** takes precedence over the roster's older
**this round** wording. Standard shadow skirmisher: 14 HP, initiative 12,
11 Embers; compare Veilbound Acolyte's reach and Gloam Stalker's positioning.

4. Each damaging hero card action records its base card id in combat-wide
   `last_hero_attack_card`; actual enemy/terrain/illusion damage is required,
   including defense absorption. Nonattacks and misses do not replace it.
   Selection snapshots only the first damaging action: its native base damage,
   range, pattern, aim and element. The name remains `Mirror: <card>`.
   Relic, status, Empower and upgrade changes are excluded, along with surface,
   status, pierce, force, Chain, selector and other riders. The copy uses the
   card's attack icon in the row, compass and threats-at-rest pill and the exact
   tooltip `Mirror: it copies the last attack you played — <card>: <damage> damage.`
   Self-centred and facing areas originate at the mimic; ranged areas preserve
   their native centred targeting rules. If needed, approach up to 2 through
   the ordinary mover, respecting terrain, actors, hazards and Immobilize.
   Shock keeps the approach and denies damage. If still outside the copy's
   reach, disclose/resolve Shade Bolt. No attack history also selects Shade
   Bolt. Seeded weighted selection filters impossible attacks; Recede remains
   possible when the hero is unreachable.
5. Native Shade Bolt deals 4 shadow damage at range 4. Recede uses the existing
   move-away-2 then Block-4 verbs. The staged data is unchanged.

Mechanics: `scripts/enemy_mechanics/mimic.gd`; presentation: `mimic_view.gd`.
The ordinary save store persists history and the selected copy dictionary.
Changing history later does not change the already selected card. Presentation
recomputes geometry/fallback against the current board. Ordinary damage,
movement, Block, enemy-action analytics, and attack-family FX/audio are reused.

Director feedback 1 defines special targeting: self-target, Chain, summon,
blink, push/pull-only, surface-only, or another shape outside single-target,
line, or pattern area becomes a single ranged hit at range 4. It preserves
`Mirror: <card>`, the first damaging action's base damage and element, and
copies no riders. This uses Shade Bolt geometry without its fixed damage or
name. A force-only card that dealt collision damage has zero native base damage.
All shared intent pills and numeric tokens format computed values as integers.

Approved art was keyed/trimmed with repository helpers: 255 static canvas,
216px body (100% hero source height), Gaoler baseline 251, default art scale 1,
no offsets/idle sheet/new rig. The 128 portrait crops the faceted head at 1:1
with top silhouette 8px down. Approved `mirror` icon is independent of Charge;
processed icons, raw hashes, untouched density source, output record and shadow
cache are registered. No art generation or new audio.

The director adds `shadow_mimic` after merge: weight 2, hollow_mimic + wick_shade.
Authored weighted cadence is 17 Time at local depth 2 (fallbacks use Shade Bolt's
4 Time). Kill first or feed a smaller attack. The heuristic and scorer own the
same encounter assumptions, with unchanged intrinsic card coefficients.

Proof and exact commands: [en06 implementation handoff](en06_implementation_handoff.md).

## spx-04 — The Hollow Prior

Only the living Warband captain with `prior_veil` gives its distant followers
Veil and hidden-enemy presentation. Distance is the ordinary closest-footprint
Manhattan distance: more than 2 hides; entering 2 reveals. Existing Light and
Truesight reveal them. All hidden targeting, threat privacy, collision, captions
and information-limited forecasts use the ordinary visibility query. Revealed
veiled bodies reuse the existing Veil presentation; native Fade flags remain
independent. Captain death disables the aura immediately and reveals followers even through
room Umbra; missing captains in partial forecasts never count as death. Break clears every
follower's native Veil before the existing flee display. It never executes Fade
or Ambush. Ordinary Mimic and Fade/Ambush full-state goldens remain unchanged.
No new art, animation, sound, analytics events or save migration are introduced.

Validation and director capture commands: [spx-04 handoff](spx04_orders.md).
