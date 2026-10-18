# Exposed hidden material — per-clip CPU maxima

Counts are source/canvas pixels. Each maximum lists its own frame. A dark component is blocking only when it contains a full 3×3 block.

| Creature | Clip/view | Before exposed | After exposed | Before largest dark | After largest dark | Before max slab px | After max slab px |
|---|---|---:|---:|---:|---:|---:|---:|
| shale_bloomer | front_idle | 1320 @ 0084 | 1283 @ 0084 | 81 @ 0138 | 34 @ 0138 | 123 @ 0132 | 0 @ 0000 |
| shale_bloomer | front_move | 1200 @ 0009 | 1167 @ 0009 | 49 @ 0009 | 12 @ 0007 | 128 @ 0010 | 0 @ 0000 |
| shale_bloomer | front_burst | 1678 @ 0025 | 1658 @ 0025 | 162 @ 0030 | 18 @ 0046 | 305 @ 0021 | 0 @ 0000 |
| shale_bloomer | front_shot | 974 @ 0012 | 960 @ 0012 | 43 @ 0018 | 29 @ 0043 | 69 @ 0018 | 0 @ 0000 |
| shale_bloomer | front_shell | 2111 @ 0043 | 1975 @ 0043 | 354 @ 0017 | 50 @ 0017 | 480 @ 0017 | 0 @ 0000 |
| shale_bloomer | front_hit | 2001 @ 0007 | 1935 @ 0007 | 75 @ 0009 | 36 @ 0009 | 296 @ 0007 | 0 @ 0000 |
| shale_bloomer | front_death | 3012 @ 0074 | 2797 @ 0074 | 406 @ 0068 | 51 @ 0022 | 667 @ 0068 | 0 @ 0000 |
| shale_bloomer | rear_idle | 1518 @ 0066 | 1430 @ 0066 | 119 @ 0066 | 19 @ 0042 | 332 @ 0066 | 0 @ 0000 |
| shale_bloomer | rear_move | 1078 @ 0016 | 794 @ 0016 | 221 @ 0018 | 10 @ 0005 | 399 @ 0013 | 0 @ 0000 |
| shale_bloomer | rear_burst | 1016 @ 0025 | 990 @ 0025 | 113 @ 0019 | 13 @ 0035 | 152 @ 0026 | 0 @ 0000 |
| shale_bloomer | rear_shot | 708 @ 0019 | 685 @ 0019 | 77 @ 0012 | 12 @ 0006 | 77 @ 0012 | 0 @ 0000 |
| shale_bloomer | rear_shell | 2032 @ 0044 | 1626 @ 0044 | 362 @ 0015 | 21 @ 0016 | 752 @ 0043 | 0 @ 0000 |
| shale_bloomer | rear_hit | 2364 @ 0005 | 2199 @ 0005 | 269 @ 0008 | 21 @ 0005 | 575 @ 0008 | 0 @ 0000 |
| shale_bloomer | rear_death | 3149 @ 0044 | 2571 @ 0069 | 611 @ 0045 | 41 @ 0050 | 1099 @ 0041 | 0 @ 0000 |
| lightning_wisp | front_idle | 97 @ 0060 | 97 @ 0060 | 12 @ 0060 | 2 @ 0000 | 0 @ 0000 | 0 @ 0000 |
| lightning_wisp | front_move | 166 @ 0013 | 166 @ 0013 | 18 @ 0010 | 7 @ 0013 | 18 @ 0010 | 0 @ 0000 |
| lightning_wisp | front_strike | 203 @ 0016 | 203 @ 0016 | 19 @ 0011 | 8 @ 0019 | 19 @ 0011 | 0 @ 0000 |
| lightning_wisp | front_cast | 169 @ 0017 | 169 @ 0017 | 21 @ 0018 | 8 @ 0017 | 21 @ 0018 | 0 @ 0000 |
| lightning_wisp | front_hit | 135 @ 0007 | 135 @ 0007 | 20 @ 0007 | 5 @ 0007 | 18 @ 0005 | 0 @ 0000 |
| lightning_wisp | front_death | 371 @ 0067 | 371 @ 0067 | 43 @ 0046 | 12 @ 0040 | 90 @ 0065 | 0 @ 0000 |
| lightning_wisp | rear_idle | 83 @ 0108 | 83 @ 0108 | 19 @ 0108 | 12 @ 0108 | 0 @ 0000 | 0 @ 0000 |
| lightning_wisp | rear_move | 243 @ 0017 | 243 @ 0017 | 33 @ 0008 | 29 @ 0012 | 0 @ 0000 | 0 @ 0000 |
| lightning_wisp | rear_strike | 277 @ 0019 | 277 @ 0019 | 34 @ 0024 | 31 @ 0019 | 34 @ 0024 | 28 @ 0014 |
| lightning_wisp | rear_cast | 206 @ 0023 | 206 @ 0023 | 36 @ 0016 | 31 @ 0020 | 35 @ 0018 | 31 @ 0020 |
| lightning_wisp | rear_hit | 168 @ 0006 | 168 @ 0006 | 86 @ 0006 | 75 @ 0006 | 86 @ 0006 | 75 @ 0006 |
| lightning_wisp | rear_death | 342 @ 0066 | 342 @ 0066 | 123 @ 0036 | 111 @ 0036 | 123 @ 0036 | 111 @ 0036 |
