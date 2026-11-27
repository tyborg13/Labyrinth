# Enemy-turn pacing census

Headless witness at default Combat speed, reduced motion off and 100% UI scale. Wall milliseconds begin at Pass. Headless timing includes CPU work and simulated draw boundaries. See [waits.md](waits.md) for the source audit.

## Headless totals

| Fixture | Pass to endpoint (ms) | Actions | ms/action | Still (ms) | Endpoint |
|---|---:|---:|---:|---:|---|
| 01-s0-seed1-0-4_0-t9 | 4515.9 | 2 | 2258.0 | pending | hero tile opened movement selection |
| 02-s0-seed12-0-1_3-t7 | 9332.5 | 6 | 1555.4 | pending | hero tile opened movement selection |
| 03-s2-seed8-2-11_-9-t64 | 1507.4 | 0 | — | pending | hero tile opened movement selection |
| 04-s0-seed8-0--3_2-t5 | 10152.4 | 6 | 1692.1 | pending | hero tile opened movement selection |
| 05-s2-seed1-2-9_-7-t2 | 6228.4 | 5 | 1245.7 | pending | hero tile opened movement selection |
| 06-s2-seed1-2-11_-10-t5 | 11492.1 | 8 | 1436.5 | pending | hero tile opened movement selection |
| 07-s4-seed1-4-19_-19-t4 | 12309.4 | 8 | 1538.7 | pending | card 0 entered selection |
| 08-s1-seed8-1-5_-4-t5 | 2699.3 | 1 | 2699.3 | pending | hero tile opened movement selection |
| 09-s3-seed12-3-16_0-t15 | 3535.7 | 2 | 1767.9 | pending | hero tile opened movement selection |
| 10-s3-seed12-3-13_-2-t4 | 5455.3 | 2 | 2727.7 | pending | hero tile opened movement selection |
| 11-s4-seed12-4-19_-14-t4 | 13637.1 | 8 | 1704.6 | pending | hero tile opened movement selection |
| 12-s1-seed1-1-7_-3-t3 | 11222.9 | 8 | 1402.9 | pending | card 0 entered selection |

An action is a production pacing action step, movement, reinforcement arrival or Worldspine pulse. Intent, rail reordering and state-only bookkeeping are separate events. Overlapping durations are not additive. A clipped span was still live at the input boundary.

## Headless beat durations

Sorted by median. The first ten rows are the ten slowest beat types in the witness.

| Beat | Samples | Median (ms) | Max (ms) |
|---|---:|---:|---:|
| caption shown | 46 | 1621.1 | 4891.3 |
| death animation | 1 | 1506.0 | 1506.0 |
| action | 56 | 1240.9 | 2630.9 |
| sampled playback | 41 | 1013.3 | 1789.2 |
| surface effect | 44 | 781.0 | 822.8 |
| defeated body held | 1 | 748.0 | 748.0 |
| contact to last number gone | 29 | 738.5 | 941.9 |
| hero fatigue | 4 | 658.9 | 755.0 |
| number on screen | 73 | 651.3 | 864.2 |
| feedback deadline | 11 | 580.3 | 1202.4 |
| hero turn-start fire | 4 | 563.8 | 571.8 |
| wind-up to contact | 29 | 491.8 | 1131.4 |
| hand draw | 11 | 478.6 | 542.4 |
| camera move | 38 | 445.5 | 588.8 |
| unit move | 11 | 384.2 | 1013.8 |
| turn banner shown | 9 | 304.5 | 734.9 |
| caption lead before motion or feedback | 42 | 275.2 | 999.0 |
| pre-action delay | 29 | 258.9 | 339.0 |
| hero hand-off drain | 12 | 189.9 | 245.7 |
| floating feedback | 37 | 185.9 | 616.4 |
| turn-order rail | 132 | 162.1 | 1323.7 |
| post-action settle | 45 | 156.6 | 336.3 |
| hit stop | 38 | 136.0 | 279.2 |
| publish hero UI | 12 | 47.7 | 85.8 |
| locked hand capture | 24 | 0.1 | 0.3 |
| defeat playback | 14 | 0.1 | 0.1 |

## Headless timelines

### 01-s0-seed1-0-4_0-t9

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 74.4 | 74.4 | — |  | locked hand capture | — |
| 123.9 | 124.0 | — |  | locked hand capture | — |
| 184.7 | 184.8 | — |  | defeat playback | — |
| 186.2 | 195.6 | — |  | turn-order rail | — |
| 188.3 | 188.3 | 0 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 202.3 | 476.3 | 0 |  | turn-order rail | — |
| 211.4 | 211.4 | 1 | enemy_1 | step dispatched | {"kind":"intent","label":"Faultline"} |
| 212.1 | 363.9 | 1 | enemy_1 | pre-action delay | — |
| 390.8 | 390.8 | 2 | enemy_1 | step dispatched | {"kind":"aoe","label":"Faultline"} |
| 390.8 | 2156.3 | 2 | enemy_1 | action | {"kind":"aoe","label":"Faultline"} |
| 395.7 | 1985.3 | 2 | enemy_1 | sampled playback | {"authored_ms":1100.0,"frames":66} |
| 440.6 | 440.6 | 2 | enemy_1 | attack wind-up | {"kind":"aoe","sample":1} |
| 440.6 | 1177.7 | 2 | enemy_1 | wind-up to contact | {"derived":true} |
| 440.8 | 1181.0 | 2 | enemy_1 | caption lead before motion or feedback | {"derived":true} |
| 440.8 | 4194.4 | 2 | enemy_1 | caption shown | {"text":"Faultline"} |
| 1154.0 | 1348.5 | 2 | enemy_1 | hit stop | {"requested_ms":105.0} |
| 1177.7 | 1965.3 | 2 | enemy_1 | contact to last number gone | {"derived":true} |
| 1177.7 | 1177.7 | 2 | enemy_1 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":42,"sample":36,"sample_count":66} |
| 1177.7 | 1177.7 | 2 | enemy_1 | impact effect start | {"targets":["player"]} |
| 1181.0 | 1769.8 | 2 | enemy_1 | camera move | {"kind":"board kick"} |
| 1181.0 | 2003.8 | 2 | enemy_1 | surface effect | {"kind":"dragon_spire_pulse","surface":"","tile":"","trigger":""} |
| 1181.0 | 2003.8 | 2 | enemy_1 | surface effect | {"kind":"surface_created","surface":"rubble","tile":"(6, 4)","trigger":""} |
| 1181.0 | 2003.8 | 2 | enemy_1 | surface effect | {"kind":"surface_created","surface":"rubble","tile":"(3, 4)","trigger":""} |
| 1181.0 | 2003.8 | 2 | enemy_1 | surface effect | {"kind":"surface_created","surface":"rubble","tile":"(2, 4)","trigger":""} |
| 1181.0 | 2003.8 | 2 | enemy_1 | surface effect | {"kind":"surface_created","surface":"rubble","tile":"(6, 5)","trigger":""} |
| 1181.0 | 2003.8 | 2 | enemy_1 | surface effect | {"kind":"surface_created","surface":"rubble","tile":"(3, 5)","trigger":""} |
| 1181.0 | 2003.8 | 2 | enemy_1 | surface effect | {"kind":"surface_created","surface":"rubble","tile":"(2, 5)","trigger":""} |
| 1181.0 | 1965.3 | 2 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"","text":"−4","tile":"(6, 4)"} |
| 1181.0 | 1965.3 | 2 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"","text":"−4","tile":"(3, 4)"} |
| 1181.0 | 1965.3 | 2 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"","text":"−4","tile":"(2, 4)"} |
| 1181.0 | 1965.3 | 2 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"","text":"−4","tile":"(6, 5)"} |
| 1181.0 | 1965.3 | 2 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"","text":"−4","tile":"(3, 5)"} |
| 1181.0 | 1965.3 | 2 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"","text":"−4","tile":"(2, 5)"} |
| 1181.0 | 1965.3 | 2 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−8","tile":"(4, 4)"} |
| 1986.1 | 2001.4 | 2 | enemy_1 | floating feedback | {"numbers":7} |
| 2002.8 | 2922.5 | 2 | enemy_1 | turn-order rail | — |
| 2003.5 | 2156.3 | 2 | enemy_1 | post-action settle | — |
| 2156.5 | 2156.5 | 3 | enemy_1 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 2156.6 | 3906.5 | 3 | enemy_1 | action | {"kind":"ranged","label":"Shot"} |
| 2160.9 | 3728.0 | 3 | enemy_1 | sampled playback | {"authored_ms":1100.0,"frames":66} |
| 2178.9 | 2178.9 | 3 | enemy_1 | attack wind-up | {"kind":"ranged","sample":1} |
| 2178.9 | 2946.1 | 3 | enemy_1 | wind-up to contact | {"derived":true} |
| 2934.9 | 3123.3 | 3 | enemy_1 | hit stop | {"requested_ms":85.0} |
| 2946.1 | 3747.9 | 3 | enemy_1 | contact to last number gone | {"derived":true} |
| 2946.1 | 2946.1 | 3 | enemy_1 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":93,"sample":37,"sample_count":66} |
| 2946.1 | 2946.1 | 3 | enemy_1 | impact effect start | {"targets":["player"]} |
| 2947.2 | 3388.1 | 3 | enemy_1 | camera move | {"kind":"board kick"} |
| 2947.2 | 3747.9 | 3 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−4","tile":"(4, 4)"} |
| 3729.4 | 3742.6 | 3 | enemy_1 | floating feedback | {"numbers":1} |
| 3745.8 | 3924.9 | 3 | enemy_1 | turn-order rail | — |
| 3747.2 | 3906.5 | 3 | enemy_1 | post-action settle | — |
| 3906.9 | 3906.9 | 4 | enemy_1 | step dispatched | {"kind":"intent_refresh","label":""} |
| 3924.6 | 3924.6 | 5 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 3927.8 | 3939.3 | 5 |  | turn-order rail | — |
| 3938.9 | 3938.9 | 6 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 3945.4 | 4132.8 | 6 |  | turn-order rail | — |
| 3954.5 | 4141.9 | — |  | hero hand-off drain | — |
| 4159.6 | 4440.7 | — |  | hand draw | {"cards":1} |
| 4441.1 | 4491.0 | — |  | publish hero UI | — |
| 4445.8 | 4445.8 | — |  | hero turn banner suppressed | {"boss_hud_or_caption":true} |
| 4515.8 | 4515.8 | — |  | ground state changed | {"kind":"surface_created","surface":"rubble","tile":"(2, 5)","trigger":""} |
| 4515.8 | 4515.8 | — |  | ground state changed | {"kind":"surface_created","surface":"rubble","tile":"(3, 5)","trigger":""} |
| 4515.8 | 4515.8 | — |  | ground state changed | {"kind":"surface_created","surface":"rubble","tile":"(6, 5)","trigger":""} |
| 4515.8 | 4515.8 | — |  | ground state changed | {"kind":"surface_created","surface":"rubble","tile":"(2, 4)","trigger":""} |
| 4515.8 | 4515.8 | — |  | ground state changed | {"kind":"surface_created","surface":"rubble","tile":"(3, 4)","trigger":""} |
| 4515.8 | 4515.8 | — |  | ground state changed | {"kind":"surface_created","surface":"rubble","tile":"(6, 4)","trigger":""} |
| 4515.9 | 4515.9 | — |  | hero input accepted | — |

### 02-s0-seed12-0-1_3-t7

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 5.2 | 5.2 | — |  | enemy turn banner requested | — |
| 35.5 | 340.0 | — |  | turn banner shown | {"text":"ENEMY TURN"} |
| 53.6 | 53.6 | — |  | locked hand capture | — |
| 142.2 | 142.3 | — |  | defeat playback | — |
| 145.7 | 149.5 | — |  | turn-order rail | — |
| 149.1 | 149.1 | 0 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 157.4 | 452.7 | 0 |  | turn-order rail | — |
| 168.2 | 168.2 | 1 | enemy_5 | step dispatched | {"kind":"intent","label":"Hiss Back"} |
| 168.9 | 360.0 | 1 | enemy_5 | pre-action delay | — |
| 340.0 | 375.1 | 1 | enemy_5 | caption lead before motion or feedback | {"derived":true} |
| 340.0 | 1469.5 | 1 | enemy_5 | caption shown | {"text":"Cinder Droplet: Hiss Back"} |
| 352.1 | 352.3 | 1 | enemy_5 | locked hand capture | — |
| 374.6 | 374.6 | 2 | enemy_5 | step dispatched | {"kind":"move","label":"Retreat"} |
| 374.7 | 621.7 | 2 | enemy_5 | action | {"kind":"move","label":"Retreat"} |
| 375.1 | 576.8 | 2 | enemy_5 | unit move | {"actor":"enemy_5","tiles":1} |
| 375.6 | 576.8 | 2 | enemy_5 | sampled playback | {"authored_ms":183.333333333333,"frames":28} |
| 621.9 | 621.9 | 3 | enemy_5 | step dispatched | {"kind":"block","label":"Guard"} |
| 621.9 | 1406.1 | 3 | enemy_5 | action | {"kind":"block","label":"Guard"} |
| 622.5 | 622.5 | 3 | enemy_5 | resolved block | {"actor":"enemy_5","kind":"block","label":"Guard","rule":"","target":"(2, 4)"} |
| 622.6 | 1230.8 | 3 | enemy_5 | floating feedback | {"numbers":1} |
| 656.3 | 1233.8 | 3 | enemy_5 | number on screen | {"category":"status","icon":"block","reaction":"","text":"+2","tile":"(2, 4)"} |
| 1233.5 | 1406.1 | 3 | enemy_5 | post-action settle | — |
| 1406.4 | 1406.4 | 4 | enemy_5 | step dispatched | {"kind":"intent_refresh","label":""} |
| 1421.6 | 1421.6 | 5 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 1422.4 | 1452.3 | 5 |  | turn-order rail | — |
| 1452.0 | 1452.0 | 6 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 1458.4 | 1630.3 | 6 |  | turn-order rail | — |
| 1468.6 | 1468.6 | 7 | enemy_4 | step dispatched | {"kind":"intent","label":"Skitter Strike"} |
| 1468.8 | 1734.1 | 7 | enemy_4 | pre-action delay | — |
| 1469.5 | 3038.6 | 7 | enemy_4 | caption shown | {"text":"Tunnel Crawler: Skitter Strike"} |
| 1469.5 | 1758.5 | 7 | enemy_4 | caption lead before motion or feedback | {"derived":true} |
| 1745.4 | 1745.4 | 8 | enemy_4 | step dispatched | {"kind":"melee","label":"Strike"} |
| 1745.5 | 2994.8 | 8 | enemy_4 | action | {"kind":"melee","label":"Strike"} |
| 1750.3 | 2644.7 | 8 | enemy_4 | sampled playback | {"authored_ms":600.0,"frames":36} |
| 1758.5 | 2081.5 | 8 | enemy_4 | wind-up to contact | {"derived":true} |
| 1758.5 | 1758.5 | 8 | enemy_4 | attack wind-up | {"kind":"melee","sample":1} |
| 2070.1 | 2224.2 | 8 | enemy_4 | hit stop | {"requested_ms":85.0} |
| 2081.5 | 2081.5 | 8 | enemy_4 | impact effect start | {"targets":["player"]} |
| 2081.5 | 2819.9 | 8 | enemy_4 | contact to last number gone | {"derived":true} |
| 2081.5 | 2081.5 | 8 | enemy_4 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":289,"sample":16,"sample_count":36} |
| 2082.8 | 2537.9 | 8 | enemy_4 | camera move | {"kind":"board kick"} |
| 2082.8 | 2819.9 | 8 | enemy_4 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−5","tile":"(3, 3)"} |
| 2645.6 | 2834.1 | 8 | enemy_4 | floating feedback | {"numbers":1} |
| 2836.8 | 2999.6 | 8 | enemy_4 | turn-order rail | — |
| 2837.6 | 2994.8 | 8 | enemy_4 | post-action settle | — |
| 2994.9 | 2994.9 | 9 | enemy_4 | step dispatched | {"kind":"intent_refresh","label":""} |
| 2999.3 | 2999.3 | 10 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 3003.3 | 3019.9 | 10 |  | turn-order rail | — |
| 3019.6 | 3019.6 | 11 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 3027.8 | 3196.3 | 11 |  | turn-order rail | — |
| 3037.6 | 3037.6 | 12 | enemy_1 | step dispatched | {"kind":"intent","label":"Icefall"} |
| 3037.9 | 3342.6 | 12 | enemy_1 | pre-action delay | — |
| 3038.6 | 3361.4 | 12 | enemy_1 | caption lead before motion or feedback | {"derived":true} |
| 3038.6 | 6039.0 | 12 | enemy_1 | caption shown | {"text":"Hoarfrost Seer: Icefall"} |
| 3352.0 | 3352.0 | 13 | enemy_1 | step dispatched | {"kind":"aoe","label":"Icefall"} |
| 3352.1 | 5983.0 | 13 | enemy_1 | action | {"kind":"aoe","label":"Icefall"} |
| 3354.9 | 4504.8 | 13 | enemy_1 | sampled playback | {"authored_ms":800.0,"frames":48} |
| 3361.4 | 3361.4 | 13 | enemy_1 | attack wind-up | {"kind":"aoe","sample":1} |
| 3361.4 | 3853.3 | 13 | enemy_1 | wind-up to contact | {"derived":true} |
| 3836.4 | 3985.4 | 13 | enemy_1 | hit stop | {"requested_ms":85.0} |
| 3853.3 | 3853.3 | 13 | enemy_1 | contact | {"evidence":"Icefall entered its authored contact phase","process_frame":392,"sample":23,"sample_count":48} |
| 3853.3 | 3853.3 | 13 | enemy_1 | impact effect start | {"targets":[]} |
| 3853.3 | 4566.7 | 13 | enemy_1 | contact to last number gone | {"derived":true} |
| 3854.1 | 3854.1 | 13 | enemy_1 | ground state changed | {"kind":"surface_replaced","surface":"ice","tile":"(3, 3)","trigger":""} |
| 3854.1 | 3854.1 | 13 | enemy_1 | ground state changed | {"kind":"surface_created","surface":"ice","tile":"(2, 3)","trigger":""} |
| 3854.1 | 3854.1 | 13 | enemy_1 | death in displayed state | {"actor":"enemies:4"} |
| 3854.1 | 4602.1 | 13 | enemy_1 | defeated body held | {"actor":"enemy_4","type":"crawler"} |
| 3854.1 | 4566.7 | 13 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−4","tile":"(4, 3)"} |
| 3854.1 | 4566.7 | 13 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−5","tile":"(3, 3)"} |
| 3854.1 | 4304.1 | 13 | enemy_1 | camera move | {"kind":"board kick"} |
| 3854.1 | 3854.1 | 13 | enemy_1 | ground state changed | {"kind":"surface_created","surface":"ice","tile":"(4, 3)","trigger":""} |
| 4508.5 | 5832.2 | 13 | enemy_1 | turn-order rail | — |
| 4509.6 | 4592.4 | 13 | enemy_1 | floating feedback | {"numbers":2} |
| 4533.0 | 6039.0 | 13 | enemy_1 | death animation | {"actor":"enemy_4","type":"crawler"} |
| 4601.6 | 5804.1 | 13 | enemy_1 | feedback deadline | — |
| 5804.1 | 5983.0 | 13 | enemy_1 | post-action settle | — |
| 5983.5 | 5983.5 | 14 | enemy_1 | step dispatched | {"kind":"intent_refresh","label":""} |
| 5995.9 | 5995.9 | 15 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 5996.4 | 6024.3 | 15 |  | turn-order rail | — |
| 6023.9 | 6023.9 | 16 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 6030.2 | 6185.6 | 16 |  | turn-order rail | — |
| 6038.4 | 6038.4 | 17 | enemy_5 | step dispatched | {"kind":"intent","label":"Spatter"} |
| 6038.5 | 6291.7 | 17 | enemy_5 | pre-action delay | — |
| 6039.0 | 8254.1 | 17 | enemy_5 | caption shown | {"text":"Cinder Droplet: Spatter"} |
| 6039.0 | 6304.3 | 17 | enemy_5 | caption lead before motion or feedback | {"derived":true} |
| 6303.8 | 6303.8 | 18 | enemy_5 | step dispatched | {"kind":"move","label":"Advance"} |
| 6303.9 | 6772.0 | 18 | enemy_5 | action | {"kind":"move","label":"Advance"} |
| 6304.3 | 6502.4 | 18 | enemy_5 | unit move | {"actor":"enemy_5","tiles":1} |
| 6304.8 | 6502.4 | 18 | enemy_5 | sampled playback | {"authored_ms":183.333333333333,"frames":28} |
| 6502.9 | 6688.9 | 18 | enemy_5 | floating feedback | {"numbers":0} |
| 6520.5 | 6701.4 | 18 | enemy_5 | surface effect | {"kind":"status_applied","surface":"ice","tile":"(2, 3)","trigger":"entry"} |
| 6696.3 | 7085.7 | 18 | enemy_5 | turn-order rail | — |
| 6772.2 | 6772.2 | 19 | enemy_5 | step dispatched | {"kind":"melee","label":"Strike"} |
| 6772.2 | 8007.4 | 19 | enemy_5 | action | {"kind":"melee","label":"Strike"} |
| 6775.4 | 7657.0 | 19 | enemy_5 | sampled playback | {"authored_ms":600.0,"frames":36} |
| 6781.8 | 6781.8 | 19 | enemy_5 | attack wind-up | {"kind":"melee","sample":1} |
| 6781.8 | 7107.7 | 19 | enemy_5 | wind-up to contact | {"derived":true} |
| 7097.5 | 7231.1 | 19 | enemy_5 | hit stop | {"requested_ms":60.0} |
| 7107.7 | 7822.7 | 19 | enemy_5 | contact to last number gone | {"derived":true} |
| 7107.7 | 7107.7 | 19 | enemy_5 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":557,"sample":16,"sample_count":36} |
| 7107.7 | 7107.7 | 19 | enemy_5 | impact effect start | {"targets":["player"]} |
| 7108.3 | 7542.3 | 19 | enemy_5 | camera move | {"kind":"board kick"} |
| 7108.3 | 7822.7 | 19 | enemy_5 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−3","tile":"(3, 3)"} |
| 7108.3 | 7664.7 | 19 | enemy_5 | surface effect | {"kind":"surface_replaced","surface":"fire","tile":"(3, 3)","trigger":""} |
| 7657.6 | 7847.3 | 19 | enemy_5 | floating feedback | {"numbers":1} |
| 7850.6 | 8023.4 | 19 | enemy_5 | turn-order rail | — |
| 7851.7 | 8007.4 | 19 | enemy_5 | post-action settle | — |
| 8007.7 | 8007.7 | 20 | enemy_5 | step dispatched | {"kind":"intent_refresh","label":""} |
| 8023.1 | 8023.1 | 21 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 8027.1 | 8034.9 | 21 |  | turn-order rail | — |
| 8034.6 | 8034.6 | 22 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 8041.9 | 8211.4 | 22 |  | turn-order rail | — |
| 8050.6 | 8214.6 | — |  | hero hand-off drain | — |
| 8234.9 | 8788.2 | — |  | hero turn-start fire | — |
| 8241.4 | 8309.2 | — |  | hit stop | {"requested_ms":60.0} |
| 8253.6 | 8253.6 | — |  | impact effect start | {"targets":["player"]} |
| 8254.1 | 8254.1 | — |  | ground state changed | {"kind":"surface_replaced","surface":"fire","tile":"(3, 3)","trigger":""} |
| 8254.1 | 8822.2 | — |  | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(3, 3)"} |
| 8254.1 | 8540.1 | — |  | camera move | {"kind":"board kick"} |
| 8788.2 | 9280.9 | — |  | hand draw | {"cards":2} |
| 9281.4 | 9315.2 | — |  | publish hero UI | — |
| 9287.6 | 9287.6 | — |  | hero turn banner requested | — |
| 9332.5 | 9332.5 | — |  | hero input accepted | — |

### 03-s2-seed8-2-11_-9-t64

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 10.1 | 10.2 | — |  | defeat playback | — |
| 41.6 | 665.4 | — |  | sampled playback | {"authored_ms":600.0,"frames":1} |
| 84.1 | 696.2 | — |  | caption lead before motion or feedback | {"derived":true} |
| 84.1 | 1507.2 | — |  | caption shown | {"text":"Upheaval"} |
| 202.2 | 202.4 | — |  | locked hand capture | — |
| 696.2 | 1081.0 | — |  | surface effect | {"kind":"terrain_created","surface":"","tile":"(5, 4)","trigger":""} |
| 696.2 | 696.2 | — |  | ground state changed | {"kind":"terrain_created","surface":"crag_outcrop","tile":"(5, 4)","trigger":""} |
| 1042.7 | 1042.8 | — |  | defeat playback | — |
| 1080.1 | 1080.3 | — |  | locked hand capture | — |
| 1202.7 | 1202.7 | — |  | defeat playback | — |
| 1207.6 | 1207.6 | 0 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 1208.5 | 1441.3 | 0 |  | turn-order rail | — |
| 1213.9 | 1441.5 | — |  | hero hand-off drain | — |
| 1466.0 | 1501.9 | — |  | publish hero UI | — |
| 1469.1 | 1469.1 | — |  | hero turn banner requested | — |
| 1507.4 | 1507.4 | — |  | hero input accepted | — |

