Historical feedback 6 evidence. Current backing CPU results are in [per_clip.md](per_clip.md); current native backing proof is pending. This preserves the original native before table and its historical comparisons.

| Creature / clip | Original pose | Original CPU/native detached px (>3 px) | Original islands | Final CPU detached px/islands | Final native detached px/islands |
| --- | ---: | ---: | ---: | ---: | --- |
| shale_bloomer/front_idle | 0030 | 19/19 | 1 | 0/0 | pending |
| shale_bloomer/front_move | 0006 | 20/20 | 3 | 0/0 | pending |
| shale_bloomer/front_burst | 0019 | 9/9 | 7 | 0/0 | pending |
| shale_bloomer/front_shot | 0017 | 11/11 | 6 | 0/0 | pending |
| shale_bloomer/front_shell | 0019 | 37/37 | 8 | 0/0 | pending |
| shale_bloomer/front_hit | 0020 | 182/182 | 2 | 0/0 | pending |
| shale_bloomer/front_death | 0030 | 207/207 | 10 | 0/0 | pending |
| shale_bloomer/rear_idle | 0000 | 0/0 | 0 | 0/0 | pending |
| shale_bloomer/rear_move | 0012 | 1/1 | 1 | 0/0 | pending |
| shale_bloomer/rear_burst | 0022 | 6/6 | 4 | 0/0 | pending |
| shale_bloomer/rear_shot | 0023 | 2/2 | 2 | 0/0 | pending |
| shale_bloomer/rear_shell | 0047 | 25/25 | 15 | 0/0 | pending |
| shale_bloomer/rear_hit | 0013 | 4/4 | 4 | 0/0 | pending |
| shale_bloomer/rear_death | 0036 | 29/29 | 17 | 0/0 | pending |
| lightning_wisp/front_idle | 0000 | 0/0 | 0 | 0/0 | 0/0 (run 4) |
| lightning_wisp/front_move | 0000 | 0/0 | 0 | 0/0 | 0/0 (run 4) |
| lightning_wisp/front_strike | 0000 | 0/0 | 0 | 0/0 | 0/0 (run 4) |
| lightning_wisp/front_cast | 0000 | 0/0 | 0 | 0/0 | 0/0 (run 4) |
| lightning_wisp/front_hit | 0004 | 1/1 | 1 | 0/0 | 0/0 (run 4) |
| lightning_wisp/front_death | 0019 | 1/1 | 1 | 0/0 | 0/0 (run 4) |
| lightning_wisp/rear_idle | 0000 | 0/0 | 0 | 0/0 | 0/0 (run 4) |
| lightning_wisp/rear_move | 0000 | 0/0 | 0 | 0/0 | 0/0 (run 4) |
| lightning_wisp/rear_strike | 0000 | 0/0 | 0 | 0/0 | 0/0 (run 4) |
| lightning_wisp/rear_cast | 0000 | 0/0 | 0 | 0/0 | 0/0 (run 4) |
| lightning_wisp/rear_hit | 0000 | 0/0 | 0 | 0/0 | 0/0 (run 4) |
| lightning_wisp/rear_death | 0000 | 0/0 | 0 | 0/0 | 0/0 (run 4) |

All final CPU detached counts are also zero under the stricter >2 px rule. Wisp run 4 has zero new holes and zero detached pixels in all 750 native poses. Bloomer’s native after is pending. Original before values are the saved captures and replay documented in feedback 4.

The table below retains the CPU pre-feedback-6 comparison and original native-hole context:

| View / clip | CPU holes before round 6 → after (max px) | Saved original native holes (max px) | Native after |
| --- | ---: | ---: | --- |
| front/idle | 98 → 91 | 219 | pending |
| front/move | 186 → 172 | 303 | pending |
| front/burst | 2 → 0 | 96 | pending |
| front/shot | 162 → 160 | 185 | pending |
| front/shell | 115 → 115 | 118 | pending |
| front/hit | 54 → 50 | 165 | pending |
| front/death | 129 → 126 | 136 | pending |
| rear/idle | 56 → 49 | 93 | pending |
| rear/move | 74 → 71 | 142 | pending |
| rear/burst | 2 → 2 | 94 | pending |
| rear/shot | 2 → 0 | 101 | pending |
| rear/shell | 29 → 29 | 68 | pending |
| rear/hit | 85 → 54 | 259 | pending |
| rear/death | 56 → 55 | 76 | pending |

Holes use the unchanged four-connected-background gate, minimum component size 2 px, registered against rest. These gate totals are distinct from the director’s visual sum of all seam cracks. The motion edit and support were not applied to any saved native frame.
