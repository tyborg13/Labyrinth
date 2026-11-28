# Screen-flow census

All times are wall milliseconds from the action listed in the replay transcript. Headless first response and total use presentation state. Native uses full-frame pixels. An em dash means no endpoint was observed. See [result.md](result.md) for the method and commands.

Native renderer results are pending the design owner’s run.

Headless transitions below two samples: `map.shop` (1), `shop.buy` (1), `shop.leave` (1), `section.change` (0).

## 1. Title and Continue

| Action | Transition | Mode | First | Ready | Total | >33 ms | >50 ms | Flags |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| descent/65 | title.continue | headless | 16.9 | 1822.4 | 2155.1 | 5 | 1 | 2 |
| descent/72 | title.continue | headless | 15.9 | 1443.0 | 1774.8 | 2 | 2 | 2 |
| — | title.continue | native pending | — | — | — | — | — | — |

## 2. Map door

| Action | Transition | Mode | First | Ready | Total | >33 ms | >50 ms | Flags |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| descent/7 | map.prebattle | headless | 115.8 | 6315.5 | 6313.3 | 45 | 42 | 44 |
| descent/73 | map.prebattle | headless | 23.3 | 2181.7 | 2181.4 | 2 | 1 | 2 |
| descent/120 | map.prebattle | headless | 56.6 | 3151.3 | 3138.8 | 24 | 20 | 21 |
| descent/228 | map.prebattle | headless | 32.6 | 2194.4 | 2194.0 | 2 | 2 | 3 |
| defeats/6 | map.prebattle | headless | 18.8 | 2240.4 | 2239.8 | 12 | 11 | 12 |
| defeats/18 | map.prebattle | headless | 21.1 | 3849.1 | 3848.5 | 27 | 24 | 25 |
| — | map.prebattle | native pending | — | — | — | — | — | — |

## 3. Opening combat

| Action | Transition | Mode | First | Ready | Total | >33 ms | >50 ms | Flags |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| descent/8 | prebattle.combat | headless | 1392.1 | 5772.4 | 5765.9 | 24 | 22 | 24 |
| descent/74 | prebattle.combat | headless | 122.0 | 2745.3 | 2743.2 | 2 | 1 | 3 |
| descent/121 | prebattle.combat | headless | 931.4 | 6106.1 | 6098.7 | 31 | 20 | 22 |
| descent/229 | prebattle.combat | headless | 155.4 | 4583.3 | 4580.9 | 2 | 1 | 3 |
| defeats/7 | prebattle.combat | headless | 214.6 | 4510.1 | 4402.7 | 25 | 21 | 23 |
| defeats/19 | prebattle.combat | headless | 197.5 | 3670.3 | 3668.2 | 22 | 20 | 22 |
| — | prebattle.combat | native pending | — | — | — | — | — | — |

## 4. Last kill and rewards

| Action | Transition | Mode | First | Ready | Total | >33 ms | >50 ms | Flags |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| descent/60 | kill.reward | headless | 33.8 | 3718.7 | 3713.6 | 2 | 1 | 2 |
| descent/113 | kill.reward | headless | 153.5 | 5825.6 | 5814.1 | 47 | 26 | 28 |
| — | kill.reward | native pending | — | — | — | — | — | — |

## 5. Reward pick

| Action | Transition | Mode | First | Ready | Total | >33 ms | >50 ms | Flags |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| descent/61 | reward.map | headless | 57.2 | 57.6 | 307.5 | 1 | 1 | 1 |
| descent/114 | reward.map | headless | 231.3 | 234.3 | 296.4 | 2 | 1 | 2 |
| — | reward.map | native pending | — | — | — | — | — | — |

## 6. Events

| Action | Transition | Mode | First | Ready | Total | >33 ms | >50 ms | Flags |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| descent/66 | map.event | headless | 17.1 | 2169.5 | 2166.1 | 1 | 1 | 2 |
| descent/219 | map.event | headless | 24.0 | 2194.2 | 2193.7 | 2 | 1 | 2 |
| — | map.event | native pending | — | — | — | — | — | — |
| descent/67 | event.result | headless | 51.7 | 51.9 | 1231.6 | 1 | 1 | 1 |
| descent/220 | event.result | headless | 43.5 | 43.7 | 1464.4 | 1 | 0 | 0 |
| — | event.result | native pending | — | — | — | — | — | — |
| descent/68 | event.map | headless | 28.2 | 194.5 | 516.6 | 0 | 0 | 0 |
| descent/221 | event.map | headless | 38.9 | 205.9 | 495.7 | 3 | 0 | 0 |
| — | event.map | native pending | — | — | — | — | — | — |

## 7. Scavenger

| Action | Transition | Mode | First | Ready | Total | >33 ms | >50 ms | Flags |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| descent/222 | map.shop | headless | 36.3 | 2056.6 | 2463.9 | 3 | 2 | 3 |
| — | map.shop | native pending | — | — | — | — | — | — |
| descent/224 | shop.buy | headless | 104.4 | 104.7 | 964.8 | 1 | 1 | 2 |
| — | shop.buy | native pending | — | — | — | — | — | — |
| descent/225 | shop.leave | headless | 36.2 | 36.8 | 323.9 | 1 | 0 | 0 |
| — | shop.leave | native pending | — | — | — | — | — | — |

## 8. Menus

| Action | Transition | Mode | First | Ready | Total | >33 ms | >50 ms | Flags |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| descent/10 | character.open | headless | 2256.1 | 2256.9 | 2364.8 | 2 | 2 | 4 |
| descent/29 | character.open | headless | 46.8 | 47.3 | 158.5 | 1 | 0 | 0 |
| — | character.open | native pending | — | — | — | — | — | — |
| descent/11 | character.magic | headless | 355.7 | 356.5 | 447.3 | 2 | 2 | 3 |
| descent/30 | character.magic | headless | 17.6 | 18.1 | 131.8 | 0 | 0 | 0 |
| — | character.magic | native pending | — | — | — | — | — | — |
| descent/12 | character.skills | headless | 335.1 | 335.9 | 374.3 | 2 | 1 | 2 |
| descent/31 | character.skills | headless | 33.3 | 33.7 | 133.6 | 1 | 0 | 0 |
| — | character.skills | native pending | — | — | — | — | — | — |
| descent/13 | character.gear | headless | 238.6 | 239.1 | 298.8 | 2 | 2 | 3 |
| descent/32 | character.gear | headless | 57.9 | 58.5 | 135.9 | 1 | 1 | 1 |
| — | character.gear | native pending | — | — | — | — | — | — |
| descent/14 | character.close | headless | 22.9 | 32.7 | 22.9 | 0 | 0 | 0 |
| descent/33 | character.close | headless | 16.4 | 19.1 | 16.4 | 0 | 0 | 0 |
| — | character.close | native pending | — | — | — | — | — | — |
| descent/15 | grimoire.open | headless | 160.5 | 162.3 | 160.5 | 1 | 1 | 2 |
| descent/34 | grimoire.open | headless | 42.3 | 42.6 | 42.3 | 1 | 0 | 0 |
| — | grimoire.open | native pending | — | — | — | — | — | — |
| descent/16 | grimoire.close | headless | 15.6 | 16.7 | 15.6 | 0 | 0 | 0 |
| descent/35 | grimoire.close | headless | 10.6 | 11.6 | 10.6 | 0 | 0 | 0 |
| — | grimoire.close | native pending | — | — | — | — | — | — |
| descent/17 | large_map.open | headless | 24.1 | 24.4 | 24.1 | 0 | 0 | 0 |
| descent/36 | large_map.open | headless | 19.7 | 23.2 | 19.7 | 0 | 0 | 0 |
| — | large_map.open | native pending | — | — | — | — | — | — |
| descent/18 | large_map.close | headless | 15.6 | 17.0 | 15.6 | 0 | 0 | 0 |
| descent/37 | large_map.close | headless | 16.5 | 17.7 | 16.5 | 0 | 0 | 0 |
| — | large_map.close | native pending | — | — | — | — | — | — |
| descent/19 | pause.open | headless | 14.0 | 14.3 | 14.0 | 0 | 0 | 0 |
| descent/38 | pause.open | headless | 15.9 | 16.3 | 15.9 | 0 | 0 | 0 |
| — | pause.open | native pending | — | — | — | — | — | — |
| descent/20 | pause.close | headless | 19.9 | 21.1 | 19.9 | 0 | 0 | 0 |
| descent/39 | pause.close | headless | 18.9 | 20.4 | 18.9 | 0 | 0 | 0 |
| — | pause.close | native pending | — | — | — | — | — | — |