### 04-s0-seed8-0--3_2-t5

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 3.9 | 3.9 | — |  | enemy turn banner requested | — |
| 24.2 | 380.7 | — |  | turn banner shown | {"text":"ENEMY TURN"} |
| 43.5 | 43.5 | — |  | locked hand capture | — |
| 165.4 | 165.5 | — |  | defeat playback | — |
| 167.9 | 170.5 | — |  | turn-order rail | — |
| 170.3 | 170.3 | 0 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 176.9 | 217.7 | 0 |  | turn-order rail | — |
| 190.9 | 190.9 | 1 | enemy_5 | step dispatched | {"kind":"status_damage","label":"Fire"} |
| 191.0 | 949.8 | 1 | enemy_5 | action | {"kind":"status_damage","label":"Fire"} |
| 191.8 | 191.8 | 1 | enemy_5 | status tick | {"actor":"enemy_5","kind":"status_damage","label":"Fire","rule":"","target":"(3, 4)"} |
| 223.4 | 1012.7 | 1 | enemy_5 | turn-order rail | — |
| 224.6 | 794.7 | 1 | enemy_5 | feedback deadline | — |
| 350.6 | 350.9 | 1 | enemy_5 | locked hand capture | — |
| 380.7 | 380.7 | 1 | enemy_5 | caption lead before motion or feedback | {"derived":true} |
| 380.7 | 657.8 | 1 | enemy_5 | surface effect | {"kind":"surface_damage","surface":"fire","tile":"(3, 4)","trigger":"start"} |
| 380.7 | 969.6 | 1 | enemy_5 | caption shown | {"text":"Dust Acolyte: Fire"} |
| 380.7 | 805.2 | 1 | enemy_5 | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(3, 4)"} |
| 794.7 | 949.8 | 1 | enemy_5 | post-action settle | — |
| 950.0 | 950.0 | 2 | enemy_5 | step dispatched | {"kind":"intent","label":"Siphon"} |
| 957.5 | 957.5 | 3 | enemy_5 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 957.6 | 2877.2 | 3 | enemy_5 | action | {"kind":"ranged","label":"Shot"} |
| 961.0 | 2611.8 | 3 | enemy_5 | sampled playback | {"authored_ms":1200.0,"frames":72} |
| 969.1 | 1967.7 | 3 | enemy_5 | wind-up to contact | {"derived":true} |
| 969.1 | 969.1 | 3 | enemy_5 | attack wind-up | {"kind":"ranged","sample":1} |
| 969.6 | 1968.6 | 3 | enemy_5 | caption lead before motion or feedback | {"derived":true} |
| 969.6 | 3736.2 | 3 | enemy_5 | caption shown | {"text":"Dust Acolyte: Siphon"} |
| 1953.7 | 2108.5 | 3 | enemy_5 | hit stop | {"requested_ms":85.0} |
| 1967.7 | 1967.7 | 3 | enemy_5 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":875,"sample":48,"sample_count":72} |
| 1967.7 | 1967.7 | 3 | enemy_5 | impact effect start | {"targets":["player"]} |
| 1967.7 | 2705.7 | 3 | enemy_5 | contact to last number gone | {"derived":true} |
| 1968.6 | 2365.9 | 3 | enemy_5 | camera move | {"kind":"board kick"} |
| 1968.6 | 2705.7 | 3 | enemy_5 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−4","tile":"(4, 4)"} |
| 2612.7 | 2719.0 | 3 | enemy_5 | floating feedback | {"numbers":1} |
| 2723.5 | 3081.6 | 3 | enemy_5 | turn-order rail | — |
| 2724.9 | 2877.2 | 3 | enemy_5 | post-action settle | — |
| 2877.4 | 2877.4 | 4 | enemy_5 | step dispatched | {"kind":"heal","label":"Heal"} |
| 2877.5 | 3674.2 | 4 | enemy_5 | action | {"kind":"heal","label":"Heal"} |
| 2878.3 | 2878.3 | 4 | enemy_5 | resolved heal | {"actor":"enemy_5","kind":"heal","label":"Heal","rule":"","target":"(3, 4)"} |
| 2878.5 | 3491.5 | 4 | enemy_5 | floating feedback | {"numbers":1} |
| 2899.2 | 3497.7 | 4 | enemy_5 | number on screen | {"category":"heal","icon":"heal","reaction":"","text":"+2","tile":"(3, 4)"} |
| 3496.0 | 3681.9 | 4 | enemy_5 | turn-order rail | — |
| 3497.3 | 3674.2 | 4 | enemy_5 | post-action settle | — |
| 3674.5 | 3674.5 | 5 | enemy_5 | step dispatched | {"kind":"intent_refresh","label":""} |
| 3681.4 | 3681.4 | 6 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 3689.6 | 3715.4 | 6 |  | turn-order rail | — |
| 3715.0 | 3715.0 | 7 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 3725.2 | 3903.4 | 7 |  | turn-order rail | — |
| 3735.4 | 3735.4 | 8 | enemy_3 | step dispatched | {"kind":"intent","label":"Smolder Slide"} |
| 3735.7 | 4026.2 | 8 | enemy_3 | pre-action delay | — |
| 3736.2 | 4058.0 | 8 | enemy_3 | caption lead before motion or feedback | {"derived":true} |
| 3736.2 | 5428.8 | 8 | enemy_3 | caption shown | {"text":"Cinder Ooze: Smolder Slide"} |
| 4044.7 | 4044.7 | 9 | enemy_3 | step dispatched | {"kind":"melee","label":"Strike"} |
| 4044.8 | 5367.8 | 9 | enemy_3 | action | {"kind":"melee","label":"Strike"} |
| 4049.6 | 5091.3 | 9 | enemy_3 | sampled playback | {"authored_ms":700.0,"frames":42} |
| 4058.0 | 4058.0 | 9 | enemy_3 | attack wind-up | {"kind":"melee","sample":1} |
| 4058.0 | 4433.4 | 9 | enemy_3 | wind-up to contact | {"derived":true} |
| 4420.3 | 4585.1 | 9 | enemy_3 | hit stop | {"requested_ms":85.0} |
| 4433.4 | 4433.4 | 9 | enemy_3 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":1024,"sample":18,"sample_count":42} |
| 4433.4 | 4433.4 | 9 | enemy_3 | impact effect start | {"targets":["player"]} |
| 4433.4 | 5177.5 | 9 | enemy_3 | contact to last number gone | {"derived":true} |
| 4434.4 | 4886.3 | 9 | enemy_3 | camera move | {"kind":"board kick"} |
| 4434.4 | 5177.5 | 9 | enemy_3 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−5","tile":"(4, 4)"} |
| 4434.4 | 5099.9 | 9 | enemy_3 | surface effect | {"kind":"surface_replaced","surface":"fire","tile":"(4, 4)","trigger":""} |
| 5092.3 | 5200.9 | 9 | enemy_3 | floating feedback | {"numbers":1} |
| 5203.3 | 5383.7 | 9 | enemy_3 | turn-order rail | — |
| 5215.2 | 5367.8 | 9 | enemy_3 | post-action settle | — |
| 5368.1 | 5368.1 | 10 | enemy_3 | step dispatched | {"kind":"intent_refresh","label":""} |
| 5383.3 | 5383.3 | 11 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 5391.1 | 5406.2 | 11 |  | turn-order rail | — |
| 5406.0 | 5406.0 | 12 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 5412.9 | 5605.7 | 12 |  | turn-order rail | — |
| 5427.7 | 5427.7 | 13 | enemy_1 | step dispatched | {"kind":"intent","label":"Arc Bolt"} |
| 5427.9 | 5684.1 | 13 | enemy_1 | pre-action delay | — |
| 5428.8 | 7508.1 | 13 | enemy_1 | caption shown | {"text":"Arc Thrall: Arc Bolt"} |
| 5428.8 | 5704.3 | 13 | enemy_1 | caption lead before motion or feedback | {"derived":true} |
| 5698.2 | 5698.2 | 14 | enemy_1 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 5698.3 | 7436.6 | 14 | enemy_1 | action | {"kind":"ranged","label":"Shot"} |
| 5699.1 | 7267.7 | 14 | enemy_1 | sampled playback | {"authored_ms":1200.0,"frames":72} |
| 5704.3 | 5704.3 | 14 | enemy_1 | attack wind-up | {"kind":"ranged","sample":1} |
| 5704.3 | 6496.8 | 14 | enemy_1 | wind-up to contact | {"derived":true} |
| 6475.7 | 6550.1 | 14 | enemy_1 | hit stop | {"requested_ms":60.0} |
| 6496.8 | 6496.8 | 14 | enemy_1 | contact | {"evidence":"contact effect submitted","process_frame":1132,"sample":37,"sample_count":72} |
| 6496.8 | 6496.8 | 14 | enemy_1 | impact effect start | {"targets":[]} |
| 6496.8 | 7156.9 | 14 | enemy_1 | contact to last number gone | {"derived":true} |
| 6497.8 | 7156.9 | 14 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−3","tile":"(4, 4)"} |
| 6497.8 | 6817.8 | 14 | enemy_1 | camera move | {"kind":"board kick"} |
| 7267.7 | 7274.9 | 14 | enemy_1 | floating feedback | {"numbers":1} |
| 7281.1 | 7436.6 | 14 | enemy_1 | post-action settle | — |
| 7436.8 | 7436.8 | 15 | enemy_1 | step dispatched | {"kind":"intent_refresh","label":""} |
| 7439.0 | 7439.0 | 16 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 7439.7 | 7486.0 | 16 |  | turn-order rail | — |
| 7485.7 | 7485.7 | 17 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 7495.8 | 7627.8 | 17 |  | turn-order rail | — |
| 7507.4 | 7507.4 | 18 | enemy_4 | step dispatched | {"kind":"intent","label":"Bulwark"} |
| 7507.6 | 7812.8 | 18 | enemy_4 | pre-action delay | — |
| 7508.1 | 7838.9 | 18 | enemy_4 | caption lead before motion or feedback | {"derived":true} |
| 7508.1 | 8934.8 | 18 | enemy_4 | caption shown | {"text":"Stone Warden: Bulwark"} |
| 7819.8 | 7819.8 | 19 | enemy_4 | step dispatched | {"kind":"block","label":"Guard Allies"} |
| 7819.9 | 8669.4 | 19 | enemy_4 | action | {"kind":"block","label":"Guard Allies"} |
| 7820.7 | 7820.7 | 19 | enemy_4 | resolved block | {"actor":"enemy_4","kind":"block","label":"Guard Allies","rule":"","target":"(1, 1)"} |
| 7820.8 | 8437.3 | 19 | enemy_4 | floating feedback | {"numbers":3} |
| 7838.5 | 7838.5 | 19 | enemy_4 | impact effect start | {"targets":["enemy_1","enemy_3","enemy_5"]} |
| 7838.9 | 8445.4 | 19 | enemy_4 | number on screen | {"category":"status","icon":"block","reaction":"","text":"+6","tile":"(6, 4)"} |
| 7838.9 | 8445.4 | 19 | enemy_4 | number on screen | {"category":"status","icon":"block","reaction":"","text":"+6","tile":"(5, 4)"} |
| 7838.9 | 8445.4 | 19 | enemy_4 | number on screen | {"category":"status","icon":"block","reaction":"","text":"+6","tile":"(3, 4)"} |
| 8444.7 | 8669.4 | 19 | enemy_4 | post-action settle | — |
| 8669.6 | 8669.6 | 20 | enemy_4 | step dispatched | {"kind":"intent_refresh","label":""} |
| 8674.7 | 8674.7 | 21 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 8675.2 | 8695.0 | 21 |  | turn-order rail | — |
| 8694.5 | 8694.5 | 22 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 8700.5 | 8895.8 | 22 |  | turn-order rail | — |
| 8709.6 | 8902.0 | — |  | hero hand-off drain | — |
| 8916.9 | 9563.2 | — |  | hero fatigue | — |
| 8924.5 | 9002.6 | — |  | hit stop | {"requested_ms":60.0} |
| 8934.5 | 8934.5 | — |  | impact effect start | {"targets":["player"]} |
| 8934.8 | 9237.8 | — |  | camera move | {"kind":"board kick"} |
| 8934.8 | 9485.7 | — |  | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−2","tile":"(4, 4)"} |
| 8934.8 | 8934.8 | — |  | ground state changed | {"kind":"surface_replaced","surface":"fire","tile":"(4, 4)","trigger":""} |
| 8934.8 | 8934.8 | — |  | ground state changed | {"kind":"surface_replaced","surface":"electrified","tile":"(4, 4)","trigger":""} |
| 9079.1 | 9598.6 | — |  | number on screen | {"category":"status","icon":"","reaction":"","text":"fatigue sets in","tile":"(4, 4)"} |
| 9563.2 | 10064.6 | — |  | hand draw | {"cards":2} |
| 10065.0 | 10116.6 | — |  | publish hero UI | — |
| 10073.8 | 10073.8 | — |  | hero turn banner requested | — |
| 10152.4 | 10152.4 | — |  | hero input accepted | — |

### 05-s2-seed1-2-9_-7-t2

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 4.6 | 4.6 | — |  | enemy turn banner requested | — |
| 24.9 | 276.0 | — |  | turn banner shown | {"text":"ENEMY TURN"} |
| 38.4 | 38.4 | — |  | locked hand capture | — |
| 136.5 | 136.5 | — |  | defeat playback | — |
| 139.0 | 140.9 | — |  | turn-order rail | — |
| 140.5 | 140.5 | 0 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 146.4 | 425.7 | 0 |  | turn-order rail | — |
| 155.1 | 155.1 | 1 | enemy_2 | step dispatched | {"kind":"intent","label":"Arc Jab"} |
| 155.7 | 372.6 | 1 | enemy_2 | pre-action delay | — |
| 276.0 | 383.6 | 1 | enemy_2 | caption lead before motion or feedback | {"derived":true} |
| 276.0 | 5167.3 | 1 | enemy_2 | caption shown | {"text":"Arc Thrall: Arc Jab"} |
| 285.4 | 285.6 | 1 | enemy_2 | locked hand capture | — |
| 383.1 | 383.1 | 2 | enemy_2 | step dispatched | {"kind":"move","label":"Advance"} |
| 383.1 | 1440.3 | 2 | enemy_2 | action | {"kind":"move","label":"Advance"} |
| 383.6 | 1397.4 | 2 | enemy_2 | unit move | {"actor":"enemy_2","tiles":2} |
| 384.1 | 1397.3 | 2 | enemy_2 | sampled playback | {"authored_ms":1000.0,"frames":60} |
| 1440.5 | 1440.5 | 3 | enemy_2 | step dispatched | {"kind":"melee","label":"Strike"} |
| 1440.6 | 2870.4 | 3 | enemy_2 | action | {"kind":"melee","label":"Strike"} |
| 1444.5 | 2485.8 | 3 | enemy_2 | sampled playback | {"authored_ms":700.0,"frames":42} |
| 1456.3 | 1823.8 | 3 | enemy_2 | wind-up to contact | {"derived":true} |
| 1456.3 | 1456.3 | 3 | enemy_2 | attack wind-up | {"kind":"melee","sample":1} |
| 1808.6 | 1970.9 | 3 | enemy_2 | hit stop | {"requested_ms":85.0} |
| 1823.8 | 2712.1 | 3 | enemy_2 | contact to last number gone | {"derived":true} |
| 1823.8 | 1823.8 | 3 | enemy_2 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":1429,"sample":18,"sample_count":42} |
| 1823.8 | 1823.8 | 3 | enemy_2 | impact effect start | {"targets":["player"]} |
| 1825.7 | 2327.6 | 3 | enemy_2 | camera move | {"kind":"board kick"} |
| 1825.7 | 2570.2 | 3 | enemy_2 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−4","tile":"(5, 2)"} |
| 1825.7 | 2500.6 | 3 | enemy_2 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(5, 2)","trigger":""} |
| 2095.7 | 2712.1 | 3 | enemy_2 | number on screen | {"category":"status","icon":"","reaction":"","text":"Shock","tile":"(5, 2)"} |
| 2486.7 | 2695.5 | 3 | enemy_2 | floating feedback | {"numbers":2} |
| 2697.9 | 2882.0 | 3 | enemy_2 | turn-order rail | — |
| 2711.2 | 2870.3 | 3 | enemy_2 | post-action settle | — |
| 2870.6 | 2870.6 | 4 | enemy_2 | step dispatched | {"kind":"intent_refresh","label":""} |
| 2881.6 | 2881.6 | 5 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 2886.2 | 2900.3 | 5 |  | turn-order rail | — |
| 2899.7 | 2899.7 | 6 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 2908.2 | 3150.9 | 6 |  | turn-order rail | — |
| 2920.4 | 2920.4 | 7 | enemy_3 | step dispatched | {"kind":"intent","label":"Arc Jab"} |
| 2920.5 | 3192.1 | 7 | enemy_3 | pre-action delay | — |
| 3198.6 | 3198.6 | 8 | enemy_3 | step dispatched | {"kind":"move","label":"Advance"} |
| 3198.6 | 3745.8 | 8 | enemy_3 | action | {"kind":"move","label":"Advance"} |
| 3199.3 | 3710.8 | 8 | enemy_3 | unit move | {"actor":"enemy_3","tiles":1} |
| 3200.1 | 3710.7 | 8 | enemy_3 | sampled playback | {"authored_ms":500.0,"frames":30} |
| 3745.9 | 3745.9 | 9 | enemy_3 | step dispatched | {"kind":"melee","label":"Strike"} |
| 3746.0 | 5103.2 | 9 | enemy_3 | action | {"kind":"melee","label":"Strike"} |
| 3748.4 | 4820.1 | 9 | enemy_3 | sampled playback | {"authored_ms":700.0,"frames":42} |
| 3761.1 | 3761.1 | 9 | enemy_3 | attack wind-up | {"kind":"melee","sample":1} |
| 3761.1 | 4126.1 | 9 | enemy_3 | wind-up to contact | {"derived":true} |
| 4112.3 | 4297.5 | 9 | enemy_3 | hit stop | {"requested_ms":85.0} |
| 4126.1 | 4895.0 | 9 | enemy_3 | contact to last number gone | {"derived":true} |
| 4126.1 | 4126.1 | 9 | enemy_3 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":1523,"sample":18,"sample_count":42} |
| 4126.1 | 4126.1 | 9 | enemy_3 | impact effect start | {"targets":["player"]} |
| 4127.4 | 4641.6 | 9 | enemy_3 | camera move | {"kind":"board kick"} |
| 4127.4 | 4895.0 | 9 | enemy_3 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−4","tile":"(5, 2)"} |
| 4127.4 | 4833.9 | 9 | enemy_3 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(5, 2)","trigger":""} |
| 4820.9 | 4928.1 | 9 | enemy_3 | floating feedback | {"numbers":1} |
| 4935.7 | 5109.6 | 9 | enemy_3 | turn-order rail | — |
| 4945.6 | 5103.2 | 9 | enemy_3 | post-action settle | — |
| 5103.3 | 5103.3 | 10 | enemy_3 | step dispatched | {"kind":"intent_refresh","label":""} |
| 5109.0 | 5109.0 | 11 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 5112.5 | 5137.1 | 11 |  | turn-order rail | — |
| 5136.8 | 5136.8 | 12 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 5142.1 | 5380.4 | 12 |  | turn-order rail | — |
| 5149.3 | 5149.3 | 13 | enemy_1 | step dispatched | {"kind":"intent","label":"Ooze Advance"} |
| 5155.6 | 5155.6 | 14 | enemy_1 | step dispatched | {"kind":"move","label":"Advance"} |
| 5155.7 | 5648.4 | 14 | enemy_1 | action | {"kind":"move","label":"Advance"} |
| 5156.4 | 5540.6 | 14 | enemy_1 | unit move | {"actor":"enemy_1","tiles":2} |
| 5156.9 | 5540.6 | 14 | enemy_1 | sampled playback | {"authored_ms":366.666666666667,"frames":74} |
| 5167.3 | 5905.2 | 14 | enemy_1 | caption shown | {"text":"Cinder Ooze: Ooze Advance"} |
| 5648.6 | 5648.6 | 15 | enemy_1 | step dispatched | {"kind":"intent_refresh","label":""} |
| 5660.9 | 5660.9 | 16 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 5661.6 | 5682.2 | 16 |  | turn-order rail | — |
| 5681.8 | 5681.8 | 17 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 5690.3 | 5845.2 | 17 |  | turn-order rail | — |
| 5703.2 | 5851.3 | — |  | hero hand-off drain | — |
| 5869.3 | 6170.5 | — |  | hand draw | {"cards":1} |
| 6170.8 | 6212.4 | — |  | publish hero UI | — |
| 6175.9 | 6175.9 | — |  | hero turn banner requested | — |
| 6228.4 | 6228.4 | — |  | hero input accepted | — |

### 06-s2-seed1-2-11_-10-t5

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 4.1 | 4.1 | — |  | enemy turn banner requested | — |
| 26.2 | 312.0 | — |  | turn banner shown | {"text":"ENEMY TURN"} |
| 46.1 | 46.1 | — |  | locked hand capture | — |
| 151.5 | 151.5 | — |  | defeat playback | — |
| 154.2 | 157.0 | — |  | turn-order rail | — |
| 156.5 | 156.5 | 0 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 166.3 | 443.9 | 0 |  | turn-order rail | — |
| 178.1 | 178.1 | 1 | enemy_5 | step dispatched | {"kind":"intent","label":"Retreat Step"} |
| 178.7 | 373.3 | 1 | enemy_5 | pre-action delay | — |
| 312.0 | 391.5 | 1 | enemy_5 | caption lead before motion or feedback | {"derived":true} |
| 312.0 | 1705.5 | 1 | enemy_5 | caption shown | {"text":"Bone Harrier: Retreat Step"} |
| 323.5 | 323.7 | 1 | enemy_5 | locked hand capture | — |
| 390.7 | 390.7 | 2 | enemy_5 | step dispatched | {"kind":"move","label":"Retreat"} |
| 390.8 | 821.4 | 2 | enemy_5 | action | {"kind":"move","label":"Retreat"} |
| 391.5 | 778.7 | 2 | enemy_5 | unit move | {"actor":"enemy_5","tiles":2} |
| 392.0 | 778.7 | 2 | enemy_5 | sampled playback | {"authored_ms":366.666666666667,"frames":56} |
| 821.6 | 821.6 | 3 | enemy_5 | step dispatched | {"kind":"block","label":"Guard"} |
| 821.6 | 1638.5 | 3 | enemy_5 | action | {"kind":"block","label":"Guard"} |
| 822.6 | 822.6 | 3 | enemy_5 | resolved block | {"actor":"enemy_5","kind":"block","label":"Guard","rule":"","target":"(2, 1)"} |
| 822.7 | 1434.6 | 3 | enemy_5 | floating feedback | {"numbers":1} |
| 850.4 | 1440.6 | 3 | enemy_5 | number on screen | {"category":"status","icon":"block","reaction":"","text":"+4","tile":"(2, 1)"} |
| 1439.4 | 1638.4 | 3 | enemy_5 | post-action settle | — |
| 1638.8 | 1638.8 | 4 | enemy_5 | step dispatched | {"kind":"intent_refresh","label":""} |
| 1653.3 | 1653.3 | 5 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 1654.1 | 1684.2 | 5 |  | turn-order rail | — |
| 1683.6 | 1683.6 | 6 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 1691.2 | 1882.0 | 6 |  | turn-order rail | — |
| 1704.7 | 1704.7 | 7 | enemy_1 | step dispatched | {"kind":"intent","label":"Arc Bolt"} |
| 1704.9 | 1976.8 | 7 | enemy_1 | pre-action delay | — |
| 1705.5 | 1995.6 | 7 | enemy_1 | caption lead before motion or feedback | {"derived":true} |
| 1705.5 | 3911.0 | 7 | enemy_1 | caption shown | {"text":"Arc Thrall: Arc Bolt"} |
| 1988.9 | 1988.9 | 8 | enemy_1 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 1989.0 | 3826.4 | 8 | enemy_1 | action | {"kind":"ranged","label":"Shot"} |
| 1990.1 | 3658.0 | 8 | enemy_1 | sampled playback | {"authored_ms":1200.0,"frames":72} |
| 1995.6 | 2780.9 | 8 | enemy_1 | wind-up to contact | {"derived":true} |
| 1995.6 | 1995.6 | 8 | enemy_1 | attack wind-up | {"kind":"ranged","sample":1} |
| 2762.3 | 2935.4 | 8 | enemy_1 | hit stop | {"requested_ms":85.0} |
| 2780.9 | 3543.2 | 8 | enemy_1 | contact to last number gone | {"derived":true} |
| 2780.9 | 2780.9 | 8 | enemy_1 | contact | {"evidence":"contact effect submitted","process_frame":1773,"sample":37,"sample_count":72} |
| 2780.9 | 2780.9 | 8 | enemy_1 | impact effect start | {"targets":[]} |
| 2782.0 | 3543.2 | 8 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−4","tile":"(4, 3)"} |
| 2782.0 | 3259.6 | 8 | enemy_1 | camera move | {"kind":"board kick"} |
| 3658.0 | 3665.0 | 8 | enemy_1 | floating feedback | {"numbers":1} |
| 3672.2 | 3826.4 | 8 | enemy_1 | post-action settle | — |
| 3826.7 | 3826.7 | 9 | enemy_1 | step dispatched | {"kind":"intent_refresh","label":""} |
| 3830.7 | 3830.7 | 10 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 3831.8 | 3858.9 | 10 |  | turn-order rail | — |
| 3858.3 | 3858.3 | 11 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 3869.1 | 3903.9 | 11 |  | turn-order rail | — |
| 3881.0 | 3881.0 | 12 | enemy_2 | step dispatched | {"kind":"status_damage","label":"Fire"} |
| 3881.1 | 4639.6 | 12 | enemy_2 | action | {"kind":"status_damage","label":"Fire"} |
| 3881.9 | 3881.9 | 12 | enemy_2 | status tick | {"actor":"enemy_2","kind":"status_damage","label":"Fire","rule":"","target":"(4, 4)"} |
| 3909.1 | 4633.6 | 12 | enemy_2 | turn-order rail | — |
| 3910.3 | 4484.5 | 12 | enemy_2 | feedback deadline | — |
| 3911.0 | 3911.0 | 12 | enemy_2 | caption lead before motion or feedback | {"derived":true} |
| 3911.0 | 4641.0 | 12 | enemy_2 | caption shown | {"text":"Arc Thrall: Fire"} |
| 3911.0 | 4499.0 | 12 | enemy_2 | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(4, 4)"} |
| 3911.0 | 4351.6 | 12 | enemy_2 | surface effect | {"kind":"surface_damage","surface":"fire","tile":"(4, 4)","trigger":"start"} |
| 4484.6 | 4639.6 | 12 | enemy_2 | post-action settle | — |
| 4639.8 | 4639.8 | 13 | enemy_2 | step dispatched | {"kind":"intent","label":"Arc Bolt"} |
| 4640.0 | 4893.7 | 13 | enemy_2 | pre-action delay | — |
| 4641.0 | 6830.0 | 13 | enemy_2 | caption shown | {"text":"Arc Thrall: Arc Bolt"} |
| 4641.0 | 4911.1 | 13 | enemy_2 | caption lead before motion or feedback | {"derived":true} |
| 4901.5 | 4901.5 | 14 | enemy_2 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 4901.6 | 6736.8 | 14 | enemy_2 | action | {"kind":"ranged","label":"Shot"} |
| 4903.0 | 6558.8 | 14 | enemy_2 | sampled playback | {"authored_ms":1200.0,"frames":72} |
| 4911.1 | 4911.1 | 14 | enemy_2 | attack wind-up | {"kind":"ranged","sample":1} |
| 4911.1 | 5693.9 | 14 | enemy_2 | wind-up to contact | {"derived":true} |
| 5680.9 | 5843.7 | 14 | enemy_2 | hit stop | {"requested_ms":85.0} |
| 5693.9 | 5693.9 | 14 | enemy_2 | contact | {"evidence":"contact effect submitted","process_frame":1939,"sample":38,"sample_count":72} |
| 5693.9 | 5693.9 | 14 | enemy_2 | impact effect start | {"targets":[]} |
| 5693.9 | 6420.8 | 14 | enemy_2 | contact to last number gone | {"derived":true} |
| 5694.6 | 6165.8 | 14 | enemy_2 | camera move | {"kind":"board kick"} |
| 5694.6 | 6420.8 | 14 | enemy_2 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−4","tile":"(4, 3)"} |
| 6558.9 | 6565.4 | 14 | enemy_2 | floating feedback | {"numbers":1} |
| 6572.7 | 6736.7 | 14 | enemy_2 | post-action settle | — |
| 6737.2 | 6737.2 | 15 | enemy_2 | step dispatched | {"kind":"intent_refresh","label":""} |
| 6752.5 | 6752.5 | 16 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 6753.3 | 6806.3 | 16 |  | turn-order rail | — |
| 6805.5 | 6805.5 | 17 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 6816.6 | 6962.4 | 17 |  | turn-order rail | — |
| 6829.3 | 6829.3 | 18 | enemy_5 | step dispatched | {"kind":"intent","label":"Rush"} |
| 6829.5 | 7080.6 | 18 | enemy_5 | pre-action delay | — |
| 6830.0 | 9769.2 | 18 | enemy_5 | caption shown | {"text":"Bone Harrier: Rush"} |
| 6830.0 | 7101.0 | 18 | enemy_5 | caption lead before motion or feedback | {"derived":true} |
| 7100.2 | 7100.2 | 19 | enemy_5 | step dispatched | {"kind":"move","label":"Advance"} |
| 7100.3 | 8377.2 | 19 | enemy_5 | action | {"kind":"move","label":"Advance"} |
| 7101.0 | 7660.3 | 19 | enemy_5 | unit move | {"actor":"enemy_5","tiles":3} |
| 7101.6 | 7660.2 | 19 | enemy_5 | sampled playback | {"authored_ms":550.0,"frames":84} |
| 7660.9 | 8214.9 | 19 | enemy_5 | floating feedback | {"numbers":1} |
| 7668.8 | 7730.5 | 19 | enemy_5 | hit stop | {"requested_ms":40.0} |
| 7680.5 | 7680.5 | 19 | enemy_5 | impact effect start | {"targets":["enemy_5"]} |
| 7681.7 | 7931.2 | 19 | enemy_5 | camera move | {"kind":"board kick"} |
| 7681.7 | 8248.0 | 19 | enemy_5 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−2","tile":"(3, 3)"} |
| 7681.7 | 8248.0 | 19 | enemy_5 | surface effect | {"kind":"surface_damage","surface":"fire","tile":"(3, 3)","trigger":"entry"} |
| 8223.7 | 8673.3 | 19 | enemy_5 | turn-order rail | — |
| 8377.4 | 8377.4 | 20 | enemy_5 | step dispatched | {"kind":"melee","label":"Strike"} |
| 8377.5 | 9675.7 | 20 | enemy_5 | action | {"kind":"melee","label":"Strike"} |
| 8380.8 | 9359.7 | 20 | enemy_5 | sampled playback | {"authored_ms":650.0,"frames":39} |
| 8403.9 | 8751.7 | 20 | enemy_5 | wind-up to contact | {"derived":true} |
| 8403.9 | 8403.9 | 20 | enemy_5 | attack wind-up | {"kind":"melee","sample":1} |
| 8739.3 | 8911.6 | 20 | enemy_5 | hit stop | {"requested_ms":85.0} |
| 8751.7 | 9507.2 | 20 | enemy_5 | contact to last number gone | {"derived":true} |
| 8751.7 | 8751.7 | 20 | enemy_5 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":2100,"sample":17,"sample_count":39} |
| 8751.7 | 8751.7 | 20 | enemy_5 | impact effect start | {"targets":["player"]} |
| 8752.5 | 9266.2 | 20 | enemy_5 | camera move | {"kind":"board kick"} |
| 8752.5 | 9507.2 | 20 | enemy_5 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−4","tile":"(4, 3)"} |
| 9360.4 | 9514.1 | 20 | enemy_5 | floating feedback | {"numbers":1} |
| 9517.2 | 9689.3 | 20 | enemy_5 | turn-order rail | — |
| 9518.2 | 9675.6 | 20 | enemy_5 | post-action settle | — |
| 9675.9 | 9675.9 | 21 | enemy_5 | step dispatched | {"kind":"intent_refresh","label":""} |
| 9688.9 | 9688.9 | 22 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 9695.1 | 9722.5 | 22 |  | turn-order rail | — |
| 9722.0 | 9722.0 | 23 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 9731.5 | 9961.6 | 23 |  | turn-order rail | — |
| 9746.7 | 9746.7 | 24 | enemy_3 | step dispatched | {"kind":"intent","label":"Ooze Advance"} |
| 9754.1 | 9754.1 | 25 | enemy_3 | step dispatched | {"kind":"move","label":"Advance"} |
| 9754.2 | 10196.5 | 25 | enemy_3 | action | {"kind":"move","label":"Advance"} |
| 9754.7 | 10153.8 | 25 | enemy_3 | unit move | {"actor":"enemy_3","tiles":2} |
| 9755.3 | 10153.7 | 25 | enemy_3 | sampled playback | {"authored_ms":366.666666666667,"frames":74} |
| 9769.2 | 10459.5 | 25 | enemy_3 | caption shown | {"text":"Cinder Ooze: Ooze Advance"} |
| 10196.8 | 10196.8 | 26 | enemy_3 | step dispatched | {"kind":"intent_refresh","label":""} |
| 10213.3 | 10213.3 | 27 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 10214.7 | 10243.4 | 27 |  | turn-order rail | — |
| 10242.7 | 10242.7 | 28 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 10251.7 | 10410.9 | 28 |  | turn-order rail | — |
| 10262.0 | 10420.2 | — |  | hero hand-off drain | — |
| 10447.5 | 11084.1 | — |  | hero fatigue | — |
| 10452.0 | 10522.8 | — |  | hit stop | {"requested_ms":60.0} |
| 10458.7 | 10458.7 | — |  | impact effect start | {"targets":["player"]} |
| 10459.5 | 11005.3 | — |  | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−2","tile":"(4, 3)"} |
| 10459.5 | 10752.9 | — |  | camera move | {"kind":"board kick"} |
| 10617.6 | 11122.3 | — |  | number on screen | {"category":"status","icon":"","reaction":"","text":"fatigue sets in","tile":"(4, 3)"} |
| 11084.1 | 11388.8 | — |  | hand draw | {"cards":1} |
| 11389.3 | 11449.1 | — |  | publish hero UI | — |
| 11405.5 | 11405.5 | — |  | hero turn banner requested | — |
| 11492.1 | 11492.1 | — |  | hero input accepted | — |

