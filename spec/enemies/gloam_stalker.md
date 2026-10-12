# Gloam Stalker (`gloam_stalker`)

Binding source: [en-03 brief](../peer_benchmark/briefs/en-03.md),
[shared rules](../peer_benchmark/briefs/en-common.md), and the protected entry in
`spec/peer_benchmark/staged/enemies/wave_e1.json`. Production data is copied
unchanged. Noctyrax's domain's skirmisher has 11 HP, initiative 10, 10 Embers,
and accent `#8a6bd6`.

4. Fade sets `veiled` and Blinks at most 4 to the free adjacent tile behind the
   hero's last voluntary movement direction in the current round. With no such
   movement, it uses the opposite of the hero-to-stalker start direction. The
   nearest free adjacent alternative uses stable existing cardinal ordering;
   with none in range, it stays and only veils. Single-target attacks/cards must
   originate from an adjacent hero tile. This gate covers ordinary, prevalidated
   and previous-target resolution. Area, surfaces, secondary Chain/conduction,
   and pushing another unit into it use the existing unrestricted hit paths.
   Walking records the final successful step; Blink and swaps record their
   displacement direction. The round-tagged direction and `veiled` are ordinary
   persisted Variant fields. Undo restores the direction with the walk snapshot;
   old saves without either field retain their previous behavior.
5. The generic `next_intent` contract forces Ambush after Fade; weight 0 intents
   cannot roll randomly. Ambush targets the hero, re-Blinks behind them within 4
   if no longer adjacent, hits for melee 7, and ends Veil after the strike. The
   normal melee threat tile is the hero tile from the actual projected position.
   If no legal adjacent strike exists even after Blink, the shared “no impossible
   intent” rule takes precedence and selects Slash as the fallback. Shock/Freeze
   and Immobilize use existing activation restrictions.
6. Slash retains existing Move 2 and melee 4 behavior.

Veiled body alpha is 35%, with a 2 px rim in `#8a6bd6`; the ordinary health bar,
intent and status row remain visible. Fade and Ambush re-Blink reuse existing
blink rift FX, including the actual enemy's afterimage, and Ambush uses the
existing melee presentation and sound. Three small violet curls start at 30%
alpha and fade to zero while rising 12 px over 1.6 seconds, staggered by 0.53
seconds and looping while veiled. They use native curve tessellation and the
existing 2 px rim stroke, within the supplied rise envelope. Reduced motion
omits wisps; retained actor layers otherwise redraw at the existing cadence.
The tooltip is “Veiled: only attacks from an adjacent tile, or area effects, can
hit it.” Invalid-target feedback reads “Veiled — attack from an adjacent tile.”
The engine and action-context target state share that reason. Invalid clicks and
board drag releases display it through the existing transient message overlay,
with its unchanged typography, position and duration.

Art: `assets/art/enemies/gloam_stalker.png`, static 255×255 fallback; natural
scale 1.0 and no added offsets. Approved raw SHA-256 is recorded in
`spec/assets/enemies/raw_sha256.txt`. Registration uses Gaoler's measured base
y=251, body height 92.47% of the Lancer reference, constrained by canvas width.
Density processing adopts and treats the untouched registration and verifies
the output. Portrait `assets/art/portraits/gloam_stalker.png` is an exact 128×128
crop of processed production art centered on the measured mask/head, with
silhouette top y=8. No images or audio were generated.

Authored repeat comparison: Fade 15, Ambush 15, Slash 14; including the forced
step, the weighted cadence is 14.75 per activation when the sequence is legal.
Tunnel Crawler is the closest existing melee-closure comparison. Counterplay is
to move away from the shown strike, block, or use area attacks; adjacent attacks
still work through Veil. Local depth/sequence scaling remains existing policy.
Encounter groups are added by the director on the integration branch; this unit
leaves `data/encounters.json` untouched, as directed in feedback 1.

Implementation and headless proof: `scripts/enemy_mechanics/veil.gd`,
`veil_view.gd`, `tests/suites/en03_enemies_suite.gd`, and
`tests/en03_fixture_check.gd`. Both Fade and Ambush retain existing
`enemy_action_resolved` events; neither is mislabeled as a status tick. Windowed
proof and exact launch commands are in [the en-03 handoff](en03_handoff.md).