## 9. Section change

| Action | Transition | Mode | First | Ready | Total | >33 ms | >50 ms | Flags |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| — | section.change | never observed | — | — | — | — | — | — |

## 10. Defeat and return

| Action | Transition | Mode | First | Ready | Total | >33 ms | >50 ms | Flags |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| descent/316 | defeat.recap | headless | 30.2 | 3758.9 | 3794.9 | 4 | 1 | 2 |
| defeats/11 | defeat.recap | headless | 205.3 | 6010.9 | 6014.6 | 29 | 28 | 30 |
| defeats/22 | defeat.recap | headless | 31.1 | 10260.8 | 10265.4 | 49 | 42 | 43 |
| — | defeat.recap | native pending | — | — | — | — | — | — |
| descent/317 | recap.title | headless | 131.7 | 264.9 | 264.8 | 1 | 1 | 2 |
| defeats/12 | recap.title | headless | 63.8 | 127.5 | 127.0 | 2 | 2 | 2 |
| defeats/23 | recap.title | headless | 302.0 | 401.4 | 401.0 | 3 | 3 | 4 |
| — | recap.title | native pending | — | — | — | — | — | — |

## Every flag

| Mode | Action | Transition | At (ms) | Flag | Duration (ms) |
|---|---:|---|---:|---|---:|
| headless | descent/7 | map.prebattle | 115.824 | first response | 115.824 |
| headless | descent/7 | map.prebattle | 115.824 | frame over 50 ms | 115.824 |
| headless | descent/7 | map.prebattle | 332.409 | frame over 50 ms | 113.067 |
| headless | descent/7 | map.prebattle | 592.614 | frame over 50 ms | 208.674 |
| headless | descent/7 | map.prebattle | 807.242 | frame over 50 ms | 194.104 |
| headless | descent/7 | map.prebattle | 1101.474 | frame over 50 ms | 294.232 |
| headless | descent/7 | map.prebattle | 1220.241 | frame over 50 ms | 118.767 |
| headless | descent/7 | map.prebattle | 1363.401 | frame over 50 ms | 143.160 |
| headless | descent/7 | map.prebattle | 1460.321 | frame over 50 ms | 96.920 |
| headless | descent/7 | map.prebattle | 1564.615 | frame over 50 ms | 104.294 |
| headless | descent/7 | map.prebattle | 1691.276 | frame over 50 ms | 126.661 |
| headless | descent/7 | map.prebattle | 2054.204 | frame over 50 ms | 236.373 |
| headless | descent/7 | map.prebattle | 2136.434 | frame over 50 ms | 82.230 |
| headless | descent/7 | map.prebattle | 2439.173 | frame over 50 ms | 270.693 |
| headless | descent/7 | map.prebattle | 2498.373 | frame over 50 ms | 59.200 |
| headless | descent/7 | map.prebattle | 2598.192 | frame over 50 ms | 99.819 |
| headless | descent/7 | map.prebattle | 2709.117 | frame over 50 ms | 110.925 |
| headless | descent/7 | map.prebattle | 2768.468 | frame over 50 ms | 59.351 |
| headless | descent/7 | map.prebattle | 2960.844 | frame over 50 ms | 183.447 |
| headless | descent/7 | map.prebattle | 3206.730 | frame over 50 ms | 240.713 |
| headless | descent/7 | map.prebattle | 3312.178 | frame over 50 ms | 105.448 |
| headless | descent/7 | map.prebattle | 3394.666 | frame over 50 ms | 82.488 |
| headless | descent/7 | map.prebattle | 3494.678 | frame over 50 ms | 100.012 |
| headless | descent/7 | map.prebattle | 3598.093 | frame over 50 ms | 103.415 |
| headless | descent/7 | map.prebattle | 3694.205 | frame over 50 ms | 96.112 |
| headless | descent/7 | map.prebattle | 3795.694 | frame over 50 ms | 101.489 |
| headless | descent/7 | map.prebattle | 3887.825 | frame over 50 ms | 92.131 |
| headless | descent/7 | map.prebattle | 3992.984 | frame over 50 ms | 105.159 |
| headless | descent/7 | map.prebattle | 4097.300 | frame over 50 ms | 104.316 |
| headless | descent/7 | map.prebattle | 4193.322 | frame over 50 ms | 96.022 |
| headless | descent/7 | map.prebattle | 4285.278 | frame over 50 ms | 91.956 |
| headless | descent/7 | map.prebattle | 4377.185 | frame over 50 ms | 91.907 |
| headless | descent/7 | map.prebattle | 4468.529 | frame over 50 ms | 91.344 |
| headless | descent/7 | map.prebattle | 4648.832 | frame over 50 ms | 122.531 |
| headless | descent/7 | map.prebattle | 4743.938 | frame over 50 ms | 71.148 |
| headless | descent/7 | map.prebattle | 4799.082 | frame over 50 ms | 55.144 |
| headless | descent/7 | map.prebattle | 5034.960 | frame over 50 ms | 212.274 |
| headless | descent/7 | map.prebattle | 5129.662 | frame over 50 ms | 94.702 |
| headless | descent/7 | map.prebattle | 5226.418 | frame over 50 ms | 96.756 |
| headless | descent/7 | map.prebattle | 6039.679 | frame over 50 ms | 813.261 |
| headless | descent/7 | map.prebattle | 6188.356 | frame over 50 ms | 148.677 |
| headless | descent/7 | map.prebattle | 6246.467 | frame over 50 ms | 58.111 |
| headless | descent/7 | map.prebattle | 6313.338 | frame over 50 ms | 66.871 |
| headless | descent/7 | map.prebattle | 6315.488 | input ready | 6315.488 |
| headless | descent/8 | prebattle.combat | 1392.142 | first response | 1392.142 |
| headless | descent/8 | prebattle.combat | 1392.142 | frame over 50 ms | 1392.142 |
| headless | descent/8 | prebattle.combat | 1468.231 | frame over 50 ms | 76.089 |
| headless | descent/8 | prebattle.combat | 1557.259 | frame over 50 ms | 89.028 |
| headless | descent/8 | prebattle.combat | 1633.722 | frame over 50 ms | 76.463 |
| headless | descent/8 | prebattle.combat | 1754.979 | frame over 50 ms | 55.125 |
| headless | descent/8 | prebattle.combat | 2214.405 | frame over 50 ms | 382.806 |
| headless | descent/8 | prebattle.combat | 2294.290 | frame over 50 ms | 79.885 |
| headless | descent/8 | prebattle.combat | 2541.118 | frame over 50 ms | 186.710 |
| headless | descent/8 | prebattle.combat | 2809.027 | frame over 50 ms | 215.989 |
| headless | descent/8 | prebattle.combat | 3033.097 | frame over 50 ms | 194.889 |
| headless | descent/8 | prebattle.combat | 3263.602 | frame over 50 ms | 179.435 |
| headless | descent/8 | prebattle.combat | 3368.749 | frame over 50 ms | 94.243 |
| headless | descent/8 | prebattle.combat | 3474.283 | frame over 50 ms | 73.370 |
| headless | descent/8 | prebattle.combat | 3691.790 | frame over 50 ms | 214.021 |
| headless | descent/8 | prebattle.combat | 3886.103 | frame over 50 ms | 169.851 |
| headless | descent/8 | prebattle.combat | 4221.035 | frame over 50 ms | 334.932 |
| headless | descent/8 | prebattle.combat | 4491.621 | frame over 50 ms | 200.187 |
| headless | descent/8 | prebattle.combat | 4680.740 | frame over 50 ms | 136.667 |
| headless | descent/8 | prebattle.combat | 4902.739 | frame over 50 ms | 181.410 |
| headless | descent/8 | prebattle.combat | 4968.957 | frame over 50 ms | 66.218 |
| headless | descent/8 | prebattle.combat | 5292.920 | frame over 50 ms | 192.070 |
| headless | descent/8 | prebattle.combat | 5765.857 | frame over 50 ms | 472.937 |
| headless | descent/8 | prebattle.combat | 5772.366 | input ready | 5772.366 |
| headless | descent/10 | character.open | 2256.126 | first response | 2256.126 |
| headless | descent/10 | character.open | 2256.126 | frame over 50 ms | 2256.126 |
| headless | descent/10 | character.open | 2256.857 | input ready | 2256.857 |
| headless | descent/10 | character.open | 2364.825 | frame over 50 ms | 108.699 |
| headless | descent/11 | character.magic | 355.661 | first response | 355.661 |
| headless | descent/11 | character.magic | 355.661 | frame over 50 ms | 355.661 |
| headless | descent/11 | character.magic | 447.305 | frame over 50 ms | 91.644 |
| headless | descent/12 | character.skills | 335.124 | first response | 335.124 |
| headless | descent/12 | character.skills | 335.124 | frame over 50 ms | 335.124 |
| headless | descent/13 | character.gear | 238.555 | first response | 238.555 |
| headless | descent/13 | character.gear | 238.555 | frame over 50 ms | 238.555 |
| headless | descent/13 | character.gear | 298.802 | frame over 50 ms | 60.247 |
| headless | descent/15 | grimoire.open | 160.465 | first response | 160.465 |
| headless | descent/15 | grimoire.open | 160.465 | frame over 50 ms | 160.465 |
| headless | descent/32 | character.gear | 57.942 | frame over 50 ms | 57.942 |
| headless | descent/60 | kill.reward | 2850.287 | frame over 50 ms | 64.490 |
| headless | descent/60 | kill.reward | 3718.651 | input ready | 3718.651 |
| headless | descent/61 | reward.map | 57.220 | frame over 50 ms | 57.220 |
| headless | descent/65 | title.continue | 669.227 | frame over 50 ms | 278.616 |
| headless | descent/65 | title.continue | 1822.375 | input ready | 1822.375 |
| headless | descent/66 | map.event | 2064.832 | frame over 50 ms | 117.876 |
| headless | descent/66 | map.event | 2169.458 | input ready | 2169.458 |
| headless | descent/67 | event.result | 51.715 | frame over 50 ms | 51.715 |
| headless | descent/72 | title.continue | 514.664 | frame over 50 ms | 253.181 |
| headless | descent/72 | title.continue | 585.109 | frame over 50 ms | 53.711 |
| headless | descent/73 | map.prebattle | 2046.763 | frame over 50 ms | 96.494 |
| headless | descent/73 | map.prebattle | 2181.725 | input ready | 2181.725 |
| headless | descent/74 | prebattle.combat | 122.033 | first response | 122.033 |
| headless | descent/74 | prebattle.combat | 122.033 | frame over 50 ms | 122.033 |
| headless | descent/74 | prebattle.combat | 2745.278 | input ready | 2745.278 |
| headless | descent/113 | kill.reward | 153.520 | first response | 153.520 |
| headless | descent/113 | kill.reward | 153.520 | frame over 50 ms | 153.520 |
| headless | descent/113 | kill.reward | 389.648 | frame over 50 ms | 208.294 |
| headless | descent/113 | kill.reward | 660.795 | frame over 50 ms | 215.802 |
| headless | descent/113 | kill.reward | 749.855 | frame over 50 ms | 89.060 |
| headless | descent/113 | kill.reward | 840.279 | frame over 50 ms | 90.424 |
| headless | descent/113 | kill.reward | 1034.988 | frame over 50 ms | 159.850 |
| headless | descent/113 | kill.reward | 1311.855 | frame over 50 ms | 62.290 |
| headless | descent/113 | kill.reward | 1391.248 | frame over 50 ms | 79.393 |
| headless | descent/113 | kill.reward | 1461.810 | frame over 50 ms | 70.562 |
| headless | descent/113 | kill.reward | 1535.962 | frame over 50 ms | 74.152 |
| headless | descent/113 | kill.reward | 1852.405 | frame over 50 ms | 177.990 |
| headless | descent/113 | kill.reward | 2248.496 | frame over 50 ms | 50.195 |
| headless | descent/113 | kill.reward | 2299.010 | frame over 50 ms | 50.514 |
| headless | descent/113 | kill.reward | 2593.693 | frame over 50 ms | 214.467 |
| headless | descent/113 | kill.reward | 2831.006 | frame over 50 ms | 210.504 |
| headless | descent/113 | kill.reward | 3151.373 | frame over 50 ms | 218.886 |
| headless | descent/113 | kill.reward | 3385.823 | frame over 50 ms | 60.534 |
| headless | descent/113 | kill.reward | 3776.771 | frame over 50 ms | 99.217 |
| headless | descent/113 | kill.reward | 3995.016 | frame over 50 ms | 211.626 |
| headless | descent/113 | kill.reward | 4127.268 | frame over 50 ms | 97.953 |
| headless | descent/113 | kill.reward | 4334.353 | frame over 50 ms | 200.209 |
| headless | descent/113 | kill.reward | 4562.278 | frame over 50 ms | 211.822 |
| headless | descent/113 | kill.reward | 4894.181 | frame over 50 ms | 331.903 |
| headless | descent/113 | kill.reward | 5143.152 | frame over 50 ms | 180.965 |
| headless | descent/113 | kill.reward | 5388.123 | frame over 50 ms | 209.932 |
| headless | descent/113 | kill.reward | 5770.934 | frame over 50 ms | 199.236 |
| headless | descent/113 | kill.reward | 5825.643 | input ready | 5825.643 |
| headless | descent/114 | reward.map | 231.272 | first response | 231.272 |
| headless | descent/114 | reward.map | 231.272 | frame over 50 ms | 231.272 |
| headless | descent/120 | map.prebattle | 56.592 | frame over 50 ms | 56.592 |
| headless | descent/120 | map.prebattle | 316.561 | frame over 50 ms | 213.110 |
| headless | descent/120 | map.prebattle | 468.857 | frame over 50 ms | 143.720 |
| headless | descent/120 | map.prebattle | 691.813 | frame over 50 ms | 196.705 |
| headless | descent/120 | map.prebattle | 860.551 | frame over 50 ms | 149.879 |
| headless | descent/120 | map.prebattle | 993.088 | frame over 50 ms | 132.537 |
| headless | descent/120 | map.prebattle | 1260.836 | frame over 50 ms | 249.406 |
| headless | descent/120 | map.prebattle | 1349.233 | frame over 50 ms | 88.397 |
| headless | descent/120 | map.prebattle | 1742.844 | frame over 50 ms | 212.583 |
| headless | descent/120 | map.prebattle | 1871.594 | frame over 50 ms | 50.236 |
| headless | descent/120 | map.prebattle | 1951.484 | frame over 50 ms | 59.493 |
| headless | descent/120 | map.prebattle | 2066.387 | frame over 50 ms | 51.306 |
| headless | descent/120 | map.prebattle | 2170.404 | frame over 50 ms | 54.223 |
| headless | descent/120 | map.prebattle | 2261.145 | frame over 50 ms | 90.741 |
| headless | descent/120 | map.prebattle | 2316.689 | frame over 50 ms | 55.544 |
| headless | descent/120 | map.prebattle | 2377.514 | frame over 50 ms | 60.825 |
| headless | descent/120 | map.prebattle | 2700.436 | frame over 50 ms | 322.922 |
| headless | descent/120 | map.prebattle | 2921.491 | frame over 50 ms | 221.055 |
| headless | descent/120 | map.prebattle | 2996.885 | frame over 50 ms | 75.394 |
| headless | descent/120 | map.prebattle | 3138.850 | frame over 50 ms | 141.965 |
| headless | descent/120 | map.prebattle | 3151.286 | input ready | 3151.286 |
| headless | descent/121 | prebattle.combat | 931.369 | first response | 931.369 |
| headless | descent/121 | prebattle.combat | 931.369 | frame over 50 ms | 931.369 |
| headless | descent/121 | prebattle.combat | 1137.088 | frame over 50 ms | 123.950 |
| headless | descent/121 | prebattle.combat | 1559.955 | frame over 50 ms | 422.867 |
| headless | descent/121 | prebattle.combat | 3233.631 | frame over 50 ms | 194.696 |
| headless | descent/121 | prebattle.combat | 3465.031 | frame over 50 ms | 212.752 |
| headless | descent/121 | prebattle.combat | 3672.353 | frame over 50 ms | 200.083 |
| headless | descent/121 | prebattle.combat | 3825.273 | frame over 50 ms | 141.599 |
| headless | descent/121 | prebattle.combat | 4028.831 | frame over 50 ms | 195.964 |
| headless | descent/121 | prebattle.combat | 4237.835 | frame over 50 ms | 203.387 |
| headless | descent/121 | prebattle.combat | 4334.756 | frame over 50 ms | 86.143 |
| headless | descent/121 | prebattle.combat | 4568.826 | frame over 50 ms | 208.618 |
| headless | descent/121 | prebattle.combat | 4782.807 | frame over 50 ms | 206.524 |
| headless | descent/121 | prebattle.combat | 4859.271 | frame over 50 ms | 76.464 |
| headless | descent/121 | prebattle.combat | 5027.203 | frame over 50 ms | 146.843 |
| headless | descent/121 | prebattle.combat | 5244.348 | frame over 50 ms | 196.110 |
| headless | descent/121 | prebattle.combat | 5418.493 | frame over 50 ms | 137.070 |
| headless | descent/121 | prebattle.combat | 5559.326 | frame over 50 ms | 133.096 |
| headless | descent/121 | prebattle.combat | 5787.661 | frame over 50 ms | 209.997 |
| headless | descent/121 | prebattle.combat | 6013.311 | frame over 50 ms | 182.787 |
| headless | descent/121 | prebattle.combat | 6098.653 | frame over 50 ms | 85.342 |
| headless | descent/121 | prebattle.combat | 6106.129 | input ready | 6106.129 |
| headless | descent/219 | map.event | 2070.400 | frame over 50 ms | 113.073 |
| headless | descent/219 | map.event | 2194.194 | input ready | 2194.194 |
| headless | descent/222 | map.shop | 670.607 | frame over 50 ms | 53.432 |
| headless | descent/222 | map.shop | 2055.996 | frame over 50 ms | 99.096 |
| headless | descent/222 | map.shop | 2056.604 | input ready | 2056.604 |
| headless | descent/224 | shop.buy | 104.409 | first response | 104.409 |
| headless | descent/224 | shop.buy | 104.409 | frame over 50 ms | 104.409 |
| headless | descent/228 | map.prebattle | 678.678 | frame over 50 ms | 57.670 |
| headless | descent/228 | map.prebattle | 2080.581 | frame over 50 ms | 108.394 |
| headless | descent/228 | map.prebattle | 2194.407 | input ready | 2194.407 |
| headless | descent/229 | prebattle.combat | 155.414 | first response | 155.414 |
| headless | descent/229 | prebattle.combat | 155.414 | frame over 50 ms | 155.414 |
| headless | descent/229 | prebattle.combat | 4583.316 | input ready | 4583.316 |
| headless | descent/316 | defeat.recap | 3757.829 | frame over 50 ms | 108.058 |
| headless | descent/316 | defeat.recap | 3758.948 | input ready | 3758.948 |
| headless | descent/317 | recap.title | 131.746 | first response | 131.746 |
| headless | descent/317 | recap.title | 264.774 | frame over 50 ms | 133.028 |
| headless | defeats/6 | map.prebattle | 213.699 | frame over 50 ms | 192.409 |
| headless | defeats/6 | map.prebattle | 419.874 | frame over 50 ms | 202.372 |
| headless | defeats/6 | map.prebattle | 633.643 | frame over 50 ms | 209.903 |
| headless | defeats/6 | map.prebattle | 693.112 | frame over 50 ms | 59.469 |
| headless | defeats/6 | map.prebattle | 1004.739 | frame over 50 ms | 209.407 |
| headless | defeats/6 | map.prebattle | 1098.843 | frame over 50 ms | 86.811 |
| headless | defeats/6 | map.prebattle | 1317.055 | frame over 50 ms | 213.147 |
| headless | defeats/6 | map.prebattle | 1618.697 | frame over 50 ms | 197.328 |
| headless | defeats/6 | map.prebattle | 1791.486 | frame over 50 ms | 156.776 |
| headless | defeats/6 | map.prebattle | 1990.465 | frame over 50 ms | 192.668 |
| headless | defeats/6 | map.prebattle | 2139.914 | frame over 50 ms | 149.449 |
| headless | defeats/6 | map.prebattle | 2240.391 | input ready | 2240.391 |
| headless | defeats/7 | prebattle.combat | 214.604 | first response | 214.604 |
| headless | defeats/7 | prebattle.combat | 214.604 | frame over 50 ms | 214.604 |
| headless | defeats/7 | prebattle.combat | 458.926 | frame over 50 ms | 214.814 |
| headless | defeats/7 | prebattle.combat | 542.163 | frame over 50 ms | 63.101 |
| headless | defeats/7 | prebattle.combat | 762.389 | frame over 50 ms | 209.545 |
| headless | defeats/7 | prebattle.combat | 981.363 | frame over 50 ms | 214.191 |
| headless | defeats/7 | prebattle.combat | 1174.906 | frame over 50 ms | 193.543 |
| headless | defeats/7 | prebattle.combat | 1375.364 | frame over 50 ms | 156.329 |
| headless | defeats/7 | prebattle.combat | 1575.394 | frame over 50 ms | 193.262 |
| headless | defeats/7 | prebattle.combat | 1789.238 | frame over 50 ms | 210.374 |
| headless | defeats/7 | prebattle.combat | 1988.857 | frame over 50 ms | 195.746 |
| headless | defeats/7 | prebattle.combat | 2202.552 | frame over 50 ms | 209.181 |
| headless | defeats/7 | prebattle.combat | 2373.030 | frame over 50 ms | 161.759 |
| headless | defeats/7 | prebattle.combat | 2597.375 | frame over 50 ms | 218.299 |
| headless | defeats/7 | prebattle.combat | 2859.402 | frame over 50 ms | 222.948 |
| headless | defeats/7 | prebattle.combat | 2993.634 | frame over 50 ms | 134.232 |
| headless | defeats/7 | prebattle.combat | 3181.857 | frame over 50 ms | 146.993 |
| headless | defeats/7 | prebattle.combat | 3423.399 | frame over 50 ms | 206.213 |
| headless | defeats/7 | prebattle.combat | 3611.403 | frame over 50 ms | 179.534 |
| headless | defeats/7 | prebattle.combat | 3887.369 | frame over 50 ms | 192.447 |
| headless | defeats/7 | prebattle.combat | 4071.308 | frame over 50 ms | 177.471 |
| headless | defeats/7 | prebattle.combat | 4402.747 | frame over 50 ms | 331.439 |
| headless | defeats/7 | prebattle.combat | 4510.057 | input ready | 4510.057 |
| headless | defeats/11 | defeat.recap | 205.280 | first response | 205.280 |
| headless | defeats/11 | defeat.recap | 205.280 | frame over 50 ms | 205.280 |
| headless | defeats/11 | defeat.recap | 360.651 | frame over 50 ms | 137.884 |
| headless | defeats/11 | defeat.recap | 619.686 | frame over 50 ms | 211.010 |
| headless | defeats/11 | defeat.recap | 852.841 | frame over 50 ms | 183.324 |
| headless | defeats/11 | defeat.recap | 1068.195 | frame over 50 ms | 200.920 |
| headless | defeats/11 | defeat.recap | 1275.114 | frame over 50 ms | 196.297 |
| headless | defeats/11 | defeat.recap | 1495.576 | frame over 50 ms | 206.948 |
| headless | defeats/11 | defeat.recap | 1709.650 | frame over 50 ms | 197.359 |
| headless | defeats/11 | defeat.recap | 1927.046 | frame over 50 ms | 200.550 |
| headless | defeats/11 | defeat.recap | 2173.317 | frame over 50 ms | 230.933 |
| headless | defeats/11 | defeat.recap | 2338.471 | frame over 50 ms | 157.245 |
| headless | defeats/11 | defeat.recap | 2549.002 | frame over 50 ms | 204.685 |
| headless | defeats/11 | defeat.recap | 2778.136 | frame over 50 ms | 215.686 |
| headless | defeats/11 | defeat.recap | 2980.607 | frame over 50 ms | 197.041 |
| headless | defeats/11 | defeat.recap | 3218.747 | frame over 50 ms | 215.354 |
| headless | defeats/11 | defeat.recap | 3448.716 | frame over 50 ms | 187.987 |
| headless | defeats/11 | defeat.recap | 3645.731 | frame over 50 ms | 179.204 |
| headless | defeats/11 | defeat.recap | 3866.617 | frame over 50 ms | 204.129 |
| headless | defeats/11 | defeat.recap | 4116.037 | frame over 50 ms | 225.802 |
| headless | defeats/11 | defeat.recap | 4346.215 | frame over 50 ms | 213.455 |
| headless | defeats/11 | defeat.recap | 4461.077 | frame over 50 ms | 92.802 |
| headless | defeats/11 | defeat.recap | 4684.677 | frame over 50 ms | 206.520 |
| headless | defeats/11 | defeat.recap | 4907.512 | frame over 50 ms | 200.246 |
| headless | defeats/11 | defeat.recap | 5101.352 | frame over 50 ms | 183.979 |
| headless | defeats/11 | defeat.recap | 5329.585 | frame over 50 ms | 219.125 |
| headless | defeats/11 | defeat.recap | 5561.913 | frame over 50 ms | 213.769 |
| headless | defeats/11 | defeat.recap | 5918.083 | frame over 50 ms | 344.847 |
| headless | defeats/11 | defeat.recap | 6010.097 | frame over 50 ms | 92.014 |
| headless | defeats/11 | defeat.recap | 6010.905 | input ready | 6010.905 |
| headless | defeats/12 | recap.title | 63.769 | frame over 50 ms | 63.769 |
| headless | defeats/12 | recap.title | 127.043 | frame over 50 ms | 63.274 |
| headless | defeats/18 | map.prebattle | 232.483 | frame over 50 ms | 208.647 |
| headless | defeats/18 | map.prebattle | 421.914 | frame over 50 ms | 184.933 |
| headless | defeats/18 | map.prebattle | 629.169 | frame over 50 ms | 203.499 |
| headless | defeats/18 | map.prebattle | 845.089 | frame over 50 ms | 212.192 |
| headless | defeats/18 | map.prebattle | 964.450 | frame over 50 ms | 119.361 |
| headless | defeats/18 | map.prebattle | 1042.910 | frame over 50 ms | 61.089 |
| headless | defeats/18 | map.prebattle | 1266.849 | frame over 50 ms | 216.142 |
| headless | defeats/18 | map.prebattle | 1535.018 | frame over 50 ms | 220.631 |
| headless | defeats/18 | map.prebattle | 1803.651 | frame over 50 ms | 249.343 |
| headless | defeats/18 | map.prebattle | 2068.835 | frame over 50 ms | 229.449 |
| headless | defeats/18 | map.prebattle | 2127.956 | frame over 50 ms | 59.121 |
| headless | defeats/18 | map.prebattle | 2232.445 | frame over 50 ms | 58.645 |
| headless | defeats/18 | map.prebattle | 2332.731 | frame over 50 ms | 100.286 |
| headless | defeats/18 | map.prebattle | 2388.259 | frame over 50 ms | 55.528 |
| headless | defeats/18 | map.prebattle | 2476.100 | frame over 50 ms | 87.841 |
| headless | defeats/18 | map.prebattle | 2597.423 | frame over 50 ms | 121.323 |
| headless | defeats/18 | map.prebattle | 2686.271 | frame over 50 ms | 88.848 |
| headless | defeats/18 | map.prebattle | 2752.365 | frame over 50 ms | 66.094 |
| headless | defeats/18 | map.prebattle | 2813.102 | frame over 50 ms | 60.737 |
| headless | defeats/18 | map.prebattle | 2863.898 | frame over 50 ms | 50.796 |
| headless | defeats/18 | map.prebattle | 2929.593 | frame over 50 ms | 65.695 |
| headless | defeats/18 | map.prebattle | 2996.090 | frame over 50 ms | 66.497 |
| headless | defeats/18 | map.prebattle | 3688.760 | frame over 50 ms | 560.247 |
| headless | defeats/18 | map.prebattle | 3760.988 | frame over 50 ms | 72.228 |
| headless | defeats/18 | map.prebattle | 3849.131 | input ready | 3849.131 |
| headless | defeats/19 | prebattle.combat | 197.523 | first response | 197.523 |
| headless | defeats/19 | prebattle.combat | 197.523 | frame over 50 ms | 197.523 |
| headless | defeats/19 | prebattle.combat | 582.832 | frame over 50 ms | 197.936 |
| headless | defeats/19 | prebattle.combat | 685.317 | frame over 50 ms | 94.483 |
| headless | defeats/19 | prebattle.combat | 895.893 | frame over 50 ms | 205.608 |
| headless | defeats/19 | prebattle.combat | 1069.799 | frame over 50 ms | 167.595 |
| headless | defeats/19 | prebattle.combat | 1236.041 | frame over 50 ms | 157.698 |
| headless | defeats/19 | prebattle.combat | 1445.894 | frame over 50 ms | 201.783 |
| headless | defeats/19 | prebattle.combat | 1662.614 | frame over 50 ms | 208.816 |
| headless | defeats/19 | prebattle.combat | 1865.167 | frame over 50 ms | 192.969 |
| headless | defeats/19 | prebattle.combat | 2080.038 | frame over 50 ms | 209.846 |
| headless | defeats/19 | prebattle.combat | 2272.087 | frame over 50 ms | 182.002 |
| headless | defeats/19 | prebattle.combat | 2379.100 | frame over 50 ms | 60.323 |
| headless | defeats/19 | prebattle.combat | 2548.972 | frame over 50 ms | 161.649 |
| headless | defeats/19 | prebattle.combat | 2640.057 | frame over 50 ms | 79.777 |
| headless | defeats/19 | prebattle.combat | 2809.923 | frame over 50 ms | 159.210 |
| headless | defeats/19 | prebattle.combat | 3032.380 | frame over 50 ms | 205.058 |
| headless | defeats/19 | prebattle.combat | 3196.983 | frame over 50 ms | 153.440 |
| headless | defeats/19 | prebattle.combat | 3404.848 | frame over 50 ms | 197.275 |
| headless | defeats/19 | prebattle.combat | 3613.974 | frame over 50 ms | 198.720 |
| headless | defeats/19 | prebattle.combat | 3668.212 | frame over 50 ms | 54.238 |
| headless | defeats/19 | prebattle.combat | 3670.335 | input ready | 3670.335 |
| headless | defeats/22 | defeat.recap | 329.517 | frame over 50 ms | 195.104 |
| headless | defeats/22 | defeat.recap | 532.970 | frame over 50 ms | 193.673 |
| headless | defeats/22 | defeat.recap | 594.695 | frame over 50 ms | 61.725 |
| headless | defeats/22 | defeat.recap | 932.901 | frame over 50 ms | 104.350 |
| headless | defeats/22 | defeat.recap | 1136.966 | frame over 50 ms | 182.965 |
| headless | defeats/22 | defeat.recap | 1388.751 | frame over 50 ms | 219.803 |
| headless | defeats/22 | defeat.recap | 1665.130 | frame over 50 ms | 259.791 |
| headless | defeats/22 | defeat.recap | 1880.794 | frame over 50 ms | 175.654 |
| headless | defeats/22 | defeat.recap | 2107.279 | frame over 50 ms | 221.928 |
| headless | defeats/22 | defeat.recap | 2331.728 | frame over 50 ms | 213.627 |
| headless | defeats/22 | defeat.recap | 2614.702 | frame over 50 ms | 247.911 |
| headless | defeats/22 | defeat.recap | 2677.146 | frame over 50 ms | 62.444 |
| headless | defeats/22 | defeat.recap | 3310.338 | frame over 50 ms | 211.347 |
| headless | defeats/22 | defeat.recap | 3610.687 | frame over 50 ms | 236.708 |
| headless | defeats/22 | defeat.recap | 4397.898 | frame over 50 ms | 211.414 |
| headless | defeats/22 | defeat.recap | 4483.886 | frame over 50 ms | 60.352 |
| headless | defeats/22 | defeat.recap | 4597.525 | frame over 50 ms | 104.705 |
| headless | defeats/22 | defeat.recap | 4658.930 | frame over 50 ms | 51.858 |
| headless | defeats/22 | defeat.recap | 4867.588 | frame over 50 ms | 173.071 |
| headless | defeats/22 | defeat.recap | 5102.869 | frame over 50 ms | 214.860 |
| headless | defeats/22 | defeat.recap | 5375.485 | frame over 50 ms | 204.746 |
| headless | defeats/22 | defeat.recap | 5617.597 | frame over 50 ms | 207.750 |
| headless | defeats/22 | defeat.recap | 5851.549 | frame over 50 ms | 198.003 |
| headless | defeats/22 | defeat.recap | 6158.014 | frame over 50 ms | 239.655 |
| headless | defeats/22 | defeat.recap | 6393.320 | frame over 50 ms | 206.988 |
| headless | defeats/22 | defeat.recap | 6607.921 | frame over 50 ms | 207.652 |
| headless | defeats/22 | defeat.recap | 6836.673 | frame over 50 ms | 206.448 |
| headless | defeats/22 | defeat.recap | 6961.902 | frame over 50 ms | 109.571 |
| headless | defeats/22 | defeat.recap | 7189.241 | frame over 50 ms | 212.141 |
| headless | defeats/22 | defeat.recap | 7419.153 | frame over 50 ms | 218.219 |
| headless | defeats/22 | defeat.recap | 7647.629 | frame over 50 ms | 201.655 |
| headless | defeats/22 | defeat.recap | 7914.269 | frame over 50 ms | 87.242 |
| headless | defeats/22 | defeat.recap | 8160.269 | frame over 50 ms | 209.198 |
| headless | defeats/22 | defeat.recap | 8351.487 | frame over 50 ms | 151.449 |
| headless | defeats/22 | defeat.recap | 8513.898 | frame over 50 ms | 151.898 |
| headless | defeats/22 | defeat.recap | 8779.865 | frame over 50 ms | 198.497 |
| headless | defeats/22 | defeat.recap | 8909.258 | frame over 50 ms | 105.143 |
| headless | defeats/22 | defeat.recap | 9176.447 | frame over 50 ms | 224.907 |
| headless | defeats/22 | defeat.recap | 9401.624 | frame over 50 ms | 206.686 |
| headless | defeats/22 | defeat.recap | 9634.786 | frame over 50 ms | 194.851 |
| headless | defeats/22 | defeat.recap | 10171.803 | frame over 50 ms | 491.283 |
| headless | defeats/22 | defeat.recap | 10260.179 | frame over 50 ms | 88.376 |
| headless | defeats/22 | defeat.recap | 10260.826 | input ready | 10260.826 |
| headless | defeats/23 | recap.title | 80.573 | frame over 50 ms | 80.573 |
| headless | defeats/23 | recap.title | 270.818 | frame over 50 ms | 182.787 |
| headless | defeats/23 | recap.title | 302.043 | first response | 302.043 |
| headless | defeats/23 | recap.title | 401.049 | frame over 50 ms | 99.006 |