### 07-s4-seed1-4-19_-19-t4

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 4.5 | 4.5 | — |  | enemy turn banner requested | — |
| 37.7 | 772.6 | — |  | turn banner shown | {"text":"ENEMY TURN"} |
| 55.8 | 55.8 | — |  | locked hand capture | — |
| 189.5 | 189.8 | — |  | locked hand capture | — |
| 204.0 | 204.0 | — |  | defeat playback | — |
| 207.5 | 221.0 | — |  | turn-order rail | — |
| 219.9 | 219.9 | 0 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 228.7 | 865.3 | 0 |  | turn-order rail | — |
| 238.7 | 238.7 | 1 | enemy_3 | step dispatched | {"kind":"intent","label":"Cudgel Press"} |
| 239.5 | 391.0 | 1 | enemy_3 | pre-action delay | — |
| 412.7 | 412.7 | 2 | enemy_3 | step dispatched | {"kind":"melee","label":"Strike"} |
| 412.8 | 1870.9 | 2 | enemy_3 | action | {"kind":"melee","label":"Strike"} |
| 414.7 | 1628.7 | 2 | enemy_3 | sampled playback | {"authored_ms":850.0,"frames":51} |
| 771.5 | 771.5 | 2 | enemy_3 | attack wind-up | {"kind":"melee","sample":1} |
| 771.5 | 962.6 | 2 | enemy_3 | wind-up to contact | {"derived":true} |
| 772.6 | 963.8 | 2 | enemy_3 | caption lead before motion or feedback | {"derived":true} |
| 772.6 | 1934.9 | 2 | enemy_3 | caption shown | {"text":"Chainbound Gaoler: Cudgel Press"} |
| 950.9 | 1102.9 | 2 | enemy_3 | hit stop | {"requested_ms":105.0} |
| 962.6 | 1693.0 | 2 | enemy_3 | contact to last number gone | {"derived":true} |
| 962.6 | 962.6 | 2 | enemy_3 | contact | {"evidence":"contact effect submitted","process_frame":2248,"sample":26,"sample_count":51} |
| 962.6 | 962.6 | 2 | enemy_3 | impact effect start | {"targets":[]} |
| 963.8 | 1504.7 | 2 | enemy_3 | camera move | {"kind":"board kick"} |
| 963.8 | 1693.0 | 2 | enemy_3 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−8","tile":"(2, 5)"} |
| 1628.7 | 1708.1 | 2 | enemy_3 | floating feedback | {"numbers":1} |
| 1718.0 | 1870.8 | 2 | enemy_3 | post-action settle | — |
| 1871.0 | 1871.0 | 3 | enemy_3 | step dispatched | {"kind":"intent_refresh","label":""} |
| 1886.8 | 1886.8 | 4 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 1888.2 | 1914.6 | 4 |  | turn-order rail | — |
| 1914.0 | 1914.0 | 5 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 1922.5 | 2081.7 | 5 |  | turn-order rail | — |
| 1934.2 | 1934.2 | 6 | enemy_4 | step dispatched | {"kind":"intent","label":"Skitter Strike"} |
| 1934.3 | 2254.4 | 6 | enemy_4 | pre-action delay | — |
| 1934.9 | 3795.2 | 6 | enemy_4 | caption shown | {"text":"Tunnel Crawler: Skitter Strike"} |
| 1934.9 | 2265.6 | 6 | enemy_4 | caption lead before motion or feedback | {"derived":true} |
| 2264.6 | 2264.6 | 7 | enemy_4 | step dispatched | {"kind":"move","label":"Advance"} |
| 2264.7 | 2505.5 | 7 | enemy_4 | action | {"kind":"move","label":"Advance"} |
| 2265.6 | 2464.5 | 7 | enemy_4 | unit move | {"actor":"enemy_4","tiles":1} |
| 2266.0 | 2464.5 | 7 | enemy_4 | sampled playback | {"authored_ms":183.333333333333,"frames":28} |
| 2505.8 | 2505.8 | 8 | enemy_4 | step dispatched | {"kind":"melee","label":"Strike"} |
| 2505.8 | 3752.5 | 8 | enemy_4 | action | {"kind":"melee","label":"Strike"} |
| 2511.3 | 3399.2 | 8 | enemy_4 | sampled playback | {"authored_ms":600.0,"frames":36} |
| 2521.7 | 2521.7 | 8 | enemy_4 | attack wind-up | {"kind":"melee","sample":1} |
| 2521.7 | 2847.4 | 8 | enemy_4 | wind-up to contact | {"derived":true} |
| 2834.3 | 2972.1 | 8 | enemy_4 | hit stop | {"requested_ms":85.0} |
| 2847.4 | 3571.7 | 8 | enemy_4 | contact to last number gone | {"derived":true} |
| 2847.4 | 2847.4 | 8 | enemy_4 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":2339,"sample":16,"sample_count":36} |
| 2847.4 | 2847.4 | 8 | enemy_4 | impact effect start | {"targets":["player"]} |
| 2848.5 | 3315.4 | 8 | enemy_4 | camera move | {"kind":"board kick"} |
| 2848.5 | 3571.7 | 8 | enemy_4 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−7","tile":"(2, 5)"} |
| 3399.9 | 3586.5 | 8 | enemy_4 | floating feedback | {"numbers":1} |
| 3589.3 | 3761.3 | 8 | enemy_4 | turn-order rail | — |
| 3599.8 | 3752.5 | 8 | enemy_4 | post-action settle | — |
| 3752.7 | 3752.7 | 9 | enemy_4 | step dispatched | {"kind":"intent_refresh","label":""} |
| 3760.9 | 3760.9 | 10 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 3763.4 | 3775.5 | 10 |  | turn-order rail | — |
| 3774.4 | 3774.4 | 11 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 3783.4 | 3979.1 | 11 |  | turn-order rail | — |
| 3794.6 | 3794.6 | 12 | enemy_1 | step dispatched | {"kind":"intent","label":"Lob Slag"} |
| 3794.8 | 4048.5 | 12 | enemy_1 | pre-action delay | — |
| 3795.2 | 5267.3 | 12 | enemy_1 | caption shown | {"text":"Lob Slag · 7 / 5"} |
| 3795.2 | 4070.2 | 12 | enemy_1 | caption lead before motion or feedback | {"derived":true} |
| 4058.1 | 4058.1 | 13 | enemy_1 | step dispatched | {"kind":"aoe","label":""} |
| 4058.2 | 5166.2 | 13 | enemy_1 | action | {"kind":"aoe","label":""} |
| 4060.5 | 4904.5 | 13 | enemy_1 | sampled playback | {"authored_ms":600.0,"frames":36} |
| 4070.2 | 4070.2 | 13 | enemy_1 | wind-up to contact | {"derived":true} |
| 4070.2 | 5012.1 | 13 | enemy_1 | contact to last number gone | {"derived":true} |
| 4070.2 | 4070.2 | 13 | enemy_1 | attack wind-up | {"kind":"aoe","sample":1} |
| 4070.2 | 4070.2 | 13 | enemy_1 | contact | {"evidence":"contact effect submitted","process_frame":2419,"sample":1,"sample_count":36} |
| 4070.2 | 4070.2 | 13 | enemy_1 | impact effect start | {"targets":[]} |
| 4338.2 | 4438.2 | 13 | enemy_1 | hit stop | {"requested_ms":85.0} |
| 4360.8 | 4698.7 | 13 | enemy_1 | camera move | {"kind":"board kick"} |
| 4360.8 | 5012.1 | 13 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−7","tile":"(2, 5)"} |
| 4360.8 | 5012.1 | 13 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−5","tile":"(3, 5)"} |
| 4360.8 | 5012.1 | 13 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−5","tile":"(1, 5)"} |
| 4360.8 | 4360.8 | 13 | enemy_1 | ground state changed | {"kind":"surface_created","surface":"fire","tile":"(2, 5)","trigger":""} |
| 4360.8 | 4360.8 | 13 | enemy_1 | ground state changed | {"kind":"surface_created","surface":"fire","tile":"(1, 5)","trigger":""} |
| 4360.8 | 4360.8 | 13 | enemy_1 | ground state changed | {"kind":"surface_created","surface":"fire","tile":"(3, 5)","trigger":""} |
| 4360.8 | 4360.8 | 13 | enemy_1 | ground state changed | {"kind":"surface_created","surface":"fire","tile":"(2, 6)","trigger":""} |
| 4904.6 | 4997.0 | 13 | enemy_1 | floating feedback | {"numbers":3} |
| 5001.1 | 5187.6 | 13 | enemy_1 | turn-order rail | — |
| 5010.1 | 5166.2 | 13 | enemy_1 | post-action settle | — |
| 5166.3 | 5166.3 | 14 | enemy_1 | step dispatched | {"kind":"intent_refresh","label":""} |
| 5186.4 | 5186.4 | 15 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 5192.5 | 5220.1 | 15 |  | turn-order rail | — |
| 5219.0 | 5219.0 | 16 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 5228.4 | 5263.8 | 16 |  | turn-order rail | — |
| 5238.2 | 5238.2 | 17 | enemy_4 | step dispatched | {"kind":"status_damage","label":"Fire"} |
| 5238.3 | 6008.4 | 17 | enemy_4 | action | {"kind":"status_damage","label":"Fire"} |
| 5239.9 | 5239.9 | 17 | enemy_4 | status tick | {"actor":"enemy_4","kind":"status_damage","label":"Fire","rule":"","target":"(1, 5)"} |
| 5265.9 | 5688.5 | 17 | enemy_4 | turn-order rail | — |
| 5266.6 | 5851.7 | 17 | enemy_4 | feedback deadline | — |
| 5267.3 | 5267.3 | 17 | enemy_4 | caption lead before motion or feedback | {"derived":true} |
| 5267.3 | 5700.0 | 17 | enemy_4 | surface effect | {"kind":"surface_damage","surface":"fire","tile":"(1, 5)","trigger":"start"} |
| 5267.3 | 5852.3 | 17 | enemy_4 | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(1, 5)"} |
| 5267.3 | 6011.3 | 17 | enemy_4 | caption shown | {"text":"Tunnel Crawler: Fire"} |
| 5851.7 | 6008.3 | 17 | enemy_4 | post-action settle | — |
| 6008.6 | 6008.6 | 18 | enemy_4 | step dispatched | {"kind":"intent","label":"Skitter Strike"} |
| 6009.0 | 6348.1 | 18 | enemy_4 | pre-action delay | — |
| 6011.3 | 7744.2 | 18 | enemy_4 | caption shown | {"text":"Tunnel Crawler: Skitter Strike"} |
| 6011.3 | 6366.9 | 18 | enemy_4 | caption lead before motion or feedback | {"derived":true} |
| 6357.2 | 6357.2 | 19 | enemy_4 | step dispatched | {"kind":"melee","label":"Strike"} |
| 6357.3 | 7661.3 | 19 | enemy_4 | action | {"kind":"melee","label":"Strike"} |
| 6361.2 | 7248.3 | 19 | enemy_4 | sampled playback | {"authored_ms":600.0,"frames":36} |
| 6366.9 | 6769.4 | 19 | enemy_4 | wind-up to contact | {"derived":true} |
| 6366.9 | 6366.9 | 19 | enemy_4 | attack wind-up | {"kind":"melee","sample":1} |
| 6759.5 | 6889.4 | 19 | enemy_4 | hit stop | {"requested_ms":85.0} |
| 6769.4 | 6769.4 | 19 | enemy_4 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":2536,"sample":19,"sample_count":36} |
| 6769.4 | 6769.4 | 19 | enemy_4 | impact effect start | {"targets":["player"]} |
| 6769.4 | 7495.7 | 19 | enemy_4 | contact to last number gone | {"derived":true} |
| 6770.0 | 7175.0 | 19 | enemy_4 | camera move | {"kind":"board kick"} |
| 6770.0 | 7495.7 | 19 | enemy_4 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−7","tile":"(2, 5)"} |
| 7249.2 | 7504.8 | 19 | enemy_4 | floating feedback | {"numbers":1} |
| 7507.8 | 7670.8 | 19 | enemy_4 | turn-order rail | — |
| 7508.9 | 7661.3 | 19 | enemy_4 | post-action settle | — |
| 7661.6 | 7661.6 | 20 | enemy_4 | step dispatched | {"kind":"intent_refresh","label":""} |
| 7669.9 | 7669.9 | 21 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 7676.9 | 7696.1 | 21 |  | turn-order rail | — |
| 7695.0 | 7695.0 | 22 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 7701.5 | 7736.7 | 22 |  | turn-order rail | — |
| 7712.9 | 7712.9 | 23 | enemy_3 | step dispatched | {"kind":"status_damage","label":"Fire"} |
| 7713.0 | 8488.0 | 23 | enemy_3 | action | {"kind":"status_damage","label":"Fire"} |
| 7714.7 | 7714.7 | 23 | enemy_3 | status tick | {"actor":"enemy_3","kind":"status_damage","label":"Fire","rule":"","target":"(3, 5)"} |
| 7741.6 | 8178.1 | 23 | enemy_3 | turn-order rail | — |
| 7742.7 | 8323.8 | 23 | enemy_3 | feedback deadline | — |
| 7744.2 | 8489.3 | 23 | enemy_3 | caption shown | {"text":"Chainbound Gaoler: Fire"} |
| 7744.2 | 8338.0 | 23 | enemy_3 | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(3, 5)"} |
| 7744.2 | 7744.2 | 23 | enemy_3 | caption lead before motion or feedback | {"derived":true} |
| 7744.2 | 8199.6 | 23 | enemy_3 | surface effect | {"kind":"surface_damage","surface":"fire","tile":"(3, 5)","trigger":"start"} |
| 8323.8 | 8487.9 | 23 | enemy_3 | post-action settle | — |
| 8488.2 | 8488.2 | 24 | enemy_3 | step dispatched | {"kind":"intent","label":"Manacle Pin"} |
| 8488.6 | 8771.5 | 24 | enemy_3 | pre-action delay | — |
| 8489.3 | 8790.9 | 24 | enemy_3 | caption lead before motion or feedback | {"derived":true} |
| 8489.3 | 10539.1 | 24 | enemy_3 | caption shown | {"text":"Chainbound Gaoler: Manacle Pin"} |
| 8779.3 | 8779.3 | 25 | enemy_3 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 8779.4 | 10233.7 | 25 | enemy_3 | action | {"kind":"ranged","label":"Shot"} |
| 8781.5 | 9866.1 | 25 | enemy_3 | sampled playback | {"authored_ms":800.0,"frames":48} |
| 8790.9 | 9321.6 | 25 | enemy_3 | wind-up to contact | {"derived":true} |
| 8790.9 | 8790.9 | 25 | enemy_3 | attack wind-up | {"kind":"ranged","sample":1} |
| 9304.3 | 9374.6 | 25 | enemy_3 | hit stop | {"requested_ms":60.0} |
| 9321.6 | 10081.9 | 25 | enemy_3 | contact to last number gone | {"derived":true} |
| 9321.6 | 9321.6 | 25 | enemy_3 | contact | {"evidence":"contact effect submitted","process_frame":2665,"sample":25,"sample_count":48} |
| 9321.6 | 9321.6 | 25 | enemy_3 | impact effect start | {"targets":[]} |
| 9323.1 | 9672.1 | 25 | enemy_3 | camera move | {"kind":"board kick"} |
| 9323.1 | 9977.9 | 25 | enemy_3 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−3","tile":"(2, 5)"} |
| 9467.1 | 10081.9 | 25 | enemy_3 | number on screen | {"category":"status","icon":"","reaction":"","text":"Immobilize","tile":"(2, 5)"} |
| 9866.1 | 10070.9 | 25 | enemy_3 | floating feedback | {"numbers":2} |
| 10080.6 | 10233.6 | 25 | enemy_3 | post-action settle | — |
| 10233.9 | 10233.9 | 26 | enemy_3 | step dispatched | {"kind":"intent_refresh","label":""} |
| 10239.3 | 10239.3 | 27 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 10240.9 | 10261.5 | 27 |  | turn-order rail | — |
| 10260.9 | 10260.9 | 28 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 10266.9 | 10487.8 | 28 |  | turn-order rail | — |
| 10279.1 | 10499.4 | — |  | hero hand-off drain | — |
| 10523.3 | 11090.2 | — |  | hero turn-start fire | — |
| 10529.2 | 10609.3 | — |  | hit stop | {"requested_ms":60.0} |
| 10537.5 | 10537.5 | — |  | impact effect start | {"targets":["player"]} |
| 10539.1 | 10816.5 | — |  | camera move | {"kind":"board kick"} |
| 10539.1 | 11100.9 | — |  | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(2, 5)"} |
| 11090.3 | 11761.8 | — |  | hero fatigue | — |
| 11096.5 | 11201.8 | — |  | hit stop | {"requested_ms":60.0} |
| 11100.9 | 11693.4 | — |  | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−2","tile":"(2, 5)"} |
| 11100.9 | 11467.7 | — |  | camera move | {"kind":"board kick"} |
| 11279.5 | 11791.9 | — |  | number on screen | {"category":"status","icon":"","reaction":"","text":"fatigue sets in","tile":"(2, 5)"} |
| 11761.8 | 12240.5 | — |  | hand draw | {"cards":2} |
| 12241.0 | 12291.2 | — |  | publish hero UI | — |
| 12248.4 | 12248.4 | — |  | hero turn banner requested | — |
| 12309.4 | 12309.4 | — |  | hero input accepted | — |

### 08-s1-seed8-1-5_-4-t5

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 3.7 | 3.7 | — |  | enemy turn banner requested | — |
| 26.4 | 305.1 | — |  | turn banner shown | {"text":"ENEMY TURN"} |
| 34.4 | 34.4 | — |  | locked hand capture | — |
| 131.1 | 131.2 | — |  | defeat playback | — |
| 132.7 | 137.4 | — |  | turn-order rail | — |
| 137.1 | 137.1 | 0 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 140.6 | 367.5 | 0 |  | turn-order rail | — |
| 146.9 | 146.9 | 1 | enemy_1 | step dispatched | {"kind":"intent","label":"Ooze Advance"} |
| 159.1 | 159.1 | 2 | enemy_1 | step dispatched | {"kind":"move","label":"Advance"} |
| 159.1 | 596.8 | 2 | enemy_1 | action | {"kind":"move","label":"Advance"} |
| 159.3 | 539.5 | 2 | enemy_1 | unit move | {"actor":"enemy_1","tiles":2} |
| 159.5 | 539.4 | 2 | enemy_1 | sampled playback | {"authored_ms":366.666666666667,"frames":74} |
| 305.1 | 905.3 | 2 | enemy_1 | caption shown | {"text":"Cinder Ooze: Ooze Advance"} |
| 325.6 | 325.8 | 2 | enemy_1 | locked hand capture | — |
| 597.1 | 597.1 | 3 | enemy_1 | step dispatched | {"kind":"intent_refresh","label":""} |
| 599.5 | 599.5 | 4 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 600.1 | 615.4 | 4 |  | turn-order rail | — |
| 615.0 | 615.0 | 5 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 620.0 | 870.4 | 5 |  | turn-order rail | — |
| 626.9 | 872.6 | — |  | hero hand-off drain | — |
| 894.1 | 1454.7 | — |  | hero turn-start fire | — |
| 899.1 | 969.9 | — |  | hit stop | {"requested_ms":60.0} |
| 904.9 | 904.9 | — |  | impact effect start | {"targets":["player"]} |
| 905.3 | 1215.9 | — |  | camera move | {"kind":"board kick"} |
| 905.3 | 1461.8 | — |  | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(5, 5)"} |
| 1454.8 | 2209.7 | — |  | hero fatigue | — |
| 1458.9 | 1592.5 | — |  | hit stop | {"requested_ms":60.0} |
| 1461.8 | 1851.8 | — |  | camera move | {"kind":"board kick"} |
| 1461.8 | 2072.9 | — |  | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−2","tile":"(5, 5)"} |
| 1665.4 | 2245.4 | — |  | number on screen | {"category":"status","icon":"","reaction":"","text":"fatigue sets in","tile":"(5, 5)"} |
| 2209.8 | 2651.9 | — |  | hand draw | {"cards":2} |
| 2652.3 | 2684.7 | — |  | publish hero UI | — |
| 2657.4 | 2657.4 | — |  | hero turn banner requested | — |
| 2699.3 | 2699.3 | — |  | hero input accepted | — |

### 09-s3-seed12-3-16_0-t15

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 53.8 | 53.8 | — |  | locked hand capture | — |
| 325.2 | 325.3 | — |  | locked hand capture | — |
| 344.8 | 344.9 | — |  | defeat playback | — |
| 352.5 | 357.3 | — |  | turn-order rail | — |
| 356.7 | 356.7 | 0 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 360.3 | 409.4 | 0 |  | turn-order rail | — |
| 365.8 | 365.8 | 1 | enemy_1 | step dispatched | {"kind":"status_damage","label":"Fire"} |
| 365.9 | 1180.0 | 1 | enemy_1 | action | {"kind":"status_damage","label":"Fire"} |
| 369.3 | 369.3 | 1 | enemy_1 | status tick | {"actor":"enemy_1","kind":"status_damage","label":"Fire","rule":"","target":"(6, 5)"} |
| 412.5 | 905.4 | 1 | enemy_1 | turn-order rail | — |
| 413.5 | 978.9 | 1 | enemy_1 | feedback deadline | — |
| 532.7 | 532.7 | 1 | enemy_1 | caption lead before motion or feedback | {"derived":true} |
| 532.7 | 861.1 | 1 | enemy_1 | surface effect | {"kind":"surface_damage","surface":"fire","tile":"(6, 5)","trigger":"start"} |
| 532.7 | 979.5 | 1 | enemy_1 | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(6, 5)"} |
| 532.7 | 1216.1 | 1 | enemy_1 | caption shown | {"text":"Fire"} |
| 979.0 | 1180.0 | 1 | enemy_1 | post-action settle | — |
| 1180.2 | 1180.2 | 2 | enemy_1 | step dispatched | {"kind":"intent","label":"Storm Lash"} |
| 1190.0 | 1190.0 | 3 | enemy_1 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 1190.0 | 2908.1 | 3 | enemy_1 | action | {"kind":"ranged","label":"Shot"} |
| 1194.5 | 2725.2 | 3 | enemy_1 | sampled playback | {"authored_ms":1100.0,"frames":66} |
| 1215.5 | 1215.5 | 3 | enemy_1 | attack wind-up | {"kind":"ranged","sample":1} |
| 1215.5 | 1974.7 | 3 | enemy_1 | wind-up to contact | {"derived":true} |
| 1216.1 | 3252.3 | 3 | enemy_1 | caption shown | {"text":"Storm Lash"} |
| 1216.1 | 1975.5 | 3 | enemy_1 | caption lead before motion or feedback | {"derived":true} |
| 1952.4 | 2073.5 | 3 | enemy_1 | hit stop | {"requested_ms":85.0} |
| 1974.7 | 2690.9 | 3 | enemy_1 | contact to last number gone | {"derived":true} |
| 1974.7 | 1974.7 | 3 | enemy_1 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":3021,"sample":36,"sample_count":66} |
| 1974.7 | 1974.7 | 3 | enemy_1 | impact effect start | {"targets":["player"]} |
| 1975.5 | 2448.4 | 3 | enemy_1 | camera move | {"kind":"board kick"} |
| 1975.5 | 2690.9 | 3 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−6","tile":"(6, 4)"} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(2, 6)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(1, 6)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(1, 5)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(6, 4)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(2, 4)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(1, 4)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(7, 3)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(6, 3)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(5, 1)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(6, 1)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(2, 2)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(3, 2)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(4, 2)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(5, 2)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(5, 3)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(4, 3)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(3, 3)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(2, 3)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(7, 2)","trigger":""} |
| 1975.5 | 2756.5 | 3 | enemy_1 | surface effect | {"kind":"surface_conducted","surface":"electrified","tile":"(6, 2)","trigger":""} |
| 2726.6 | 2744.3 | 3 | enemy_1 | floating feedback | {"numbers":1} |
| 2754.4 | 2931.8 | 3 | enemy_1 | turn-order rail | — |
| 2755.9 | 2908.1 | 3 | enemy_1 | post-action settle | — |
| 2908.4 | 2908.4 | 4 | enemy_1 | step dispatched | {"kind":"intent_refresh","label":""} |
| 2930.8 | 2930.8 | 5 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 2935.2 | 2963.0 | 5 |  | turn-order rail | — |
| 2962.4 | 2962.4 | 6 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 2967.6 | 3136.5 | 6 |  | turn-order rail | — |
| 2975.0 | 3158.2 | — |  | hero hand-off drain | — |
| 3206.5 | 3445.7 | — |  | hand draw | {"cards":1} |
| 3446.3 | 3511.4 | — |  | publish hero UI | — |
| 3460.9 | 3460.9 | — |  | hero turn banner suppressed | {"boss_hud_or_caption":true} |
| 3535.7 | 3535.7 | — |  | hero input accepted | — |

### 10-s3-seed12-3-13_-2-t4

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 3.6 | 3.6 | — |  | enemy turn banner requested | — |
| 28.4 | 296.6 | — |  | turn banner shown | {"text":"ENEMY TURN"} |
| 37.9 | 37.9 | — |  | locked hand capture | — |
| 163.2 | 163.3 | — |  | defeat playback | — |
| 165.0 | 167.7 | — |  | turn-order rail | — |
| 167.1 | 167.1 | 0 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 171.4 | 434.4 | 0 |  | turn-order rail | — |
| 179.3 | 179.3 | 1 | enemy_3 | step dispatched | {"kind":"intent","label":"Dust Bolt"} |
| 179.9 | 398.5 | 1 | enemy_3 | pre-action delay | — |
| 288.9 | 289.1 | 1 | enemy_3 | locked hand capture | — |
| 296.6 | 424.2 | 1 | enemy_3 | caption lead before motion or feedback | {"derived":true} |
| 296.6 | 2440.1 | 1 | enemy_3 | caption shown | {"text":"Dust Acolyte: Dust Bolt"} |
| 412.4 | 412.4 | 2 | enemy_3 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 412.5 | 2391.7 | 2 | enemy_3 | action | {"kind":"ranged","label":"Shot"} |
| 416.4 | 2071.7 | 2 | enemy_3 | sampled playback | {"authored_ms":1200.0,"frames":72} |
| 424.2 | 1474.5 | 2 | enemy_3 | wind-up to contact | {"derived":true} |
| 424.2 | 424.2 | 2 | enemy_3 | attack wind-up | {"kind":"ranged","sample":1} |
| 1467.9 | 1627.3 | 2 | enemy_3 | hit stop | {"requested_ms":85.0} |
| 1474.5 | 1474.5 | 2 | enemy_3 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":3122,"sample":51,"sample_count":72} |
| 1474.5 | 1474.5 | 2 | enemy_3 | impact effect start | {"targets":["player"]} |
| 1474.5 | 2230.9 | 2 | enemy_3 | contact to last number gone | {"derived":true} |
| 1475.2 | 1889.9 | 2 | enemy_3 | camera move | {"kind":"board kick"} |
| 1475.2 | 2230.9 | 2 | enemy_3 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−7","tile":"(4, 4)"} |
| 2072.4 | 2237.9 | 2 | enemy_3 | floating feedback | {"numbers":1} |
| 2240.2 | 2403.3 | 2 | enemy_3 | turn-order rail | — |
| 2241.2 | 2391.7 | 2 | enemy_3 | post-action settle | — |
| 2392.0 | 2392.0 | 3 | enemy_3 | step dispatched | {"kind":"intent_refresh","label":""} |
| 2402.7 | 2402.7 | 4 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 2406.6 | 2432.0 | 4 |  | turn-order rail | — |
| 2431.4 | 2431.4 | 5 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 2434.9 | 2625.2 | 5 |  | turn-order rail | — |
| 2439.5 | 2439.5 | 6 | enemy_3 | step dispatched | {"kind":"intent","label":"Siphon"} |
| 2439.6 | 2766.2 | 6 | enemy_3 | pre-action delay | — |
| 2440.1 | 2783.1 | 6 | enemy_3 | caption lead before motion or feedback | {"derived":true} |
| 2440.1 | 4929.7 | 6 | enemy_3 | caption shown | {"text":"Dust Acolyte: Siphon"} |
| 2770.7 | 2770.7 | 7 | enemy_3 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 2770.8 | 4663.2 | 7 | enemy_3 | action | {"kind":"ranged","label":"Shot"} |
| 2774.7 | 4399.0 | 7 | enemy_3 | sampled playback | {"authored_ms":1200.0,"frames":72} |
| 2783.1 | 2783.1 | 7 | enemy_3 | attack wind-up | {"kind":"ranged","sample":1} |
| 2783.1 | 3769.0 | 7 | enemy_3 | wind-up to contact | {"derived":true} |
| 3762.1 | 3889.4 | 7 | enemy_3 | hit stop | {"requested_ms":85.0} |
| 3769.0 | 4484.7 | 7 | enemy_3 | contact to last number gone | {"derived":true} |
| 3769.0 | 3769.0 | 7 | enemy_3 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":3258,"sample":48,"sample_count":72} |
| 3769.0 | 3769.0 | 7 | enemy_3 | impact effect start | {"targets":["player"]} |
| 3769.4 | 4225.9 | 7 | enemy_3 | camera move | {"kind":"board kick"} |
| 3769.4 | 4484.7 | 7 | enemy_3 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−6","tile":"(4, 4)"} |
| 4399.7 | 4504.6 | 7 | enemy_3 | floating feedback | {"numbers":1} |
| 4506.7 | 4675.7 | 7 | enemy_3 | turn-order rail | — |
| 4507.7 | 4663.2 | 7 | enemy_3 | post-action settle | — |
| 4663.4 | 4663.4 | 8 | enemy_3 | step dispatched | {"kind":"intent_refresh","label":""} |
| 4674.6 | 4674.6 | 9 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 4679.4 | 4687.7 | 9 |  | turn-order rail | — |
| 4687.0 | 4687.0 | 10 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 4691.2 | 4872.9 | 10 |  | turn-order rail | — |
| 4698.3 | 4875.7 | — |  | hero hand-off drain | — |
| 4897.6 | 5392.3 | — |  | hand draw | {"cards":2} |
| 5392.5 | 5429.4 | — |  | publish hero UI | — |
| 5397.3 | 5397.3 | — |  | hero turn banner requested | — |
| 5455.3 | 5455.3 | — |  | hero input accepted | — |

