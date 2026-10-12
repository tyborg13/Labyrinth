# Arc Thrall (`arc_thrall`)

Binding source: [en-03 brief](../peer_benchmark/briefs/en-03.md),
[shared rules](../peer_benchmark/briefs/en-common.md), and the protected entry in
`spec/peer_benchmark/staged/enemies/wave_e1.json`. Production data is copied
unchanged. Tempest Spire's standard spacing threat has 10 HP, initiative 11,
9 Embers, and accent `#a77bf0`.

1. `spawn_group: 2` is enforced only when RoomGenerator constructs the initial
   composition. Odd counts add a thrall, replacing the last other concrete unit
   when `max_units` is full. Summons and splits do not use this helper. An
   all-thrall odd composition already at its hard cap cannot satisfy “add a mate”;
   the implementation removes the unmatched remainder to preserve both the cap
   and even count. No current encounter table uses that impossible case.
2. Tether holds its partner id and approach in the selected intent. Clear rows
   and columns of length ≤6 hit strictly intermediate tiles; actors do not block
   the beam, terrain does. With no existing alignment, actual movement navigation
   chooses an approach of at most 3, prioritizing a beam through the hero and then
   shortest cost with stable tile/partner ordering. The exact path and beam are
   projected by the same helper used at resolution. A dead/out-of-line partner
   cancels the held beam instead of selecting a different partner. All occupants
   take 4 lightning + Shock 1 through existing damage/status helpers. Existing
   Ember drops, defense, retaliation, illusion retorts, and card kill-credit rules
   remain authoritative. Shock allows approach movement but cancels damage;
   Immobilize allows an already-aligned stationary beam.
3. Arc Jab uses the existing Move 2 and melee 3 + Shock 1 actions without new
   tuning or targeting policy.

The violet dashed chest-to-chest telegraph feeds the existing threat tiles, move
path and damage previews. Cancellation appears in intent rows and resolution;
the intent compass reports zero damage when the beam cannot resolve. The
resolution uses three seeded eight-segment jagged paths over 0.3 seconds,
with ±3 px perpendicular jitter and alpha 100% / 40% / 100%, followed by a
0.1-second fade. It retains the existing lightning Chain ribbon material and
attack cue. The telegraph is 2 px `#a77bf0` at 85% alpha, with 10 px dashes,
6 px gaps and 24 px/s scrolling; reduced motion holds it static. Retained effects
layers redraw at the existing continuous-presentation cadence. Card aim effects
retain their own forecast and still show beam damage previews on other occupants.
The keyword tooltip is “Tether: lightning strikes every tile between the two Arc
Thralls for 4 and Shocks. Break the line to stop it.”

Art: `assets/art/enemies/arc_thrall.png`, static 255×255 fallback; natural scale
1.0 and no added offsets. Approved raw SHA-256 is recorded in
`spec/assets/enemies/raw_sha256.txt`. Registration uses Gaoler's measured base
y=251, body height 94.98% of the Lancer reference. Density processing adopts the
untouched registration, processes it, records the static pipeline's zero rig
rests, and checks the output. Portrait `assets/art/portraits/arc_thrall.png` is an
exact 128×128 crop of processed production art centered on the measured head,
with silhouette top y=8. No images or audio were generated.

Authored repeat comparison: Tether 16, Jab 15, weighted 15.6 before spawn
stagger. Lightning Wisp is the closest existing Shock-pressure comparison;
Tether adds a held partner and a friendly-fire lane. Counterplay is to leave the
lane, displace/kill a partner, or push an enemy into it. Local depth/sequence
scaling remains the existing engine policy. Encounter groups are added by the director on the integration branch; this unit
leaves `data/encounters.json` untouched, as directed in feedback 1.

Implementation and headless proof: `scripts/enemy_mechanics/tether.gd`,
`tether_view.gd`, `tests/suites/en03_enemies_suite.gd`, and
`tests/en03_fixture_check.gd`. Windowed proof and exact launch commands are in
[the en-03 handoff](en03_handoff.md).