## Five slowest headless beats

| Action | Transition | Beat | Start (ms) | Duration (ms) | Code |
|---:|---|---|---:|---:|---|
| descent/7 | map.prebattle | Board door open | 1101.5 | 4938.2 | `scripts/run_scene.gd:27928` |
| descent/121 | prebattle.combat | Objective intro | 1013.1 | 3846.1 | `scripts/run_scene.gd:11700` |
| descent/229 | prebattle.combat | Objective intro | 186.5 | 3426.4 | `scripts/run_scene.gd:11700` |
| defeats/18 | map.prebattle | Board door open | 964.5 | 2724.3 | `scripts/run_scene.gd:27928` |
| defeats/11 | defeat.recap | Death playback | 2980.6 | 2581.3 | `scripts/run_scene.gd:23115` |

## Beat breakdown

| Mode | Action | Beat | Start (ms) | End (ms) | Code |
|---|---:|---|---:|---:|---|
| headless | descent/7 | Dispatch and synchronous UI work | 0.0 | 6.0 | `scripts/section_map_panel.gd:548` |
| headless | descent/7 | Map acknowledgement and lantern walk | 115.8 | 1101.5 | `scripts/section_map_panel.gd:548` |
| headless | descent/7 | Board door open | 1101.5 | 6039.7 | `scripts/run_scene.gd:27928` |
| headless | descent/7 | Pre-battle fade and scale | 6188.4 | 6313.3 | `scripts/run_scene.gd:5617` |
| headless | descent/8 | Dispatch and synchronous UI work | 0.0 | 866.4 | `scripts/run_scene.gd:27759` |
| headless | descent/8 | Opening layout wait | 1392.1 | 1831.6 | `scripts/run_scene.gd:27842` |
| headless | descent/8 | Objective intro | 1831.6 | 4221.0 | `scripts/run_scene.gd:11700` |
| headless | descent/8 | Opening hand deal | 4221.0 | 5765.9 | `scripts/run_scene.gd:27834` |
| headless | descent/10 | Dispatch and synchronous UI work | 0.0 | 1921.1 | `scripts/run_scene.gd:29961` |
| headless | descent/10 | Character arrival | 2256.1 | 2364.8 | `scripts/run_scene.gd:29992` |
| headless | descent/11 | Dispatch and synchronous UI work | 0.0 | 239.3 | `scripts/run_scene.gd:29961` |
| headless | descent/11 | Character arrival | 355.7 | 447.3 | `scripts/run_scene.gd:29992` |
| headless | descent/12 | Dispatch and synchronous UI work | 0.0 | 152.2 | `scripts/run_scene.gd:29961` |
| headless | descent/12 | Character arrival | 335.1 | 374.3 | `scripts/run_scene.gd:29992` |
| headless | descent/13 | Dispatch and synchronous UI work | 0.0 | 143.8 | `scripts/run_scene.gd:29961` |
| headless | descent/13 | Character arrival | 238.6 | 298.8 | `scripts/run_scene.gd:29992` |
| headless | descent/14 | Dispatch and synchronous UI work | 0.0 | 5.5 | `scripts/run_scene.gd:21521` |
| headless | descent/15 | Dispatch and synchronous UI work | 0.0 | 60.0 | `scripts/run_scene.gd:29079` |
| headless | descent/16 | Dispatch and synchronous UI work | 0.0 | 6.8 | `scripts/run_scene.gd:29100` |
| headless | descent/17 | Dispatch and synchronous UI work | 0.0 | 12.7 | `scripts/run_scene.gd:21677` |
| headless | descent/18 | Dispatch and synchronous UI work | 0.0 | 0.9 | `scripts/run_scene.gd:21709` |
| headless | descent/19 | Dispatch and synchronous UI work | 0.0 | 6.9 | `scripts/run_scene.gd:28991` |
| headless | descent/20 | Dispatch and synchronous UI work | 0.0 | 0.4 | `scripts/run_scene.gd:29013` |
| headless | descent/29 | Dispatch and synchronous UI work | 0.0 | 25.6 | `scripts/run_scene.gd:29961` |
| headless | descent/29 | Character arrival | 46.8 | 158.5 | `scripts/run_scene.gd:29992` |
| headless | descent/30 | Dispatch and synchronous UI work | 0.0 | 7.1 | `scripts/run_scene.gd:29961` |
| headless | descent/30 | Character arrival | 17.6 | 131.8 | `scripts/run_scene.gd:29992` |
| headless | descent/31 | Dispatch and synchronous UI work | 0.0 | 23.3 | `scripts/run_scene.gd:29961` |
| headless | descent/31 | Character arrival | 33.3 | 133.6 | `scripts/run_scene.gd:29992` |
| headless | descent/32 | Dispatch and synchronous UI work | 0.0 | 32.6 | `scripts/run_scene.gd:29961` |
| headless | descent/32 | Character arrival | 57.9 | 135.9 | `scripts/run_scene.gd:29992` |
| headless | descent/33 | Dispatch and synchronous UI work | 0.0 | 1.0 | `scripts/run_scene.gd:21521` |
| headless | descent/34 | Dispatch and synchronous UI work | 0.0 | 33.2 | `scripts/run_scene.gd:29079` |
| headless | descent/35 | Dispatch and synchronous UI work | 0.0 | 6.9 | `scripts/run_scene.gd:29100` |
| headless | descent/36 | Dispatch and synchronous UI work | 0.0 | 12.4 | `scripts/run_scene.gd:21677` |
| headless | descent/37 | Dispatch and synchronous UI work | 0.0 | 1.1 | `scripts/run_scene.gd:21709` |
| headless | descent/38 | Dispatch and synchronous UI work | 0.0 | 5.2 | `scripts/run_scene.gd:28991` |
| headless | descent/39 | Dispatch and synchronous UI work | 0.0 | 0.6 | `scripts/run_scene.gd:29013` |
| headless | descent/60 | Dispatch and synchronous UI work | 0.0 | 29.1 | `scripts/run_scene.gd:21100` |
| headless | descent/60 | Death playback | 461.0 | 1839.7 | `scripts/run_scene.gd:23115` |
| headless | descent/60 | Victory banner and hold | 1935.0 | 2850.3 | `scripts/post_combat_reward_sequence.gd:12` |
| headless | descent/60 | Reward reveal | 2850.3 | 3713.6 | `scripts/post_combat_reward_sequence.gd:19` |
| headless | descent/61 | Dispatch and synchronous UI work | 0.0 | 23.9 | `scripts/run_scene.gd:28007` |
| headless | descent/61 | Map fade in | 57.2 | 307.5 | `scripts/large_map_backdrop.gd:12` |
| headless | descent/65 | Dispatch and synchronous UI work | 0.0 | 8.1 | `scripts/main_menu.gd:1185` |
| headless | descent/65 | Threaded load | 16.9 | 48.5 | `scripts/menu_run_transition.gd:147` |
| headless | descent/65 | Build and warm destination | 48.5 | 1600.7 | `scripts/menu_run_transition.gd:203` |
| headless | descent/65 | Loading cover fade out | 1600.7 | 1821.5 | `scripts/menu_run_transition.gd:291` |
| headless | descent/65 | Map fade in | 1821.5 | 2155.1 | `scripts/large_map_backdrop.gd:12` |
| headless | descent/66 | Dispatch and synchronous UI work | 0.0 | 2.1 | `scripts/section_map_panel.gd:548` |
| headless | descent/66 | Map acknowledgement and lantern walk | 17.1 | 637.3 | `scripts/section_map_panel.gd:548` |
| headless | descent/66 | Board door open | 637.3 | 2064.8 | `scripts/run_scene.gd:27928` |
| headless | descent/66 | Event entry | 2064.8 | 2166.1 | `scripts/event_view.gd:545` |
| headless | descent/67 | Dispatch and synchronous UI work | 0.0 | 39.7 | `scripts/run_scene.gd:35202` |
| headless | descent/67 | Event entry | 51.7 | 231.8 | `scripts/event_view.gd:545` |
| headless | descent/67 | Event outcome feedback | 51.7 | 1231.6 | `scripts/event_view.gd:620` |
| headless | descent/68 | Dispatch and synchronous UI work | 0.0 | 15.4 | `scripts/run_scene.gd:35202` |
| headless | descent/68 | Event entry | 28.2 | 194.2 | `scripts/event_view.gd:545` |
| headless | descent/68 | Event dismissal | 28.2 | 194.2 | `scripts/event_view.gd:653` |
| headless | descent/68 | Map fade in | 194.2 | 516.6 | `scripts/large_map_backdrop.gd:12` |
| headless | descent/72 | Dispatch and synchronous UI work | 0.0 | 10.7 | `scripts/main_menu.gd:1185` |
| headless | descent/72 | Threaded load | 15.9 | 44.5 | `scripts/menu_run_transition.gd:147` |
| headless | descent/72 | Build and warm destination | 44.5 | 1211.9 | `scripts/menu_run_transition.gd:203` |
| headless | descent/72 | Loading cover fade out | 1211.9 | 1442.2 | `scripts/menu_run_transition.gd:291` |
| headless | descent/72 | Map fade in | 1442.2 | 1774.8 | `scripts/large_map_backdrop.gd:12` |
| headless | descent/73 | Dispatch and synchronous UI work | 0.0 | 1.1 | `scripts/section_map_panel.gd:548` |
| headless | descent/73 | Map acknowledgement and lantern walk | 23.3 | 652.7 | `scripts/section_map_panel.gd:548` |
| headless | descent/73 | Board door open | 652.7 | 2046.8 | `scripts/run_scene.gd:27928` |
| headless | descent/73 | Pre-battle fade and scale | 2046.8 | 2181.4 | `scripts/run_scene.gd:5617` |
| headless | descent/74 | Dispatch and synchronous UI work | 0.0 | 85.1 | `scripts/run_scene.gd:27759` |
| headless | descent/74 | Opening layout wait | 122.0 | 290.8 | `scripts/run_scene.gd:27842` |
| headless | descent/74 | Objective intro | 290.8 | 1760.3 | `scripts/run_scene.gd:11700` |
| headless | descent/74 | Opening hand deal | 1760.3 | 2743.2 | `scripts/run_scene.gd:27834` |
| headless | descent/113 | Dispatch and synchronous UI work | 0.0 | 126.6 | `scripts/run_scene.gd:21100` |
| headless | descent/113 | Death playback | 840.3 | 2299.0 | `scripts/run_scene.gd:23115` |
| headless | descent/113 | Victory banner and hold | 3452.3 | 4894.2 | `scripts/post_combat_reward_sequence.gd:12` |
| headless | descent/113 | Reward reveal | 4894.2 | 5814.1 | `scripts/post_combat_reward_sequence.gd:19` |
| headless | descent/114 | Dispatch and synchronous UI work | 0.0 | 62.6 | `scripts/run_scene.gd:28007` |
| headless | descent/114 | Map fade in | 231.3 | 296.4 | `scripts/large_map_backdrop.gd:12` |
| headless | descent/120 | Map fade in | 0.0 | 325.1 | `scripts/large_map_backdrop.gd:12` |
| headless | descent/120 | Dispatch and synchronous UI work | 0.0 | 8.5 | `scripts/section_map_panel.gd:548` |
| headless | descent/120 | Map acknowledgement and lantern walk | 56.6 | 993.1 | `scripts/section_map_panel.gd:548` |
| headless | descent/120 | Board door open | 993.1 | 2700.4 | `scripts/run_scene.gd:27928` |
| headless | descent/120 | Pre-battle fade and scale | 2921.5 | 3138.8 | `scripts/run_scene.gd:5617` |
| headless | descent/121 | Dispatch and synchronous UI work | 0.0 | 729.3 | `scripts/run_scene.gd:27759` |
| headless | descent/121 | Opening layout wait | 931.4 | 1013.1 | `scripts/run_scene.gd:27842` |
| headless | descent/121 | Objective intro | 1013.1 | 4859.3 | `scripts/run_scene.gd:11700` |
| headless | descent/121 | Opening hand deal | 4859.3 | 6098.7 | `scripts/run_scene.gd:27834` |
| headless | descent/219 | Map fade in | 0.0 | 164.1 | `scripts/large_map_backdrop.gd:12` |
| headless | descent/219 | Dispatch and synchronous UI work | 0.0 | 0.9 | `scripts/section_map_panel.gd:548` |
| headless | descent/219 | Map acknowledgement and lantern walk | 24.0 | 652.1 | `scripts/section_map_panel.gd:548` |
| headless | descent/219 | Board door open | 652.1 | 2070.4 | `scripts/run_scene.gd:27928` |
| headless | descent/219 | Event entry | 2070.4 | 2193.7 | `scripts/event_view.gd:545` |
| headless | descent/220 | Dispatch and synchronous UI work | 0.0 | 38.1 | `scripts/run_scene.gd:35202` |
| headless | descent/220 | Event entry | 43.5 | 233.0 | `scripts/event_view.gd:545` |
| headless | descent/220 | Event outcome feedback | 43.5 | 1464.4 | `scripts/event_view.gd:620` |
| headless | descent/221 | Dispatch and synchronous UI work | 0.0 | 24.3 | `scripts/run_scene.gd:35202` |
| headless | descent/221 | Event entry | 38.9 | 205.4 | `scripts/event_view.gd:545` |
| headless | descent/221 | Event dismissal | 38.9 | 205.4 | `scripts/event_view.gd:653` |
| headless | descent/221 | Map fade in | 205.4 | 495.7 | `scripts/large_map_backdrop.gd:12` |
| headless | descent/222 | Dispatch and synchronous UI work | 0.0 | 1.4 | `scripts/section_map_panel.gd:548` |
| headless | descent/222 | Map acknowledgement and lantern walk | 36.3 | 670.6 | `scripts/section_map_panel.gd:548` |
| headless | descent/222 | Board door open | 670.6 | 2056.0 | `scripts/run_scene.gd:27928` |
| headless | descent/222 | Scavenger entry | 2056.0 | 2463.9 | `scripts/scavenger_shop_view.gd:1524` |
| headless | descent/224 | Dispatch and synchronous UI work | 0.0 | 76.5 | `scripts/run_scene.gd:28399` |
| headless | descent/224 | Scavenger trade feedback | 104.4 | 964.8 | `scripts/scavenger_shop_view.gd:356` |
| headless | descent/225 | Dispatch and synchronous UI work | 0.0 | 14.0 | `scripts/run_scene.gd:15852` |
| headless | descent/225 | Map fade in | 36.2 | 323.9 | `scripts/large_map_backdrop.gd:12` |
| headless | descent/228 | Map fade in | 0.0 | 99.0 | `scripts/large_map_backdrop.gd:12` |
| headless | descent/228 | Dispatch and synchronous UI work | 0.0 | 0.8 | `scripts/section_map_panel.gd:548` |
| headless | descent/228 | Map acknowledgement and lantern walk | 32.6 | 678.7 | `scripts/section_map_panel.gd:548` |
| headless | descent/228 | Board door open | 678.7 | 2080.6 | `scripts/run_scene.gd:27928` |
| headless | descent/228 | Pre-battle fade and scale | 2080.6 | 2194.0 | `scripts/run_scene.gd:5617` |
| headless | descent/229 | Dispatch and synchronous UI work | 0.0 | 104.9 | `scripts/run_scene.gd:27759` |
| headless | descent/229 | Opening layout wait | 155.4 | 186.5 | `scripts/run_scene.gd:27842` |
| headless | descent/229 | Objective intro | 186.5 | 3612.9 | `scripts/run_scene.gd:11700` |
| headless | descent/229 | Opening hand deal | 3612.9 | 4580.9 | `scripts/run_scene.gd:27834` |
| headless | descent/316 | Dispatch and synchronous UI work | 0.0 | 2.3 | `scripts/run_scene.gd:14923` |
| headless | descent/316 | Death playback | 1364.1 | 3472.9 | `scripts/run_scene.gd:23115` |
| headless | descent/316 | Recap shroud, rows and score | 3757.8 | 3794.9 | `scripts/run_end_recap_overlay.gd:847` |
| headless | descent/317 | Dispatch and synchronous UI work | 0.0 | 8.8 | `scripts/cursor_feedback.gd:148` |
| headless | defeats/6 | Dispatch and synchronous UI work | 0.0 | 2.2 | `scripts/section_map_panel.gd:548` |
| headless | defeats/6 | Map acknowledgement and lantern walk | 18.8 | 693.1 | `scripts/section_map_panel.gd:548` |
| headless | defeats/6 | Board door open | 693.1 | 2139.9 | `scripts/run_scene.gd:27928` |
| headless | defeats/6 | Pre-battle fade and scale | 2139.9 | 2239.8 | `scripts/run_scene.gd:5617` |
| headless | defeats/7 | Dispatch and synchronous UI work | 0.0 | 106.9 | `scripts/run_scene.gd:27759` |
| headless | defeats/7 | Opening layout wait | 214.6 | 981.4 | `scripts/run_scene.gd:27842` |
| headless | defeats/7 | Objective intro | 981.4 | 2993.6 | `scripts/run_scene.gd:11700` |
| headless | defeats/7 | Opening hand deal | 2993.6 | 4402.7 | `scripts/run_scene.gd:27834` |
| headless | defeats/11 | Dispatch and synchronous UI work | 0.0 | 2.8 | `scripts/run_scene.gd:14923` |
| headless | defeats/11 | Death playback | 2980.6 | 5561.9 | `scripts/run_scene.gd:23115` |
| headless | defeats/11 | Recap shroud, rows and score | 5918.1 | 6014.6 | `scripts/run_end_recap_overlay.gd:847` |
| headless | defeats/12 | Dispatch and synchronous UI work | 0.0 | 37.8 | `scripts/cursor_feedback.gd:148` |
| headless | defeats/18 | Dispatch and synchronous UI work | 0.0 | 2.2 | `scripts/section_map_panel.gd:548` |
| headless | defeats/18 | Map acknowledgement and lantern walk | 21.1 | 964.5 | `scripts/section_map_panel.gd:548` |
| headless | defeats/18 | Board door open | 964.5 | 3688.8 | `scripts/run_scene.gd:27928` |
| headless | defeats/18 | Pre-battle fade and scale | 3761.0 | 3848.5 | `scripts/run_scene.gd:5617` |
| headless | defeats/19 | Dispatch and synchronous UI work | 0.0 | 124.6 | `scripts/run_scene.gd:27759` |
| headless | defeats/19 | Opening layout wait | 197.5 | 590.8 | `scripts/run_scene.gd:27842` |
| headless | defeats/19 | Objective intro | 590.8 | 2379.1 | `scripts/run_scene.gd:11700` |
| headless | defeats/19 | Opening hand deal | 2379.1 | 3668.2 | `scripts/run_scene.gd:27834` |
| headless | defeats/22 | Dispatch and synchronous UI work | 0.0 | 2.1 | `scripts/run_scene.gd:14923` |
| headless | defeats/22 | Death playback | 7419.2 | 9662.2 | `scripts/run_scene.gd:23115` |
| headless | defeats/22 | Recap shroud, rows and score | 10171.8 | 10265.4 | `scripts/run_end_recap_overlay.gd:847` |
| headless | defeats/23 | Dispatch and synchronous UI work | 0.0 | 76.6 | `scripts/cursor_feedback.gd:148` |