### 11-s4-seed12-4-19_-14-t4

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 5.1 | 5.1 | — |  | enemy turn banner requested | — |
| 31.7 | 405.1 | — |  | turn banner shown | {"text":"ENEMY TURN"} |
| 52.6 | 52.6 | — |  | locked hand capture | — |
| 198.6 | 198.8 | — |  | locked hand capture | — |
| 213.8 | 213.9 | — |  | defeat playback | — |
| 217.8 | 221.5 | — |  | turn-order rail | — |
| 220.5 | 220.5 | 0 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 228.1 | 472.1 | 0 |  | turn-order rail | — |
| 237.3 | 237.3 | 1 | enemy_5 | step dispatched | {"kind":"intent","label":"Dust Bolt"} |
| 237.7 | 373.1 | 1 | enemy_5 | pre-action delay | — |
| 394.8 | 394.8 | 2 | enemy_5 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 394.9 | 2323.6 | 2 | enemy_5 | action | {"kind":"ranged","label":"Shot"} |
| 397.7 | 2038.7 | 2 | enemy_5 | sampled playback | {"authored_ms":1200.0,"frames":72} |
| 404.0 | 404.0 | 2 | enemy_5 | attack wind-up | {"kind":"ranged","sample":1} |
| 404.0 | 1401.4 | 2 | enemy_5 | wind-up to contact | {"derived":true} |
| 405.1 | 1402.0 | 2 | enemy_5 | caption lead before motion or feedback | {"derived":true} |
| 405.1 | 2413.6 | 2 | enemy_5 | caption shown | {"text":"Dust Acolyte: Dust Bolt"} |
| 1392.5 | 1529.6 | 2 | enemy_5 | hit stop | {"requested_ms":85.0} |
| 1401.4 | 2125.7 | 2 | enemy_5 | contact to last number gone | {"derived":true} |
| 1401.4 | 1401.4 | 2 | enemy_5 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":3415,"sample":48,"sample_count":72} |
| 1401.4 | 1401.4 | 2 | enemy_5 | impact effect start | {"targets":["player"]} |
| 1402.0 | 1858.5 | 2 | enemy_5 | camera move | {"kind":"board kick"} |
| 1402.0 | 2125.7 | 2 | enemy_5 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−7","tile":"(3, 6)"} |
| 2039.5 | 2150.4 | 2 | enemy_5 | floating feedback | {"numbers":1} |
| 2154.0 | 2333.5 | 2 | enemy_5 | turn-order rail | — |
| 2167.0 | 2323.6 | 2 | enemy_5 | post-action settle | — |
| 2323.8 | 2323.8 | 3 | enemy_5 | step dispatched | {"kind":"intent_refresh","label":""} |
| 2332.9 | 2332.9 | 4 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 2340.3 | 2361.3 | 4 |  | turn-order rail | — |
| 2360.7 | 2360.7 | 5 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 2367.5 | 2405.6 | 5 |  | turn-order rail | — |
| 2381.3 | 2381.3 | 6 | enemy_4 | step dispatched | {"kind":"status_damage","label":"Fire"} |
| 2381.4 | 3136.9 | 6 | enemy_4 | action | {"kind":"status_damage","label":"Fire"} |
| 2382.9 | 2382.9 | 6 | enemy_4 | status tick | {"actor":"enemy_4","kind":"status_damage","label":"Fire","rule":"","target":"(3, 5)"} |
| 2411.2 | 3096.4 | 6 | enemy_4 | turn-order rail | — |
| 2412.4 | 2985.1 | 6 | enemy_4 | feedback deadline | — |
| 2413.6 | 3137.5 | 6 | enemy_4 | caption shown | {"text":"Tunnel Crawler: Fire"} |
| 2413.6 | 2413.6 | 6 | enemy_4 | caption lead before motion or feedback | {"derived":true} |
| 2413.6 | 3002.8 | 6 | enemy_4 | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(3, 5)"} |
| 2413.6 | 2848.1 | 6 | enemy_4 | surface effect | {"kind":"surface_damage","surface":"fire","tile":"(3, 5)","trigger":"start"} |
| 2985.2 | 3136.9 | 6 | enemy_4 | post-action settle | — |
| 3137.0 | 3137.0 | 7 | enemy_4 | step dispatched | {"kind":"intent","label":"Skitter Strike"} |
| 3137.1 | 3393.3 | 7 | enemy_4 | pre-action delay | — |
| 3137.5 | 4810.5 | 7 | enemy_4 | caption shown | {"text":"Tunnel Crawler: Skitter Strike"} |
| 3137.5 | 3412.4 | 7 | enemy_4 | caption lead before motion or feedback | {"derived":true} |
| 3398.6 | 3398.6 | 8 | enemy_4 | step dispatched | {"kind":"melee","label":"Strike"} |
| 3398.7 | 4757.7 | 8 | enemy_4 | action | {"kind":"melee","label":"Strike"} |
| 3403.1 | 4317.5 | 8 | enemy_4 | sampled playback | {"authored_ms":600.0,"frames":36} |
| 3412.4 | 3412.4 | 8 | enemy_4 | attack wind-up | {"kind":"melee","sample":1} |
| 3412.4 | 3821.6 | 8 | enemy_4 | wind-up to contact | {"derived":true} |
| 3806.7 | 3970.5 | 8 | enemy_4 | hit stop | {"requested_ms":85.0} |
| 3821.6 | 3821.6 | 8 | enemy_4 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":3558,"sample":19,"sample_count":36} |
| 3821.6 | 3821.6 | 8 | enemy_4 | impact effect start | {"targets":["player"]} |
| 3821.6 | 4567.5 | 8 | enemy_4 | contact to last number gone | {"derived":true} |
| 3822.7 | 4283.9 | 8 | enemy_4 | camera move | {"kind":"board kick"} |
| 3822.7 | 4567.5 | 8 | enemy_4 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−7","tile":"(3, 6)"} |
| 4318.5 | 4586.9 | 8 | enemy_4 | floating feedback | {"numbers":1} |
| 4591.4 | 4764.2 | 8 | enemy_4 | turn-order rail | — |
| 4592.6 | 4757.7 | 8 | enemy_4 | post-action settle | — |
| 4758.0 | 4758.0 | 9 | enemy_4 | step dispatched | {"kind":"intent_refresh","label":""} |
| 4763.5 | 4763.5 | 10 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 4769.2 | 4792.0 | 10 |  | turn-order rail | — |
| 4791.3 | 4791.3 | 11 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 4797.6 | 4959.0 | 11 |  | turn-order rail | — |
| 4809.0 | 4809.0 | 12 | enemy_1 | step dispatched | {"kind":"intent","label":"Spear Cast"} |
| 4809.3 | 5120.4 | 12 | enemy_1 | pre-action delay | — |
| 4810.5 | 6786.8 | 12 | enemy_1 | caption shown | {"text":"Frostglass Lancer: Spear Cast"} |
| 4810.5 | 5150.3 | 12 | enemy_1 | caption lead before motion or feedback | {"derived":true} |
| 5138.4 | 5138.4 | 13 | enemy_1 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 5138.5 | 6702.3 | 13 | enemy_1 | action | {"kind":"ranged","label":"Shot"} |
| 5140.5 | 6457.6 | 13 | enemy_1 | sampled playback | {"authored_ms":950.0,"frames":57} |
| 5150.3 | 5150.3 | 13 | enemy_1 | attack wind-up | {"kind":"ranged","sample":1} |
| 5150.3 | 5804.8 | 13 | enemy_1 | wind-up to contact | {"derived":true} |
| 5794.5 | 5929.3 | 13 | enemy_1 | hit stop | {"requested_ms":85.0} |
| 5804.8 | 5804.8 | 13 | enemy_1 | impact effect start | {"targets":[]} |
| 5804.8 | 5804.8 | 13 | enemy_1 | contact | {"evidence":"contact effect submitted","process_frame":3669,"sample":32,"sample_count":57} |
| 5804.8 | 6528.0 | 13 | enemy_1 | contact to last number gone | {"derived":true} |
| 5806.0 | 6528.0 | 13 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−6","tile":"(3, 6)"} |
| 5806.0 | 6287.1 | 13 | enemy_1 | camera move | {"kind":"board kick"} |
| 6457.6 | 6541.5 | 13 | enemy_1 | floating feedback | {"numbers":1} |
| 6550.3 | 6702.3 | 13 | enemy_1 | post-action settle | — |
| 6702.7 | 6702.7 | 14 | enemy_1 | step dispatched | {"kind":"intent_refresh","label":""} |
| 6707.6 | 6707.6 | 15 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 6709.2 | 6760.9 | 15 |  | turn-order rail | — |
| 6759.8 | 6759.8 | 16 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 6769.4 | 6903.3 | 16 |  | turn-order rail | — |
| 6785.5 | 6785.5 | 17 | enemy_2 | step dispatched | {"kind":"intent","label":"Bulwark"} |
| 6785.8 | 7044.9 | 17 | enemy_2 | pre-action delay | — |
| 6786.8 | 7961.3 | 17 | enemy_2 | caption shown | {"text":"Stone Warden: Bulwark"} |
| 6786.8 | 7074.4 | 17 | enemy_2 | caption lead before motion or feedback | {"derived":true} |
| 7051.0 | 7051.0 | 18 | enemy_2 | step dispatched | {"kind":"block","label":"Guard Allies"} |
| 7051.1 | 7891.7 | 18 | enemy_2 | action | {"kind":"block","label":"Guard Allies"} |
| 7052.6 | 7052.6 | 18 | enemy_2 | resolved block | {"actor":"enemy_2","kind":"block","label":"Guard Allies","rule":"","target":"(6, 6)"} |
| 7052.8 | 7661.3 | 18 | enemy_2 | floating feedback | {"numbers":3} |
| 7073.3 | 7073.3 | 18 | enemy_2 | impact effect start | {"targets":["enemy_1","enemy_4","enemy_5"]} |
| 7074.4 | 7670.8 | 18 | enemy_2 | number on screen | {"category":"status","icon":"block","reaction":"","text":"+8","tile":"(1, 6)"} |
| 7074.4 | 7670.8 | 18 | enemy_2 | number on screen | {"category":"status","icon":"block","reaction":"","text":"+8","tile":"(3, 5)"} |
| 7074.4 | 7670.8 | 18 | enemy_2 | number on screen | {"category":"status","icon":"block","reaction":"","text":"+8","tile":"(2, 4)"} |
| 7669.9 | 7891.7 | 18 | enemy_2 | post-action settle | — |
| 7891.9 | 7891.9 | 19 | enemy_2 | step dispatched | {"kind":"intent_refresh","label":""} |
| 7897.9 | 7897.9 | 20 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 7899.2 | 7937.8 | 20 |  | turn-order rail | — |
| 7936.7 | 7936.7 | 21 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 7948.3 | 8089.1 | 21 |  | turn-order rail | — |
| 7960.4 | 7960.4 | 22 | enemy_5 | step dispatched | {"kind":"intent","label":"Dust Bolt"} |
| 7960.5 | 8295.0 | 22 | enemy_5 | pre-action delay | — |
| 7961.3 | 10327.9 | 22 | enemy_5 | caption shown | {"text":"Dust Acolyte: Dust Bolt"} |
| 7961.3 | 8326.5 | 22 | enemy_5 | caption lead before motion or feedback | {"derived":true} |
| 8314.1 | 8314.1 | 23 | enemy_5 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 8314.2 | 10234.4 | 23 | enemy_5 | action | {"kind":"ranged","label":"Shot"} |
| 8318.9 | 9935.3 | 23 | enemy_5 | sampled playback | {"authored_ms":1200.0,"frames":72} |
| 8326.5 | 8326.5 | 23 | enemy_5 | attack wind-up | {"kind":"ranged","sample":1} |
| 8326.5 | 9335.3 | 23 | enemy_5 | wind-up to contact | {"derived":true} |
| 9323.4 | 9440.8 | 23 | enemy_5 | hit stop | {"requested_ms":85.0} |
| 9335.3 | 9335.3 | 23 | enemy_5 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":3866,"sample":48,"sample_count":72} |
| 9335.3 | 9335.3 | 23 | enemy_5 | impact effect start | {"targets":["player"]} |
| 9335.3 | 10040.6 | 23 | enemy_5 | contact to last number gone | {"derived":true} |
| 9336.6 | 9734.3 | 23 | enemy_5 | camera move | {"kind":"board kick"} |
| 9336.6 | 10040.6 | 23 | enemy_5 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−7","tile":"(3, 6)"} |
| 9936.2 | 10057.1 | 23 | enemy_5 | floating feedback | {"numbers":1} |
| 10061.3 | 10249.6 | 23 | enemy_5 | turn-order rail | — |
| 10076.9 | 10234.4 | 23 | enemy_5 | post-action settle | — |
| 10234.6 | 10234.6 | 24 | enemy_5 | step dispatched | {"kind":"intent_refresh","label":""} |
| 10248.5 | 10248.5 | 25 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 10255.6 | 10275.0 | 25 |  | turn-order rail | — |
| 10274.3 | 10274.3 | 26 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 10283.5 | 10322.5 | 26 |  | turn-order rail | — |
| 10297.6 | 10297.6 | 27 | enemy_4 | step dispatched | {"kind":"status_damage","label":"Fire"} |
| 10297.7 | 11068.9 | 27 | enemy_4 | action | {"kind":"status_damage","label":"Fire"} |
| 10298.9 | 10298.9 | 27 | enemy_4 | status tick | {"actor":"enemy_4","kind":"status_damage","label":"Fire","rule":"","target":"(3, 5)"} |
| 10326.3 | 11023.2 | 27 | enemy_4 | turn-order rail | — |
| 10327.1 | 10915.5 | 27 | enemy_4 | feedback deadline | — |
| 10327.9 | 10327.9 | 27 | enemy_4 | caption lead before motion or feedback | {"derived":true} |
| 10327.9 | 10759.0 | 27 | enemy_4 | surface effect | {"kind":"surface_damage","surface":"fire","tile":"(3, 5)","trigger":"start"} |
| 10327.9 | 10916.7 | 27 | enemy_4 | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(3, 5)"} |
| 10327.9 | 11070.0 | 27 | enemy_4 | caption shown | {"text":"Tunnel Crawler: Fire"} |
| 10915.6 | 11068.9 | 27 | enemy_4 | post-action settle | — |
| 11069.1 | 11069.1 | 28 | enemy_4 | step dispatched | {"kind":"intent","label":"Skitter Strike"} |
| 11069.2 | 11378.0 | 28 | enemy_4 | pre-action delay | — |
| 11070.0 | 11399.9 | 28 | enemy_4 | caption lead before motion or feedback | {"derived":true} |
| 11070.0 | 13020.2 | 28 | enemy_4 | caption shown | {"text":"Tunnel Crawler: Skitter Strike"} |
| 11387.5 | 11387.5 | 29 | enemy_4 | step dispatched | {"kind":"melee","label":"Strike"} |
| 11387.6 | 12655.8 | 29 | enemy_4 | action | {"kind":"melee","label":"Strike"} |
| 11392.9 | 12273.8 | 29 | enemy_4 | sampled playback | {"authored_ms":600.0,"frames":36} |
| 11399.9 | 11766.7 | 29 | enemy_4 | wind-up to contact | {"derived":true} |
| 11399.9 | 11399.9 | 29 | enemy_4 | attack wind-up | {"kind":"melee","sample":1} |
| 11756.4 | 11875.2 | 29 | enemy_4 | hit stop | {"requested_ms":85.0} |
| 11766.7 | 12472.5 | 29 | enemy_4 | contact to last number gone | {"derived":true} |
| 11766.7 | 11766.7 | 29 | enemy_4 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":3999,"sample":17,"sample_count":36} |
| 11766.7 | 11766.7 | 29 | enemy_4 | impact effect start | {"targets":["player"]} |
| 11767.7 | 12169.0 | 29 | enemy_4 | camera move | {"kind":"board kick"} |
| 11767.7 | 12472.5 | 29 | enemy_4 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−7","tile":"(3, 6)"} |
| 12275.0 | 12487.4 | 29 | enemy_4 | floating feedback | {"numbers":1} |
| 12490.3 | 12664.8 | 29 | enemy_4 | turn-order rail | — |
| 12491.7 | 12655.8 | 29 | enemy_4 | post-action settle | — |
| 12656.1 | 12656.1 | 30 | enemy_4 | step dispatched | {"kind":"intent_refresh","label":""} |
| 12664.0 | 12664.0 | 31 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 12671.5 | 12679.9 | 31 |  | turn-order rail | — |
| 12679.2 | 12679.2 | 32 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 12690.3 | 12922.8 | 32 |  | turn-order rail | — |
| 12703.4 | 12946.6 | — |  | hero hand-off drain | — |
| 12972.5 | 13501.7 | — |  | hand draw | {"cards":2} |
| 13502.3 | 13588.1 | — |  | publish hero UI | — |
| 13520.4 | 13520.4 | — |  | hero turn banner requested | — |
| 13637.1 | 13637.1 | — |  | hero input accepted | — |

### 12-s1-seed1-1-7_-3-t3

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 4.7 | 4.7 | — |  | enemy turn banner requested | — |
| 31.0 | 416.0 | — |  | turn banner shown | {"text":"ENEMY TURN"} |
| 49.3 | 49.3 | — |  | locked hand capture | — |
| 174.7 | 174.8 | — |  | defeat playback | — |
| 178.3 | 182.3 | — |  | turn-order rail | — |
| 181.6 | 181.6 | 0 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 191.7 | 232.0 | 0 |  | turn-order rail | — |
| 203.5 | 203.5 | 1 | enemy_3 | step dispatched | {"kind":"status_damage","label":"Fire"} |
| 203.7 | 1048.6 | 1 | enemy_3 | action | {"kind":"status_damage","label":"Fire"} |
| 204.6 | 204.6 | 1 | enemy_3 | status tick | {"actor":"enemy_3","kind":"status_damage","label":"Fire","rule":"","target":"(2, 6)"} |
| 234.6 | 781.4 | 1 | enemy_3 | turn-order rail | — |
| 235.7 | 816.0 | 1 | enemy_3 | feedback deadline | — |
| 390.4 | 390.6 | 1 | enemy_3 | locked hand capture | — |
| 416.0 | 416.0 | 1 | enemy_3 | caption lead before motion or feedback | {"derived":true} |
| 416.0 | 667.5 | 1 | enemy_3 | surface effect | {"kind":"surface_damage","surface":"fire","tile":"(2, 6)","trigger":"start"} |
| 416.0 | 1069.3 | 1 | enemy_3 | caption shown | {"text":"Tunnel Crawler: Fire"} |
| 416.0 | 816.6 | 1 | enemy_3 | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(2, 6)"} |
| 816.0 | 1048.6 | 1 | enemy_3 | post-action settle | — |
| 1048.9 | 1048.9 | 2 | enemy_3 | step dispatched | {"kind":"intent","label":"Skitter Strike"} |
| 1056.7 | 1056.7 | 3 | enemy_3 | step dispatched | {"kind":"melee","label":"Strike"} |
| 1056.8 | 2419.4 | 3 | enemy_3 | action | {"kind":"melee","label":"Strike"} |
| 1062.3 | 2067.0 | 3 | enemy_3 | sampled playback | {"authored_ms":600.0,"frames":36} |
| 1068.9 | 1408.1 | 3 | enemy_3 | wind-up to contact | {"derived":true} |
| 1068.9 | 1068.9 | 3 | enemy_3 | attack wind-up | {"kind":"melee","sample":1} |
| 1069.3 | 1409.2 | 3 | enemy_3 | caption lead before motion or feedback | {"derived":true} |
| 1069.3 | 2499.0 | 3 | enemy_3 | caption shown | {"text":"Tunnel Crawler: Skitter Strike"} |
| 1395.4 | 1645.3 | 3 | enemy_3 | hit stop | {"requested_ms":85.0} |
| 1408.1 | 1408.1 | 3 | enemy_3 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":4163,"sample":16,"sample_count":36} |
| 1408.1 | 1408.1 | 3 | enemy_3 | impact effect start | {"targets":["player"]} |
| 1408.1 | 2240.8 | 3 | enemy_3 | contact to last number gone | {"derived":true} |
| 1409.2 | 1966.2 | 3 | enemy_3 | camera move | {"kind":"board kick"} |
| 1409.2 | 2240.8 | 3 | enemy_3 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−6","tile":"(3, 6)"} |
| 2067.8 | 2261.2 | 3 | enemy_3 | floating feedback | {"numbers":1} |
| 2263.5 | 2426.8 | 3 | enemy_3 | turn-order rail | — |
| 2264.4 | 2419.4 | 3 | enemy_3 | post-action settle | — |
| 2419.8 | 2419.8 | 4 | enemy_3 | step dispatched | {"kind":"intent_refresh","label":""} |
| 2426.4 | 2426.4 | 5 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 2431.5 | 2451.6 | 5 |  | turn-order rail | — |
| 2451.2 | 2451.2 | 6 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 2458.8 | 2492.7 | 6 |  | turn-order rail | — |
| 2470.2 | 2470.2 | 7 | enemy_1 | step dispatched | {"kind":"status_damage","label":"Fire"} |
| 2470.3 | 3304.8 | 7 | enemy_1 | action | {"kind":"status_damage","label":"Fire"} |
| 2471.3 | 2471.3 | 7 | enemy_1 | status tick | {"actor":"enemy_1","kind":"status_damage","label":"Fire","rule":"","target":"(3, 7)"} |
| 2497.2 | 2926.7 | 7 | enemy_1 | turn-order rail | — |
| 2498.2 | 3077.9 | 7 | enemy_1 | feedback deadline | — |
| 2499.0 | 2499.0 | 7 | enemy_1 | caption lead before motion or feedback | {"derived":true} |
| 2499.0 | 3078.5 | 7 | enemy_1 | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(3, 7)"} |
| 2499.0 | 2936.0 | 7 | enemy_1 | surface effect | {"kind":"surface_damage","surface":"fire","tile":"(3, 7)","trigger":"start"} |
| 2499.0 | 3306.0 | 7 | enemy_1 | caption shown | {"text":"Dust Acolyte: Fire"} |
| 3077.9 | 3304.8 | 7 | enemy_1 | post-action settle | — |
| 3305.1 | 3305.1 | 8 | enemy_1 | step dispatched | {"kind":"intent","label":"Siphon"} |
| 3305.4 | 3560.2 | 8 | enemy_1 | pre-action delay | — |
| 3306.0 | 3574.5 | 8 | enemy_1 | caption lead before motion or feedback | {"derived":true} |
| 3306.0 | 6738.6 | 8 | enemy_1 | caption shown | {"text":"Dust Acolyte: Siphon"} |
| 3565.1 | 3565.1 | 9 | enemy_1 | step dispatched | {"kind":"ranged","label":"Shot"} |
| 3565.1 | 5750.7 | 9 | enemy_1 | action | {"kind":"ranged","label":"Shot"} |
| 3566.8 | 5356.0 | 9 | enemy_1 | sampled playback | {"authored_ms":1200.0,"frames":72} |
| 3574.5 | 3574.5 | 9 | enemy_1 | attack wind-up | {"kind":"ranged","sample":1} |
| 3574.5 | 4705.9 | 9 | enemy_1 | wind-up to contact | {"derived":true} |
| 4696.0 | 4970.7 | 9 | enemy_1 | hit stop | {"requested_ms":85.0} |
| 4705.9 | 5567.2 | 9 | enemy_1 | contact to last number gone | {"derived":true} |
| 4705.9 | 4705.9 | 9 | enemy_1 | impact effect start | {"targets":["player"]} |
| 4705.9 | 4705.9 | 9 | enemy_1 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":4309,"sample":54,"sample_count":72} |
| 4706.6 | 5197.6 | 9 | enemy_1 | camera move | {"kind":"board kick"} |
| 4706.6 | 5567.2 | 9 | enemy_1 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−5","tile":"(3, 6)"} |
| 5356.6 | 5593.8 | 9 | enemy_1 | floating feedback | {"numbers":1} |
| 5596.8 | 6008.3 | 9 | enemy_1 | turn-order rail | — |
| 5598.0 | 5750.7 | 9 | enemy_1 | post-action settle | — |
| 5751.0 | 5751.0 | 10 | enemy_1 | step dispatched | {"kind":"heal","label":"Heal"} |
| 5751.1 | 6637.6 | 10 | enemy_1 | action | {"kind":"heal","label":"Heal"} |
| 5752.1 | 5752.1 | 10 | enemy_1 | resolved heal | {"actor":"enemy_1","kind":"heal","label":"Heal","rule":"","target":"(3, 7)"} |
| 5752.2 | 6362.5 | 10 | enemy_1 | floating feedback | {"numbers":1} |
| 5771.8 | 6368.5 | 10 | enemy_1 | number on screen | {"category":"heal","icon":"heal","reaction":"","text":"+2","tile":"(3, 7)"} |
| 6366.6 | 6646.9 | 10 | enemy_1 | turn-order rail | — |
| 6367.9 | 6637.5 | 10 | enemy_1 | post-action settle | — |
| 6637.9 | 6637.9 | 11 | enemy_1 | step dispatched | {"kind":"intent_refresh","label":""} |
| 6646.3 | 6646.3 | 12 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 6651.4 | 6694.3 | 12 |  | turn-order rail | — |
| 6694.0 | 6694.0 | 13 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 6703.3 | 6992.3 | 13 |  | turn-order rail | — |
| 6718.8 | 6718.8 | 14 | enemy_4 | step dispatched | {"kind":"intent","label":"Triage Suture"} |
| 6724.6 | 6724.6 | 15 | enemy_4 | step dispatched | {"kind":"move","label":"Advance"} |
| 6724.6 | 6997.9 | 15 | enemy_4 | action | {"kind":"move","label":"Advance"} |
| 6724.9 | 6938.6 | 15 | enemy_4 | unit move | {"actor":"enemy_4","tiles":1} |
| 6725.1 | 6938.6 | 15 | enemy_4 | sampled playback | {"authored_ms":183.333333333333,"frames":33} |
| 6738.6 | 7162.2 | 15 | enemy_4 | caption shown | {"text":"Grave Surgeon: Triage Suture"} |
| 6998.2 | 6998.2 | 16 | enemy_4 | step dispatched | {"kind":"intent_refresh","label":""} |
| 7001.7 | 7001.7 | 17 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 7002.8 | 7043.5 | 17 |  | turn-order rail | — |
| 7042.9 | 7042.9 | 18 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 7051.7 | 7085.6 | 18 |  | turn-order rail | — |
| 7063.2 | 7063.2 | 19 | enemy_3 | step dispatched | {"kind":"status_damage","label":"Fire"} |
| 7063.3 | 8016.1 | 19 | enemy_3 | action | {"kind":"status_damage","label":"Fire"} |
| 7064.3 | 7064.3 | 19 | enemy_3 | status tick | {"actor":"enemy_3","kind":"status_damage","label":"Fire","rule":"","target":"(2, 6)"} |
| 7090.1 | 7559.7 | 19 | enemy_3 | turn-order rail | — |
| 7090.4 | 7679.7 | 19 | enemy_3 | feedback deadline | — |
| 7162.2 | 8017.2 | 19 | enemy_3 | caption shown | {"text":"Tunnel Crawler: Fire"} |
| 7162.2 | 7680.3 | 19 | enemy_3 | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(2, 6)"} |
| 7162.2 | 7162.2 | 19 | enemy_3 | caption lead before motion or feedback | {"derived":true} |
| 7162.2 | 7532.1 | 19 | enemy_3 | surface effect | {"kind":"surface_damage","surface":"fire","tile":"(2, 6)","trigger":"start"} |
| 7679.8 | 8016.1 | 19 | enemy_3 | post-action settle | — |
| 8016.3 | 8016.3 | 20 | enemy_3 | step dispatched | {"kind":"intent","label":"Skitter Strike"} |
| 8016.6 | 8275.5 | 20 | enemy_3 | pre-action delay | — |
| 8017.2 | 8295.3 | 20 | enemy_3 | caption lead before motion or feedback | {"derived":true} |
| 8017.2 | 10060.9 | 20 | enemy_3 | caption shown | {"text":"Tunnel Crawler: Skitter Strike"} |
| 8283.0 | 8283.0 | 21 | enemy_3 | step dispatched | {"kind":"melee","label":"Strike"} |
| 8283.1 | 9758.4 | 21 | enemy_3 | action | {"kind":"melee","label":"Strike"} |
| 8287.7 | 9320.1 | 21 | enemy_3 | sampled playback | {"authored_ms":600.0,"frames":36} |
| 8295.3 | 8724.3 | 21 | enemy_3 | wind-up to contact | {"derived":true} |
| 8295.3 | 8295.3 | 21 | enemy_3 | attack wind-up | {"kind":"melee","sample":1} |
| 8710.8 | 8990.1 | 21 | enemy_3 | hit stop | {"requested_ms":85.0} |
| 8724.3 | 9589.1 | 21 | enemy_3 | contact to last number gone | {"derived":true} |
| 8724.3 | 8724.3 | 21 | enemy_3 | contact | {"evidence":"effect progress reached feedback threshold","process_frame":4488,"sample":20,"sample_count":36} |
| 8724.3 | 8724.3 | 21 | enemy_3 | impact effect start | {"targets":["player"]} |
| 8724.9 | 9202.3 | 21 | enemy_3 | camera move | {"kind":"board kick"} |
| 8724.9 | 9589.1 | 21 | enemy_3 | number on screen | {"category":"damage","icon":"","reaction":"hit","text":"−6","tile":"(3, 6)"} |
| 9321.1 | 9598.7 | 21 | enemy_3 | floating feedback | {"numbers":1} |
| 9601.3 | 9765.2 | 21 | enemy_3 | turn-order rail | — |
| 9602.6 | 9758.4 | 21 | enemy_3 | post-action settle | — |
| 9758.7 | 9758.7 | 22 | enemy_3 | step dispatched | {"kind":"intent_refresh","label":""} |
| 9764.8 | 9764.8 | 23 |  | step dispatched | {"kind":"turn_order","label":"reschedule"} |
| 9771.6 | 9779.6 | 23 |  | turn-order rail | — |
| 9779.1 | 9779.1 | 24 |  | step dispatched | {"kind":"turn_order","label":"activate"} |
| 9786.2 | 10000.5 | 24 |  | turn-order rail | — |
| 9798.3 | 10019.7 | — |  | hero hand-off drain | — |
| 10043.0 | 10614.8 | — |  | hero turn-start fire | — |
| 10050.5 | 10123.6 | — |  | hit stop | {"requested_ms":60.0} |
| 10060.5 | 10060.5 | — |  | impact effect start | {"targets":["player"]} |
| 10060.9 | 10648.5 | — |  | number on screen | {"category":"damage","icon":"surface_fire","reaction":"hit","text":"−3","tile":"(3, 6)"} |
| 10060.9 | 10339.4 | — |  | camera move | {"kind":"board kick"} |
| 10614.9 | 11157.3 | — |  | hand draw | {"cards":2} |
| 11157.9 | 11203.3 | — |  | publish hero UI | — |
| 11162.8 | 11162.8 | — |  | hero turn banner requested | — |
| 11222.9 | 11222.9 | — |  | hero input accepted | — |

## Native renderer measurements

Native 1920×1080 RGB, 100% UI scale, default Combat speed, reduced motion off and cel look all. [Capture artifacts](captures/native.syHCHS/).
Zero is activation of the production Pass control. Paired images are consecutive post-draw frames. Readback is synchronous and can affect cadence. The table records measured readback and frame intervals.

### Native per fixture

| Fixture | Pass to endpoint (ms) | Actions | ms/action | All still (ms) | Still in ≥150 ms runs (ms) | Ambient candidates above threshold | Resting control above threshold | Median frame / readback (ms) | Longest frame gap (ms) | Endpoint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| [01-s0-seed1-0-4_0-t9](captures/native.syHCHS/01-s0-seed1-0-4_0-t9/still.json) | 4217.6 | 2 | 2108.8 | 215.3 | 0.0 | 3/4 | 116/121 | 14.8 / 6.0 | 123.0 | hero tile opened movement selection |
| [02-s0-seed12-0-1_3-t7](captures/native.syHCHS/02-s0-seed12-0-1_3-t7/still.json) | 8875.7 | 6 | 1479.3 | 239.2 | 0.0 | 38/38 | 119/119 | 12.4 / 6.7 | 76.7 | hero tile opened movement selection |
| [03-s2-seed8-2-11_-9-t64](captures/native.syHCHS/03-s2-seed8-2-11_-9-t64/still.json) | 1332.5 | 0 | — | 27.5 | 0.0 | 47/49 | 115/120 | 10.5 / 5.8 | 72.9 | hero tile opened movement selection |
| [04-s0-seed8-0--3_2-t5](captures/native.syHCHS/04-s0-seed8-0--3_2-t5/still.json) | 9538.8 | 6 | 1589.8 | 196.9 | 0.0 | 103/103 | 106/106 | 12.3 / 7.2 | 75.8 | hero tile opened movement selection |
| [05-s2-seed1-2-9_-7-t2](captures/native.syHCHS/05-s2-seed1-2-9_-7-t2/still.json) | 5825.9 | 5 | 1165.2 | 152.3 | 0.0 | 13/14 | 115/115 | 15.9 / 6.9 | 76.6 | hero tile opened movement selection |
| [06-s2-seed1-2-11_-10-t5](captures/native.syHCHS/06-s2-seed1-2-11_-10-t5/still.json) | 10690.9 | 8 | 1336.4 | 230.8 | 0.0 | 192/193 | 101/101 | 13.3 / 7.3 | 62.7 | hero tile opened movement selection |
| [07-s4-seed1-4-19_-19-t4](captures/native.syHCHS/07-s4-seed1-4-19_-19-t4/still.json) | 11520.5 | 8 | 1440.1 | 337.6 | 0.0 | 141/141 | 107/107 | 15.2 / 7.9 | 145.2 | card 0 entered selection |
| [08-s1-seed8-1-5_-4-t5](captures/native.syHCHS/08-s1-seed8-1-5_-4-t5/still.json) | 2490.8 | 1 | 2490.8 | 68.4 | 0.0 | 3/3 | 121/121 | 10.3 / 5.9 | 66.4 | hero tile opened movement selection |
| [09-s3-seed12-3-16_0-t15](captures/native.syHCHS/09-s3-seed12-3-16_0-t15/still.json) | 3180.4 | 2 | 1590.2 | 39.1 | 0.0 | 18/18 | 120/120 | 17.2 / 7.2 | 79.9 | hero tile opened movement selection |
| [10-s3-seed12-3-13_-2-t4](captures/native.syHCHS/10-s3-seed12-3-13_-2-t4/still.json) | 5084.9 | 2 | 2542.4 | 140.2 | 0.0 | 2/2 | 120/120 | 10.5 / 6.5 | 57.7 | hero tile opened movement selection |
| [11-s4-seed12-4-19_-14-t4](captures/native.syHCHS/11-s4-seed12-4-19_-14-t4/still.json) | 12481.7 | 8 | 1560.2 | 325.6 | 0.0 | 128/128 | 97/97 | 13.3 / 7.9 | 68.6 | hero tile opened movement selection |
| [12-s1-seed1-1-7_-3-t3](captures/native.syHCHS/12-s1-seed1-1-7_-3-t3/still.json) | 9619.9 | 8 | 1202.5 | 217.9 | 0.0 | 81/81 | 115/115 | 12.6 / 7.3 | 80.5 | card 0 entered selection |

The settled next-hero-turn idle control exceeded the threshold in **1352/1362 pairs (99.3%)**. This separate resting-board sample measures idle and persistent idle-UI motion without Pass, travel or attack playback.

During the enemy turn, motion with no observed foreground activity met or exceeded the threshold in **769/774 pairs (99.4%)**.
This is an ambient-only candidate count. Both endpoint frames had no tracked foreground transitions or animation. Untracked changes can enter the count, and idle motion overlapping a foreground beat cannot be isolated this way.

### Ten longest still runs

| Fixture | Start–end (ms) | Duration (ms) | Before | After | Holding wait | Strip |
|---|---:|---:|---|---|---|---|

No still run reached 150 ms.

Each fixture's linked JSON lists all qualifying intervals and partially overlapping waits.

### Ten slowest beat types by median

| Beat | Samples | Median (ms) | Max (ms) |
|---|---:|---:|---:|
| caption shown | 46 | 1495.8 | 4655.0 |
| death animation | 1 | 1478.3 | 1478.3 |
| action | 56 | 1177.2 | 2566.3 |
| sampled playback | 41 | 910.9 | 1599.9 |
| surface effect | 44 | 739.5 | 765.6 |
| defeated body held | 1 | 719.8 | 719.8 |
| contact to last number gone | 29 | 696.0 | 961.5 |
| number on screen | 73 | 652.3 | 711.3 |
| hero fatigue | 4 | 628.7 | 633.3 |
| feedback deadline | 11 | 597.4 | 1228.3 |

### All measured beat durations

| Beat | Samples | Median (ms) | Max (ms) |
|---|---:|---:|---:|
| action | 56 | 1177.2 | 2566.3 |
| camera move | 38 | 429.7 | 505.3 |
| caption lead before motion or feedback | 42 | 245.1 | 989.7 |
| caption shown | 46 | 1495.8 | 4655.0 |
| contact to last number gone | 29 | 696.0 | 961.5 |
| death animation | 1 | 1478.3 | 1478.3 |
| defeat playback | 14 | 0.0 | 0.0 |
| defeated body held | 1 | 719.8 | 719.8 |
| feedback deadline | 11 | 597.4 | 1228.3 |
| floating feedback | 37 | 154.8 | 609.9 |
| hand draw | 11 | 456.5 | 480.4 |
| hero fatigue | 4 | 628.7 | 633.3 |
| hero hand-off drain | 12 | 207.0 | 223.2 |
| hero turn-start fire | 4 | 555.5 | 559.3 |
| hit stop | 38 | 90.8 | 114.2 |
| locked hand capture | 24 | 9.7 | 47.0 |
| number on screen | 73 | 652.3 | 711.3 |
| post-action settle | 45 | 156.6 | 163.4 |
| pre-action delay | 29 | 256.5 | 265.4 |
| publish hero UI | 12 | 13.7 | 19.8 |
| sampled playback | 41 | 910.9 | 1599.9 |
| surface effect | 44 | 739.5 | 765.6 |
| turn banner shown | 9 | 203.1 | 222.9 |
| turn-order rail | 132 | 157.0 | 1312.3 |
| unit move | 11 | 373.9 | 1009.4 |
| wind-up to contact | 29 | 452.4 | 990.8 |

### Native event timelines

### 01-s0-seed1-0-4_0-t9

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 72.2 | 72.2 | — |  | locked hand capture | — |
| 81.8 | 94.7 | — |  | locked hand capture | — |
| 262.0 | 262.0 | — |  | defeat playback | — |
| 262.8 | 267.5 | — |  | turn-order rail | — |
| 263.9 | 263.9 | 0 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 269.7 | 418.5 | 0 |  | turn-order rail | — |
| 272.5 | 272.5 | 1 | enemy_1 | step dispatched | {"kind": "intent", "label": "Faultline"} |
| 272.7 | 355.4 | 1 | enemy_1 | pre-action delay | — |
| 301.5 | 3911.1 | 1 | enemy_1 | caption shown | {"text": "Faultline"} |
| 301.5 | 371.0 | 1 | enemy_1 | caption lead before motion or feedback | {"derived": true} |
| 364.1 | 364.1 | 2 | enemy_1 | step dispatched | {"kind": "aoe", "label": "Faultline"} |
| 364.2 | 2030.7 | 2 | enemy_1 | action | {"kind": "aoe", "label": "Faultline"} |
| 365.8 | 1871.4 | 2 | enemy_1 | sampled playback | {"authored_ms": 1100.0, "frames": 66} |
| 371.0 | 371.0 | 2 | enemy_1 | attack wind-up | {"kind": "aoe", "sample": 1} |
| 371.0 | 1089.6 | 2 | enemy_1 | wind-up to contact | {"derived": true} |
| 1082.2 | 1196.4 | 2 | enemy_1 | hit stop | {"requested_ms": 105.0} |
| 1089.6 | 1089.6 | 2 | enemy_1 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 35, "sample_count": 66, "process_frame": 48} |
| 1089.6 | 1089.6 | 2 | enemy_1 | impact effect start | {"targets": ["player"]} |
| 1089.6 | 1815.9 | 2 | enemy_1 | contact to last number gone | {"derived": true} |
| 1120.8 | 1599.5 | 2 | enemy_1 | camera move | {"kind": "board kick"} |
| 1120.8 | 1815.9 | 2 | enemy_1 | number on screen | {"text": "−8", "category": "damage", "tile": "(4, 4)", "icon": "", "reaction": "hit"} |
| 1120.8 | 1815.9 | 2 | enemy_1 | number on screen | {"text": "−4", "category": "damage", "tile": "(2, 5)", "icon": "", "reaction": ""} |
| 1120.8 | 1815.9 | 2 | enemy_1 | number on screen | {"text": "−4", "category": "damage", "tile": "(3, 5)", "icon": "", "reaction": ""} |
| 1120.8 | 1815.9 | 2 | enemy_1 | number on screen | {"text": "−4", "category": "damage", "tile": "(6, 5)", "icon": "", "reaction": ""} |
| 1120.8 | 1815.9 | 2 | enemy_1 | number on screen | {"text": "−4", "category": "damage", "tile": "(2, 4)", "icon": "", "reaction": ""} |
| 1120.8 | 1815.9 | 2 | enemy_1 | number on screen | {"text": "−4", "category": "damage", "tile": "(3, 4)", "icon": "", "reaction": ""} |
| 1120.8 | 1815.9 | 2 | enemy_1 | number on screen | {"text": "−4", "category": "damage", "tile": "(6, 4)", "icon": "", "reaction": ""} |
| 1120.8 | 1886.4 | 2 | enemy_1 | surface effect | {"tile": "(2, 5)", "kind": "surface_created", "surface": "rubble", "trigger": ""} |
| 1120.8 | 1886.4 | 2 | enemy_1 | surface effect | {"tile": "(3, 5)", "kind": "surface_created", "surface": "rubble", "trigger": ""} |
| 1120.8 | 1886.4 | 2 | enemy_1 | surface effect | {"tile": "(6, 5)", "kind": "surface_created", "surface": "rubble", "trigger": ""} |
| 1120.8 | 1886.4 | 2 | enemy_1 | surface effect | {"tile": "(2, 4)", "kind": "surface_created", "surface": "rubble", "trigger": ""} |
| 1120.8 | 1886.4 | 2 | enemy_1 | surface effect | {"tile": "(3, 4)", "kind": "surface_created", "surface": "rubble", "trigger": ""} |
| 1120.8 | 1886.4 | 2 | enemy_1 | surface effect | {"tile": "(6, 4)", "kind": "surface_created", "surface": "rubble", "trigger": ""} |
| 1120.8 | 1886.4 | 2 | enemy_1 | surface effect | {"tile": "", "kind": "dragon_spire_pulse", "surface": "", "trigger": ""} |
| 1872.0 | 1876.9 | 2 | enemy_1 | floating feedback | {"numbers": 7} |
| 1877.7 | 2249.9 | 2 | enemy_1 | turn-order rail | — |
| 1878.1 | 2030.7 | 2 | enemy_1 | post-action settle | — |
| 2030.8 | 2030.8 | 3 | enemy_1 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 2030.8 | 3659.8 | 3 | enemy_1 | action | {"kind": "ranged", "label": "Shot"} |
| 2032.2 | 3500.7 | 3 | enemy_1 | sampled playback | {"authored_ms": 1100.0, "frames": 66} |
| 2037.2 | 2037.2 | 3 | enemy_1 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 2037.2 | 2756.0 | 3 | enemy_1 | wind-up to contact | {"derived": true} |
| 2752.9 | 2844.7 | 3 | enemy_1 | hit stop | {"requested_ms": 85.0} |
| 2756.0 | 2756.0 | 3 | enemy_1 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 35, "sample_count": 66, "process_frame": 142} |
| 2756.0 | 2756.0 | 3 | enemy_1 | impact effect start | {"targets": ["player"]} |
| 2756.0 | 3453.4 | 3 | enemy_1 | contact to last number gone | {"derived": true} |
| 2762.0 | 3214.0 | 3 | enemy_1 | camera move | {"kind": "board kick"} |
| 2762.0 | 3453.4 | 3 | enemy_1 | number on screen | {"text": "−4", "category": "damage", "tile": "(4, 4)", "icon": "", "reaction": "hit"} |
| 3501.1 | 3504.6 | 3 | enemy_1 | floating feedback | {"numbers": 1} |
| 3505.3 | 3667.6 | 3 | enemy_1 | turn-order rail | — |
| 3505.7 | 3659.8 | 3 | enemy_1 | post-action settle | — |
| 3660.2 | 3660.2 | 4 | enemy_1 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 3667.5 | 3667.5 | 5 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 3668.8 | 3672.4 | 5 |  | turn-order rail | — |
| 3672.3 | 3672.3 | 6 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 3673.9 | 3880.3 | 6 |  | turn-order rail | — |
| 3675.9 | 3888.0 | — |  | hero hand-off drain | — |
| 3894.6 | 4190.6 | — |  | hand draw | {"cards": 1} |
| 4190.7 | 4204.9 | — |  | publish hero UI | — |
| 4192.5 | 4192.5 | — |  | hero turn banner suppressed | {"boss_hud_or_caption": true} |
| 4216.1 | 4216.1 | — |  | ground state changed | {"kind": "surface_created", "surface": "rubble", "tile": "(2, 5)", "trigger": ""} |
| 4216.1 | 4216.1 | — |  | ground state changed | {"kind": "surface_created", "surface": "rubble", "tile": "(3, 5)", "trigger": ""} |
| 4216.1 | 4216.1 | — |  | ground state changed | {"kind": "surface_created", "surface": "rubble", "tile": "(6, 5)", "trigger": ""} |
| 4216.1 | 4216.1 | — |  | ground state changed | {"kind": "surface_created", "surface": "rubble", "tile": "(2, 4)", "trigger": ""} |
| 4216.1 | 4216.1 | — |  | ground state changed | {"kind": "surface_created", "surface": "rubble", "tile": "(3, 4)", "trigger": ""} |
| 4216.1 | 4216.1 | — |  | ground state changed | {"kind": "surface_created", "surface": "rubble", "tile": "(6, 4)", "trigger": ""} |
| 4217.6 | 4217.6 | — |  | hero input accepted | — |

### 02-s0-seed12-0-1_3-t7

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 1.7 | 1.7 | — |  | enemy turn banner requested | — |
| 40.9 | 231.5 | — |  | turn banner shown | {"text": "ENEMY TURN"} |
| 48.1 | 48.1 | — |  | locked hand capture | — |
| 80.1 | 92.5 | — |  | locked hand capture | — |
| 178.0 | 178.0 | — |  | defeat playback | — |
| 179.0 | 182.8 | — |  | turn-order rail | — |
| 180.0 | 180.0 | 0 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 185.3 | 341.7 | 0 |  | turn-order rail | — |
| 189.1 | 189.1 | 1 | enemy_5 | step dispatched | {"kind": "intent", "label": "Hiss Back"} |
| 189.4 | 354.4 | 1 | enemy_5 | pre-action delay | — |
| 231.5 | 1420.6 | 1 | enemy_5 | caption shown | {"text": "Cinder Droplet: Hiss Back"} |
| 231.5 | 359.8 | 1 | enemy_5 | caption lead before motion or feedback | {"derived": true} |
| 359.7 | 359.7 | 2 | enemy_5 | step dispatched | {"kind": "move", "label": "Retreat"} |
| 359.7 | 606.8 | 2 | enemy_5 | action | {"kind": "move", "label": "Retreat"} |
| 359.8 | 557.0 | 2 | enemy_5 | unit move | {"actor": "enemy_5", "tiles": 1} |
| 360.0 | 556.9 | 2 | enemy_5 | sampled playback | {"authored_ms": 183.333333333333, "frames": 28} |
| 606.9 | 606.9 | 3 | enemy_5 | step dispatched | {"kind": "block", "label": "Guard"} |
| 606.9 | 1377.1 | 3 | enemy_5 | action | {"kind": "block", "label": "Guard"} |
| 607.2 | 607.2 | 3 | enemy_5 | resolved block | {"kind": "block", "label": "Guard", "rule": "", "actor": "enemy_5", "target": "(2, 4)"} |
| 607.2 | 1217.1 | 3 | enemy_5 | floating feedback | {"numbers": 1} |
| 617.3 | 1219.2 | 3 | enemy_5 | number on screen | {"text": "+2", "category": "status", "tile": "(2, 4)", "icon": "block", "reaction": ""} |
| 1218.1 | 1377.1 | 3 | enemy_5 | post-action settle | — |
| 1377.3 | 1377.3 | 4 | enemy_5 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 1381.9 | 1381.9 | 5 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 1382.1 | 1390.3 | 5 |  | turn-order rail | — |
| 1390.2 | 1390.2 | 6 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 1392.3 | 1587.6 | 6 |  | turn-order rail | — |
| 1395.8 | 1395.8 | 7 | enemy_4 | step dispatched | {"kind": "intent", "label": "Skitter Strike"} |
| 1395.9 | 1657.0 | 7 | enemy_4 | pre-action delay | — |
| 1420.6 | 2893.7 | 7 | enemy_4 | caption shown | {"text": "Tunnel Crawler: Skitter Strike"} |
| 1420.6 | 1665.6 | 7 | enemy_4 | caption lead before motion or feedback | {"derived": true} |
| 1661.1 | 1661.1 | 8 | enemy_4 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 1661.1 | 2865.7 | 8 | enemy_4 | action | {"kind": "melee", "label": "Strike"} |
| 1662.5 | 2518.0 | 8 | enemy_4 | sampled playback | {"authored_ms": 600.0, "frames": 36} |
| 1665.6 | 1665.6 | 8 | enemy_4 | attack wind-up | {"kind": "melee", "sample": 1} |
| 1665.6 | 1982.7 | 8 | enemy_4 | wind-up to contact | {"derived": true} |
| 1978.3 | 2074.5 | 8 | enemy_4 | hit stop | {"requested_ms": 85.0} |
| 1982.7 | 1982.7 | 8 | enemy_4 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 16, "sample_count": 36, "process_frame": 145} |
| 1982.7 | 1982.7 | 8 | enemy_4 | impact effect start | {"targets": ["player"]} |
| 1982.7 | 2675.1 | 8 | enemy_4 | contact to last number gone | {"derived": true} |
| 1993.6 | 2421.3 | 8 | enemy_4 | camera move | {"kind": "board kick"} |
| 1993.6 | 2675.1 | 8 | enemy_4 | number on screen | {"text": "−5", "category": "damage", "tile": "(3, 3)", "icon": "", "reaction": "hit"} |
| 2518.3 | 2711.1 | 8 | enemy_4 | floating feedback | {"numbers": 1} |
| 2712.1 | 2868.2 | 8 | enemy_4 | turn-order rail | — |
| 2712.6 | 2865.7 | 8 | enemy_4 | post-action settle | — |
| 2865.9 | 2865.9 | 9 | enemy_4 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 2868.1 | 2868.1 | 10 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 2869.6 | 2874.3 | 10 |  | turn-order rail | — |
| 2874.2 | 2874.2 | 11 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 2876.7 | 3071.2 | 11 |  | turn-order rail | — |
| 2880.6 | 2880.6 | 12 | enemy_1 | step dispatched | {"kind": "intent", "label": "Icefall"} |
| 2880.7 | 3133.4 | 12 | enemy_1 | pre-action delay | — |
| 2893.7 | 5747.7 | 12 | enemy_1 | caption shown | {"text": "Hoarfrost Seer: Icefall"} |
| 2893.7 | 3139.0 | 12 | enemy_1 | caption lead before motion or feedback | {"derived": true} |
| 3136.0 | 3136.0 | 13 | enemy_1 | step dispatched | {"kind": "aoe", "label": "Icefall"} |
| 3136.0 | 5702.3 | 13 | enemy_1 | action | {"kind": "aoe", "label": "Icefall"} |
| 3136.6 | 4248.7 | 13 | enemy_1 | sampled playback | {"authored_ms": 800.0, "frames": 48} |
| 3139.0 | 3139.0 | 13 | enemy_1 | attack wind-up | {"kind": "aoe", "sample": 1} |
| 3139.0 | 3591.4 | 13 | enemy_1 | wind-up to contact | {"derived": true} |
| 3586.6 | 3691.1 | 13 | enemy_1 | hit stop | {"requested_ms": 85.0} |
| 3591.4 | 3591.4 | 13 | enemy_1 | contact | {"evidence": "Icefall entered its authored contact phase", "sample": 22, "sample_count": 48, "process_frame": 260} |
| 3591.4 | 3591.4 | 13 | enemy_1 | impact effect start | {"targets": []} |
| 3591.4 | 4303.2 | 13 | enemy_1 | contact to last number gone | {"derived": true} |
| 3602.2 | 4087.8 | 13 | enemy_1 | camera move | {"kind": "board kick"} |
| 3602.2 | 4303.2 | 13 | enemy_1 | number on screen | {"text": "−5", "category": "damage", "tile": "(3, 3)", "icon": "", "reaction": "hit"} |
| 3602.2 | 4303.2 | 13 | enemy_1 | number on screen | {"text": "−4", "category": "damage", "tile": "(4, 3)", "icon": "", "reaction": "hit"} |
| 3602.2 | 4322.1 | 13 | enemy_1 | defeated body held | {"actor": "enemy_4", "type": "crawler"} |
| 3602.2 | 3602.2 | 13 | enemy_1 | death in displayed state | {"actor": "enemies:4"} |
| 3602.2 | 3602.2 | 13 | enemy_1 | ground state changed | {"kind": "surface_created", "surface": "ice", "tile": "(2, 3)", "trigger": ""} |
| 3602.2 | 3602.2 | 13 | enemy_1 | ground state changed | {"kind": "surface_replaced", "surface": "ice", "tile": "(3, 3)", "trigger": ""} |
| 3602.2 | 3602.2 | 13 | enemy_1 | ground state changed | {"kind": "surface_created", "surface": "ice", "tile": "(4, 3)", "trigger": ""} |
| 4249.8 | 5562.1 | 13 | enemy_1 | turn-order rail | — |
| 4250.2 | 4315.0 | 13 | enemy_1 | floating feedback | {"numbers": 2} |
| 4269.4 | 5747.7 | 13 | enemy_1 | death animation | {"actor": "enemy_4", "type": "crawler"} |
| 4317.9 | 5546.2 | 13 | enemy_1 | feedback deadline | — |
| 5546.2 | 5702.3 | 13 | enemy_1 | post-action settle | — |
| 5702.4 | 5702.4 | 14 | enemy_1 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 5707.1 | 5707.1 | 15 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 5707.3 | 5716.4 | 15 |  | turn-order rail | — |
| 5716.3 | 5716.3 | 16 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 5718.0 | 5903.8 | 16 |  | turn-order rail | — |
| 5720.8 | 5720.8 | 17 | enemy_5 | step dispatched | {"kind": "intent", "label": "Spatter"} |
| 5720.8 | 5977.3 | 17 | enemy_5 | pre-action delay | — |
| 5747.7 | 7844.8 | 17 | enemy_5 | caption shown | {"text": "Cinder Droplet: Spatter"} |
| 5747.7 | 5982.2 | 17 | enemy_5 | caption lead before motion or feedback | {"derived": true} |
| 5982.1 | 5982.1 | 18 | enemy_5 | step dispatched | {"kind": "move", "label": "Advance"} |
| 5982.1 | 6418.2 | 18 | enemy_5 | action | {"kind": "move", "label": "Advance"} |
| 5982.2 | 6170.1 | 18 | enemy_5 | unit move | {"actor": "enemy_5", "tiles": 1} |
| 5982.4 | 6170.1 | 18 | enemy_5 | sampled playback | {"authored_ms": 183.333333333333, "frames": 28} |
| 6170.3 | 6352.4 | 18 | enemy_5 | floating feedback | {"numbers": 0} |
| 6182.2 | 6359.1 | 18 | enemy_5 | surface effect | {"tile": "(2, 3)", "kind": "status_applied", "surface": "ice", "trigger": "entry"} |
| 6355.0 | 6752.7 | 18 | enemy_5 | turn-order rail | — |
| 6418.3 | 6418.3 | 19 | enemy_5 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 6418.3 | 7600.2 | 19 | enemy_5 | action | {"kind": "melee", "label": "Strike"} |
| 6419.4 | 7241.4 | 19 | enemy_5 | sampled playback | {"authored_ms": 600.0, "frames": 36} |
| 6421.8 | 6421.8 | 19 | enemy_5 | attack wind-up | {"kind": "melee", "sample": 1} |
| 6421.8 | 6740.8 | 19 | enemy_5 | wind-up to contact | {"derived": true} |
| 6737.3 | 6805.2 | 19 | enemy_5 | hit stop | {"requested_ms": 60.0} |
| 6740.8 | 6740.8 | 19 | enemy_5 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 16, "sample_count": 36, "process_frame": 500} |
| 6740.8 | 6740.8 | 19 | enemy_5 | impact effect start | {"targets": ["player"]} |
| 6740.8 | 7405.5 | 19 | enemy_5 | contact to last number gone | {"derived": true} |
| 6753.2 | 7107.1 | 19 | enemy_5 | camera move | {"kind": "board kick"} |
| 6753.2 | 7405.5 | 19 | enemy_5 | number on screen | {"text": "−3", "category": "damage", "tile": "(3, 3)", "icon": "", "reaction": "hit"} |
| 6753.2 | 7246.0 | 19 | enemy_5 | surface effect | {"tile": "(3, 3)", "kind": "surface_replaced", "surface": "fire", "trigger": ""} |
| 7241.8 | 7436.3 | 19 | enemy_5 | floating feedback | {"numbers": 1} |
| 7437.3 | 7605.2 | 19 | enemy_5 | turn-order rail | — |
| 7437.7 | 7600.2 | 19 | enemy_5 | post-action settle | — |
| 7600.3 | 7600.3 | 20 | enemy_5 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 7605.1 | 7605.1 | 21 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 7606.4 | 7609.5 | 21 |  | turn-order rail | — |
| 7609.4 | 7609.4 | 22 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 7611.2 | 7812.0 | 22 |  | turn-order rail | — |
| 7614.1 | 7821.0 | — |  | hero hand-off drain | — |
| 7827.0 | 8380.4 | — |  | hero turn-start fire | — |
| 7829.1 | 7895.8 | — |  | hit stop | {"requested_ms": 60.0} |
| 7832.9 | 7832.9 | — |  | impact effect start | {"targets": ["player"]} |
| 7844.8 | 8137.8 | — |  | camera move | {"kind": "board kick"} |
| 7844.8 | 8400.7 | — |  | number on screen | {"text": "−3", "category": "damage", "tile": "(3, 3)", "icon": "surface_fire", "reaction": "hit"} |
| 7844.8 | 7844.8 | — |  | ground state changed | {"kind": "surface_replaced", "surface": "fire", "tile": "(3, 3)", "trigger": ""} |
| 8380.4 | 8852.5 | — |  | hand draw | {"cards": 2} |
| 8852.7 | 8864.0 | — |  | publish hero UI | — |
| 8854.6 | 8854.6 | — |  | hero turn banner requested | — |
| 8875.7 | 8875.7 | — |  | hero input accepted | — |

### 03-s2-seed8-2-11_-9-t64

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 4.0 | 4.1 | — |  | defeat playback | — |
| 12.7 | 616.7 | — |  | sampled playback | {"authored_ms": 600.0, "frames": 1} |
| 56.3 | 1330.0 | — |  | caption shown | {"text": "Upheaval"} |
| 56.3 | 653.6 | — |  | caption lead before motion or feedback | {"derived": true} |
| 96.6 | 105.2 | — |  | locked hand capture | — |
| 653.6 | 1019.6 | — |  | surface effect | {"tile": "(5, 4)", "kind": "terrain_created", "surface": "", "trigger": ""} |
| 653.6 | 653.6 | — |  | ground state changed | {"kind": "terrain_created", "surface": "crag_outcrop", "tile": "(5, 4)", "trigger": ""} |
| 985.6 | 985.6 | — |  | defeat playback | — |
| 996.3 | 1031.6 | — |  | locked hand capture | — |
| 1099.8 | 1099.8 | — |  | defeat playback | — |
| 1102.1 | 1102.1 | 0 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 1105.7 | 1291.8 | 0 |  | turn-order rail | — |
| 1107.4 | 1299.3 | — |  | hero hand-off drain | — |
| 1307.0 | 1319.7 | — |  | publish hero UI | — |
| 1308.6 | 1308.6 | — |  | hero turn banner requested | — |
| 1330.0 | 1332.5 | — |  | turn banner shown (clipped) | {"text": "YOUR TURN"} |
| 1332.5 | 1332.5 | — |  | hero input accepted | — |

### 04-s0-seed8-0--3_2-t5

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 2.0 | 2.0 | — |  | enemy turn banner requested | — |
| 51.3 | 274.2 | — |  | turn banner shown | {"text": "ENEMY TURN"} |
| 59.7 | 59.7 | — |  | locked hand capture | — |
| 89.2 | 101.3 | — |  | locked hand capture | — |
| 193.9 | 194.0 | — |  | defeat playback | — |
| 195.0 | 200.2 | — |  | turn-order rail | — |
| 196.2 | 196.2 | 0 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 203.0 | 215.7 | 0 |  | turn-order rail | — |
| 206.8 | 206.8 | 1 | enemy_5 | step dispatched | {"kind": "status_damage", "label": "Fire"} |
| 206.9 | 973.4 | 1 | enemy_5 | action | {"kind": "status_damage", "label": "Fire"} |
| 207.1 | 207.1 | 1 | enemy_5 | status tick | {"kind": "status_damage", "label": "Fire", "rule": "", "actor": "enemy_5", "target": "(3, 4)"} |
| 217.0 | 889.6 | 1 | enemy_5 | turn-order rail | — |
| 217.3 | 814.7 | 1 | enemy_5 | feedback deadline | — |
| 274.2 | 986.9 | 1 | enemy_5 | caption shown | {"text": "Dust Acolyte: Fire"} |
| 274.2 | 818.6 | 1 | enemy_5 | number on screen | {"text": "−3", "category": "damage", "tile": "(3, 4)", "icon": "surface_fire", "reaction": "hit"} |
| 274.2 | 662.3 | 1 | enemy_5 | surface effect | {"tile": "(3, 4)", "kind": "surface_damage", "surface": "fire", "trigger": "start"} |
| 274.2 | 274.2 | 1 | enemy_5 | caption lead before motion or feedback | {"derived": true} |
| 814.8 | 973.4 | 1 | enemy_5 | post-action settle | — |
| 973.5 | 973.5 | 2 | enemy_5 | step dispatched | {"kind": "intent", "label": "Siphon"} |
| 976.1 | 976.1 | 3 | enemy_5 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 976.1 | 2839.2 | 3 | enemy_5 | action | {"kind": "ranged", "label": "Shot"} |
| 977.1 | 2572.2 | 3 | enemy_5 | sampled playback | {"authored_ms": 1200.0, "frames": 72} |
| 979.3 | 979.3 | 3 | enemy_5 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 979.3 | 1964.2 | 3 | enemy_5 | wind-up to contact | {"derived": true} |
| 986.9 | 3633.2 | 3 | enemy_5 | caption shown | {"text": "Dust Acolyte: Siphon"} |
| 986.9 | 1976.6 | 3 | enemy_5 | caption lead before motion or feedback | {"derived": true} |
| 1960.7 | 2056.9 | 3 | enemy_5 | hit stop | {"requested_ms": 85.0} |
| 1964.2 | 1964.2 | 3 | enemy_5 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 48, "sample_count": 72, "process_frame": 144} |
| 1964.2 | 1964.2 | 3 | enemy_5 | impact effect start | {"targets": ["player"]} |
| 1964.2 | 2658.3 | 3 | enemy_5 | contact to last number gone | {"derived": true} |
| 1976.6 | 2412.9 | 3 | enemy_5 | camera move | {"kind": "board kick"} |
| 1976.6 | 2658.3 | 3 | enemy_5 | number on screen | {"text": "−4", "category": "damage", "tile": "(4, 4)", "icon": "", "reaction": "hit"} |
| 2572.5 | 2680.9 | 3 | enemy_5 | floating feedback | {"numbers": 1} |
| 2682.0 | 3065.1 | 3 | enemy_5 | turn-order rail | — |
| 2682.4 | 2839.2 | 3 | enemy_5 | post-action settle | — |
| 2839.3 | 2839.3 | 4 | enemy_5 | step dispatched | {"kind": "heal", "label": "Heal"} |
| 2839.3 | 3599.0 | 4 | enemy_5 | action | {"kind": "heal", "label": "Heal"} |
| 2839.7 | 2839.7 | 4 | enemy_5 | resolved heal | {"kind": "heal", "label": "Heal", "rule": "", "actor": "enemy_5", "target": "(3, 4)"} |
| 2839.7 | 3442.9 | 4 | enemy_5 | floating feedback | {"numbers": 1} |
| 2854.7 | 3445.8 | 4 | enemy_5 | number on screen | {"text": "+2", "category": "heal", "tile": "(3, 4)", "icon": "heal", "reaction": ""} |
| 3444.0 | 3601.9 | 4 | enemy_5 | turn-order rail | — |
| 3444.5 | 3599.0 | 4 | enemy_5 | post-action settle | — |
| 3599.2 | 3599.2 | 5 | enemy_5 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 3601.8 | 3601.8 | 6 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 3603.7 | 3612.3 | 6 |  | turn-order rail | — |
| 3612.2 | 3612.2 | 7 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 3614.8 | 3808.9 | 7 |  | turn-order rail | — |
| 3618.3 | 3618.3 | 8 | enemy_3 | step dispatched | {"kind": "intent", "label": "Smolder Slide"} |
| 3618.4 | 3873.1 | 8 | enemy_3 | pre-action delay | — |
| 3633.2 | 5152.5 | 8 | enemy_3 | caption shown | {"text": "Cinder Ooze: Smolder Slide"} |
| 3633.2 | 3882.9 | 8 | enemy_3 | caption lead before motion or feedback | {"derived": true} |
| 3879.3 | 3879.3 | 9 | enemy_3 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 3879.3 | 5120.1 | 9 | enemy_3 | action | {"kind": "melee", "label": "Strike"} |
| 3880.5 | 4853.6 | 9 | enemy_3 | sampled playback | {"authored_ms": 700.0, "frames": 42} |
| 3882.9 | 3882.9 | 9 | enemy_3 | attack wind-up | {"kind": "melee", "sample": 1} |
| 3882.9 | 4248.3 | 9 | enemy_3 | wind-up to contact | {"derived": true} |
| 4244.2 | 4335.0 | 9 | enemy_3 | hit stop | {"requested_ms": 85.0} |
| 4248.3 | 4248.3 | 9 | enemy_3 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 18, "sample_count": 42, "process_frame": 322} |
| 4248.3 | 4248.3 | 9 | enemy_3 | impact effect start | {"targets": ["player"]} |
| 4248.3 | 4941.8 | 9 | enemy_3 | contact to last number gone | {"derived": true} |
| 4260.0 | 4685.5 | 9 | enemy_3 | camera move | {"kind": "board kick"} |
| 4260.0 | 4941.8 | 9 | enemy_3 | number on screen | {"text": "−5", "category": "damage", "tile": "(4, 4)", "icon": "", "reaction": "hit"} |
| 4260.0 | 4858.8 | 9 | enemy_3 | surface effect | {"tile": "(4, 4)", "kind": "surface_replaced", "surface": "fire", "trigger": ""} |
| 4854.0 | 4962.6 | 9 | enemy_3 | floating feedback | {"numbers": 1} |
| 4963.7 | 5126.0 | 9 | enemy_3 | turn-order rail | — |
| 4968.3 | 5120.1 | 9 | enemy_3 | post-action settle | — |
| 5120.3 | 5120.3 | 10 | enemy_3 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 5125.8 | 5125.8 | 11 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 5127.7 | 5132.8 | 11 |  | turn-order rail | — |
| 5132.7 | 5132.7 | 12 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 5135.3 | 5333.0 | 12 |  | turn-order rail | — |
| 5138.7 | 5138.7 | 13 | enemy_1 | step dispatched | {"kind": "intent", "label": "Arc Bolt"} |
| 5138.8 | 5397.6 | 13 | enemy_1 | pre-action delay | — |
| 5152.5 | 7157.0 | 13 | enemy_1 | caption shown | {"text": "Arc Thrall: Arc Bolt"} |
| 5152.5 | 5404.3 | 13 | enemy_1 | caption lead before motion or feedback | {"derived": true} |
| 5401.8 | 5401.8 | 14 | enemy_1 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 5401.8 | 7126.5 | 14 | enemy_1 | action | {"kind": "ranged", "label": "Shot"} |
| 5402.2 | 6971.8 | 14 | enemy_1 | sampled playback | {"authored_ms": 1200.0, "frames": 72} |
| 5404.3 | 5404.3 | 14 | enemy_1 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 5404.3 | 6167.0 | 14 | enemy_1 | wind-up to contact | {"derived": true} |
| 6160.9 | 6226.7 | 14 | enemy_1 | hit stop | {"requested_ms": 60.0} |
| 6167.0 | 6167.0 | 14 | enemy_1 | contact | {"evidence": "contact effect submitted", "sample": 37, "sample_count": 72, "process_frame": 472} |
| 6167.0 | 6167.0 | 14 | enemy_1 | impact effect start | {"targets": []} |
| 6167.0 | 6830.1 | 14 | enemy_1 | contact to last number gone | {"derived": true} |
| 6178.4 | 6551.6 | 14 | enemy_1 | camera move | {"kind": "board kick"} |
| 6178.4 | 6830.1 | 14 | enemy_1 | number on screen | {"text": "−3", "category": "damage", "tile": "(4, 4)", "icon": "", "reaction": "hit"} |
| 6971.8 | 6974.2 | 14 | enemy_1 | floating feedback | {"numbers": 1} |
| 6976.4 | 7126.5 | 14 | enemy_1 | post-action settle | — |
| 7126.6 | 7126.6 | 15 | enemy_1 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 7127.7 | 7127.7 | 16 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 7127.9 | 7143.5 | 16 |  | turn-order rail | — |
| 7143.4 | 7143.4 | 17 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 7146.0 | 7332.4 | 17 |  | turn-order rail | — |
| 7149.6 | 7149.6 | 18 | enemy_4 | step dispatched | {"kind": "intent", "label": "Bulwark"} |
| 7149.7 | 7406.5 | 18 | enemy_4 | pre-action delay | — |
| 7157.0 | 8398.2 | 18 | enemy_4 | caption shown | {"text": "Stone Warden: Bulwark"} |
| 7157.0 | 7421.2 | 18 | enemy_4 | caption lead before motion or feedback | {"derived": true} |
| 7409.1 | 7409.1 | 19 | enemy_4 | step dispatched | {"kind": "block", "label": "Guard Allies"} |
| 7409.1 | 8173.4 | 19 | enemy_4 | action | {"kind": "block", "label": "Guard Allies"} |
| 7409.4 | 7409.4 | 19 | enemy_4 | resolved block | {"kind": "block", "label": "Guard Allies", "rule": "", "actor": "enemy_4", "target": "(1, 1)"} |
| 7409.4 | 8012.2 | 19 | enemy_4 | floating feedback | {"numbers": 3} |
| 7415.3 | 7415.3 | 19 | enemy_4 | impact effect start | {"targets": ["enemy_1", "enemy_3", "enemy_5"]} |
| 7421.2 | 8016.9 | 19 | enemy_4 | number on screen | {"text": "+6", "category": "status", "tile": "(6, 4)", "icon": "block", "reaction": ""} |
| 7421.2 | 8016.9 | 19 | enemy_4 | number on screen | {"text": "+6", "category": "status", "tile": "(5, 4)", "icon": "block", "reaction": ""} |
| 7421.2 | 8016.9 | 19 | enemy_4 | number on screen | {"text": "+6", "category": "status", "tile": "(3, 4)", "icon": "block", "reaction": ""} |
| 8015.3 | 8173.3 | 19 | enemy_4 | post-action settle | — |
| 8173.5 | 8173.5 | 20 | enemy_4 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 8176.2 | 8176.2 | 21 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 8176.5 | 8182.3 | 21 |  | turn-order rail | — |
| 8182.1 | 8182.1 | 22 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 8184.7 | 8368.0 | 22 |  | turn-order rail | — |
| 8188.1 | 8378.1 | — |  | hero hand-off drain | — |
| 8384.8 | 9018.0 | — |  | hero fatigue | — |
| 8387.0 | 8457.7 | — |  | hit stop | {"requested_ms": 60.0} |
| 8390.6 | 8390.6 | — |  | impact effect start | {"targets": ["player"]} |
| 8398.2 | 8701.6 | — |  | camera move | {"kind": "board kick"} |
| 8398.2 | 8941.7 | — |  | number on screen | {"text": "−2", "category": "damage", "tile": "(4, 4)", "icon": "", "reaction": "hit"} |
| 8398.2 | 8398.2 | — |  | ground state changed | {"kind": "surface_replaced", "surface": "fire", "tile": "(4, 4)", "trigger": ""} |
| 8398.2 | 8398.2 | — |  | ground state changed | {"kind": "surface_replaced", "surface": "electrified", "tile": "(4, 4)", "trigger": ""} |
| 8533.8 | 9041.8 | — |  | number on screen | {"text": "fatigue sets in", "category": "status", "tile": "(4, 4)", "icon": "", "reaction": ""} |
| 9018.1 | 9498.5 | — |  | hand draw | {"cards": 2} |
| 9498.6 | 9516.9 | — |  | publish hero UI | — |
| 9503.3 | 9503.3 | — |  | hero turn banner requested | — |
| 9538.8 | 9538.8 | — |  | hero input accepted | — |

### 05-s2-seed1-2-9_-7-t2

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 1.8 | 1.8 | — |  | enemy turn banner requested | — |
| 42.3 | 214.4 | — |  | turn banner shown | {"text": "ENEMY TURN"} |
| 49.5 | 49.5 | — |  | locked hand capture | — |
| 83.4 | 100.7 | — |  | locked hand capture | — |
| 179.8 | 179.8 | — |  | defeat playback | — |
| 180.7 | 184.7 | — |  | turn-order rail | — |
| 181.4 | 181.4 | 0 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 187.2 | 331.9 | 0 |  | turn-order rail | — |
| 190.6 | 190.6 | 1 | enemy_2 | step dispatched | {"kind": "intent", "label": "Arc Jab"} |
| 190.8 | 352.0 | 1 | enemy_2 | pre-action delay | — |
| 214.4 | 4869.4 | 1 | enemy_2 | caption shown | {"text": "Arc Thrall: Arc Jab"} |
| 214.4 | 357.6 | 1 | enemy_2 | caption lead before motion or feedback | {"derived": true} |
| 357.3 | 357.3 | 2 | enemy_2 | step dispatched | {"kind": "move", "label": "Advance"} |
| 357.4 | 1407.8 | 2 | enemy_2 | action | {"kind": "move", "label": "Advance"} |
| 357.6 | 1367.0 | 2 | enemy_2 | unit move | {"actor": "enemy_2", "tiles": 2} |
| 357.8 | 1366.9 | 2 | enemy_2 | sampled playback | {"authored_ms": 1000.0, "frames": 60} |
| 1407.9 | 1407.9 | 3 | enemy_2 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 1407.9 | 2747.0 | 3 | enemy_2 | action | {"kind": "melee", "label": "Strike"} |
| 1409.1 | 2385.5 | 3 | enemy_2 | sampled playback | {"authored_ms": 700.0, "frames": 42} |
| 1413.6 | 1413.6 | 3 | enemy_2 | attack wind-up | {"kind": "melee", "sample": 1} |
| 1413.6 | 1771.2 | 3 | enemy_2 | wind-up to contact | {"derived": true} |
| 1767.0 | 1863.7 | 3 | enemy_2 | hit stop | {"requested_ms": 85.0} |
| 1771.2 | 1771.2 | 3 | enemy_2 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 18, "sample_count": 42, "process_frame": 105} |
| 1771.2 | 1771.2 | 3 | enemy_2 | impact effect start | {"targets": ["player"]} |
| 1771.2 | 2596.4 | 3 | enemy_2 | contact to last number gone | {"derived": true} |
| 1783.3 | 2221.7 | 3 | enemy_2 | camera move | {"kind": "board kick"} |
| 1783.3 | 2471.9 | 3 | enemy_2 | number on screen | {"text": "−4", "category": "damage", "tile": "(5, 2)", "icon": "", "reaction": "hit"} |
| 1783.3 | 2394.2 | 3 | enemy_2 | surface effect | {"tile": "(5, 2)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1983.0 | 2596.4 | 3 | enemy_2 | number on screen | {"text": "Shock", "category": "status", "tile": "(5, 2)", "icon": "", "reaction": ""} |
| 2385.7 | 2585.6 | 3 | enemy_2 | floating feedback | {"numbers": 2} |
| 2586.5 | 2752.3 | 3 | enemy_2 | turn-order rail | — |
| 2590.3 | 2747.0 | 3 | enemy_2 | post-action settle | — |
| 2747.1 | 2747.1 | 4 | enemy_2 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 2752.1 | 2752.1 | 5 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 2753.7 | 2757.5 | 5 |  | turn-order rail | — |
| 2757.4 | 2757.4 | 6 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 2759.7 | 2945.0 | 6 |  | turn-order rail | — |
| 2763.3 | 2763.3 | 7 | enemy_3 | step dispatched | {"kind": "intent", "label": "Arc Jab"} |
| 2763.3 | 3021.3 | 7 | enemy_3 | pre-action delay | — |
| 3023.6 | 3023.6 | 8 | enemy_3 | step dispatched | {"kind": "move", "label": "Advance"} |
| 3023.6 | 3577.9 | 8 | enemy_3 | action | {"kind": "move", "label": "Advance"} |
| 3023.8 | 3526.6 | 8 | enemy_3 | unit move | {"actor": "enemy_3", "tiles": 1} |
| 3024.0 | 3526.6 | 8 | enemy_3 | sampled playback | {"authored_ms": 500.0, "frames": 30} |
| 3578.0 | 3578.0 | 9 | enemy_3 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 3578.0 | 4826.2 | 9 | enemy_3 | action | {"kind": "melee", "label": "Strike"} |
| 3579.1 | 4554.6 | 9 | enemy_3 | sampled playback | {"authored_ms": 700.0, "frames": 42} |
| 3582.9 | 3582.9 | 9 | enemy_3 | attack wind-up | {"kind": "melee", "sample": 1} |
| 3582.9 | 3940.5 | 9 | enemy_3 | wind-up to contact | {"derived": true} |
| 3936.4 | 4030.4 | 9 | enemy_3 | hit stop | {"requested_ms": 85.0} |
| 3940.5 | 3940.5 | 9 | enemy_3 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 18, "sample_count": 42, "process_frame": 245} |
| 3940.5 | 3940.5 | 9 | enemy_3 | impact effect start | {"targets": ["player"]} |
| 3940.5 | 4637.9 | 9 | enemy_3 | contact to last number gone | {"derived": true} |
| 3951.9 | 4383.3 | 9 | enemy_3 | camera move | {"kind": "board kick"} |
| 3951.9 | 4637.9 | 9 | enemy_3 | number on screen | {"text": "−4", "category": "damage", "tile": "(5, 2)", "icon": "", "reaction": "hit"} |
| 3951.9 | 4564.8 | 9 | enemy_3 | surface effect | {"tile": "(5, 2)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 4554.8 | 4660.7 | 9 | enemy_3 | floating feedback | {"numbers": 1} |
| 4661.6 | 4828.8 | 9 | enemy_3 | turn-order rail | — |
| 4665.1 | 4826.2 | 9 | enemy_3 | post-action settle | — |
| 4826.3 | 4826.3 | 10 | enemy_3 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 4828.7 | 4828.7 | 11 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 4830.3 | 4837.9 | 11 |  | turn-order rail | — |
| 4837.7 | 4837.7 | 12 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 4840.1 | 5046.3 | 12 |  | turn-order rail | — |
| 4843.4 | 4843.4 | 13 | enemy_1 | step dispatched | {"kind": "intent", "label": "Ooze Advance"} |
| 4845.6 | 4845.6 | 14 | enemy_1 | step dispatched | {"kind": "move", "label": "Advance"} |
| 4845.6 | 5276.8 | 14 | enemy_1 | action | {"kind": "move", "label": "Advance"} |
| 4845.8 | 5219.8 | 14 | enemy_1 | unit move | {"actor": "enemy_1", "tiles": 2} |
| 4845.9 | 5219.7 | 14 | enemy_1 | sampled playback | {"authored_ms": 366.666666666667, "frames": 74} |
| 4869.4 | 5504.9 | 14 | enemy_1 | caption shown | {"text": "Cinder Ooze: Ooze Advance"} |
| 5276.9 | 5276.9 | 15 | enemy_1 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 5281.0 | 5281.0 | 16 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 5281.3 | 5288.2 | 16 |  | turn-order rail | — |
| 5288.0 | 5288.0 | 17 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 5290.4 | 5470.9 | 17 |  | turn-order rail | — |
| 5293.9 | 5480.4 | — |  | hero hand-off drain | — |
| 5486.1 | 5801.3 | — |  | hand draw | {"cards": 1} |
| 5801.4 | 5814.6 | — |  | publish hero UI | — |
| 5803.1 | 5803.1 | — |  | hero turn banner requested | — |
| 5825.9 | 5825.9 | — |  | hero input accepted | — |

### 06-s2-seed1-2-11_-10-t5

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 1.9 | 1.9 | — |  | enemy turn banner requested | — |
| 47.9 | 225.5 | — |  | turn banner shown | {"text": "ENEMY TURN"} |
| 56.9 | 56.9 | — |  | locked hand capture | — |
| 84.5 | 97.5 | — |  | locked hand capture | — |
| 189.5 | 189.6 | — |  | defeat playback | — |
| 190.6 | 195.2 | — |  | turn-order rail | — |
| 191.6 | 191.6 | 0 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 198.1 | 336.1 | 0 |  | turn-order rail | — |
| 201.8 | 201.8 | 1 | enemy_5 | step dispatched | {"kind": "intent", "label": "Retreat Step"} |
| 202.1 | 356.7 | 1 | enemy_5 | pre-action delay | — |
| 225.5 | 1588.5 | 1 | enemy_5 | caption shown | {"text": "Bone Harrier: Retreat Step"} |
| 225.5 | 363.2 | 1 | enemy_5 | caption lead before motion or feedback | {"derived": true} |
| 362.9 | 362.9 | 2 | enemy_5 | step dispatched | {"kind": "move", "label": "Retreat"} |
| 362.9 | 793.0 | 2 | enemy_5 | action | {"kind": "move", "label": "Retreat"} |
| 363.2 | 742.1 | 2 | enemy_5 | unit move | {"actor": "enemy_5", "tiles": 2} |
| 363.3 | 742.1 | 2 | enemy_5 | sampled playback | {"authored_ms": 366.666666666667, "frames": 56} |
| 793.1 | 793.1 | 3 | enemy_5 | step dispatched | {"kind": "block", "label": "Guard"} |
| 793.1 | 1552.3 | 3 | enemy_5 | action | {"kind": "block", "label": "Guard"} |
| 793.5 | 793.5 | 3 | enemy_5 | resolved block | {"kind": "block", "label": "Guard", "rule": "", "actor": "enemy_5", "target": "(2, 1)"} |
| 793.6 | 1395.8 | 3 | enemy_5 | floating feedback | {"numbers": 1} |
| 803.2 | 1399.4 | 3 | enemy_5 | number on screen | {"text": "+4", "category": "status", "tile": "(2, 1)", "icon": "block", "reaction": ""} |
| 1397.0 | 1552.3 | 3 | enemy_5 | post-action settle | — |
| 1552.5 | 1552.5 | 4 | enemy_5 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 1557.6 | 1557.6 | 5 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 1557.9 | 1566.3 | 5 |  | turn-order rail | — |
| 1566.1 | 1566.1 | 6 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 1568.4 | 1752.9 | 6 |  | turn-order rail | — |
| 1571.8 | 1571.8 | 7 | enemy_1 | step dispatched | {"kind": "intent", "label": "Arc Bolt"} |
| 1571.9 | 1825.6 | 7 | enemy_1 | pre-action delay | — |
| 1588.5 | 3630.8 | 7 | enemy_1 | caption shown | {"text": "Arc Thrall: Arc Bolt"} |
| 1588.5 | 1832.2 | 7 | enemy_1 | caption lead before motion or feedback | {"derived": true} |
| 1829.8 | 1829.8 | 8 | enemy_1 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 1829.8 | 3589.0 | 8 | enemy_1 | action | {"kind": "ranged", "label": "Shot"} |
| 1830.2 | 3425.8 | 8 | enemy_1 | sampled playback | {"authored_ms": 1200.0, "frames": 72} |
| 1832.2 | 1832.2 | 8 | enemy_1 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 1832.2 | 2593.2 | 8 | enemy_1 | wind-up to contact | {"derived": true} |
| 2587.8 | 2679.6 | 8 | enemy_1 | hit stop | {"requested_ms": 85.0} |
| 2593.2 | 2593.2 | 8 | enemy_1 | contact | {"evidence": "contact effect submitted", "sample": 37, "sample_count": 72, "process_frame": 211} |
| 2593.2 | 2593.2 | 8 | enemy_1 | impact effect start | {"targets": []} |
| 2593.2 | 3288.9 | 8 | enemy_1 | contact to last number gone | {"derived": true} |
| 2605.3 | 3034.8 | 8 | enemy_1 | camera move | {"kind": "board kick"} |
| 2605.3 | 3288.9 | 8 | enemy_1 | number on screen | {"text": "−4", "category": "damage", "tile": "(4, 3)", "icon": "", "reaction": "hit"} |
| 3425.8 | 3428.3 | 8 | enemy_1 | floating feedback | {"numbers": 1} |
| 3430.1 | 3589.0 | 8 | enemy_1 | post-action settle | — |
| 3589.1 | 3589.1 | 9 | enemy_1 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 3590.4 | 3590.4 | 10 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 3590.7 | 3599.0 | 10 |  | turn-order rail | — |
| 3598.9 | 3598.9 | 11 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 3601.4 | 3612.1 | 11 |  | turn-order rail | — |
| 3604.8 | 3604.8 | 12 | enemy_2 | step dispatched | {"kind": "status_damage", "label": "Fire"} |
| 3604.8 | 4364.9 | 12 | enemy_2 | action | {"kind": "status_damage", "label": "Fire"} |
| 3605.1 | 3605.1 | 12 | enemy_2 | status tick | {"kind": "status_damage", "label": "Fire", "rule": "", "actor": "enemy_2", "target": "(4, 4)"} |
| 3613.3 | 4286.3 | 12 | enemy_2 | turn-order rail | — |
| 3613.6 | 4210.1 | 12 | enemy_2 | feedback deadline | — |
| 3630.8 | 4372.7 | 12 | enemy_2 | caption shown | {"text": "Arc Thrall: Fire"} |
| 3630.8 | 4214.9 | 12 | enemy_2 | number on screen | {"text": "−3", "category": "damage", "tile": "(4, 4)", "icon": "surface_fire", "reaction": "hit"} |
| 3630.8 | 4067.8 | 12 | enemy_2 | surface effect | {"tile": "(4, 4)", "kind": "surface_damage", "surface": "fire", "trigger": "start"} |
| 3630.8 | 3630.8 | 12 | enemy_2 | caption lead before motion or feedback | {"derived": true} |
| 4210.2 | 4364.9 | 12 | enemy_2 | post-action settle | — |
| 4365.0 | 4365.0 | 13 | enemy_2 | step dispatched | {"kind": "intent", "label": "Arc Bolt"} |
| 4365.2 | 4622.7 | 13 | enemy_2 | pre-action delay | — |
| 4372.7 | 6415.6 | 13 | enemy_2 | caption shown | {"text": "Arc Thrall: Arc Bolt"} |
| 4372.7 | 4627.8 | 13 | enemy_2 | caption lead before motion or feedback | {"derived": true} |
| 4625.2 | 4625.2 | 14 | enemy_2 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 4625.2 | 6380.5 | 14 | enemy_2 | action | {"kind": "ranged", "label": "Shot"} |
| 4625.6 | 6224.3 | 14 | enemy_2 | sampled playback | {"authored_ms": 1200.0, "frames": 72} |
| 4627.8 | 4627.8 | 14 | enemy_2 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 4627.8 | 5391.5 | 14 | enemy_2 | wind-up to contact | {"derived": true} |
| 5386.1 | 5479.4 | 14 | enemy_2 | hit stop | {"requested_ms": 85.0} |
| 5391.5 | 5391.5 | 14 | enemy_2 | contact | {"evidence": "contact effect submitted", "sample": 37, "sample_count": 72, "process_frame": 414} |
| 5391.5 | 5391.5 | 14 | enemy_2 | impact effect start | {"targets": []} |
| 5391.5 | 6091.4 | 14 | enemy_2 | contact to last number gone | {"derived": true} |
| 5404.3 | 5826.3 | 14 | enemy_2 | camera move | {"kind": "board kick"} |
| 5404.3 | 6091.4 | 14 | enemy_2 | number on screen | {"text": "−4", "category": "damage", "tile": "(4, 3)", "icon": "", "reaction": "hit"} |
| 6224.3 | 6226.7 | 14 | enemy_2 | floating feedback | {"numbers": 1} |
| 6228.6 | 6380.5 | 14 | enemy_2 | post-action settle | — |
| 6380.6 | 6380.6 | 15 | enemy_2 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 6385.7 | 6385.7 | 16 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 6386.1 | 6399.3 | 16 |  | turn-order rail | — |
| 6399.1 | 6399.1 | 17 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 6401.9 | 6586.9 | 17 |  | turn-order rail | — |
| 6405.3 | 6405.3 | 18 | enemy_5 | step dispatched | {"kind": "intent", "label": "Rush"} |
| 6405.4 | 6659.4 | 18 | enemy_5 | pre-action delay | — |
| 6415.6 | 9106.2 | 18 | enemy_5 | caption shown | {"text": "Bone Harrier: Rush"} |
| 6415.6 | 6665.7 | 18 | enemy_5 | caption lead before motion or feedback | {"derived": true} |
| 6665.5 | 6665.5 | 19 | enemy_5 | step dispatched | {"kind": "move", "label": "Advance"} |
| 6665.5 | 7838.1 | 19 | enemy_5 | action | {"kind": "move", "label": "Advance"} |
| 6665.7 | 7229.5 | 19 | enemy_5 | unit move | {"actor": "enemy_5", "tiles": 3} |
| 6665.8 | 7229.5 | 19 | enemy_5 | sampled playback | {"authored_ms": 550.0, "frames": 84} |
| 7229.7 | 7767.1 | 19 | enemy_5 | floating feedback | {"numbers": 1} |
| 7231.8 | 7279.7 | 19 | enemy_5 | hit stop | {"requested_ms": 40.0} |
| 7235.2 | 7235.2 | 19 | enemy_5 | impact effect start | {"targets": ["enemy_5"]} |
| 7244.8 | 7495.0 | 19 | enemy_5 | camera move | {"kind": "board kick"} |
| 7244.8 | 7793.3 | 19 | enemy_5 | number on screen | {"text": "−2", "category": "damage", "tile": "(3, 3)", "icon": "", "reaction": "hit"} |
| 7244.8 | 7793.3 | 19 | enemy_5 | surface effect | {"tile": "(3, 3)", "kind": "surface_damage", "surface": "fire", "trigger": "entry"} |
| 7770.2 | 8160.0 | 19 | enemy_5 | turn-order rail | — |
| 7838.2 | 7838.2 | 20 | enemy_5 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 7838.2 | 9058.1 | 20 | enemy_5 | action | {"kind": "melee", "label": "Strike"} |
| 7839.6 | 8750.5 | 20 | enemy_5 | sampled playback | {"authored_ms": 650.0, "frames": 39} |
| 7848.3 | 7848.3 | 20 | enemy_5 | attack wind-up | {"kind": "melee", "sample": 1} |
| 7848.3 | 8186.5 | 20 | enemy_5 | wind-up to contact | {"derived": true} |
| 8181.9 | 8272.7 | 20 | enemy_5 | hit stop | {"requested_ms": 85.0} |
| 8186.5 | 8186.5 | 20 | enemy_5 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 17, "sample_count": 39, "process_frame": 603} |
| 8186.5 | 8186.5 | 20 | enemy_5 | impact effect start | {"targets": ["player"]} |
| 8186.5 | 8881.5 | 20 | enemy_5 | contact to last number gone | {"derived": true} |
| 8199.4 | 8629.9 | 20 | enemy_5 | camera move | {"kind": "board kick"} |
| 8199.4 | 8881.5 | 20 | enemy_5 | number on screen | {"text": "−4", "category": "damage", "tile": "(4, 3)", "icon": "", "reaction": "hit"} |
| 8750.8 | 8905.6 | 20 | enemy_5 | floating feedback | {"numbers": 1} |
| 8906.7 | 9063.9 | 20 | enemy_5 | turn-order rail | — |
| 8907.1 | 9058.0 | 20 | enemy_5 | post-action settle | — |
| 9058.2 | 9058.2 | 21 | enemy_5 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 9063.7 | 9063.7 | 22 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 9065.6 | 9073.8 | 22 |  | turn-order rail | — |
| 9073.6 | 9073.6 | 23 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 9076.4 | 9289.6 | 23 |  | turn-order rail | — |
| 9080.1 | 9080.1 | 24 | enemy_3 | step dispatched | {"kind": "intent", "label": "Ooze Advance"} |
| 9082.5 | 9082.5 | 25 | enemy_3 | step dispatched | {"kind": "move", "label": "Advance"} |
| 9082.6 | 9506.1 | 25 | enemy_3 | action | {"kind": "move", "label": "Advance"} |
| 9082.7 | 9456.6 | 25 | enemy_3 | unit move | {"actor": "enemy_3", "tiles": 2} |
| 9082.9 | 9456.6 | 25 | enemy_3 | sampled playback | {"authored_ms": 366.666666666667, "frames": 74} |
| 9106.2 | 9735.9 | 25 | enemy_3 | caption shown | {"text": "Cinder Ooze: Ooze Advance"} |
| 9506.2 | 9506.2 | 26 | enemy_3 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 9511.0 | 9511.0 | 27 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 9511.4 | 9518.7 | 27 |  | turn-order rail | — |
| 9518.5 | 9518.5 | 28 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 9521.3 | 9703.1 | 28 |  | turn-order rail | — |
| 9524.6 | 9711.7 | — |  | hero hand-off drain | — |
| 9719.0 | 10350.1 | — |  | hero fatigue | — |
| 9721.4 | 9791.8 | — |  | hit stop | {"requested_ms": 60.0} |
| 9725.0 | 9725.0 | — |  | impact effect start | {"targets": ["player"]} |
| 9735.9 | 10027.1 | — |  | camera move | {"kind": "board kick"} |
| 9735.9 | 10287.0 | — |  | number on screen | {"text": "−2", "category": "damage", "tile": "(4, 3)", "icon": "", "reaction": "hit"} |
| 9873.7 | 10369.8 | — |  | number on screen | {"text": "fatigue sets in", "category": "status", "tile": "(4, 3)", "icon": "", "reaction": ""} |
| 10350.1 | 10657.0 | — |  | hand draw | {"cards": 1} |
| 10657.2 | 10675.0 | — |  | publish hero UI | — |
| 10661.5 | 10661.5 | — |  | hero turn banner requested | — |
| 10690.9 | 10690.9 | — |  | hero input accepted | — |

### 07-s4-seed1-4-19_-19-t4

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 1.9 | 1.9 | — |  | enemy turn banner requested | — |
| 53.6 | 256.7 | — |  | turn banner shown | {"text": "ENEMY TURN"} |
| 61.7 | 61.7 | — |  | locked hand capture | — |
| 94.9 | 106.0 | — |  | locked hand capture | — |
| 206.3 | 206.3 | — |  | defeat playback | — |
| 207.4 | 215.5 | — |  | turn-order rail | — |
| 212.0 | 212.0 | 0 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 218.1 | 528.3 | 0 |  | turn-order rail | — |
| 222.0 | 222.0 | 1 | enemy_3 | step dispatched | {"kind": "intent", "label": "Cudgel Press"} |
| 222.4 | 367.8 | 1 | enemy_3 | pre-action delay | — |
| 256.7 | 1820.3 | 1 | enemy_3 | caption shown | {"text": "Chainbound Gaoler: Cudgel Press"} |
| 256.7 | 490.6 | 1 | enemy_3 | caption lead before motion or feedback | {"derived": true} |
| 376.2 | 376.2 | 2 | enemy_3 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 376.3 | 1780.6 | 2 | enemy_3 | action | {"kind": "melee", "label": "Strike"} |
| 376.8 | 1550.9 | 2 | enemy_3 | sampled playback | {"authored_ms": 850.0, "frames": 51} |
| 490.6 | 490.6 | 2 | enemy_3 | attack wind-up | {"kind": "melee", "sample": 1} |
| 490.6 | 913.3 | 2 | enemy_3 | wind-up to contact | {"derived": true} |
| 907.9 | 1020.5 | 2 | enemy_3 | hit stop | {"requested_ms": 105.0} |
| 913.3 | 913.3 | 2 | enemy_3 | contact | {"evidence": "contact effect submitted", "sample": 26, "sample_count": 51, "process_frame": 36} |
| 913.3 | 913.3 | 2 | enemy_3 | impact effect start | {"targets": []} |
| 913.3 | 1637.5 | 2 | enemy_3 | contact to last number gone | {"derived": true} |
| 926.2 | 1431.5 | 2 | enemy_3 | camera move | {"kind": "board kick"} |
| 926.2 | 1637.5 | 2 | enemy_3 | number on screen | {"text": "−8", "category": "damage", "tile": "(2, 5)", "icon": "", "reaction": "hit"} |
| 1550.9 | 1624.3 | 2 | enemy_3 | floating feedback | {"numbers": 1} |
| 1627.0 | 1780.6 | 2 | enemy_3 | post-action settle | — |
| 1780.7 | 1780.7 | 3 | enemy_3 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 1786.1 | 1786.1 | 4 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 1786.6 | 1796.6 | 4 |  | turn-order rail | — |
| 1796.3 | 1796.3 | 5 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 1799.0 | 1996.6 | 5 |  | turn-order rail | — |
| 1802.7 | 1802.7 | 6 | enemy_4 | step dispatched | {"kind": "intent", "label": "Skitter Strike"} |
| 1802.8 | 2058.3 | 6 | enemy_4 | pre-action delay | — |
| 1820.3 | 3505.9 | 6 | enemy_4 | caption shown | {"text": "Tunnel Crawler: Skitter Strike"} |
| 1820.3 | 2062.9 | 6 | enemy_4 | caption lead before motion or feedback | {"derived": true} |
| 2062.6 | 2062.6 | 7 | enemy_4 | step dispatched | {"kind": "move", "label": "Advance"} |
| 2062.6 | 2285.0 | 7 | enemy_4 | action | {"kind": "move", "label": "Advance"} |
| 2062.9 | 2251.2 | 7 | enemy_4 | unit move | {"actor": "enemy_4", "tiles": 1} |
| 2063.1 | 2251.1 | 7 | enemy_4 | sampled playback | {"authored_ms": 183.333333333333, "frames": 28} |
| 2285.1 | 2285.1 | 8 | enemy_4 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 2285.1 | 3477.8 | 8 | enemy_4 | action | {"kind": "melee", "label": "Strike"} |
| 2286.7 | 3124.7 | 8 | enemy_4 | sampled playback | {"authored_ms": 600.0, "frames": 36} |
| 2290.3 | 2290.3 | 8 | enemy_4 | attack wind-up | {"kind": "melee", "sample": 1} |
| 2290.3 | 2618.1 | 8 | enemy_4 | wind-up to contact | {"derived": true} |
| 2614.1 | 2704.4 | 8 | enemy_4 | hit stop | {"requested_ms": 85.0} |
| 2618.1 | 2618.1 | 8 | enemy_4 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 16, "sample_count": 36, "process_frame": 140} |
| 2618.1 | 2618.1 | 8 | enemy_4 | impact effect start | {"targets": ["player"]} |
| 2618.1 | 3310.2 | 8 | enemy_4 | contact to last number gone | {"derived": true} |
| 2630.3 | 3052.7 | 8 | enemy_4 | camera move | {"kind": "board kick"} |
| 2630.3 | 3310.2 | 8 | enemy_4 | number on screen | {"text": "−7", "category": "damage", "tile": "(2, 5)", "icon": "", "reaction": "hit"} |
| 3125.0 | 3321.4 | 8 | enemy_4 | floating feedback | {"numbers": 1} |
| 3322.6 | 3481.4 | 8 | enemy_4 | turn-order rail | — |
| 3326.4 | 3477.8 | 8 | enemy_4 | post-action settle | — |
| 3477.9 | 3477.9 | 9 | enemy_4 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 3481.0 | 3481.0 | 10 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 3482.9 | 3486.8 | 10 |  | turn-order rail | — |
| 3486.5 | 3486.5 | 11 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 3488.9 | 3707.4 | 11 |  | turn-order rail | — |
| 3492.5 | 3492.5 | 12 | enemy_1 | step dispatched | {"kind": "intent", "label": "Lob Slag"} |
| 3492.6 | 3758.0 | 12 | enemy_1 | pre-action delay | — |
| 3505.9 | 4911.2 | 12 | enemy_1 | caption shown | {"text": "Lob Slag · 7 / 5"} |
| 3505.9 | 3764.9 | 12 | enemy_1 | caption lead before motion or feedback | {"derived": true} |
| 3760.8 | 3760.8 | 13 | enemy_1 | step dispatched | {"kind": "aoe", "label": ""} |
| 3760.9 | 4854.5 | 13 | enemy_1 | action | {"kind": "aoe", "label": ""} |
| 3761.5 | 4609.4 | 13 | enemy_1 | sampled playback | {"authored_ms": 600.0, "frames": 36} |
| 3764.9 | 3764.9 | 13 | enemy_1 | attack wind-up | {"kind": "aoe", "sample": 1} |
| 3764.9 | 3764.9 | 13 | enemy_1 | contact | {"evidence": "contact effect submitted", "sample": 1, "sample_count": 36, "process_frame": 213} |
| 3764.9 | 3764.9 | 13 | enemy_1 | impact effect start | {"targets": []} |
| 3764.9 | 3764.9 | 13 | enemy_1 | wind-up to contact | {"derived": true} |
| 3764.9 | 4726.4 | 13 | enemy_1 | contact to last number gone | {"derived": true} |
| 4001.2 | 4101.3 | 13 | enemy_1 | hit stop | {"requested_ms": 85.0} |
| 4024.4 | 4469.8 | 13 | enemy_1 | camera move | {"kind": "board kick"} |
| 4024.4 | 4726.4 | 13 | enemy_1 | number on screen | {"text": "−7", "category": "damage", "tile": "(2, 5)", "icon": "", "reaction": "hit"} |
| 4024.4 | 4726.4 | 13 | enemy_1 | number on screen | {"text": "−5", "category": "damage", "tile": "(3, 5)", "icon": "", "reaction": "hit"} |
| 4024.4 | 4726.4 | 13 | enemy_1 | number on screen | {"text": "−5", "category": "damage", "tile": "(1, 5)", "icon": "", "reaction": "hit"} |
| 4024.4 | 4024.4 | 13 | enemy_1 | ground state changed | {"kind": "surface_created", "surface": "fire", "tile": "(2, 5)", "trigger": ""} |
| 4024.4 | 4024.4 | 13 | enemy_1 | ground state changed | {"kind": "surface_created", "surface": "fire", "tile": "(3, 5)", "trigger": ""} |
| 4024.4 | 4024.4 | 13 | enemy_1 | ground state changed | {"kind": "surface_created", "surface": "fire", "tile": "(2, 6)", "trigger": ""} |
| 4024.4 | 4024.4 | 13 | enemy_1 | ground state changed | {"kind": "surface_created", "surface": "fire", "tile": "(1, 5)", "trigger": ""} |
| 4609.4 | 4691.5 | 13 | enemy_1 | floating feedback | {"numbers": 3} |
| 4693.4 | 4861.7 | 13 | enemy_1 | turn-order rail | — |
| 4696.8 | 4854.5 | 13 | enemy_1 | post-action settle | — |
| 4854.6 | 4854.6 | 14 | enemy_1 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 4861.4 | 4861.4 | 15 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 4863.2 | 4875.3 | 15 |  | turn-order rail | — |
| 4874.9 | 4874.9 | 16 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 4877.7 | 4890.3 | 16 |  | turn-order rail | — |
| 4881.7 | 4881.7 | 17 | enemy_4 | step dispatched | {"kind": "status_damage", "label": "Fire"} |
| 4881.7 | 5654.8 | 17 | enemy_4 | action | {"kind": "status_damage", "label": "Fire"} |
| 4882.2 | 4882.2 | 17 | enemy_4 | status tick | {"kind": "status_damage", "label": "Fire", "rule": "", "actor": "enemy_4", "target": "(1, 5)"} |
| 4891.8 | 5303.0 | 17 | enemy_4 | turn-order rail | — |
| 4892.1 | 5496.5 | 17 | enemy_4 | feedback deadline | — |
| 4911.2 | 5661.3 | 17 | enemy_4 | caption shown | {"text": "Tunnel Crawler: Fire"} |
| 4911.2 | 5500.6 | 17 | enemy_4 | number on screen | {"text": "−3", "category": "damage", "tile": "(1, 5)", "icon": "surface_fire", "reaction": "hit"} |
| 4911.2 | 5351.7 | 17 | enemy_4 | surface effect | {"tile": "(1, 5)", "kind": "surface_damage", "surface": "fire", "trigger": "start"} |
| 4911.2 | 4911.2 | 17 | enemy_4 | caption lead before motion or feedback | {"derived": true} |
| 5496.5 | 5654.8 | 17 | enemy_4 | post-action settle | — |
| 5654.9 | 5654.9 | 18 | enemy_4 | step dispatched | {"kind": "intent", "label": "Skitter Strike"} |
| 5655.0 | 5912.4 | 18 | enemy_4 | pre-action delay | — |
| 5661.3 | 7165.5 | 18 | enemy_4 | caption shown | {"text": "Tunnel Crawler: Skitter Strike"} |
| 5661.3 | 5920.7 | 18 | enemy_4 | caption lead before motion or feedback | {"derived": true} |
| 5916.0 | 5916.0 | 19 | enemy_4 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 5916.0 | 7114.3 | 19 | enemy_4 | action | {"kind": "melee", "label": "Strike"} |
| 5917.5 | 6769.4 | 19 | enemy_4 | sampled playback | {"authored_ms": 600.0, "frames": 36} |
| 5920.7 | 5920.7 | 19 | enemy_4 | attack wind-up | {"kind": "melee", "sample": 1} |
| 5920.7 | 6243.2 | 19 | enemy_4 | wind-up to contact | {"derived": true} |
| 6238.8 | 6330.9 | 19 | enemy_4 | hit stop | {"requested_ms": 85.0} |
| 6243.2 | 6243.2 | 19 | enemy_4 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 16, "sample_count": 36, "process_frame": 371} |
| 6243.2 | 6243.2 | 19 | enemy_4 | impact effect start | {"targets": ["player"]} |
| 6243.2 | 6934.0 | 19 | enemy_4 | contact to last number gone | {"derived": true} |
| 6256.7 | 6694.0 | 19 | enemy_4 | camera move | {"kind": "board kick"} |
| 6256.7 | 6934.0 | 19 | enemy_4 | number on screen | {"text": "−7", "category": "damage", "tile": "(2, 5)", "icon": "", "reaction": "hit"} |
| 6769.7 | 6960.4 | 19 | enemy_4 | floating feedback | {"numbers": 1} |
| 6961.4 | 7118.2 | 19 | enemy_4 | turn-order rail | — |
| 6961.8 | 7114.3 | 19 | enemy_4 | post-action settle | — |
| 7114.5 | 7114.5 | 20 | enemy_4 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 7117.9 | 7117.9 | 21 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 7119.8 | 7126.4 | 21 |  | turn-order rail | — |
| 7126.1 | 7126.1 | 22 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 7128.7 | 7142.8 | 22 |  | turn-order rail | — |
| 7132.9 | 7132.9 | 23 | enemy_3 | step dispatched | {"kind": "status_damage", "label": "Fire"} |
| 7133.0 | 7904.1 | 23 | enemy_3 | action | {"kind": "status_damage", "label": "Fire"} |
| 7133.5 | 7133.5 | 23 | enemy_3 | status tick | {"kind": "status_damage", "label": "Fire", "rule": "", "actor": "enemy_3", "target": "(3, 5)"} |
| 7144.5 | 7559.0 | 23 | enemy_3 | turn-order rail | — |
| 7144.8 | 7745.1 | 23 | enemy_3 | feedback deadline | — |
| 7165.5 | 7907.6 | 23 | enemy_3 | caption shown | {"text": "Chainbound Gaoler: Fire"} |
| 7165.5 | 7753.0 | 23 | enemy_3 | number on screen | {"text": "−3", "category": "damage", "tile": "(3, 5)", "icon": "surface_fire", "reaction": "hit"} |
| 7165.5 | 7591.2 | 23 | enemy_3 | surface effect | {"tile": "(3, 5)", "kind": "surface_damage", "surface": "fire", "trigger": "start"} |
| 7165.5 | 7165.5 | 23 | enemy_3 | caption lead before motion or feedback | {"derived": true} |
| 7745.1 | 7904.1 | 23 | enemy_3 | post-action settle | — |
| 7904.2 | 7904.2 | 24 | enemy_3 | step dispatched | {"kind": "intent", "label": "Manacle Pin"} |
| 7904.4 | 8154.6 | 24 | enemy_3 | pre-action delay | — |
| 7907.6 | 9856.3 | 24 | enemy_3 | caption shown | {"text": "Chainbound Gaoler: Manacle Pin"} |
| 7907.6 | 8161.8 | 24 | enemy_3 | caption lead before motion or feedback | {"derived": true} |
| 8157.5 | 8157.5 | 25 | enemy_3 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 8157.5 | 9592.2 | 25 | enemy_3 | action | {"kind": "ranged", "label": "Shot"} |
| 8158.1 | 9227.6 | 25 | enemy_3 | sampled playback | {"authored_ms": 800.0, "frames": 48} |
| 8161.8 | 8161.8 | 25 | enemy_3 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 8161.8 | 8671.9 | 25 | enemy_3 | wind-up to contact | {"derived": true} |
| 8667.1 | 8732.2 | 25 | enemy_3 | hit stop | {"requested_ms": 60.0} |
| 8671.9 | 8671.9 | 25 | enemy_3 | contact | {"evidence": "contact effect submitted", "sample": 25, "sample_count": 48, "process_frame": 525} |
| 8671.9 | 8671.9 | 25 | enemy_3 | impact effect start | {"targets": []} |
| 8671.9 | 9446.5 | 25 | enemy_3 | contact to last number gone | {"derived": true} |
| 8682.7 | 9056.2 | 25 | enemy_3 | camera move | {"kind": "board kick"} |
| 8682.7 | 9343.1 | 25 | enemy_3 | number on screen | {"text": "−3", "category": "damage", "tile": "(2, 5)", "icon": "", "reaction": "hit"} |
| 8847.5 | 9446.5 | 25 | enemy_3 | number on screen | {"text": "Immobilize", "category": "status", "tile": "(2, 5)", "icon": "", "reaction": ""} |
| 9227.7 | 9432.4 | 25 | enemy_3 | floating feedback | {"numbers": 2} |
| 9435.2 | 9592.2 | 25 | enemy_3 | post-action settle | — |
| 9592.3 | 9592.3 | 26 | enemy_3 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 9594.0 | 9594.0 | 27 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 9594.4 | 9600.9 | 27 |  | turn-order rail | — |
| 9600.6 | 9600.6 | 28 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 9603.2 | 9819.3 | 28 |  | turn-order rail | — |
| 9607.1 | 9830.2 | — |  | hero hand-off drain | — |
| 9838.6 | 10397.9 | — |  | hero turn-start fire | — |
| 9841.6 | 9906.3 | — |  | hit stop | {"requested_ms": 60.0} |
| 9845.3 | 9845.3 | — |  | impact effect start | {"targets": ["player"]} |
| 9856.3 | 10136.1 | — |  | camera move | {"kind": "board kick"} |
| 9856.3 | 10406.7 | — |  | number on screen | {"text": "−3", "category": "damage", "tile": "(2, 5)", "icon": "surface_fire", "reaction": "hit"} |
| 10397.9 | 11024.1 | — |  | hero fatigue | — |
| 10399.6 | 10466.8 | — |  | hit stop | {"requested_ms": 60.0} |
| 10406.7 | 10735.9 | — |  | camera move | {"kind": "board kick"} |
| 10406.7 | 10950.5 | — |  | number on screen | {"text": "−2", "category": "damage", "tile": "(2, 5)", "icon": "", "reaction": "hit"} |
| 10550.0 | 11047.0 | — |  | number on screen | {"text": "fatigue sets in", "category": "status", "tile": "(2, 5)", "icon": "", "reaction": ""} |
| 11024.1 | 11489.8 | — |  | hand draw | {"cards": 2} |
| 11490.0 | 11505.0 | — |  | publish hero UI | — |
| 11492.2 | 11492.2 | — |  | hero turn banner requested | — |
| 11520.5 | 11520.5 | — |  | hero input accepted | — |

### 08-s1-seed8-1-5_-4-t5

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 1.5 | 1.5 | — |  | enemy turn banner requested | — |
| 38.0 | 250.3 | — |  | turn banner shown | {"text": "ENEMY TURN"} |
| 43.4 | 43.4 | — |  | locked hand capture | — |
| 82.2 | 92.9 | — |  | locked hand capture | — |
| 180.4 | 180.5 | — |  | defeat playback | — |
| 181.1 | 185.8 | — |  | turn-order rail | — |
| 182.9 | 182.9 | 0 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 187.2 | 345.6 | 0 |  | turn-order rail | — |
| 189.1 | 189.1 | 1 | enemy_1 | step dispatched | {"kind": "intent", "label": "Ooze Advance"} |
| 193.2 | 193.2 | 2 | enemy_1 | step dispatched | {"kind": "move", "label": "Advance"} |
| 193.2 | 610.7 | 2 | enemy_1 | action | {"kind": "move", "label": "Advance"} |
| 193.3 | 562.8 | 2 | enemy_1 | unit move | {"actor": "enemy_1", "tiles": 2} |
| 193.5 | 562.8 | 2 | enemy_1 | sampled playback | {"authored_ms": 366.666666666667, "frames": 74} |
| 250.3 | 842.8 | 2 | enemy_1 | caption shown | {"text": "Cinder Ooze: Ooze Advance"} |
| 610.8 | 610.8 | 3 | enemy_1 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 611.6 | 611.6 | 4 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 611.8 | 616.0 | 4 |  | turn-order rail | — |
| 615.9 | 615.9 | 5 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 617.1 | 810.9 | 5 |  | turn-order rail | — |
| 618.7 | 821.4 | — |  | hero hand-off drain | — |
| 827.0 | 1379.0 | — |  | hero turn-start fire | — |
| 828.8 | 893.1 | — |  | hit stop | {"requested_ms": 60.0} |
| 831.4 | 831.4 | — |  | impact effect start | {"targets": ["player"]} |
| 842.8 | 1132.5 | — |  | camera move | {"kind": "board kick"} |
| 842.8 | 1383.9 | — |  | number on screen | {"text": "−3", "category": "damage", "tile": "(5, 5)", "icon": "surface_fire", "reaction": "hit"} |
| 1379.0 | 1999.3 | — |  | hero fatigue | — |
| 1380.1 | 1444.9 | — |  | hit stop | {"requested_ms": 60.0} |
| 1383.9 | 1714.0 | — |  | camera move | {"kind": "board kick"} |
| 1383.9 | 1934.8 | — |  | number on screen | {"text": "−2", "category": "damage", "tile": "(5, 5)", "icon": "", "reaction": "hit"} |
| 1525.8 | 2022.9 | — |  | number on screen | {"text": "fatigue sets in", "category": "status", "tile": "(5, 5)", "icon": "", "reaction": ""} |
| 1999.3 | 2470.0 | — |  | hand draw | {"cards": 2} |
| 2470.2 | 2479.5 | — |  | publish hero UI | — |
| 2471.7 | 2471.7 | — |  | hero turn banner requested | — |
| 2490.8 | 2490.8 | — |  | hero input accepted | — |

### 09-s3-seed12-3-16_0-t15

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 44.8 | 44.8 | — |  | locked hand capture | — |
| 93.0 | 140.0 | — |  | locked hand capture | — |
| 212.9 | 212.9 | — |  | defeat playback | — |
| 215.9 | 221.8 | — |  | turn-order rail | — |
| 218.1 | 218.1 | 0 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 223.4 | 239.8 | 0 |  | turn-order rail | — |
| 225.2 | 225.2 | 1 | enemy_1 | step dispatched | {"kind": "status_damage", "label": "Fire"} |
| 225.3 | 983.7 | 1 | enemy_1 | action | {"kind": "status_damage", "label": "Fire"} |
| 226.3 | 226.3 | 1 | enemy_1 | status tick | {"kind": "status_damage", "label": "Fire", "rule": "", "actor": "enemy_1", "target": "(6, 5)"} |
| 240.6 | 627.4 | 1 | enemy_1 | turn-order rail | — |
| 240.8 | 833.0 | 1 | enemy_1 | feedback deadline | — |
| 317.6 | 1010.4 | 1 | enemy_1 | caption shown | {"text": "Fire"} |
| 317.6 | 838.2 | 1 | enemy_1 | number on screen | {"text": "−3", "category": "damage", "tile": "(6, 5)", "icon": "surface_fire", "reaction": "hit"} |
| 317.6 | 694.5 | 1 | enemy_1 | surface effect | {"tile": "(6, 5)", "kind": "surface_damage", "surface": "fire", "trigger": "start"} |
| 317.6 | 317.6 | 1 | enemy_1 | caption lead before motion or feedback | {"derived": true} |
| 833.0 | 983.6 | 1 | enemy_1 | post-action settle | — |
| 983.8 | 983.8 | 2 | enemy_1 | step dispatched | {"kind": "intent", "label": "Storm Lash"} |
| 987.9 | 987.9 | 3 | enemy_1 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 987.9 | 2625.6 | 3 | enemy_1 | action | {"kind": "ranged", "label": "Shot"} |
| 989.6 | 2464.4 | 3 | enemy_1 | sampled playback | {"authored_ms": 1100.0, "frames": 66} |
| 996.7 | 996.7 | 3 | enemy_1 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 996.7 | 1713.3 | 3 | enemy_1 | wind-up to contact | {"derived": true} |
| 1010.4 | 2885.4 | 3 | enemy_1 | caption shown | {"text": "Storm Lash"} |
| 1010.4 | 1743.5 | 3 | enemy_1 | caption lead before motion or feedback | {"derived": true} |
| 1706.9 | 1801.4 | 3 | enemy_1 | hit stop | {"requested_ms": 85.0} |
| 1713.3 | 1713.3 | 3 | enemy_1 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 35, "sample_count": 66, "process_frame": 86} |
| 1713.3 | 1713.3 | 3 | enemy_1 | impact effect start | {"targets": ["player"]} |
| 1713.3 | 2419.9 | 3 | enemy_1 | contact to last number gone | {"derived": true} |
| 1743.5 | 2181.1 | 3 | enemy_1 | camera move | {"kind": "board kick"} |
| 1743.5 | 2419.9 | 3 | enemy_1 | number on screen | {"text": "−6", "category": "damage", "tile": "(6, 4)", "icon": "", "reaction": "hit"} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(5, 1)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(6, 1)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(2, 2)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(3, 2)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(4, 2)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(5, 2)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(6, 2)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(7, 2)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(2, 3)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(3, 3)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(4, 3)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(5, 3)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(6, 3)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(7, 3)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(1, 4)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(2, 4)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(6, 4)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(1, 5)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(1, 6)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 1743.5 | 2483.0 | 3 | enemy_1 | surface effect | {"tile": "(2, 6)", "kind": "surface_conducted", "surface": "electrified", "trigger": ""} |
| 2465.0 | 2471.3 | 3 | enemy_1 | floating feedback | {"numbers": 1} |
| 2474.4 | 2632.8 | 3 | enemy_1 | turn-order rail | — |
| 2474.9 | 2625.6 | 3 | enemy_1 | post-action settle | — |
| 2625.7 | 2625.7 | 4 | enemy_1 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 2632.6 | 2632.6 | 5 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 2633.7 | 2642.1 | 5 |  | turn-order rail | — |
| 2641.8 | 2641.8 | 6 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 2643.5 | 2844.0 | 6 |  | turn-order rail | — |
| 2645.9 | 2853.2 | — |  | hero hand-off drain | — |
| 2864.6 | 3152.2 | — |  | hand draw | {"cards": 1} |
| 3152.3 | 3166.7 | — |  | publish hero UI | — |
| 3154.1 | 3154.1 | — |  | hero turn banner suppressed | {"boss_hud_or_caption": true} |
| 3180.4 | 3180.4 | — |  | hero input accepted | — |

### 10-s3-seed12-3-13_-2-t4

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 1.8 | 1.8 | — |  | enemy turn banner requested | — |
| 51.1 | 232.0 | — |  | turn banner shown | {"text": "ENEMY TURN"} |
| 56.7 | 56.7 | — |  | locked hand capture | — |
| 103.3 | 126.7 | — |  | locked hand capture | — |
| 186.0 | 186.0 | — |  | defeat playback | — |
| 186.6 | 191.9 | — |  | turn-order rail | — |
| 187.5 | 187.5 | 0 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 193.3 | 350.5 | 0 |  | turn-order rail | — |
| 195.3 | 195.3 | 1 | enemy_3 | step dispatched | {"kind": "intent", "label": "Dust Bolt"} |
| 195.5 | 357.3 | 1 | enemy_3 | pre-action delay | — |
| 232.0 | 2243.1 | 1 | enemy_3 | caption shown | {"text": "Dust Acolyte: Dust Bolt"} |
| 232.0 | 365.5 | 1 | enemy_3 | caption lead before motion or feedback | {"derived": true} |
| 362.1 | 362.1 | 2 | enemy_3 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 362.1 | 2219.1 | 2 | enemy_3 | action | {"kind": "ranged", "label": "Shot"} |
| 363.2 | 1952.2 | 2 | enemy_3 | sampled playback | {"authored_ms": 1200.0, "frames": 72} |
| 365.5 | 365.5 | 2 | enemy_3 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 365.5 | 1351.4 | 2 | enemy_3 | wind-up to contact | {"derived": true} |
| 1348.7 | 1438.8 | 2 | enemy_3 | hit stop | {"requested_ms": 85.0} |
| 1351.4 | 1351.4 | 2 | enemy_3 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 48, "sample_count": 72, "process_frame": 129} |
| 1351.4 | 1351.4 | 2 | enemy_3 | impact effect start | {"targets": ["player"]} |
| 1351.4 | 2041.7 | 2 | enemy_3 | contact to last number gone | {"derived": true} |
| 1358.4 | 1794.0 | 2 | enemy_3 | camera move | {"kind": "board kick"} |
| 1358.4 | 2041.7 | 2 | enemy_3 | number on screen | {"text": "−7", "category": "damage", "tile": "(4, 4)", "icon": "", "reaction": "hit"} |
| 1952.5 | 2060.8 | 2 | enemy_3 | floating feedback | {"numbers": 1} |
| 2061.4 | 2223.6 | 2 | enemy_3 | turn-order rail | — |
| 2061.7 | 2219.1 | 2 | enemy_3 | post-action settle | — |
| 2219.2 | 2219.2 | 3 | enemy_3 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 2223.4 | 2223.4 | 4 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 2224.5 | 2231.5 | 4 |  | turn-order rail | — |
| 2231.2 | 2231.2 | 5 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 2232.8 | 2445.4 | 5 |  | turn-order rail | — |
| 2234.6 | 2234.6 | 6 | enemy_3 | step dispatched | {"kind": "intent", "label": "Siphon"} |
| 2234.7 | 2491.4 | 6 | enemy_3 | pre-action delay | — |
| 2243.1 | 4641.0 | 6 | enemy_3 | caption shown | {"text": "Dust Acolyte: Siphon"} |
| 2243.1 | 2496.6 | 6 | enemy_3 | caption lead before motion or feedback | {"derived": true} |
| 2493.6 | 2493.6 | 7 | enemy_3 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 2493.7 | 4358.3 | 7 | enemy_3 | action | {"kind": "ranged", "label": "Shot"} |
| 2494.7 | 4086.8 | 7 | enemy_3 | sampled playback | {"authored_ms": 1200.0, "frames": 72} |
| 2496.6 | 2496.6 | 7 | enemy_3 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 2496.6 | 3479.7 | 7 | enemy_3 | wind-up to contact | {"derived": true} |
| 3476.9 | 3567.5 | 7 | enemy_3 | hit stop | {"requested_ms": 85.0} |
| 3479.7 | 3479.7 | 7 | enemy_3 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 48, "sample_count": 72, "process_frame": 321} |
| 3479.7 | 3479.7 | 7 | enemy_3 | impact effect start | {"targets": ["player"]} |
| 3479.7 | 4177.1 | 7 | enemy_3 | contact to last number gone | {"derived": true} |
| 3485.6 | 3927.8 | 7 | enemy_3 | camera move | {"kind": "board kick"} |
| 3485.6 | 4177.1 | 7 | enemy_3 | number on screen | {"text": "−6", "category": "damage", "tile": "(4, 4)", "icon": "", "reaction": "hit"} |
| 4087.1 | 4198.2 | 7 | enemy_3 | floating feedback | {"numbers": 1} |
| 4199.2 | 4362.9 | 7 | enemy_3 | turn-order rail | — |
| 4199.6 | 4358.3 | 7 | enemy_3 | post-action settle | — |
| 4358.4 | 4358.4 | 8 | enemy_3 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 4362.7 | 4362.7 | 9 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 4364.1 | 4366.9 | 9 |  | turn-order rail | — |
| 4366.6 | 4366.6 | 10 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 4368.9 | 4583.4 | 10 |  | turn-order rail | — |
| 4371.5 | 4592.3 | — |  | hero hand-off drain | — |
| 4598.6 | 5055.0 | — |  | hand draw | {"cards": 2} |
| 5055.1 | 5068.1 | — |  | publish hero UI | — |
| 5056.9 | 5056.9 | — |  | hero turn banner requested | — |
| 5084.9 | 5084.9 | — |  | hero input accepted | — |

### 11-s4-seed12-4-19_-14-t4

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 1.9 | 1.9 | — |  | enemy turn banner requested | — |
| 54.8 | 265.1 | — |  | turn banner shown | {"text": "ENEMY TURN"} |
| 64.2 | 64.2 | — |  | locked hand capture | — |
| 99.1 | 112.3 | — |  | locked hand capture | — |
| 222.8 | 222.8 | — |  | defeat playback | — |
| 224.0 | 229.1 | — |  | turn-order rail | — |
| 225.0 | 225.0 | 0 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 232.4 | 386.7 | 0 |  | turn-order rail | — |
| 236.3 | 236.3 | 1 | enemy_5 | step dispatched | {"kind": "intent", "label": "Dust Bolt"} |
| 236.5 | 369.0 | 1 | enemy_5 | pre-action delay | — |
| 265.1 | 2302.0 | 1 | enemy_5 | caption shown | {"text": "Dust Acolyte: Dust Bolt"} |
| 265.1 | 381.8 | 1 | enemy_5 | caption lead before motion or feedback | {"derived": true} |
| 377.2 | 377.2 | 2 | enemy_5 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 377.3 | 2254.5 | 2 | enemy_5 | action | {"kind": "ranged", "label": "Shot"} |
| 378.5 | 1978.4 | 2 | enemy_5 | sampled playback | {"authored_ms": 1200.0, "frames": 72} |
| 381.8 | 381.8 | 2 | enemy_5 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 381.8 | 1370.9 | 2 | enemy_5 | wind-up to contact | {"derived": true} |
| 1367.4 | 1466.7 | 2 | enemy_5 | hit stop | {"requested_ms": 85.0} |
| 1370.9 | 1370.9 | 2 | enemy_5 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 48, "sample_count": 72, "process_frame": 97} |
| 1370.9 | 1370.9 | 2 | enemy_5 | impact effect start | {"targets": ["player"]} |
| 1370.9 | 2067.5 | 2 | enemy_5 | contact to last number gone | {"derived": true} |
| 1381.5 | 1813.9 | 2 | enemy_5 | camera move | {"kind": "board kick"} |
| 1381.5 | 2067.5 | 2 | enemy_5 | number on screen | {"text": "−7", "category": "damage", "tile": "(3, 6)", "icon": "", "reaction": "hit"} |
| 1978.7 | 2090.3 | 2 | enemy_5 | floating feedback | {"numbers": 1} |
| 2091.3 | 2259.4 | 2 | enemy_5 | turn-order rail | — |
| 2095.7 | 2254.5 | 2 | enemy_5 | post-action settle | — |
| 2254.6 | 2254.6 | 3 | enemy_5 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 2259.1 | 2259.1 | 4 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 2261.1 | 2267.7 | 4 |  | turn-order rail | — |
| 2267.4 | 2267.4 | 5 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 2270.1 | 2281.7 | 5 |  | turn-order rail | — |
| 2273.8 | 2273.8 | 6 | enemy_4 | step dispatched | {"kind": "status_damage", "label": "Fire"} |
| 2273.8 | 3035.8 | 6 | enemy_4 | action | {"kind": "status_damage", "label": "Fire"} |
| 2274.3 | 2274.3 | 6 | enemy_4 | status tick | {"kind": "status_damage", "label": "Fire", "rule": "", "actor": "enemy_4", "target": "(3, 5)"} |
| 2283.0 | 2967.4 | 6 | enemy_4 | turn-order rail | — |
| 2283.3 | 2879.9 | 6 | enemy_4 | feedback deadline | — |
| 2302.0 | 3043.0 | 6 | enemy_4 | caption shown | {"text": "Tunnel Crawler: Fire"} |
| 2302.0 | 2885.4 | 6 | enemy_4 | number on screen | {"text": "−3", "category": "damage", "tile": "(3, 5)", "icon": "surface_fire", "reaction": "hit"} |
| 2302.0 | 2733.8 | 6 | enemy_4 | surface effect | {"tile": "(3, 5)", "kind": "surface_damage", "surface": "fire", "trigger": "start"} |
| 2302.0 | 2302.0 | 6 | enemy_4 | caption lead before motion or feedback | {"derived": true} |
| 2879.9 | 3035.8 | 6 | enemy_4 | post-action settle | — |
| 3035.9 | 3035.9 | 7 | enemy_4 | step dispatched | {"kind": "intent", "label": "Skitter Strike"} |
| 3036.1 | 3293.8 | 7 | enemy_4 | pre-action delay | — |
| 3043.0 | 4530.3 | 7 | enemy_4 | caption shown | {"text": "Tunnel Crawler: Skitter Strike"} |
| 3043.0 | 3301.0 | 7 | enemy_4 | caption lead before motion or feedback | {"derived": true} |
| 3296.4 | 3296.4 | 8 | enemy_4 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 3296.4 | 4503.4 | 8 | enemy_4 | action | {"kind": "melee", "label": "Strike"} |
| 3298.3 | 4151.7 | 8 | enemy_4 | sampled playback | {"authored_ms": 600.0, "frames": 36} |
| 3301.0 | 3301.0 | 8 | enemy_4 | attack wind-up | {"kind": "melee", "sample": 1} |
| 3301.0 | 3619.2 | 8 | enemy_4 | wind-up to contact | {"derived": true} |
| 3614.7 | 3707.3 | 8 | enemy_4 | hit stop | {"requested_ms": 85.0} |
| 3619.2 | 3619.2 | 8 | enemy_4 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 16, "sample_count": 36, "process_frame": 254} |
| 3619.2 | 3619.2 | 8 | enemy_4 | impact effect start | {"targets": ["player"]} |
| 3619.2 | 4307.4 | 8 | enemy_4 | contact to last number gone | {"derived": true} |
| 3630.5 | 4061.8 | 8 | enemy_4 | camera move | {"kind": "board kick"} |
| 3630.5 | 4307.4 | 8 | enemy_4 | number on screen | {"text": "−7", "category": "damage", "tile": "(3, 6)", "icon": "", "reaction": "hit"} |
| 4152.0 | 4346.1 | 8 | enemy_4 | floating feedback | {"numbers": 1} |
| 4347.2 | 4506.5 | 8 | enemy_4 | turn-order rail | — |
| 4347.7 | 4503.4 | 8 | enemy_4 | post-action settle | — |
| 4503.5 | 4503.5 | 9 | enemy_4 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 4506.2 | 4506.2 | 10 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 4508.3 | 4515.9 | 10 |  | turn-order rail | — |
| 4515.5 | 4515.5 | 11 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 4518.5 | 4710.8 | 11 |  | turn-order rail | — |
| 4522.2 | 4522.2 | 12 | enemy_1 | step dispatched | {"kind": "intent", "label": "Spear Cast"} |
| 4522.3 | 4777.9 | 12 | enemy_1 | pre-action delay | — |
| 4530.3 | 6330.7 | 12 | enemy_1 | caption shown | {"text": "Frostglass Lancer: Spear Cast"} |
| 4530.3 | 4790.5 | 12 | enemy_1 | caption lead before motion or feedback | {"derived": true} |
| 4784.5 | 4784.5 | 13 | enemy_1 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 4784.6 | 6302.5 | 13 | enemy_1 | action | {"kind": "ranged", "label": "Shot"} |
| 4785.1 | 6066.8 | 13 | enemy_1 | sampled playback | {"authored_ms": 950.0, "frames": 57} |
| 4790.5 | 4790.5 | 13 | enemy_1 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 4790.5 | 5445.9 | 13 | enemy_1 | wind-up to contact | {"derived": true} |
| 5442.1 | 5535.3 | 13 | enemy_1 | hit stop | {"requested_ms": 85.0} |
| 5445.9 | 5445.9 | 13 | enemy_1 | contact | {"evidence": "contact effect submitted", "sample": 32, "sample_count": 57, "process_frame": 384} |
| 5445.9 | 5445.9 | 13 | enemy_1 | impact effect start | {"targets": []} |
| 5445.9 | 6144.7 | 13 | enemy_1 | contact to last number gone | {"derived": true} |
| 5454.6 | 5886.2 | 13 | enemy_1 | camera move | {"kind": "board kick"} |
| 5454.6 | 6144.7 | 13 | enemy_1 | number on screen | {"text": "−6", "category": "damage", "tile": "(3, 6)", "icon": "", "reaction": "hit"} |
| 6066.8 | 6136.9 | 13 | enemy_1 | floating feedback | {"numbers": 1} |
| 6139.0 | 6302.5 | 13 | enemy_1 | post-action settle | — |
| 6302.6 | 6302.6 | 14 | enemy_1 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 6304.0 | 6304.0 | 15 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 6304.4 | 6318.4 | 15 |  | turn-order rail | — |
| 6318.1 | 6318.1 | 16 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 6320.7 | 6508.4 | 16 |  | turn-order rail | — |
| 6324.3 | 6324.3 | 17 | enemy_2 | step dispatched | {"kind": "intent", "label": "Bulwark"} |
| 6324.4 | 6584.7 | 17 | enemy_2 | pre-action delay | — |
| 6330.7 | 7386.1 | 17 | enemy_2 | caption shown | {"text": "Stone Warden: Bulwark"} |
| 6330.7 | 6601.0 | 17 | enemy_2 | caption lead before motion or feedback | {"derived": true} |
| 6587.4 | 6587.4 | 18 | enemy_2 | step dispatched | {"kind": "block", "label": "Guard Allies"} |
| 6587.4 | 7354.6 | 18 | enemy_2 | action | {"kind": "block", "label": "Guard Allies"} |
| 6587.8 | 6587.8 | 18 | enemy_2 | resolved block | {"kind": "block", "label": "Guard Allies", "rule": "", "actor": "enemy_2", "target": "(6, 6)"} |
| 6587.8 | 7191.2 | 18 | enemy_2 | floating feedback | {"numbers": 3} |
| 6594.3 | 6594.3 | 18 | enemy_2 | impact effect start | {"targets": ["enemy_1", "enemy_4", "enemy_5"]} |
| 6601.0 | 7196.6 | 18 | enemy_2 | number on screen | {"text": "+8", "category": "status", "tile": "(2, 4)", "icon": "block", "reaction": ""} |
| 6601.0 | 7196.6 | 18 | enemy_2 | number on screen | {"text": "+8", "category": "status", "tile": "(3, 5)", "icon": "block", "reaction": ""} |
| 6601.0 | 7196.6 | 18 | enemy_2 | number on screen | {"text": "+8", "category": "status", "tile": "(1, 6)", "icon": "block", "reaction": ""} |
| 7194.7 | 7354.6 | 18 | enemy_2 | post-action settle | — |
| 7354.7 | 7354.7 | 19 | enemy_2 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 7357.5 | 7357.5 | 20 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 7357.9 | 7368.8 | 20 |  | turn-order rail | — |
| 7368.5 | 7368.5 | 21 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 7371.5 | 7555.7 | 21 |  | turn-order rail | — |
| 7375.2 | 7375.2 | 22 | enemy_5 | step dispatched | {"kind": "intent", "label": "Dust Bolt"} |
| 7375.3 | 7635.1 | 22 | enemy_5 | pre-action delay | — |
| 7386.1 | 9555.9 | 22 | enemy_5 | caption shown | {"text": "Dust Acolyte: Dust Bolt"} |
| 7386.1 | 7644.6 | 22 | enemy_5 | caption lead before motion or feedback | {"derived": true} |
| 7641.0 | 7641.0 | 23 | enemy_5 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 7641.0 | 9515.6 | 23 | enemy_5 | action | {"kind": "ranged", "label": "Shot"} |
| 7642.0 | 9235.0 | 23 | enemy_5 | sampled playback | {"authored_ms": 1200.0, "frames": 72} |
| 7644.6 | 7644.6 | 23 | enemy_5 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 7644.6 | 8635.4 | 23 | enemy_5 | wind-up to contact | {"derived": true} |
| 8631.6 | 8724.8 | 23 | enemy_5 | hit stop | {"requested_ms": 85.0} |
| 8635.4 | 8635.4 | 23 | enemy_5 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 48, "sample_count": 72, "process_frame": 628} |
| 8635.4 | 8635.4 | 23 | enemy_5 | impact effect start | {"targets": ["player"]} |
| 8635.4 | 9324.9 | 23 | enemy_5 | contact to last number gone | {"derived": true} |
| 8645.2 | 9082.9 | 23 | enemy_5 | camera move | {"kind": "board kick"} |
| 8645.2 | 9324.9 | 23 | enemy_5 | number on screen | {"text": "−7", "category": "damage", "tile": "(3, 6)", "icon": "", "reaction": "hit"} |
| 9235.3 | 9348.2 | 23 | enemy_5 | floating feedback | {"numbers": 1} |
| 9349.3 | 9520.1 | 23 | enemy_5 | turn-order rail | — |
| 9353.8 | 9515.6 | 23 | enemy_5 | post-action settle | — |
| 9515.8 | 9515.8 | 24 | enemy_5 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 9519.8 | 9519.8 | 25 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 9521.9 | 9528.5 | 25 |  | turn-order rail | — |
| 9528.2 | 9528.2 | 26 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 9531.3 | 9542.9 | 26 |  | turn-order rail | — |
| 9534.9 | 9534.9 | 27 | enemy_4 | step dispatched | {"kind": "status_damage", "label": "Fire"} |
| 9535.0 | 10298.6 | 27 | enemy_4 | action | {"kind": "status_damage", "label": "Fire"} |
| 9535.4 | 9535.4 | 27 | enemy_4 | status tick | {"kind": "status_damage", "label": "Fire", "rule": "", "actor": "enemy_4", "target": "(3, 5)"} |
| 9544.2 | 10217.4 | 27 | enemy_4 | turn-order rail | — |
| 9544.5 | 10141.7 | 27 | enemy_4 | feedback deadline | — |
| 9555.9 | 10305.1 | 27 | enemy_4 | caption shown | {"text": "Tunnel Crawler: Fire"} |
| 9555.9 | 10147.5 | 27 | enemy_4 | number on screen | {"text": "−3", "category": "damage", "tile": "(3, 5)", "icon": "surface_fire", "reaction": "hit"} |
| 9555.9 | 9994.8 | 27 | enemy_4 | surface effect | {"tile": "(3, 5)", "kind": "surface_damage", "surface": "fire", "trigger": "start"} |
| 9555.9 | 9555.9 | 27 | enemy_4 | caption lead before motion or feedback | {"derived": true} |
| 10141.7 | 10298.6 | 27 | enemy_4 | post-action settle | — |
| 10298.7 | 10298.7 | 28 | enemy_4 | step dispatched | {"kind": "intent", "label": "Skitter Strike"} |
| 10298.8 | 10555.7 | 28 | enemy_4 | pre-action delay | — |
| 10305.1 | 12006.8 | 28 | enemy_4 | caption shown | {"text": "Tunnel Crawler: Skitter Strike"} |
| 10305.1 | 10562.4 | 28 | enemy_4 | caption lead before motion or feedback | {"derived": true} |
| 10558.2 | 10558.2 | 29 | enemy_4 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 10558.2 | 11743.5 | 29 | enemy_4 | action | {"kind": "melee", "label": "Strike"} |
| 10559.7 | 11398.5 | 29 | enemy_4 | sampled playback | {"authored_ms": 600.0, "frames": 36} |
| 10562.4 | 10562.4 | 29 | enemy_4 | attack wind-up | {"kind": "melee", "sample": 1} |
| 10562.4 | 10884.4 | 29 | enemy_4 | wind-up to contact | {"derived": true} |
| 10880.2 | 10969.5 | 29 | enemy_4 | hit stop | {"requested_ms": 85.0} |
| 10884.4 | 10884.4 | 29 | enemy_4 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 16, "sample_count": 36, "process_frame": 785} |
| 10884.4 | 10884.4 | 29 | enemy_4 | impact effect start | {"targets": ["player"]} |
| 10884.4 | 11580.4 | 29 | enemy_4 | contact to last number gone | {"derived": true} |
| 10895.1 | 11325.0 | 29 | enemy_4 | camera move | {"kind": "board kick"} |
| 10895.1 | 11580.4 | 29 | enemy_4 | number on screen | {"text": "−7", "category": "damage", "tile": "(3, 6)", "icon": "", "reaction": "hit"} |
| 11398.9 | 11590.3 | 29 | enemy_4 | floating feedback | {"numbers": 1} |
| 11591.4 | 11746.5 | 29 | enemy_4 | turn-order rail | — |
| 11591.8 | 11743.5 | 29 | enemy_4 | post-action settle | — |
| 11743.6 | 11743.6 | 30 | enemy_4 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 11746.2 | 11746.2 | 31 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 11748.4 | 11750.7 | 31 |  | turn-order rail | — |
| 11750.5 | 11750.5 | 32 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 11753.1 | 11965.2 | 32 |  | turn-order rail | — |
| 11756.8 | 11977.7 | — |  | hero hand-off drain | — |
| 11985.8 | 12439.2 | — |  | hand draw | {"cards": 2} |
| 12439.3 | 12459.1 | — |  | publish hero UI | — |
| 12443.7 | 12443.7 | — |  | hero turn banner requested | — |
| 12481.7 | 12481.7 | — |  | hero input accepted | — |

### 12-s1-seed1-1-7_-3-t3

| Start (ms) | End (ms) | Step | Actor | Beat | Details |
|---:|---:|---:|---|---|---|
| 0.0 | 0.0 | — |  | Pass pressed | — |
| 1.7 | 1.7 | — |  | enemy turn banner requested | — |
| 72.2 | 281.3 | — |  | turn banner shown | {"text": "ENEMY TURN"} |
| 80.4 | 80.4 | — |  | locked hand capture | — |
| 105.1 | 122.1 | — |  | locked hand capture | — |
| 193.5 | 193.6 | — |  | defeat playback | — |
| 194.6 | 199.4 | — |  | turn-order rail | — |
| 195.6 | 195.6 | 0 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 202.0 | 214.8 | 0 |  | turn-order rail | — |
| 205.9 | 205.9 | 1 | enemy_3 | step dispatched | {"kind": "status_damage", "label": "Fire"} |
| 206.0 | 971.6 | 1 | enemy_3 | action | {"kind": "status_damage", "label": "Fire"} |
| 206.3 | 206.3 | 1 | enemy_3 | status tick | {"kind": "status_damage", "label": "Fire", "rule": "", "actor": "enemy_3", "target": "(2, 6)"} |
| 216.3 | 587.5 | 1 | enemy_3 | turn-order rail | — |
| 216.6 | 820.4 | 1 | enemy_3 | feedback deadline | — |
| 281.3 | 991.9 | 1 | enemy_3 | caption shown | {"text": "Tunnel Crawler: Fire"} |
| 281.3 | 810.7 | 1 | enemy_3 | number on screen | {"text": "−3", "category": "damage", "tile": "(2, 6)", "icon": "surface_fire", "reaction": "hit"} |
| 281.3 | 669.0 | 1 | enemy_3 | surface effect | {"tile": "(2, 6)", "kind": "surface_damage", "surface": "fire", "trigger": "start"} |
| 281.3 | 281.3 | 1 | enemy_3 | caption lead before motion or feedback | {"derived": true} |
| 820.4 | 971.5 | 1 | enemy_3 | post-action settle | — |
| 971.7 | 971.7 | 2 | enemy_3 | step dispatched | {"kind": "intent", "label": "Skitter Strike"} |
| 974.3 | 974.3 | 3 | enemy_3 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 974.3 | 2167.4 | 3 | enemy_3 | action | {"kind": "melee", "label": "Strike"} |
| 975.9 | 1821.6 | 3 | enemy_3 | sampled playback | {"authored_ms": 600.0, "frames": 36} |
| 978.4 | 978.4 | 3 | enemy_3 | attack wind-up | {"kind": "melee", "sample": 1} |
| 978.4 | 1295.2 | 3 | enemy_3 | wind-up to contact | {"derived": true} |
| 991.9 | 2211.0 | 3 | enemy_3 | caption shown | {"text": "Tunnel Crawler: Skitter Strike"} |
| 991.9 | 1307.7 | 3 | enemy_3 | caption lead before motion or feedback | {"derived": true} |
| 1291.4 | 1380.4 | 3 | enemy_3 | hit stop | {"requested_ms": 85.0} |
| 1295.2 | 1295.2 | 3 | enemy_3 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 16, "sample_count": 36, "process_frame": 81} |
| 1295.2 | 1295.2 | 3 | enemy_3 | impact effect start | {"targets": ["player"]} |
| 1295.2 | 1992.1 | 3 | enemy_3 | contact to last number gone | {"derived": true} |
| 1307.7 | 1727.1 | 3 | enemy_3 | camera move | {"kind": "board kick"} |
| 1307.7 | 1992.1 | 3 | enemy_3 | number on screen | {"text": "−6", "category": "damage", "tile": "(3, 6)", "icon": "", "reaction": "hit"} |
| 1821.9 | 2015.1 | 3 | enemy_3 | floating feedback | {"numbers": 1} |
| 2016.1 | 2170.2 | 3 | enemy_3 | turn-order rail | — |
| 2016.6 | 2167.4 | 3 | enemy_3 | post-action settle | — |
| 2167.6 | 2167.6 | 4 | enemy_3 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 2170.0 | 2170.0 | 5 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 2171.8 | 2178.1 | 5 |  | turn-order rail | — |
| 2177.9 | 2177.9 | 6 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 2180.4 | 2191.3 | 6 |  | turn-order rail | — |
| 2184.1 | 2184.1 | 7 | enemy_1 | step dispatched | {"kind": "status_damage", "label": "Fire"} |
| 2184.1 | 2949.1 | 7 | enemy_1 | action | {"kind": "status_damage", "label": "Fire"} |
| 2184.4 | 2184.4 | 7 | enemy_1 | status tick | {"kind": "status_damage", "label": "Fire", "rule": "", "actor": "enemy_1", "target": "(3, 7)"} |
| 2192.6 | 2590.8 | 7 | enemy_1 | turn-order rail | — |
| 2192.9 | 2788.7 | 7 | enemy_1 | feedback deadline | — |
| 2211.0 | 2952.6 | 7 | enemy_1 | caption shown | {"text": "Dust Acolyte: Fire"} |
| 2211.0 | 2791.7 | 7 | enemy_1 | number on screen | {"text": "−3", "category": "damage", "tile": "(3, 7)", "icon": "surface_fire", "reaction": "hit"} |
| 2211.0 | 2644.2 | 7 | enemy_1 | surface effect | {"tile": "(3, 7)", "kind": "surface_damage", "surface": "fire", "trigger": "start"} |
| 2211.0 | 2211.0 | 7 | enemy_1 | caption lead before motion or feedback | {"derived": true} |
| 2788.7 | 2949.1 | 7 | enemy_1 | post-action settle | — |
| 2949.2 | 2949.2 | 8 | enemy_1 | step dispatched | {"kind": "intent", "label": "Siphon"} |
| 2949.4 | 3208.2 | 8 | enemy_1 | pre-action delay | — |
| 2952.6 | 5900.8 | 8 | enemy_1 | caption shown | {"text": "Dust Acolyte: Siphon"} |
| 2952.6 | 3213.8 | 8 | enemy_1 | caption lead before motion or feedback | {"derived": true} |
| 3210.5 | 3210.5 | 9 | enemy_1 | step dispatched | {"kind": "ranged", "label": "Shot"} |
| 3210.5 | 5077.2 | 9 | enemy_1 | action | {"kind": "ranged", "label": "Shot"} |
| 3211.5 | 4805.6 | 9 | enemy_1 | sampled playback | {"authored_ms": 1200.0, "frames": 72} |
| 3213.8 | 3213.8 | 9 | enemy_1 | attack wind-up | {"kind": "ranged", "sample": 1} |
| 3213.8 | 4201.6 | 9 | enemy_1 | wind-up to contact | {"derived": true} |
| 4198.0 | 4287.7 | 9 | enemy_1 | hit stop | {"requested_ms": 85.0} |
| 4201.6 | 4201.6 | 9 | enemy_1 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 48, "sample_count": 72, "process_frame": 310} |
| 4201.6 | 4201.6 | 9 | enemy_1 | impact effect start | {"targets": ["player"]} |
| 4201.6 | 4890.7 | 9 | enemy_1 | contact to last number gone | {"derived": true} |
| 4213.9 | 4636.3 | 9 | enemy_1 | camera move | {"kind": "board kick"} |
| 4213.9 | 4890.7 | 9 | enemy_1 | number on screen | {"text": "−5", "category": "damage", "tile": "(3, 6)", "icon": "", "reaction": "hit"} |
| 4805.9 | 4915.2 | 9 | enemy_1 | floating feedback | {"numbers": 1} |
| 4916.2 | 5289.7 | 9 | enemy_1 | turn-order rail | — |
| 4916.5 | 5077.2 | 9 | enemy_1 | post-action settle | — |
| 5077.3 | 5077.3 | 10 | enemy_1 | step dispatched | {"kind": "heal", "label": "Heal"} |
| 5077.4 | 5842.3 | 10 | enemy_1 | action | {"kind": "heal", "label": "Heal"} |
| 5077.7 | 5077.7 | 10 | enemy_1 | resolved heal | {"kind": "heal", "label": "Heal", "rule": "", "actor": "enemy_1", "target": "(3, 7)"} |
| 5077.8 | 5682.2 | 10 | enemy_1 | floating feedback | {"numbers": 1} |
| 5092.6 | 5684.4 | 10 | enemy_1 | number on screen | {"text": "+2", "category": "heal", "tile": "(3, 7)", "icon": "heal", "reaction": ""} |
| 5683.2 | 5845.1 | 10 | enemy_1 | turn-order rail | — |
| 5683.6 | 5842.2 | 10 | enemy_1 | post-action settle | — |
| 5842.4 | 5842.4 | 11 | enemy_1 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 5844.9 | 5844.9 | 12 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 5846.5 | 5857.2 | 12 |  | turn-order rail | — |
| 5857.0 | 5857.0 | 13 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 5859.7 | 6078.2 | 13 |  | turn-order rail | — |
| 5863.0 | 5863.0 | 14 | enemy_4 | step dispatched | {"kind": "intent", "label": "Triage Suture"} |
| 5865.1 | 5865.1 | 15 | enemy_4 | step dispatched | {"kind": "move", "label": "Advance"} |
| 5865.1 | 6100.7 | 15 | enemy_4 | action | {"kind": "move", "label": "Advance"} |
| 5865.2 | 6063.9 | 15 | enemy_4 | unit move | {"actor": "enemy_4", "tiles": 1} |
| 5865.4 | 6063.9 | 15 | enemy_4 | sampled playback | {"authored_ms": 183.333333333333, "frames": 33} |
| 5900.8 | 6143.1 | 15 | enemy_4 | caption shown | {"text": "Grave Surgeon: Triage Suture"} |
| 6100.8 | 6100.8 | 16 | enemy_4 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 6101.8 | 6101.8 | 17 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 6102.1 | 6112.6 | 17 |  | turn-order rail | — |
| 6112.4 | 6112.4 | 18 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 6114.9 | 6124.9 | 18 |  | turn-order rail | — |
| 6118.5 | 6118.5 | 19 | enemy_3 | step dispatched | {"kind": "status_damage", "label": "Fire"} |
| 6118.5 | 6881.1 | 19 | enemy_3 | action | {"kind": "status_damage", "label": "Fire"} |
| 6118.8 | 6118.8 | 19 | enemy_3 | status tick | {"kind": "status_damage", "label": "Fire", "rule": "", "actor": "enemy_3", "target": "(2, 6)"} |
| 6126.1 | 6521.6 | 19 | enemy_3 | turn-order rail | — |
| 6126.4 | 6728.5 | 19 | enemy_3 | feedback deadline | — |
| 6143.1 | 6888.3 | 19 | enemy_3 | caption shown | {"text": "Tunnel Crawler: Fire"} |
| 6143.1 | 6731.5 | 19 | enemy_3 | number on screen | {"text": "−3", "category": "damage", "tile": "(2, 6)", "icon": "surface_fire", "reaction": "hit"} |
| 6143.1 | 6571.8 | 19 | enemy_3 | surface effect | {"tile": "(2, 6)", "kind": "surface_damage", "surface": "fire", "trigger": "start"} |
| 6143.1 | 6143.1 | 19 | enemy_3 | caption lead before motion or feedback | {"derived": true} |
| 6728.5 | 6881.1 | 19 | enemy_3 | post-action settle | — |
| 6881.2 | 6881.2 | 20 | enemy_3 | step dispatched | {"kind": "intent", "label": "Skitter Strike"} |
| 6881.3 | 7141.0 | 20 | enemy_3 | pre-action delay | — |
| 6888.3 | 8585.2 | 20 | enemy_3 | caption shown | {"text": "Tunnel Crawler: Skitter Strike"} |
| 6888.3 | 7147.1 | 20 | enemy_3 | caption lead before motion or feedback | {"derived": true} |
| 7143.5 | 7143.5 | 21 | enemy_3 | step dispatched | {"kind": "melee", "label": "Strike"} |
| 7143.5 | 8345.8 | 21 | enemy_3 | action | {"kind": "melee", "label": "Strike"} |
| 7144.9 | 7988.5 | 21 | enemy_3 | sampled playback | {"authored_ms": 600.0, "frames": 36} |
| 7147.1 | 7147.1 | 21 | enemy_3 | attack wind-up | {"kind": "melee", "sample": 1} |
| 7147.1 | 7468.9 | 21 | enemy_3 | wind-up to contact | {"derived": true} |
| 7465.1 | 7561.9 | 21 | enemy_3 | hit stop | {"requested_ms": 85.0} |
| 7468.9 | 7468.9 | 21 | enemy_3 | contact | {"evidence": "effect progress reached feedback threshold", "sample": 16, "sample_count": 36, "process_frame": 559} |
| 7468.9 | 7468.9 | 21 | enemy_3 | impact effect start | {"targets": ["player"]} |
| 7468.9 | 8162.1 | 21 | enemy_3 | contact to last number gone | {"derived": true} |
| 7480.6 | 7912.2 | 21 | enemy_3 | camera move | {"kind": "board kick"} |
| 7480.6 | 8162.1 | 21 | enemy_3 | number on screen | {"text": "−6", "category": "damage", "tile": "(3, 6)", "icon": "", "reaction": "hit"} |
| 7988.7 | 8184.4 | 21 | enemy_3 | floating feedback | {"numbers": 1} |
| 8185.4 | 8348.2 | 21 | enemy_3 | turn-order rail | — |
| 8185.8 | 8345.8 | 21 | enemy_3 | post-action settle | — |
| 8345.9 | 8345.9 | 22 | enemy_3 | step dispatched | {"kind": "intent_refresh", "label": ""} |
| 8348.1 | 8348.1 | 23 |  | step dispatched | {"kind": "turn_order", "label": "reschedule"} |
| 8349.7 | 8351.8 | 23 |  | turn-order rail | — |
| 8351.6 | 8351.6 | 24 |  | step dispatched | {"kind": "turn_order", "label": "activate"} |
| 8353.8 | 8554.4 | 24 |  | turn-order rail | — |
| 8357.3 | 8564.3 | — |  | hero hand-off drain | — |
| 8570.6 | 9128.2 | — |  | hero turn-start fire | — |
| 8572.9 | 8638.1 | — |  | hit stop | {"requested_ms": 60.0} |
| 8576.4 | 8576.4 | — |  | impact effect start | {"targets": ["player"]} |
| 8585.2 | 8872.7 | — |  | camera move | {"kind": "board kick"} |
| 8585.2 | 9149.8 | — |  | number on screen | {"text": "−3", "category": "damage", "tile": "(3, 6)", "icon": "surface_fire", "reaction": "hit"} |
| 9128.2 | 9594.0 | — |  | hand draw | {"cards": 2} |
| 9594.2 | 9607.1 | — |  | publish hero UI | — |
| 9595.8 | 9595.8 | — |  | hero turn banner requested | — |
| 9619.9 | 9619.9 | — |  | hero input accepted | — |

