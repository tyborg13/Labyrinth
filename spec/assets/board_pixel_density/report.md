# Board pixel-density report

Native calibration uses each facing's untouched rest or the first prop frame.
Before/after are means over the first frame of each registered paint path.
After derives from sources in memory; native rest/visual proof is separate.
Screen-pixel ratios are relative to the hero on each axis: r_axis/scale_axis = 1.0;
integer frame-size rounding can differ slightly from that ideal ratio.

| Entry / facing | r (x) | t | grid | mode | Pixel ratio x old → new | Pixel ratio y old → new | Native orphan / run | Before orphan / run | After orphan / run | Screen run x before → after |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Hero front (untouched reference) | 1 | — | — | reference | 1.000 → 1.000 | 1.000 → 1.000 | 7.30% / 2.321 | 7.30% / 2.321 | 7.30% / 2.321 | 2.321 → 2.321 |
| warden / front | 1.180000 | 1.5000 | 1.27 | regrid | 1.180 → 1.180 | 1.180 → 1.180 | 17.25% / 1.613 | 23.83% / 1.507 | 8.03% / 1.999 | 1.779 → 2.359 |
| warden / rear | 1.180000 | 1.5000 | 1.27 | regrid | 1.180 → 1.180 | 1.180 → 1.180 | 18.06% / 1.716 | 22.38% / 1.604 | 5.50% / 2.152 | 1.893 → 2.539 |
| crawler / front | 0.640000 | 1.1068 | 1.73 | regrid | 0.640 → 0.640 | 0.640 → 0.640 | 7.14% / 2.110 | 10.93% / 2.264 | 7.59% / 2.779 | 1.449 → 1.778 |
| crawler / rear | 0.640000 | 1.1102 | 1.73 | regrid | 0.640 → 0.640 | 0.640 → 0.640 | 7.20% / 2.084 | 8.55% / 2.192 | 2.98% / 2.898 | 1.403 → 1.855 |
| acolyte / front | 1.000000 | 1.0005 | 1.00 | clean | 1.000 → 1.000 | 1.000 → 1.000 | 5.01% / 2.359 | 11.10% / 2.271 | 7.01% / 2.378 | 2.271 → 2.378 |
| acolyte / rear | 1.000000 | 1.0000 | 1.00 | clean | 1.000 → 1.000 | 1.000 → 1.000 | 2.54% / 2.542 | 5.61% / 2.496 | 3.46% / 2.567 | 2.496 → 2.567 |
| bile_bloomer / front | 0.860000 | 1.5000 | 1.74 | regrid | 0.860 → 0.860 | 0.860 → 0.860 | 35.69% / 1.334 | 38.15% / 1.293 | 6.20% / 2.304 | 1.112 → 1.981 |
| bile_bloomer / rear | 0.860000 | 1.5000 | 1.74 | regrid | 0.860 → 0.860 | 0.860 → 0.860 | 32.35% / 1.354 | 35.01% / 1.335 | 8.05% / 2.361 | 1.148 → 2.030 |
| chainbound_gaoler / front | 0.900000 | 1.1086 | 1.23 | regrid | 0.900 → 0.900 | 0.900 → 0.900 | 7.17% / 2.271 | 9.25% / 2.236 | 3.61% / 2.671 | 2.012 → 2.404 |
| chainbound_gaoler / rear | 0.900000 | 1.3168 | 1.46 | regrid | 0.900 → 0.900 | 0.900 → 0.900 | 11.34% / 1.861 | 13.89% / 1.928 | 5.10% / 2.633 | 1.735 → 2.370 |
| cinder_droplet / front | 0.560000 | 1.5000 | 2.68 | regrid | 0.560 → 0.560 | 0.560 → 0.560 | 18.38% / 1.700 | 17.40% / 1.702 | 2.89% / 3.413 | 0.953 → 1.911 |
| cinder_droplet / rear | 0.560000 | 1.5000 | 2.68 | regrid | 0.560 → 0.560 | 0.560 → 0.560 | 24.77% / 1.490 | 23.99% / 1.502 | 5.35% / 3.265 | 0.841 → 1.829 |
| cinder_ooze / front | 0.820000 | 1.5000 | 1.83 | regrid | 0.820 → 0.820 | 0.820 → 0.820 | 18.28% / 1.707 | 15.71% / 1.980 | 6.06% / 2.938 | 1.623 → 2.410 |
| cinder_ooze / rear | 0.820000 | 1.5000 | 1.83 | regrid | 0.820 → 0.820 | 0.820 → 0.820 | 30.25% / 1.398 | 22.75% / 1.802 | 4.58% / 2.921 | 1.478 → 2.395 |
| frostglass_lancer / front | 1.000000 | 1.0825 | 1.08 | clean | 1.000 → 1.000 | 1.000 → 1.000 | 6.65% / 2.077 | 13.37% / 1.784 | 6.45% / 1.938 | 1.784 → 1.938 |
| frostglass_lancer / rear | 1.000000 | 1.3680 | 1.37 | regrid | 1.000 → 1.000 | 1.000 → 1.000 | 12.36% / 1.744 | 17.20% / 1.577 | 5.42% / 2.050 | 1.577 → 2.050 |
| grave_surgeon / front | 0.980000 | 1.5000 | 1.53 | regrid | 0.980 → 0.980 | 0.980 → 0.980 | 20.19% / 1.670 | 20.06% / 2.799 | 3.91% / 3.343 | 2.743 → 3.277 |
| grave_surgeon / rear | 0.980000 | 1.5000 | 1.53 | regrid | 0.980 → 0.980 | 0.980 → 0.980 | 20.21% / 1.660 | 23.50% / 2.995 | 5.77% / 3.797 | 2.935 → 3.721 |
| harrier / front | 1.000000 | 1.5000 | 1.50 | regrid | 1.000 → 1.000 | 1.000 → 1.000 | 34.33% / 1.325 | 49.60% / 1.202 | 21.01% / 1.688 | 1.202 → 1.688 |
| harrier / rear | 1.000000 | 1.5000 | 1.50 | regrid | 1.000 → 1.000 | 1.000 → 1.000 | 20.37% / 1.555 | 45.12% / 1.275 | 16.52% / 1.852 | 1.275 → 1.852 |
| iskaldra / front | 1.780000 | 1.5000 | 0.84 | clean | 1.780 → 1.780 | 1.780 → 1.780 | 50.65% / 1.181 | 59.07% / 1.148 | 33.97% / 1.349 | 2.044 → 2.400 |
| iskaldra / rear | 1.780000 | 1.5000 | 0.84 | clean | 1.780 → 1.780 | 1.780 → 1.780 | 44.73% / 1.220 | 57.34% / 1.157 | 31.37% / 1.378 | 2.060 → 2.453 |
| lightning_wisp / front | 0.680000 | 1.5000 | 1.50 | regrid | 0.680 → 0.680 | 0.680 → 0.680 | 39.71% / 1.523 | 60.08% / 1.219 | 28.09% / 1.680 | 0.829 → 1.142 |
| lightning_wisp / rear | 0.680000 | 1.5000 | 1.50 | regrid | 0.680 → 0.680 | 0.680 → 0.680 | 48.22% / 1.359 | 62.82% / 1.214 | 27.83% / 1.678 | 0.826 → 1.141 |
| noctyrax / front | 1.860000 | 1.5000 | 0.81 | clean | 1.860 → 1.860 | 1.860 → 1.860 | 26.67% / 1.484 | 32.46% / 1.464 | 16.27% / 1.733 | 2.724 → 3.223 |
| noctyrax / rear | 1.860000 | 1.5000 | 0.81 | clean | 1.860 → 1.860 | 1.860 → 1.860 | 24.81% / 1.507 | 29.87% / 1.448 | 13.94% / 1.719 | 2.693 → 3.198 |
| tharokh / front | 1.780000 | 1.5000 | 0.84 | clean | 1.780 → 1.780 | 1.780 → 1.780 | 29.52% / 1.395 | 32.33% / 1.391 | 14.30% / 1.682 | 2.477 → 2.994 |
| tharokh / rear | 1.780000 | 1.5000 | 0.84 | clean | 1.780 → 1.780 | 1.780 → 1.780 | 27.53% / 1.429 | 28.39% / 1.420 | 10.11% / 1.729 | 2.527 → 3.077 |
| vaeloryx / front | 1.820000 | 1.5000 | 0.82 | clean | 1.820 → 1.820 | 1.820 → 1.820 | 39.54% / 1.312 | 47.90% / 1.238 | 26.74% / 1.478 | 2.253 → 2.690 |
| vaeloryx / rear | 1.820000 | 1.5000 | 0.82 | clean | 1.820 → 1.820 | 1.820 → 1.820 | 44.74% / 1.273 | 51.55% / 1.209 | 28.78% / 1.446 | 2.200 → 2.631 |
| veilbound_acolyte / front | 1.000000 | 1.0005 | 1.00 | clean | 1.000 → 1.000 | 1.000 → 1.000 | 5.01% / 2.359 | 8.59% / 2.566 | 5.61% / 2.632 | 2.566 → 2.632 |
| veilbound_acolyte / rear | 1.000000 | 1.0000 | 1.00 | clean | 1.000 → 1.000 | 1.000 → 1.000 | 2.03% / 3.480 | 5.73% / 2.997 | 2.87% / 3.102 | 2.997 → 3.102 |
| vyraketh / front | 1.760000 | 1.5000 | 0.85 | clean | 1.760 → 1.760 | 1.760 → 1.760 | 38.27% / 1.316 | 37.82% / 1.432 | 22.37% / 1.678 | 2.520 → 2.953 |
| vyraketh / rear | 1.760000 | 1.5000 | 0.85 | clean | 1.760 → 1.760 | 1.760 → 1.760 | 39.38% / 1.266 | 37.60% / 1.416 | 21.07% / 1.668 | 2.492 → 2.935 |
| zekarion / front | 1.920000 | 1.5000 | 0.78 | clean | 1.920 → 1.920 | 1.920 → 1.920 | 42.08% / 1.288 | 41.81% / 1.313 | 24.79% / 1.522 | 2.521 → 2.921 |
| zekarion / rear | 1.920000 | 1.5000 | 0.78 | clean | 1.920 → 1.920 | 1.920 → 1.920 | 42.68% / 1.310 | 45.09% / 1.221 | 31.20% / 1.379 | 2.344 → 2.647 |
| ash_hound / front | 0.750000 | 1.2580 | 1.68 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 10.16% / 1.703 | 11.88% / 1.683 | 4.32% / 2.445 | 1.262 → 1.834 |
| ash_hound / rear | 0.750000 | 1.3816 | 1.84 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 12.63% / 1.656 | 13.86% / 1.630 | 3.30% / 2.611 | 1.223 → 1.958 |
| ashen_reaver / front | 1.150000 | 1.1630 | 1.01 | clean | 1.150 → 1.150 | 1.150 → 1.150 | 8.26% / 1.902 | 9.40% / 1.836 | 4.86% / 1.953 | 2.112 → 2.246 |
| ashen_reaver / rear | 1.150000 | 1.0137 | 0.88 | clean | 1.150 → 1.150 | 1.150 → 1.150 | 5.27% / 2.118 | 5.59% / 2.042 | 3.06% / 2.118 | 2.349 → 2.436 |
| bell_tender / front | 0.750000 | 1.1119 | 1.48 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 7.24% / 1.843 | 8.48% / 1.812 | 3.83% / 2.344 | 1.359 → 1.758 |
| bell_tender / rear | 0.750000 | 1.3225 | 1.76 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 11.45% / 1.721 | 14.29% / 1.718 | 4.20% / 2.479 | 1.289 → 1.859 |
| craghide / front | 1.150000 | 1.2046 | 1.05 | clean | 1.150 → 1.150 | 1.150 → 1.150 | 9.09% / 1.779 | 8.08% / 1.915 | 3.76% / 2.016 | 2.202 → 2.319 |
| craghide / rear | 1.150000 | 1.4035 | 1.22 | regrid | 1.150 → 1.150 | 1.150 → 1.150 | 13.07% / 1.616 | 11.62% / 1.648 | 3.42% / 2.104 | 1.895 → 2.419 |
| gallows_roc / front | 1.150000 | 1.5000 | 1.30 | regrid | 1.150 → 1.150 | 1.150 → 1.150 | 21.73% / 1.455 | 26.23% / 1.399 | 7.19% / 1.943 | 1.609 → 2.234 |
| gallows_roc / rear | 1.150000 | 1.5000 | 1.30 | regrid | 1.150 → 1.150 | 1.150 → 1.150 | 31.17% / 1.265 | 40.29% / 1.217 | 12.32% / 1.732 | 1.399 → 1.991 |
| last_lamplighter / front | 1.150000 | 1.5000 | 1.30 | regrid | 1.150 → 1.150 | 1.150 → 1.150 | 18.34% / 1.430 | 20.90% / 1.396 | 5.34% / 1.797 | 1.605 → 2.066 |
| last_lamplighter / rear | 1.150000 | 1.5000 | 1.30 | regrid | 1.150 → 1.150 | 1.150 → 1.150 | 16.58% / 1.437 | 18.86% / 1.396 | 5.65% / 1.757 | 1.605 → 2.020 |
| rime_spitter / front | 0.750000 | 1.0690 | 1.43 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 6.38% / 1.829 | 6.97% / 1.792 | 3.22% / 2.173 | 1.344 → 1.630 |
| rime_spitter / rear | 0.750000 | 1.1495 | 1.53 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 7.99% / 1.810 | 10.64% / 1.721 | 5.02% / 2.276 | 1.291 → 1.707 |
| rime_whelp / front | 0.750000 | 1.0000 | 1.33 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 4.57% / 1.887 | 5.47% / 1.954 | 3.58% / 2.233 | 1.465 → 1.675 |
| rime_whelp / rear | 0.750000 | 1.0725 | 1.43 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 6.45% / 1.844 | 6.51% / 1.849 | 3.48% / 2.286 | 1.386 → 1.714 |
| rimejaw / front | 1.150000 | 1.5000 | 1.30 | regrid | 1.150 → 1.150 | 1.150 → 1.150 | 20.17% / 1.448 | 20.34% / 1.475 | 6.47% / 1.952 | 1.696 → 2.245 |
| rimejaw / rear | 1.150000 | 1.5000 | 1.30 | regrid | 1.150 → 1.150 | 1.150 → 1.150 | 25.49% / 1.395 | 26.17% / 1.385 | 7.64% / 1.878 | 1.593 → 2.159 |
| roc_fledgling / front | 0.750000 | 1.1754 | 1.57 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 8.51% / 1.891 | 9.80% / 1.814 | 3.63% / 2.507 | 1.360 → 1.880 |
| roc_fledgling / rear | 0.750000 | 1.5000 | 2.00 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 38.26% / 1.236 | 40.21% / 1.234 | 10.81% / 2.276 | 0.925 → 1.707 |
| stoneback_mite / front | 0.750000 | 1.0000 | 1.33 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 1.54% / 2.221 | 1.94% / 2.017 | 2.16% / 2.043 | 1.513 → 1.532 |
| stoneback_mite / rear | 0.750000 | 1.0000 | 1.33 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 4.03% / 2.003 | 3.80% / 1.824 | 2.99% / 2.025 | 1.368 → 1.519 |
| storm_cantor / front | 1.150000 | 1.5000 | 1.30 | regrid | 1.150 → 1.150 | 1.150 → 1.150 | 28.86% / 1.335 | 39.07% / 1.263 | 18.59% / 1.644 | 1.453 → 1.890 |
| storm_cantor / rear | 1.150000 | 1.5000 | 1.30 | regrid | 1.150 → 1.150 | 1.150 → 1.150 | 26.92% / 1.355 | 32.72% / 1.288 | 11.68% / 1.730 | 1.481 → 1.990 |
| wick_shade / front | 0.750000 | 1.0000 | 1.33 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 2.76% / 2.081 | 3.28% / 2.026 | 2.25% / 2.280 | 1.520 → 1.710 |
| wick_shade / rear | 0.750000 | 1.1253 | 1.50 | regrid | 0.750 → 0.750 | 0.750 → 0.750 | 7.51% / 1.849 | 9.37% / 1.770 | 3.07% / 2.264 | 1.327 → 1.698 |
| column_torch_idle | 0.351510 | 1.0000 | 2.84 | regrid | 0.352 → 0.352 | 0.352 → 0.352 | 0.00% / 5.130 | 0.00% / 5.130 | 0.00% / 4.939 | 1.803 → 1.736 |
| column_torch_static | 1.406039 | 1.5000 | 1.50 | resample | 1.406 → 1.000 | 1.406 → 1.000 | 29.83% / 1.266 | 30.41% / 1.258 | 2.43% / 2.158 | 1.769 → 2.158 |
| campfire | 0.322568 | 1.0000 | 3.10 | regrid | 0.323 → 0.323 | 0.323 → 0.323 | 0.00% / 7.181 | 0.00% / 7.181 | 0.00% / 7.341 | 2.316 → 2.368 |
| campfire_idle | 0.322568 | 1.0000 | 3.10 | regrid | 0.323 → 0.323 | 0.323 → 0.323 | 0.00% / 7.181 | 0.00% / 7.181 | 0.00% / 7.341 | 2.316 → 2.368 |
| door | 1.359223 | 1.0904 | 1.50 | resample | 1.359 → 1.000 | 1.359 → 1.000 | 6.81% / 2.200 | 6.81% / 2.200 | 0.26% / 3.422 | 2.991 → 3.422 |
| door_opening | 0.649288 | 1.0000 | 1.54 | regrid | 0.649 → 0.649 | 0.649 → 0.649 | 1.45% / 3.888 | 1.45% / 3.888 | 0.43% / 4.859 | 2.525 → 3.155 |
| watch_brazier | 0.582524 | 1.0000 | 1.72 | regrid | 0.583 → 0.583 | 0.583 → 0.583 | 3.33% / 3.184 | 3.33% / 3.184 | 0.28% / 4.067 | 1.855 → 2.369 |
| scavenger_stall | 1.114078 | 1.5000 | 1.50 | resample | 1.114 → 1.000 | 1.114 → 1.000 | 34.46% / 1.368 | 34.46% / 1.368 | 3.18% / 2.388 | 1.524 → 2.388 |
| scavenger_npc | 0.920000 | 1.5000 | 1.00 | clean | 0.920 → 0.920 | 0.920 → 0.920 | 29.14% / 1.426 | 29.14% / 1.426 | 8.26% / 1.799 | 1.312 → 1.655 |
| dropped_embers | 0.876820 | 1.5000 | 1.71 | regrid | 0.877 → 0.877 | 0.877 → 0.877 | 51.95% / 1.236 | 51.95% / 1.236 | 3.77% / 2.244 | 1.084 → 1.967 |
| emaciated_man_idle | 0.230000 | 1.0000 | 4.35 | regrid | 0.230 → 0.230 | 0.230 → 0.230 | 0.00% / 9.280 | 0.00% / 9.280 | 0.00% / 10.552 | 2.135 → 2.427 |
| wooden_box | 1.237864 | 1.2853 | 1.50 | resample | 1.238 → 1.000 | 1.238 → 1.000 | 10.71% / 1.868 | 10.71% / 1.868 | 0.46% / 3.243 | 2.312 → 3.243 |
| wooden_box_destroy | 1.237864 | 1.2660 | 1.50 | resample | 1.238 → 1.000 | 1.238 → 1.000 | 10.32% / 2.170 | 10.32% / 2.170 | 0.51% / 3.595 | 2.687 → 3.595 |
| wooden_crate | 1.237864 | 1.3777 | 1.50 | resample | 1.238 → 1.000 | 1.238 → 1.000 | 12.55% / 1.819 | 12.55% / 1.819 | 0.45% / 3.090 | 2.251 → 3.090 |
| wooden_crate_destroy | 1.237864 | 1.2740 | 1.50 | resample | 1.238 → 1.000 | 1.238 → 1.000 | 10.48% / 2.043 | 10.48% / 2.043 | 0.58% / 3.180 | 2.529 → 3.180 |
| powder_keg | 1.237864 | 1.5000 | 1.50 | resample | 1.238 → 1.000 | 1.238 → 1.000 | 21.82% / 1.630 | 21.82% / 1.630 | 1.86% / 2.856 | 2.018 → 2.856 |
| relic_chest | 1.753641 | 1.5000 | 1.50 | resample | 1.754 → 1.000 | 1.754 → 1.000 | 26.64% / 1.522 | 26.64% / 1.522 | 1.10% / 2.976 | 2.668 → 2.976 |
| relic_chest_opening | 1.753641 | 1.5000 | 1.50 | resample | 1.754 → 1.000 | 1.754 → 1.000 | 23.91% / 1.548 | 23.65% / 2.129 | 1.24% / 4.040 | 3.734 → 4.040 |
| pillar | 1.376746 | 1.0000 | 1.50 | resample | 1.377 → 1.000 | 1.377 → 1.000 | 3.64% / 2.940 | 3.64% / 2.940 | 0.26% / 4.621 | 4.047 → 4.621 |
| moss_pillar_overlay | 1.888109 | 1.4233 | 1.50 | resample | 1.888 → 1.000 | 1.561 → 1.000 | 13.47% / 1.705 | 13.47% / 1.705 | 0.74% / 2.456 | 3.220 → 2.456 |
| floor_tiles | 2.029285 | 1.0000 | 1.50 | resample | 2.029 → 1.000 | 1.547 → 1.000 | 3.58% / 4.779 | 4.97% / 4.246 | 0.30% / 7.273 | 8.617 → 7.273 |
| moss_floor_overlays | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 1.547 → 1.000 | 25.25% / 1.357 | 19.18% / 1.527 | 1.39% / 2.590 | 3.099 → 2.590 |
| fire_floor_overlay_01 | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 1.547 → 1.000 | 67.28% / 1.164 | 67.28% / 1.164 | 8.19% / 2.442 | 2.363 → 2.442 |
| fire_floor_overlay_02 | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 1.547 → 1.000 | 60.87% / 1.185 | 60.87% / 1.185 | 15.11% / 2.127 | 2.405 → 2.127 |
| ice_floor_overlay_01 | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 1.547 → 1.000 | 74.32% / 1.094 | 74.32% / 1.094 | 27.35% / 1.734 | 2.220 → 1.734 |
| ice_floor_overlay_02 | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 1.547 → 1.000 | 35.05% / 1.785 | 35.05% / 1.785 | 7.10% / 2.933 | 3.623 → 2.933 |
| lightning_floor_overlay_01 | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 1.547 → 1.000 | 17.93% / 1.688 | 17.93% / 1.688 | 6.65% / 2.206 | 3.426 → 2.206 |
| lightning_floor_overlay_02 | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 1.547 → 1.000 | 34.44% / 1.337 | 34.44% / 1.337 | 9.93% / 1.908 | 2.713 → 1.908 |
| air_floor_overlay_01 | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 1.547 → 1.000 | 33.33% / 1.352 | 33.33% / 1.352 | 5.55% / 2.177 | 2.744 → 2.177 |
| air_floor_overlay_02 | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 1.547 → 1.000 | 19.69% / 1.798 | 19.69% / 1.798 | 3.61% / 2.932 | 3.648 → 2.932 |
| trap_air | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 2.029 → 1.000 | 33.42% / 1.455 | 33.42% / 1.455 | 0.87% / 3.455 | 2.953 → 3.455 |
| trap_air_sheets | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 2.029 → 1.000 | 33.43% / 1.454 | 33.42% / 1.455 | 0.91% / 3.431 | 2.952 → 3.431 |
| trap_earth | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 2.029 → 1.000 | 28.70% / 1.616 | 28.70% / 1.616 | 0.74% / 4.013 | 3.280 → 4.013 |
| trap_earth_sheets | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 2.029 → 1.000 | 28.82% / 1.613 | 28.80% / 1.614 | 0.79% / 3.987 | 3.276 → 3.987 |
| trap_fire | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 2.029 → 1.000 | 35.08% / 1.450 | 35.08% / 1.450 | 1.12% / 3.462 | 2.942 → 3.462 |
| trap_fire_sheets | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 2.029 → 1.000 | 34.14% / 1.453 | 33.85% / 1.460 | 1.29% / 3.436 | 2.963 → 3.436 |
| trap_ice | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 2.029 → 1.000 | 30.81% / 1.549 | 30.81% / 1.549 | 0.76% / 3.735 | 3.143 → 3.735 |
| trap_ice_sheets | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 2.029 → 1.000 | 30.49% / 1.591 | 30.79% / 1.569 | 0.95% / 3.625 | 3.183 → 3.625 |
| trap_lightning | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 2.029 → 1.000 | 35.89% / 1.431 | 35.89% / 1.431 | 0.97% / 3.459 | 2.904 → 3.459 |
| trap_lightning_sheets | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 2.029 → 1.000 | 35.51% / 1.438 | 35.53% / 1.435 | 1.55% / 3.183 | 2.912 → 3.183 |
| ember_floor | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 1.547 → 1.000 | 38.05% / 1.435 | 38.05% / 1.435 | 5.00% / 3.063 | 2.912 → 3.063 |
| stone_floor_fallback | 2.029285 | 1.5000 | 1.50 | resample | 2.029 → 1.000 | 1.547 → 1.000 | 38.13% / 1.365 | 38.13% / 1.365 | 4.01% / 3.032 | 2.769 → 3.032 |
| hero_rear / rear | 1.000000 | 1.1317 | 1.00 | clean | 1.000 → 1.000 | 1.000 → 1.000 | 7.63% / 2.216 | 8.91% / 2.221 | 3.02% / 2.418 | 2.221 → 2.418 |

## Fixed rig geometry

Rigs retain their 255-pixel logical canvas and never resample. Dragon pixels
still draw larger than the hero; native cleanup preserves their fixed geometry.

## Resample alpha families

Each entry measures once; linked sheets/parts inherit their static family source.
The translucent fraction counts 64 ≤ alpha < 240 among nonzero source pixels.

| Entry | Measurement owner | Alpha class | Translucent fraction | Measurement path |
| --- | --- | --- | ---: | --- |
| column_torch_static | column_torch_static | solid | 0.000000 | `assets/art/tiles/column_torch_left.png` |
| door | door | solid | 0.000000 | `assets/placeholders/tiles/door.png` |
| scavenger_stall | scavenger_stall | solid | 0.037192 | `assets/art/tiles/scavenger_stall.png` |
| wooden_box | wooden_box | solid | 0.008852 | `assets/art/tiles/wooden_box.png` |
| wooden_box_destroy | wooden_box | solid | 0.008852 | `assets/art/tiles/wooden_box.png` |
| wooden_crate | wooden_crate | solid | 0.010469 | `assets/art/tiles/wooden_crate.png` |
| wooden_crate_destroy | wooden_crate | solid | 0.010469 | `assets/art/tiles/wooden_crate.png` |
| powder_keg | powder_keg | solid | 0.043333 | `assets/art/tiles/powder_keg.png` |
| relic_chest | relic_chest | solid | 0.042211 | `assets/art/tiles/relic_chest.png` |
| relic_chest_opening | relic_chest | solid | 0.042211 | `assets/art/tiles/relic_chest.png` |
| pillar | pillar | solid | 0.000000 | `assets/placeholders/tiles/pillar.png` |
| moss_pillar_overlay | moss_pillar_overlay | solid | 0.000000 | `assets/placeholders/tiles/moss_overlays/moss_pillar_overlay_01.png` |
| floor_tiles | floor_tiles | solid | 0.000000 | `assets/placeholders/tiles/base_floor_tile_02.png` |
| moss_floor_overlays | moss_floor_overlays | solid | 0.000000 | `assets/placeholders/tiles/moss_overlays/moss_floor_overlay_01.png` |
| fire_floor_overlay_01 | fire_floor_overlay_01 | soft | 0.159509 | `assets/placeholders/tiles/element_overlays/fire/fire_floor_overlay_01.png` |
| fire_floor_overlay_02 | fire_floor_overlay_02 | soft | 0.189369 | `assets/placeholders/tiles/element_overlays/fire/fire_floor_overlay_02.png` |
| ice_floor_overlay_01 | ice_floor_overlay_01 | soft | 0.188172 | `assets/placeholders/tiles/element_overlays/ice/ice_floor_overlay_01.png` |
| ice_floor_overlay_02 | ice_floor_overlay_02 | solid | 0.092784 | `assets/placeholders/tiles/element_overlays/ice/ice_floor_overlay_02.png` |
| lightning_floor_overlay_01 | lightning_floor_overlay_01 | solid | 0.029891 | `assets/placeholders/tiles/element_overlays/lightning/lightning_floor_overlay_01.png` |
| lightning_floor_overlay_02 | lightning_floor_overlay_02 | solid | 0.028926 | `assets/placeholders/tiles/element_overlays/lightning/lightning_floor_overlay_02.png` |
| air_floor_overlay_01 | air_floor_overlay_01 | solid | 0.020661 | `assets/placeholders/tiles/element_overlays/air/air_floor_overlay_01.png` |
| air_floor_overlay_02 | air_floor_overlay_02 | solid | 0.034375 | `assets/placeholders/tiles/element_overlays/air/air_floor_overlay_02.png` |
| trap_air | trap_air | solid | 0.064320 | `assets/art/traps/trap_air.png` |
| trap_air_sheets | trap_air | solid | 0.064320 | `assets/art/traps/trap_air.png` |
| trap_earth | trap_earth | solid | 0.061069 | `assets/art/traps/trap_earth.png` |
| trap_earth_sheets | trap_earth | solid | 0.061069 | `assets/art/traps/trap_earth.png` |
| trap_fire | trap_fire | solid | 0.068826 | `assets/art/traps/trap_fire.png` |
| trap_fire_sheets | trap_fire | solid | 0.068826 | `assets/art/traps/trap_fire.png` |
| trap_ice | trap_ice | solid | 0.058776 | `assets/art/traps/trap_ice.png` |
| trap_ice_sheets | trap_ice | solid | 0.058776 | `assets/art/traps/trap_ice.png` |
| trap_lightning | trap_lightning | solid | 0.067921 | `assets/art/traps/trap_lightning.png` |
| trap_lightning_sheets | trap_lightning | solid | 0.067921 | `assets/art/traps/trap_lightning.png` |
| ember_floor | ember_floor | solid | 0.056309 | `assets/art/tiles/ember.png` |
| stone_floor_fallback | stone_floor_fallback | solid | 0.055306 | `assets/art/tiles/stone.png` |

## Production files per entry

A † marks changed decoded pixels or dimensions relative to untouched source paint.

### warden

- `assets/units/stone_warden_cutout/front/arm_r.png` †
- `assets/units/stone_warden_cutout/front/foot_l.png` †
- `assets/units/stone_warden_cutout/front/foot_r.png` †
- `assets/units/stone_warden_cutout/front/hand_r.png` †
- `assets/units/stone_warden_cutout/front/head.png` †
- `assets/units/stone_warden_cutout/front/leg_l.png` †
- `assets/units/stone_warden_cutout/front/leg_r.png` †
- `assets/units/stone_warden_cutout/front/mace.png` †
- `assets/units/stone_warden_cutout/front/pauldron_l.png` †
- `assets/units/stone_warden_cutout/front/pelvis_cover.png` †
- `assets/units/stone_warden_cutout/front/shield.png` †
- `assets/units/stone_warden_cutout/front/shield_arm.png` †
- `assets/units/stone_warden_cutout/front/shoulder_cap_r.png` †
- `assets/units/stone_warden_cutout/front/tabard.png` †
- `assets/units/stone_warden_cutout/front/thigh_cap_l.png` †
- `assets/units/stone_warden_cutout/front/thigh_cap_r.png` †
- `assets/units/stone_warden_cutout/front/torso.png` †
- `assets/units/stone_warden_cutout/rear/arm_l.png` †
- `assets/units/stone_warden_cutout/rear/arm_r.png` †
- `assets/units/stone_warden_cutout/rear/foot_l.png` †
- `assets/units/stone_warden_cutout/rear/foot_r.png` †
- `assets/units/stone_warden_cutout/rear/hand_r.png` †
- `assets/units/stone_warden_cutout/rear/head.png` †
- `assets/units/stone_warden_cutout/rear/leg_l.png` †
- `assets/units/stone_warden_cutout/rear/leg_r.png` †
- `assets/units/stone_warden_cutout/rear/mace.png` †
- `assets/units/stone_warden_cutout/rear/pelvis_cover.png` †
- `assets/units/stone_warden_cutout/rear/shield.png` †
- `assets/units/stone_warden_cutout/rear/shoulder_cap_r.png` †
- `assets/units/stone_warden_cutout/rear/shoulder_socket_r.png` †
- `assets/units/stone_warden_cutout/rear/tabard.png` †
- `assets/units/stone_warden_cutout/rear/torso.png` †

### crawler

- `assets/units/crawler_cutout/front/arm_far.png` †
- `assets/units/crawler_cutout/front/arm_fill_far.png` †
- `assets/units/crawler_cutout/front/arm_fill_near.png` †
- `assets/units/crawler_cutout/front/arm_near.png` †
- `assets/units/crawler_cutout/front/body.png` †
- `assets/units/crawler_cutout/front/claw_far.png` †
- `assets/units/crawler_cutout/front/claw_near.png` †
- `assets/units/crawler_cutout/front/foot_far.png` †
- `assets/units/crawler_cutout/front/foot_near.png` †
- `assets/units/crawler_cutout/front/head.png` †
- `assets/units/crawler_cutout/front/leg_far.png` †
- `assets/units/crawler_cutout/front/leg_fill_far.png` †
- `assets/units/crawler_cutout/front/leg_fill_near.png` †
- `assets/units/crawler_cutout/front/leg_near.png` †
- `assets/units/crawler_cutout/front/shoulder_pocket.png` †
- `assets/units/crawler_cutout/rear/arm_far.png` †
- `assets/units/crawler_cutout/rear/arm_fill_far.png` †
- `assets/units/crawler_cutout/rear/arm_fill_near.png` †
- `assets/units/crawler_cutout/rear/arm_near.png` †
- `assets/units/crawler_cutout/rear/body.png` †
- `assets/units/crawler_cutout/rear/claw_far.png` †
- `assets/units/crawler_cutout/rear/claw_near.png` †
- `assets/units/crawler_cutout/rear/foot_far.png` †
- `assets/units/crawler_cutout/rear/foot_near.png` †
- `assets/units/crawler_cutout/rear/head.png` †
- `assets/units/crawler_cutout/rear/leg_far.png` †
- `assets/units/crawler_cutout/rear/leg_fill_far.png` †
- `assets/units/crawler_cutout/rear/leg_fill_near.png` †
- `assets/units/crawler_cutout/rear/leg_near.png` †
- `assets/units/crawler_cutout/rear/shoulder_pocket.png` †

### acolyte

- `assets/units/acolyte_cutout/front/cast_hand.png` †
- `assets/units/acolyte_cutout/front/cast_sleeve.png` †
- `assets/units/acolyte_cutout/front/hood.png` †
- `assets/units/acolyte_cutout/front/orb.png` †
- `assets/units/acolyte_cutout/front/rest_hand.png` †
- `assets/units/acolyte_cutout/front/rest_sleeve.png` †
- `assets/units/acolyte_cutout/front/robe_l.png` †
- `assets/units/acolyte_cutout/front/robe_r.png` †
- `assets/units/acolyte_cutout/front/shoulder_socket.png` †
- `assets/units/acolyte_cutout/front/torso.png` †
- `assets/units/acolyte_cutout/front/underrobe.png` (pixels unchanged)
- `assets/units/acolyte_cutout/rear/cast_hand.png` †
- `assets/units/acolyte_cutout/rear/cast_sleeve.png` †
- `assets/units/acolyte_cutout/rear/hood.png` †
- `assets/units/acolyte_cutout/rear/orb.png` †
- `assets/units/acolyte_cutout/rear/rest_sleeve.png` †
- `assets/units/acolyte_cutout/rear/robe_l.png` †
- `assets/units/acolyte_cutout/rear/robe_r.png` †
- `assets/units/acolyte_cutout/rear/shoulder_socket.png` †
- `assets/units/acolyte_cutout/rear/torso.png` †
- `assets/units/acolyte_cutout/rear/underrobe.png` (pixels unchanged)

### bile_bloomer

- `assets/units/bile_bloomer_cutout/front/core.png` †
- `assets/units/bile_bloomer_cutout/front/hidden_calyx.png` †
- `assets/units/bile_bloomer_cutout/front/hidden_roots.png` †
- `assets/units/bile_bloomer_cutout/front/petal_far_l.png` †
- `assets/units/bile_bloomer_cutout/front/petal_far_r.png` †
- `assets/units/bile_bloomer_cutout/front/petal_near_l.png` †
- `assets/units/bile_bloomer_cutout/front/petal_near_r.png` †
- `assets/units/bile_bloomer_cutout/front/root_stem_c.png` †
- `assets/units/bile_bloomer_cutout/front/root_stem_l.png` †
- `assets/units/bile_bloomer_cutout/front/root_stem_r.png` †
- `assets/units/bile_bloomer_cutout/front/root_tip_c.png` †
- `assets/units/bile_bloomer_cutout/front/root_tip_l.png` †
- `assets/units/bile_bloomer_cutout/front/root_tip_r.png` †
- `assets/units/bile_bloomer_cutout/front/tendril_high_l.png` †
- `assets/units/bile_bloomer_cutout/front/tendril_high_r.png` †
- `assets/units/bile_bloomer_cutout/front/tendril_low_l.png` †
- `assets/units/bile_bloomer_cutout/front/tendril_low_r.png` †
- `assets/units/bile_bloomer_cutout/front/tendril_mid_l.png` †
- `assets/units/bile_bloomer_cutout/front/trunk.png` †
- `assets/units/bile_bloomer_cutout/rear/core.png` †
- `assets/units/bile_bloomer_cutout/rear/hidden_calyx.png` †
- `assets/units/bile_bloomer_cutout/rear/hidden_roots.png` †
- `assets/units/bile_bloomer_cutout/rear/petal_far_l.png` †
- `assets/units/bile_bloomer_cutout/rear/petal_far_r.png` †
- `assets/units/bile_bloomer_cutout/rear/petal_near_l.png` †
- `assets/units/bile_bloomer_cutout/rear/petal_near_r.png` †
- `assets/units/bile_bloomer_cutout/rear/root_stem_c.png` †
- `assets/units/bile_bloomer_cutout/rear/root_stem_l.png` †
- `assets/units/bile_bloomer_cutout/rear/root_stem_r.png` †
- `assets/units/bile_bloomer_cutout/rear/root_tip_c.png` †
- `assets/units/bile_bloomer_cutout/rear/root_tip_l.png` †
- `assets/units/bile_bloomer_cutout/rear/root_tip_r.png` †
- `assets/units/bile_bloomer_cutout/rear/tendril_high_l.png` †
- `assets/units/bile_bloomer_cutout/rear/tendril_high_r.png` †
- `assets/units/bile_bloomer_cutout/rear/tendril_low_l.png` †
- `assets/units/bile_bloomer_cutout/rear/tendril_low_r.png` †
- `assets/units/bile_bloomer_cutout/rear/tendril_mid_r.png` †
- `assets/units/bile_bloomer_cutout/rear/trunk.png` †

### chainbound_gaoler

- `assets/units/chainbound_gaoler_cutout/front/arm_fist.png` †
- `assets/units/chainbound_gaoler_cutout/front/arm_hook.png` †
- `assets/units/chainbound_gaoler_cutout/front/belt.png` †
- `assets/units/chainbound_gaoler_cutout/front/chain_a.png` †
- `assets/units/chainbound_gaoler_cutout/front/chain_b.png` †
- `assets/units/chainbound_gaoler_cutout/front/chain_c.png` †
- `assets/units/chainbound_gaoler_cutout/front/coat_fist.png` †
- `assets/units/chainbound_gaoler_cutout/front/coat_hook.png` †
- `assets/units/chainbound_gaoler_cutout/front/drape_a.png` †
- `assets/units/chainbound_gaoler_cutout/front/drape_b.png` †
- `assets/units/chainbound_gaoler_cutout/front/drape_c.png` †
- `assets/units/chainbound_gaoler_cutout/front/drape_d.png` †
- `assets/units/chainbound_gaoler_cutout/front/foot_fist.png` †
- `assets/units/chainbound_gaoler_cutout/front/foot_hook.png` †
- `assets/units/chainbound_gaoler_cutout/front/hand_fist.png` †
- `assets/units/chainbound_gaoler_cutout/front/hand_hook.png` †
- `assets/units/chainbound_gaoler_cutout/front/head.png` †
- `assets/units/chainbound_gaoler_cutout/front/hook.png` †
- `assets/units/chainbound_gaoler_cutout/front/leg_fist.png` †
- `assets/units/chainbound_gaoler_cutout/front/leg_hook.png` †
- `assets/units/chainbound_gaoler_cutout/front/pelvis_under.png` †
- `assets/units/chainbound_gaoler_cutout/front/shoulder_fist_under.png` †
- `assets/units/chainbound_gaoler_cutout/front/shoulder_hook_under.png` †
- `assets/units/chainbound_gaoler_cutout/front/tabard.png` †
- `assets/units/chainbound_gaoler_cutout/front/thigh_fist_under.png` †
- `assets/units/chainbound_gaoler_cutout/front/thigh_hook_under.png` †
- `assets/units/chainbound_gaoler_cutout/front/torso.png` †
- `assets/units/chainbound_gaoler_cutout/front/wrist_strap.png` †
- `assets/units/chainbound_gaoler_cutout/rear/arm_fist.png` †
- `assets/units/chainbound_gaoler_cutout/rear/arm_hook.png` †
- `assets/units/chainbound_gaoler_cutout/rear/belt.png` †
- `assets/units/chainbound_gaoler_cutout/rear/chain_a.png` †
- `assets/units/chainbound_gaoler_cutout/rear/chain_b.png` †
- `assets/units/chainbound_gaoler_cutout/rear/chain_c.png` †
- `assets/units/chainbound_gaoler_cutout/rear/coat_fist.png` †
- `assets/units/chainbound_gaoler_cutout/rear/coat_hook.png` †
- `assets/units/chainbound_gaoler_cutout/rear/drape_a.png` †
- `assets/units/chainbound_gaoler_cutout/rear/drape_b.png` †
- `assets/units/chainbound_gaoler_cutout/rear/drape_c.png` †
- `assets/units/chainbound_gaoler_cutout/rear/drape_d.png` †
- `assets/units/chainbound_gaoler_cutout/rear/foot_fist.png` †
- `assets/units/chainbound_gaoler_cutout/rear/foot_hook.png` †
- `assets/units/chainbound_gaoler_cutout/rear/hand_fist.png` †
- `assets/units/chainbound_gaoler_cutout/rear/hand_hook.png` †
- `assets/units/chainbound_gaoler_cutout/rear/head.png` †
- `assets/units/chainbound_gaoler_cutout/rear/hook.png` †
- `assets/units/chainbound_gaoler_cutout/rear/leg_fist.png` †
- `assets/units/chainbound_gaoler_cutout/rear/leg_hook.png` †
- `assets/units/chainbound_gaoler_cutout/rear/pelvis_under.png` †
- `assets/units/chainbound_gaoler_cutout/rear/shoulder_fist_under.png` †
- `assets/units/chainbound_gaoler_cutout/rear/shoulder_hook_under.png` †
- `assets/units/chainbound_gaoler_cutout/rear/tabard.png` †
- `assets/units/chainbound_gaoler_cutout/rear/thigh_fist_under.png` †
- `assets/units/chainbound_gaoler_cutout/rear/thigh_hook_under.png` †
- `assets/units/chainbound_gaoler_cutout/rear/torso.png` †
- `assets/units/chainbound_gaoler_cutout/rear/wrist_strap.png` †

### cinder_droplet

- `assets/units/cinder_droplet_cutout/front/center.png` †
- `assets/units/cinder_droplet_cutout/front/core.png` †
- `assets/units/cinder_droplet_cutout/front/left_inner.png` †
- `assets/units/cinder_droplet_cutout/front/left_outer.png` †
- `assets/units/cinder_droplet_cutout/front/right_inner.png` †
- `assets/units/cinder_droplet_cutout/front/right_outer.png` †
- `assets/units/cinder_droplet_cutout/rear/center.png` †
- `assets/units/cinder_droplet_cutout/rear/core.png` †
- `assets/units/cinder_droplet_cutout/rear/left_inner.png` †
- `assets/units/cinder_droplet_cutout/rear/left_outer.png` †
- `assets/units/cinder_droplet_cutout/rear/right_inner.png` †
- `assets/units/cinder_droplet_cutout/rear/right_outer.png` †

### cinder_ooze

- `assets/units/cinder_ooze_cutout/front/bridge_front_left.png` †
- `assets/units/cinder_ooze_cutout/front/bridge_front_mid.png` †
- `assets/units/cinder_ooze_cutout/front/bridge_left_outer.png` (pixels unchanged)
- `assets/units/cinder_ooze_cutout/front/bridge_near_right.png` †
- `assets/units/cinder_ooze_cutout/front/bridge_right_outer.png` †
- `assets/units/cinder_ooze_cutout/front/crust_mass.png` †
- `assets/units/cinder_ooze_cutout/front/far_right.png` †
- `assets/units/cinder_ooze_cutout/front/front_left.png` †
- `assets/units/cinder_ooze_cutout/front/front_mid.png` †
- `assets/units/cinder_ooze_cutout/front/left_outer.png` †
- `assets/units/cinder_ooze_cutout/front/near_right.png` †
- `assets/units/cinder_ooze_cutout/front/right_outer.png` †
- `assets/units/cinder_ooze_cutout/rear/bridge_front_left.png` †
- `assets/units/cinder_ooze_cutout/rear/bridge_front_mid.png` †
- `assets/units/cinder_ooze_cutout/rear/bridge_left_outer.png` †
- `assets/units/cinder_ooze_cutout/rear/bridge_near_right.png` †
- `assets/units/cinder_ooze_cutout/rear/bridge_right_outer.png` †
- `assets/units/cinder_ooze_cutout/rear/crust_mass.png` †
- `assets/units/cinder_ooze_cutout/rear/far_right.png` †
- `assets/units/cinder_ooze_cutout/rear/front_left.png` †
- `assets/units/cinder_ooze_cutout/rear/front_mid.png` †
- `assets/units/cinder_ooze_cutout/rear/left_outer.png` †
- `assets/units/cinder_ooze_cutout/rear/near_right.png` †
- `assets/units/cinder_ooze_cutout/rear/right_outer.png` †

### frostglass_lancer

- `assets/units/frostglass_lancer_cutout/front/arm_l.png` †
- `assets/units/frostglass_lancer_cutout/front/arm_r.png` †
- `assets/units/frostglass_lancer_cutout/front/cape.png` †
- `assets/units/frostglass_lancer_cutout/front/foot_l.png` †
- `assets/units/frostglass_lancer_cutout/front/foot_r.png` †
- `assets/units/frostglass_lancer_cutout/front/hand_l.png` †
- `assets/units/frostglass_lancer_cutout/front/hand_r.png` †
- `assets/units/frostglass_lancer_cutout/front/head.png` †
- `assets/units/frostglass_lancer_cutout/front/lance.png` †
- `assets/units/frostglass_lancer_cutout/front/leg_l.png` †
- `assets/units/frostglass_lancer_cutout/front/leg_r.png` †
- `assets/units/frostglass_lancer_cutout/front/pelvis.png` †
- `assets/units/frostglass_lancer_cutout/front/pelvis_under.png` †
- `assets/units/frostglass_lancer_cutout/front/sleeve_l.png` †
- `assets/units/frostglass_lancer_cutout/front/sleeve_r.png` †
- `assets/units/frostglass_lancer_cutout/front/tabard.png` †
- `assets/units/frostglass_lancer_cutout/front/thigh_cover_l.png` †
- `assets/units/frostglass_lancer_cutout/front/thigh_cover_r.png` †
- `assets/units/frostglass_lancer_cutout/front/torso.png` †
- `assets/units/frostglass_lancer_cutout/front/torso_under.png` †
- `assets/units/frostglass_lancer_cutout/rear/arm_l.png` †
- `assets/units/frostglass_lancer_cutout/rear/arm_r.png` †
- `assets/units/frostglass_lancer_cutout/rear/cape.png` †
- `assets/units/frostglass_lancer_cutout/rear/foot_l.png` †
- `assets/units/frostglass_lancer_cutout/rear/foot_r.png` †
- `assets/units/frostglass_lancer_cutout/rear/hand_l.png` †
- `assets/units/frostglass_lancer_cutout/rear/hand_r.png` †
- `assets/units/frostglass_lancer_cutout/rear/head.png` †
- `assets/units/frostglass_lancer_cutout/rear/lance.png` †
- `assets/units/frostglass_lancer_cutout/rear/leg_l.png` †
- `assets/units/frostglass_lancer_cutout/rear/leg_r.png` †
- `assets/units/frostglass_lancer_cutout/rear/pelvis.png` †
- `assets/units/frostglass_lancer_cutout/rear/pelvis_under.png` †
- `assets/units/frostglass_lancer_cutout/rear/sleeve_l.png` †
- `assets/units/frostglass_lancer_cutout/rear/sleeve_r.png` †
- `assets/units/frostglass_lancer_cutout/rear/tabard.png` †
- `assets/units/frostglass_lancer_cutout/rear/thigh_cover_l.png` †
- `assets/units/frostglass_lancer_cutout/rear/thigh_cover_r.png` †
- `assets/units/frostglass_lancer_cutout/rear/torso.png` †
- `assets/units/frostglass_lancer_cutout/rear/torso_under.png` †

### grave_surgeon

- `assets/units/grave_surgeon_cutout/front/belt_kit.png` †
- `assets/units/grave_surgeon_cutout/front/foot_l.png` †
- `assets/units/grave_surgeon_cutout/front/foot_r.png` †
- `assets/units/grave_surgeon_cutout/front/hand_saw.png` †
- `assets/units/grave_surgeon_cutout/front/hand_vial.png` †
- `assets/units/grave_surgeon_cutout/front/hip_fill.png` †
- `assets/units/grave_surgeon_cutout/front/hood.png` †
- `assets/units/grave_surgeon_cutout/front/leg_l.png` †
- `assets/units/grave_surgeon_cutout/front/leg_r.png` †
- `assets/units/grave_surgeon_cutout/front/robe.png` †
- `assets/units/grave_surgeon_cutout/front/saw.png` †
- `assets/units/grave_surgeon_cutout/front/sleeve_cap_saw.png` †
- `assets/units/grave_surgeon_cutout/front/sleeve_cap_vial.png` †
- `assets/units/grave_surgeon_cutout/front/sleeve_saw.png` †
- `assets/units/grave_surgeon_cutout/front/sleeve_vial.png` †
- `assets/units/grave_surgeon_cutout/front/thigh_fill_l.png` †
- `assets/units/grave_surgeon_cutout/front/thigh_fill_r.png` †
- `assets/units/grave_surgeon_cutout/front/torso.png` †
- `assets/units/grave_surgeon_cutout/front/vial.png` †
- `assets/units/grave_surgeon_cutout/rear/belt_kit.png` †
- `assets/units/grave_surgeon_cutout/rear/foot_l.png` †
- `assets/units/grave_surgeon_cutout/rear/foot_r.png` †
- `assets/units/grave_surgeon_cutout/rear/hand_saw.png` †
- `assets/units/grave_surgeon_cutout/rear/hand_vial.png` †
- `assets/units/grave_surgeon_cutout/rear/hip_fill.png` †
- `assets/units/grave_surgeon_cutout/rear/hood.png` †
- `assets/units/grave_surgeon_cutout/rear/leg_l.png` †
- `assets/units/grave_surgeon_cutout/rear/leg_r.png` †
- `assets/units/grave_surgeon_cutout/rear/robe.png` †
- `assets/units/grave_surgeon_cutout/rear/saw.png` †
- `assets/units/grave_surgeon_cutout/rear/sleeve_cap_saw.png` †
- `assets/units/grave_surgeon_cutout/rear/sleeve_cap_vial.png` †
- `assets/units/grave_surgeon_cutout/rear/sleeve_saw.png` †
- `assets/units/grave_surgeon_cutout/rear/sleeve_vial.png` †
- `assets/units/grave_surgeon_cutout/rear/thigh_fill_l.png` †
- `assets/units/grave_surgeon_cutout/rear/thigh_fill_r.png` †
- `assets/units/grave_surgeon_cutout/rear/torso.png` †
- `assets/units/grave_surgeon_cutout/rear/vial.png` †

### harrier

- `assets/units/harrier_cutout/front/arm_l.png` †
- `assets/units/harrier_cutout/front/arm_r.png` †
- `assets/units/harrier_cutout/front/foot_l.png` †
- `assets/units/harrier_cutout/front/foot_r.png` †
- `assets/units/harrier_cutout/front/hand_l.png` †
- `assets/units/harrier_cutout/front/hand_r.png` †
- `assets/units/harrier_cutout/front/head.png` †
- `assets/units/harrier_cutout/front/hip_cap_l.png` †
- `assets/units/harrier_cutout/front/hip_cap_r.png` †
- `assets/units/harrier_cutout/front/leg_l.png` †
- `assets/units/harrier_cutout/front/leg_r.png` †
- `assets/units/harrier_cutout/front/pelvis_undercloth.png` †
- `assets/units/harrier_cutout/front/shoulder_cap_l.png` †
- `assets/units/harrier_cutout/front/shoulder_cap_r.png` †
- `assets/units/harrier_cutout/front/spear.png` †
- `assets/units/harrier_cutout/front/spine_undercloth.png` †
- `assets/units/harrier_cutout/front/thigh_fill_l.png` †
- `assets/units/harrier_cutout/front/thigh_fill_r.png` †
- `assets/units/harrier_cutout/front/torso.png` †
- `assets/units/harrier_cutout/front/waistcloth.png` †
- `assets/units/harrier_cutout/rear/arm_l.png` †
- `assets/units/harrier_cutout/rear/arm_r.png` †
- `assets/units/harrier_cutout/rear/foot_l.png` †
- `assets/units/harrier_cutout/rear/foot_r.png` †
- `assets/units/harrier_cutout/rear/hand_l.png` †
- `assets/units/harrier_cutout/rear/hand_r.png` †
- `assets/units/harrier_cutout/rear/head.png` †
- `assets/units/harrier_cutout/rear/hip_cap_l.png` †
- `assets/units/harrier_cutout/rear/hip_cap_r.png` †
- `assets/units/harrier_cutout/rear/leg_l.png` †
- `assets/units/harrier_cutout/rear/leg_r.png` †
- `assets/units/harrier_cutout/rear/pelvis_undercloth.png` †
- `assets/units/harrier_cutout/rear/shoulder_cap_l.png` †
- `assets/units/harrier_cutout/rear/shoulder_cap_r.png` †
- `assets/units/harrier_cutout/rear/spear.png` †
- `assets/units/harrier_cutout/rear/spine_undercloth.png` †
- `assets/units/harrier_cutout/rear/thigh_fill_l.png` †
- `assets/units/harrier_cutout/rear/thigh_fill_r.png` †
- `assets/units/harrier_cutout/rear/torso.png` †
- `assets/units/harrier_cutout/rear/waistcloth.png` †

### iskaldra

- `assets/units/iskaldra_cutout/front/arm_far.png` †
- `assets/units/iskaldra_cutout/front/arm_near.png` †
- `assets/units/iskaldra_cutout/front/arm_socket_far.png` †
- `assets/units/iskaldra_cutout/front/arm_socket_near.png` †
- `assets/units/iskaldra_cutout/front/foot_far.png` †
- `assets/units/iskaldra_cutout/front/foot_near.png` †
- `assets/units/iskaldra_cutout/front/head.png` †
- `assets/units/iskaldra_cutout/front/hip_fill_far.png` †
- `assets/units/iskaldra_cutout/front/hip_fill_near.png` †
- `assets/units/iskaldra_cutout/front/leg_far.png` †
- `assets/units/iskaldra_cutout/front/leg_near.png` †
- `assets/units/iskaldra_cutout/front/neck_socket.png` †
- `assets/units/iskaldra_cutout/front/tail.png` †
- `assets/units/iskaldra_cutout/front/tail_socket.png` †
- `assets/units/iskaldra_cutout/front/talon_far.png` †
- `assets/units/iskaldra_cutout/front/talon_near.png` †
- `assets/units/iskaldra_cutout/front/torso.png` †
- `assets/units/iskaldra_cutout/front/wing_far.png` †
- `assets/units/iskaldra_cutout/front/wing_near.png` †
- `assets/units/iskaldra_cutout/front/wing_socket_far.png` †
- `assets/units/iskaldra_cutout/front/wing_socket_near.png` †
- `assets/units/iskaldra_cutout/rear/arm_far.png` †
- `assets/units/iskaldra_cutout/rear/arm_near.png` †
- `assets/units/iskaldra_cutout/rear/arm_socket_far.png` †
- `assets/units/iskaldra_cutout/rear/arm_socket_near.png` †
- `assets/units/iskaldra_cutout/rear/foot_far.png` †
- `assets/units/iskaldra_cutout/rear/foot_near.png` †
- `assets/units/iskaldra_cutout/rear/head.png` †
- `assets/units/iskaldra_cutout/rear/hip_fill_far.png` †
- `assets/units/iskaldra_cutout/rear/hip_fill_near.png` †
- `assets/units/iskaldra_cutout/rear/leg_far.png` †
- `assets/units/iskaldra_cutout/rear/leg_near.png` †
- `assets/units/iskaldra_cutout/rear/neck_socket.png` †
- `assets/units/iskaldra_cutout/rear/pelvic_bridge.png` †
- `assets/units/iskaldra_cutout/rear/tail.png` †
- `assets/units/iskaldra_cutout/rear/tail_socket.png` †
- `assets/units/iskaldra_cutout/rear/talon_far.png` †
- `assets/units/iskaldra_cutout/rear/talon_near.png` †
- `assets/units/iskaldra_cutout/rear/torso.png` †
- `assets/units/iskaldra_cutout/rear/wing_far.png` †
- `assets/units/iskaldra_cutout/rear/wing_near.png` †
- `assets/units/iskaldra_cutout/rear/wing_socket_far.png` †
- `assets/units/iskaldra_cutout/rear/wing_socket_near.png` †

### lightning_wisp

- `assets/units/lightning_wisp_cutout/front/arc_left.png` †
- `assets/units/lightning_wisp_cutout/front/arc_right.png` †
- `assets/units/lightning_wisp_cutout/front/core.png` †
- `assets/units/lightning_wisp_cutout/front/crown.png` †
- `assets/units/lightning_wisp_cutout/front/tail.png` †
- `assets/units/lightning_wisp_cutout/rear/arc_left.png` †
- `assets/units/lightning_wisp_cutout/rear/arc_right.png` †
- `assets/units/lightning_wisp_cutout/rear/core.png` †
- `assets/units/lightning_wisp_cutout/rear/crown.png` †
- `assets/units/lightning_wisp_cutout/rear/tail.png` †

### noctyrax

- `assets/units/noctyrax_cutout/front/claw_fore_far.png` †
- `assets/units/noctyrax_cutout/front/claw_fore_near.png` †
- `assets/units/noctyrax_cutout/front/claw_hind_far.png` †
- `assets/units/noctyrax_cutout/front/claw_hind_near.png` †
- `assets/units/noctyrax_cutout/front/fore_far.png` †
- `assets/units/noctyrax_cutout/front/fore_near.png` †
- `assets/units/noctyrax_cutout/front/head.png` †
- `assets/units/noctyrax_cutout/front/hidden_fore_near.png` †
- `assets/units/noctyrax_cutout/front/hidden_wing_near.png` †
- `assets/units/noctyrax_cutout/front/hidden_wing_near_base.png` †
- `assets/units/noctyrax_cutout/front/hind_far.png` †
- `assets/units/noctyrax_cutout/front/hind_near.png` †
- `assets/units/noctyrax_cutout/front/neck.png` †
- `assets/units/noctyrax_cutout/front/tail.png` †
- `assets/units/noctyrax_cutout/front/torso.png` †
- `assets/units/noctyrax_cutout/front/wing_far.png` †
- `assets/units/noctyrax_cutout/front/wing_near.png` †
- `assets/units/noctyrax_cutout/rear/claw_fore_far.png` †
- `assets/units/noctyrax_cutout/rear/claw_fore_near.png` †
- `assets/units/noctyrax_cutout/rear/claw_hind_far.png` †
- `assets/units/noctyrax_cutout/rear/claw_hind_near.png` †
- `assets/units/noctyrax_cutout/rear/fore_far.png` †
- `assets/units/noctyrax_cutout/rear/fore_near.png` †
- `assets/units/noctyrax_cutout/rear/head.png` †
- `assets/units/noctyrax_cutout/rear/hidden_fore_near.png` †
- `assets/units/noctyrax_cutout/rear/hidden_wing_far.png` †
- `assets/units/noctyrax_cutout/rear/hidden_wing_near.png` †
- `assets/units/noctyrax_cutout/rear/hind_far.png` †
- `assets/units/noctyrax_cutout/rear/hind_near.png` †
- `assets/units/noctyrax_cutout/rear/neck.png` †
- `assets/units/noctyrax_cutout/rear/tail.png` †
- `assets/units/noctyrax_cutout/rear/torso.png` †
- `assets/units/noctyrax_cutout/rear/wing_far.png` †
- `assets/units/noctyrax_cutout/rear/wing_near.png` †

### tharokh

- `assets/units/tharokh_cutout/front/body_under_fore_far.png` †
- `assets/units/tharokh_cutout/front/body_under_fore_near.png` †
- `assets/units/tharokh_cutout/front/body_under_hind_far.png` †
- `assets/units/tharokh_cutout/front/body_under_hind_near.png` †
- `assets/units/tharokh_cutout/front/claw_fore_far.png` †
- `assets/units/tharokh_cutout/front/claw_fore_near.png` †
- `assets/units/tharokh_cutout/front/claw_hind_far.png` †
- `assets/units/tharokh_cutout/front/claw_hind_near.png` †
- `assets/units/tharokh_cutout/front/fore_far.png` †
- `assets/units/tharokh_cutout/front/fore_near.png` †
- `assets/units/tharokh_cutout/front/head.png` †
- `assets/units/tharokh_cutout/front/hind_far.png` †
- `assets/units/tharokh_cutout/front/hind_near.png` †
- `assets/units/tharokh_cutout/front/neck.png` †
- `assets/units/tharokh_cutout/front/tail.png` †
- `assets/units/tharokh_cutout/front/torso.png` †
- `assets/units/tharokh_cutout/front/wing_far.png` †
- `assets/units/tharokh_cutout/front/wing_near.png` †
- `assets/units/tharokh_cutout/rear/body_under_fore_far.png` †
- `assets/units/tharokh_cutout/rear/body_under_fore_near.png` †
- `assets/units/tharokh_cutout/rear/body_under_hind_far.png` †
- `assets/units/tharokh_cutout/rear/body_under_hind_near.png` †
- `assets/units/tharokh_cutout/rear/claw_fore_far.png` †
- `assets/units/tharokh_cutout/rear/claw_fore_near.png` †
- `assets/units/tharokh_cutout/rear/claw_hind_far.png` †
- `assets/units/tharokh_cutout/rear/claw_hind_near.png` †
- `assets/units/tharokh_cutout/rear/fore_far.png` †
- `assets/units/tharokh_cutout/rear/fore_near.png` †
- `assets/units/tharokh_cutout/rear/head.png` †
- `assets/units/tharokh_cutout/rear/hind_far.png` †
- `assets/units/tharokh_cutout/rear/hind_near.png` †
- `assets/units/tharokh_cutout/rear/neck.png` †
- `assets/units/tharokh_cutout/rear/tail.png` †
- `assets/units/tharokh_cutout/rear/torso.png` †
- `assets/units/tharokh_cutout/rear/wing_far.png` †
- `assets/units/tharokh_cutout/rear/wing_near.png` †

### vaeloryx

- `assets/units/vaeloryx_cutout/front/arm_cap_far.png` †
- `assets/units/vaeloryx_cutout/front/arm_cap_near.png` †
- `assets/units/vaeloryx_cutout/front/arm_far.png` †
- `assets/units/vaeloryx_cutout/front/arm_near.png` †
- `assets/units/vaeloryx_cutout/front/back_underwing.png` †
- `assets/units/vaeloryx_cutout/front/claw_far.png` †
- `assets/units/vaeloryx_cutout/front/claw_hind.png` †
- `assets/units/vaeloryx_cutout/front/claw_near.png` †
- `assets/units/vaeloryx_cutout/front/head.png` †
- `assets/units/vaeloryx_cutout/front/hind_cap.png` †
- `assets/units/vaeloryx_cutout/front/hind_limb.png` †
- `assets/units/vaeloryx_cutout/front/neck.png` †
- `assets/units/vaeloryx_cutout/front/tail.png` †
- `assets/units/vaeloryx_cutout/front/torso.png` †
- `assets/units/vaeloryx_cutout/front/wing_far.png` †
- `assets/units/vaeloryx_cutout/front/wing_near.png` †
- `assets/units/vaeloryx_cutout/front/wing_socket_far.png` †
- `assets/units/vaeloryx_cutout/front/wing_socket_near.png` †
- `assets/units/vaeloryx_cutout/rear/arm_cap_far.png` †
- `assets/units/vaeloryx_cutout/rear/arm_cap_near.png` †
- `assets/units/vaeloryx_cutout/rear/arm_far.png` †
- `assets/units/vaeloryx_cutout/rear/arm_near.png` †
- `assets/units/vaeloryx_cutout/rear/claw_far.png` †
- `assets/units/vaeloryx_cutout/rear/claw_hind.png` †
- `assets/units/vaeloryx_cutout/rear/claw_near.png` †
- `assets/units/vaeloryx_cutout/rear/head.png` †
- `assets/units/vaeloryx_cutout/rear/hind_cap.png` †
- `assets/units/vaeloryx_cutout/rear/hind_limb.png` †
- `assets/units/vaeloryx_cutout/rear/neck.png` †
- `assets/units/vaeloryx_cutout/rear/tail.png` †
- `assets/units/vaeloryx_cutout/rear/torso.png` †
- `assets/units/vaeloryx_cutout/rear/wing_far.png` †
- `assets/units/vaeloryx_cutout/rear/wing_near.png` †
- `assets/units/vaeloryx_cutout/rear/wing_socket_far.png` †
- `assets/units/vaeloryx_cutout/rear/wing_socket_near.png` †

### veilbound_acolyte

- `assets/units/veilbound_acolyte_cutout/front/cast_cap.png` (pixels unchanged)
- `assets/units/veilbound_acolyte_cutout/front/cast_hand.png` †
- `assets/units/veilbound_acolyte_cutout/front/cast_sleeve.png` †
- `assets/units/veilbound_acolyte_cutout/front/hood.png` †
- `assets/units/veilbound_acolyte_cutout/front/orb.png` †
- `assets/units/veilbound_acolyte_cutout/front/skirt_l.png` †
- `assets/units/veilbound_acolyte_cutout/front/skirt_r.png` †
- `assets/units/veilbound_acolyte_cutout/front/strike_cap.png` (pixels unchanged)
- `assets/units/veilbound_acolyte_cutout/front/strike_hand.png` †
- `assets/units/veilbound_acolyte_cutout/front/strike_sleeve.png` †
- `assets/units/veilbound_acolyte_cutout/front/torso.png` †
- `assets/units/veilbound_acolyte_cutout/front/under_cast.png` (pixels unchanged)
- `assets/units/veilbound_acolyte_cutout/front/under_strike.png` (pixels unchanged)
- `assets/units/veilbound_acolyte_cutout/front/under_strike_hand.png` †
- `assets/units/veilbound_acolyte_cutout/rear/cast_cap.png` (pixels unchanged)
- `assets/units/veilbound_acolyte_cutout/rear/cast_hand.png` †
- `assets/units/veilbound_acolyte_cutout/rear/cast_sleeve.png` †
- `assets/units/veilbound_acolyte_cutout/rear/hood.png` †
- `assets/units/veilbound_acolyte_cutout/rear/orb.png` †
- `assets/units/veilbound_acolyte_cutout/rear/skirt_l.png` †
- `assets/units/veilbound_acolyte_cutout/rear/skirt_r.png` †
- `assets/units/veilbound_acolyte_cutout/rear/strike_sleeve.png` †
- `assets/units/veilbound_acolyte_cutout/rear/torso.png` †
- `assets/units/veilbound_acolyte_cutout/rear/under_cast.png` (pixels unchanged)
- `assets/units/veilbound_acolyte_cutout/rear/under_strike.png` (pixels unchanged)

### vyraketh

- `assets/units/vyraketh_cutout/front/cap_fore_far.png` †
- `assets/units/vyraketh_cutout/front/cap_fore_near.png` †
- `assets/units/vyraketh_cutout/front/cap_hind_far.png` †
- `assets/units/vyraketh_cutout/front/cap_hind_near.png` †
- `assets/units/vyraketh_cutout/front/claw_fore_far.png` †
- `assets/units/vyraketh_cutout/front/claw_fore_near.png` †
- `assets/units/vyraketh_cutout/front/claw_hind_far.png` †
- `assets/units/vyraketh_cutout/front/claw_hind_near.png` †
- `assets/units/vyraketh_cutout/front/fore_far.png` †
- `assets/units/vyraketh_cutout/front/fore_near.png` †
- `assets/units/vyraketh_cutout/front/head.png` †
- `assets/units/vyraketh_cutout/front/hind_far.png` †
- `assets/units/vyraketh_cutout/front/hind_near.png` †
- `assets/units/vyraketh_cutout/front/jaw.png` †
- `assets/units/vyraketh_cutout/front/mouth_lining.png` †
- `assets/units/vyraketh_cutout/front/neck.png` †
- `assets/units/vyraketh_cutout/front/socket_fore_far.png` †
- `assets/units/vyraketh_cutout/front/socket_fore_near.png` †
- `assets/units/vyraketh_cutout/front/socket_hind_far.png` †
- `assets/units/vyraketh_cutout/front/socket_hind_near.png` †
- `assets/units/vyraketh_cutout/front/tail.png` †
- `assets/units/vyraketh_cutout/front/torso.png` †
- `assets/units/vyraketh_cutout/front/wing_far.png` †
- `assets/units/vyraketh_cutout/front/wing_near.png` †
- `assets/units/vyraketh_cutout/rear/cap_fore_far.png` †
- `assets/units/vyraketh_cutout/rear/cap_fore_near.png` †
- `assets/units/vyraketh_cutout/rear/cap_hind_far.png` †
- `assets/units/vyraketh_cutout/rear/cap_hind_near.png` †
- `assets/units/vyraketh_cutout/rear/claw_fore_far.png` †
- `assets/units/vyraketh_cutout/rear/claw_fore_near.png` †
- `assets/units/vyraketh_cutout/rear/claw_hind_far.png` †
- `assets/units/vyraketh_cutout/rear/claw_hind_near.png` †
- `assets/units/vyraketh_cutout/rear/fore_far.png` †
- `assets/units/vyraketh_cutout/rear/fore_near.png` †
- `assets/units/vyraketh_cutout/rear/head.png` †
- `assets/units/vyraketh_cutout/rear/hind_far.png` †
- `assets/units/vyraketh_cutout/rear/hind_near.png` †
- `assets/units/vyraketh_cutout/rear/jaw.png` †
- `assets/units/vyraketh_cutout/rear/mouth_lining.png` †
- `assets/units/vyraketh_cutout/rear/neck.png` †
- `assets/units/vyraketh_cutout/rear/socket_fore_far.png` †
- `assets/units/vyraketh_cutout/rear/socket_fore_near.png` †
- `assets/units/vyraketh_cutout/rear/socket_hind_far.png` †
- `assets/units/vyraketh_cutout/rear/socket_hind_near.png` †
- `assets/units/vyraketh_cutout/rear/tail.png` †
- `assets/units/vyraketh_cutout/rear/torso.png` †
- `assets/units/vyraketh_cutout/rear/wing_far.png` †
- `assets/units/vyraketh_cutout/rear/wing_near.png` †

### zekarion

- `assets/units/zekarion_cutout/front/cap_head.png` †
- `assets/units/zekarion_cutout/front/cap_jaw.png` †
- `assets/units/zekarion_cutout/front/cap_tail_base.png` †
- `assets/units/zekarion_cutout/front/cap_upper_far.png` †
- `assets/units/zekarion_cutout/front/cap_upper_near.png` †
- `assets/units/zekarion_cutout/front/cap_wing_far.png` †
- `assets/units/zekarion_cutout/front/cap_wing_near.png` †
- `assets/units/zekarion_cutout/front/claw_far.png` †
- `assets/units/zekarion_cutout/front/claw_near.png` †
- `assets/units/zekarion_cutout/front/foot_far.png` †
- `assets/units/zekarion_cutout/front/foot_near.png` †
- `assets/units/zekarion_cutout/front/foreleg_far.png` †
- `assets/units/zekarion_cutout/front/foreleg_near.png` †
- `assets/units/zekarion_cutout/front/head.png` †
- `assets/units/zekarion_cutout/front/hindleg_far.png` †
- `assets/units/zekarion_cutout/front/hindleg_near.png` †
- `assets/units/zekarion_cutout/front/jaw.png` †
- `assets/units/zekarion_cutout/front/neck.png` †
- `assets/units/zekarion_cutout/front/tail.png` †
- `assets/units/zekarion_cutout/front/torso.png` †
- `assets/units/zekarion_cutout/front/wing_far.png` †
- `assets/units/zekarion_cutout/front/wing_near.png` †
- `assets/units/zekarion_cutout/rear/cap_head.png` (pixels unchanged)
- `assets/units/zekarion_cutout/rear/cap_jaw.png` (pixels unchanged)
- `assets/units/zekarion_cutout/rear/cap_upper_far.png` (pixels unchanged)
- `assets/units/zekarion_cutout/rear/cap_upper_near.png` (pixels unchanged)
- `assets/units/zekarion_cutout/rear/cap_wing_far.png` (pixels unchanged)
- `assets/units/zekarion_cutout/rear/cap_wing_near.png` (pixels unchanged)
- `assets/units/zekarion_cutout/rear/claw_far.png` †
- `assets/units/zekarion_cutout/rear/claw_near.png` †
- `assets/units/zekarion_cutout/rear/foot_far.png` †
- `assets/units/zekarion_cutout/rear/foot_near.png` †
- `assets/units/zekarion_cutout/rear/foreleg_far.png` †
- `assets/units/zekarion_cutout/rear/foreleg_near.png` †
- `assets/units/zekarion_cutout/rear/head.png` †
- `assets/units/zekarion_cutout/rear/hindleg_far.png` †
- `assets/units/zekarion_cutout/rear/hindleg_near.png` †
- `assets/units/zekarion_cutout/rear/jaw.png` †
- `assets/units/zekarion_cutout/rear/neck.png` †
- `assets/units/zekarion_cutout/rear/tail.png` †
- `assets/units/zekarion_cutout/rear/torso.png` †
- `assets/units/zekarion_cutout/rear/wing_far.png` †
- `assets/units/zekarion_cutout/rear/wing_near.png` †

### ash_hound

- `assets/units/guardians/ash_hound/front/body.png` †
- `assets/units/guardians/ash_hound/front/foot_fore_far.png` †
- `assets/units/guardians/ash_hound/front/foot_fore_near.png` †
- `assets/units/guardians/ash_hound/front/foot_hind_far.png` †
- `assets/units/guardians/ash_hound/front/foot_hind_near.png` †
- `assets/units/guardians/ash_hound/front/head.png` †
- `assets/units/guardians/ash_hound/front/leg_fore_far.png` †
- `assets/units/guardians/ash_hound/front/leg_fore_near.png` †
- `assets/units/guardians/ash_hound/front/leg_hind_far.png` †
- `assets/units/guardians/ash_hound/front/leg_hind_near.png` †
- `assets/units/guardians/ash_hound/front/tail.png` †
- `assets/units/guardians/ash_hound/rear/body.png` †
- `assets/units/guardians/ash_hound/rear/foot_fore_far.png` †
- `assets/units/guardians/ash_hound/rear/foot_fore_near.png` †
- `assets/units/guardians/ash_hound/rear/foot_hind_far.png` †
- `assets/units/guardians/ash_hound/rear/foot_hind_near.png` †
- `assets/units/guardians/ash_hound/rear/head.png` †
- `assets/units/guardians/ash_hound/rear/leg_fore_far.png` †
- `assets/units/guardians/ash_hound/rear/leg_fore_near.png` †
- `assets/units/guardians/ash_hound/rear/leg_hind_far.png` †
- `assets/units/guardians/ash_hound/rear/leg_hind_near.png` †
- `assets/units/guardians/ash_hound/rear/tail.png` †

### ashen_reaver

- `assets/units/guardians/ashen_reaver/front/arm_far.png` †
- `assets/units/guardians/ashen_reaver/front/arm_near.png` †
- `assets/units/guardians/ashen_reaver/front/blade.png` †
- `assets/units/guardians/ashen_reaver/front/body.png` †
- `assets/units/guardians/ashen_reaver/front/drape.png` †
- `assets/units/guardians/ashen_reaver/front/foot_far.png` †
- `assets/units/guardians/ashen_reaver/front/foot_near.png` †
- `assets/units/guardians/ashen_reaver/front/hand_far.png` †
- `assets/units/guardians/ashen_reaver/front/hand_near.png` †
- `assets/units/guardians/ashen_reaver/front/head.png` †
- `assets/units/guardians/ashen_reaver/front/leg_far.png` †
- `assets/units/guardians/ashen_reaver/front/leg_near.png` †
- `assets/units/guardians/ashen_reaver/rear/arm_far.png` †
- `assets/units/guardians/ashen_reaver/rear/arm_near.png` †
- `assets/units/guardians/ashen_reaver/rear/blade.png` †
- `assets/units/guardians/ashen_reaver/rear/body.png` †
- `assets/units/guardians/ashen_reaver/rear/drape.png` †
- `assets/units/guardians/ashen_reaver/rear/foot_far.png` †
- `assets/units/guardians/ashen_reaver/rear/foot_near.png` †
- `assets/units/guardians/ashen_reaver/rear/hand_far.png` (pixels unchanged)
- `assets/units/guardians/ashen_reaver/rear/hand_near.png` †
- `assets/units/guardians/ashen_reaver/rear/head.png` †
- `assets/units/guardians/ashen_reaver/rear/leg_far.png` †
- `assets/units/guardians/ashen_reaver/rear/leg_near.png` †

### bell_tender

- `assets/units/guardians/bell_tender/front/arm_far.png` †
- `assets/units/guardians/bell_tender/front/arm_near.png` †
- `assets/units/guardians/bell_tender/front/body.png` †
- `assets/units/guardians/bell_tender/front/drape.png` †
- `assets/units/guardians/bell_tender/front/foot_far.png` †
- `assets/units/guardians/bell_tender/front/foot_near.png` †
- `assets/units/guardians/bell_tender/front/hand_far.png` †
- `assets/units/guardians/bell_tender/front/hand_near.png` †
- `assets/units/guardians/bell_tender/front/head.png` †
- `assets/units/guardians/bell_tender/front/leg_far.png` †
- `assets/units/guardians/bell_tender/front/leg_near.png` †
- `assets/units/guardians/bell_tender/front/spear.png` †
- `assets/units/guardians/bell_tender/rear/arm_far.png` †
- `assets/units/guardians/bell_tender/rear/arm_near.png` †
- `assets/units/guardians/bell_tender/rear/body.png` †
- `assets/units/guardians/bell_tender/rear/drape.png` †
- `assets/units/guardians/bell_tender/rear/foot_far.png` †
- `assets/units/guardians/bell_tender/rear/foot_near.png` †
- `assets/units/guardians/bell_tender/rear/hand_far.png` †
- `assets/units/guardians/bell_tender/rear/hand_near.png` †
- `assets/units/guardians/bell_tender/rear/head.png` †
- `assets/units/guardians/bell_tender/rear/leg_far.png` †
- `assets/units/guardians/bell_tender/rear/leg_near.png` †
- `assets/units/guardians/bell_tender/rear/spear.png` †

### craghide

- `assets/units/guardians/craghide/front/body.png` †
- `assets/units/guardians/craghide/front/foot_fore_far.png` †
- `assets/units/guardians/craghide/front/foot_fore_near.png` †
- `assets/units/guardians/craghide/front/foot_hind_far.png` †
- `assets/units/guardians/craghide/front/foot_hind_near.png` †
- `assets/units/guardians/craghide/front/head.png` †
- `assets/units/guardians/craghide/front/leg_fore_far.png` †
- `assets/units/guardians/craghide/front/leg_fore_near.png` †
- `assets/units/guardians/craghide/front/leg_hind_far.png` †
- `assets/units/guardians/craghide/front/leg_hind_near.png` †
- `assets/units/guardians/craghide/front/tail.png` †
- `assets/units/guardians/craghide/rear/body.png` †
- `assets/units/guardians/craghide/rear/foot_fore_far.png` †
- `assets/units/guardians/craghide/rear/foot_fore_near.png` †
- `assets/units/guardians/craghide/rear/foot_hind_far.png` †
- `assets/units/guardians/craghide/rear/foot_hind_near.png` †
- `assets/units/guardians/craghide/rear/head.png` †
- `assets/units/guardians/craghide/rear/leg_fore_far.png` †
- `assets/units/guardians/craghide/rear/leg_fore_near.png` †
- `assets/units/guardians/craghide/rear/leg_hind_far.png` †
- `assets/units/guardians/craghide/rear/leg_hind_near.png` †
- `assets/units/guardians/craghide/rear/tail.png` †

### gallows_roc

- `assets/units/guardians/gallows_roc/front/body.png` †
- `assets/units/guardians/gallows_roc/front/foot_far.png` †
- `assets/units/guardians/gallows_roc/front/foot_near.png` †
- `assets/units/guardians/gallows_roc/front/head.png` †
- `assets/units/guardians/gallows_roc/front/leg_far.png` †
- `assets/units/guardians/gallows_roc/front/leg_near.png` †
- `assets/units/guardians/gallows_roc/front/tail.png` †
- `assets/units/guardians/gallows_roc/front/wing_far.png` †
- `assets/units/guardians/gallows_roc/front/wing_near.png` †
- `assets/units/guardians/gallows_roc/rear/body.png` †
- `assets/units/guardians/gallows_roc/rear/foot_far.png` †
- `assets/units/guardians/gallows_roc/rear/foot_near.png` †
- `assets/units/guardians/gallows_roc/rear/head.png` †
- `assets/units/guardians/gallows_roc/rear/leg_far.png` †
- `assets/units/guardians/gallows_roc/rear/leg_near.png` †
- `assets/units/guardians/gallows_roc/rear/tail.png` †
- `assets/units/guardians/gallows_roc/rear/wing_far.png` †
- `assets/units/guardians/gallows_roc/rear/wing_near.png` †

### last_lamplighter

- `assets/units/guardians/last_lamplighter/front/arm_far.png` †
- `assets/units/guardians/last_lamplighter/front/arm_near.png` †
- `assets/units/guardians/last_lamplighter/front/body.png` †
- `assets/units/guardians/last_lamplighter/front/drape.png` †
- `assets/units/guardians/last_lamplighter/front/foot_far.png` †
- `assets/units/guardians/last_lamplighter/front/foot_near.png` †
- `assets/units/guardians/last_lamplighter/front/hand_far.png` †
- `assets/units/guardians/last_lamplighter/front/hand_near.png` †
- `assets/units/guardians/last_lamplighter/front/head.png` †
- `assets/units/guardians/last_lamplighter/front/lantern.png` †
- `assets/units/guardians/last_lamplighter/front/leg_far.png` †
- `assets/units/guardians/last_lamplighter/front/leg_near.png` †
- `assets/units/guardians/last_lamplighter/rear/arm_far.png` †
- `assets/units/guardians/last_lamplighter/rear/arm_near.png` †
- `assets/units/guardians/last_lamplighter/rear/body.png` †
- `assets/units/guardians/last_lamplighter/rear/drape.png` †
- `assets/units/guardians/last_lamplighter/rear/foot_far.png` †
- `assets/units/guardians/last_lamplighter/rear/foot_near.png` †
- `assets/units/guardians/last_lamplighter/rear/hand_far.png` †
- `assets/units/guardians/last_lamplighter/rear/hand_near.png` †
- `assets/units/guardians/last_lamplighter/rear/head.png` †
- `assets/units/guardians/last_lamplighter/rear/lantern.png` †
- `assets/units/guardians/last_lamplighter/rear/leg_far.png` †
- `assets/units/guardians/last_lamplighter/rear/leg_near.png` †

### rime_spitter

- `assets/units/guardians/rime_spitter/front/body.png` †
- `assets/units/guardians/rime_spitter/front/foot_fore_far.png` †
- `assets/units/guardians/rime_spitter/front/foot_fore_near.png` †
- `assets/units/guardians/rime_spitter/front/foot_hind_near.png` †
- `assets/units/guardians/rime_spitter/front/head.png` †
- `assets/units/guardians/rime_spitter/front/leg_fore_far.png` †
- `assets/units/guardians/rime_spitter/front/leg_fore_near.png` †
- `assets/units/guardians/rime_spitter/front/leg_hind_near.png` †
- `assets/units/guardians/rime_spitter/front/tail.png` †
- `assets/units/guardians/rime_spitter/front/throat.png` †
- `assets/units/guardians/rime_spitter/rear/body.png` †
- `assets/units/guardians/rime_spitter/rear/foot_fore_near.png` †
- `assets/units/guardians/rime_spitter/rear/foot_hind_far.png` †
- `assets/units/guardians/rime_spitter/rear/foot_hind_near.png` †
- `assets/units/guardians/rime_spitter/rear/head.png` †
- `assets/units/guardians/rime_spitter/rear/leg_fore_near.png` †
- `assets/units/guardians/rime_spitter/rear/leg_hind_far.png` †
- `assets/units/guardians/rime_spitter/rear/leg_hind_near.png` †
- `assets/units/guardians/rime_spitter/rear/tail.png` †
- `assets/units/guardians/rime_spitter/rear/throat.png` †

### rime_whelp

- `assets/units/guardians/rime_whelp/front/body.png` †
- `assets/units/guardians/rime_whelp/front/foot_fore_far.png` †
- `assets/units/guardians/rime_whelp/front/foot_fore_near.png` †
- `assets/units/guardians/rime_whelp/front/foot_hind_far.png` †
- `assets/units/guardians/rime_whelp/front/foot_hind_near.png` †
- `assets/units/guardians/rime_whelp/front/head.png` †
- `assets/units/guardians/rime_whelp/front/leg_fore_far.png` †
- `assets/units/guardians/rime_whelp/front/leg_fore_near.png` †
- `assets/units/guardians/rime_whelp/front/leg_hind_far.png` †
- `assets/units/guardians/rime_whelp/front/leg_hind_near.png` †
- `assets/units/guardians/rime_whelp/front/tail.png` †
- `assets/units/guardians/rime_whelp/rear/body.png` †
- `assets/units/guardians/rime_whelp/rear/foot_fore_far.png` †
- `assets/units/guardians/rime_whelp/rear/foot_fore_near.png` †
- `assets/units/guardians/rime_whelp/rear/foot_hind_far.png` †
- `assets/units/guardians/rime_whelp/rear/foot_hind_near.png` †
- `assets/units/guardians/rime_whelp/rear/head.png` †
- `assets/units/guardians/rime_whelp/rear/leg_fore_far.png` †
- `assets/units/guardians/rime_whelp/rear/leg_fore_near.png` †
- `assets/units/guardians/rime_whelp/rear/leg_hind_far.png` †
- `assets/units/guardians/rime_whelp/rear/leg_hind_near.png` †
- `assets/units/guardians/rime_whelp/rear/tail.png` †

### rimejaw

- `assets/units/guardians/rimejaw/front/body.png` †
- `assets/units/guardians/rimejaw/front/foot_fore_far.png` †
- `assets/units/guardians/rimejaw/front/foot_fore_near.png` †
- `assets/units/guardians/rimejaw/front/foot_hind_near.png` †
- `assets/units/guardians/rimejaw/front/head.png` †
- `assets/units/guardians/rimejaw/front/leg_fore_far.png` †
- `assets/units/guardians/rimejaw/front/leg_fore_near.png` †
- `assets/units/guardians/rimejaw/front/leg_hind_near.png` †
- `assets/units/guardians/rimejaw/front/tail.png` †
- `assets/units/guardians/rimejaw/rear/body.png` †
- `assets/units/guardians/rimejaw/rear/foot_fore_far.png` †
- `assets/units/guardians/rimejaw/rear/foot_fore_near.png` †
- `assets/units/guardians/rimejaw/rear/foot_hind_far.png` †
- `assets/units/guardians/rimejaw/rear/foot_hind_near.png` †
- `assets/units/guardians/rimejaw/rear/head.png` †
- `assets/units/guardians/rimejaw/rear/leg_fore_far.png` †
- `assets/units/guardians/rimejaw/rear/leg_fore_near.png` †
- `assets/units/guardians/rimejaw/rear/leg_hind_far.png` †
- `assets/units/guardians/rimejaw/rear/leg_hind_near.png` †
- `assets/units/guardians/rimejaw/rear/tail.png` †

### roc_fledgling

- `assets/units/guardians/roc_fledgling/front/body.png` †
- `assets/units/guardians/roc_fledgling/front/foot_far.png` †
- `assets/units/guardians/roc_fledgling/front/foot_near.png` †
- `assets/units/guardians/roc_fledgling/front/head.png` †
- `assets/units/guardians/roc_fledgling/front/leg_far.png` †
- `assets/units/guardians/roc_fledgling/front/leg_near.png` †
- `assets/units/guardians/roc_fledgling/front/tail.png` †
- `assets/units/guardians/roc_fledgling/front/wing_far.png` †
- `assets/units/guardians/roc_fledgling/front/wing_near.png` †
- `assets/units/guardians/roc_fledgling/rear/body.png` †
- `assets/units/guardians/roc_fledgling/rear/foot_far.png` †
- `assets/units/guardians/roc_fledgling/rear/foot_near.png` †
- `assets/units/guardians/roc_fledgling/rear/head.png` †
- `assets/units/guardians/roc_fledgling/rear/leg_far.png` †
- `assets/units/guardians/roc_fledgling/rear/leg_near.png` †
- `assets/units/guardians/roc_fledgling/rear/tail.png` †
- `assets/units/guardians/roc_fledgling/rear/wing_far.png` †
- `assets/units/guardians/roc_fledgling/rear/wing_near.png` †

### stoneback_mite

- `assets/units/guardians/stoneback_mite/front/body.png` †
- `assets/units/guardians/stoneback_mite/front/foot_front_far.png` †
- `assets/units/guardians/stoneback_mite/front/foot_front_near.png` †
- `assets/units/guardians/stoneback_mite/front/foot_hind_near.png` †
- `assets/units/guardians/stoneback_mite/front/foot_middle_near.png` †
- `assets/units/guardians/stoneback_mite/front/head.png` †
- `assets/units/guardians/stoneback_mite/front/leg_front_far.png` †
- `assets/units/guardians/stoneback_mite/front/leg_front_near.png` †
- `assets/units/guardians/stoneback_mite/front/leg_hind_near.png` †
- `assets/units/guardians/stoneback_mite/front/leg_middle_near.png` †
- `assets/units/guardians/stoneback_mite/rear/body.png` †
- `assets/units/guardians/stoneback_mite/rear/foot_front_near.png` †
- `assets/units/guardians/stoneback_mite/rear/foot_hind_far.png` †
- `assets/units/guardians/stoneback_mite/rear/foot_hind_near.png` †
- `assets/units/guardians/stoneback_mite/rear/foot_middle_far.png` †
- `assets/units/guardians/stoneback_mite/rear/foot_middle_near.png` †
- `assets/units/guardians/stoneback_mite/rear/leg_front_near.png` †
- `assets/units/guardians/stoneback_mite/rear/leg_hind_far.png` †
- `assets/units/guardians/stoneback_mite/rear/leg_hind_near.png` †
- `assets/units/guardians/stoneback_mite/rear/leg_middle_far.png` †
- `assets/units/guardians/stoneback_mite/rear/leg_middle_near.png` †

### storm_cantor

- `assets/units/guardians/storm_cantor/front/arm_far.png` †
- `assets/units/guardians/storm_cantor/front/arm_near.png` †
- `assets/units/guardians/storm_cantor/front/body.png` †
- `assets/units/guardians/storm_cantor/front/drape.png` †
- `assets/units/guardians/storm_cantor/front/foot_far.png` †
- `assets/units/guardians/storm_cantor/front/foot_near.png` †
- `assets/units/guardians/storm_cantor/front/hand_far.png` †
- `assets/units/guardians/storm_cantor/front/hand_near.png` (pixels unchanged)
- `assets/units/guardians/storm_cantor/front/head.png` †
- `assets/units/guardians/storm_cantor/front/leg_far.png` †
- `assets/units/guardians/storm_cantor/front/leg_near.png` †
- `assets/units/guardians/storm_cantor/front/spear.png` †
- `assets/units/guardians/storm_cantor/rear/arm_far.png` †
- `assets/units/guardians/storm_cantor/rear/arm_near.png` †
- `assets/units/guardians/storm_cantor/rear/body.png` †
- `assets/units/guardians/storm_cantor/rear/drape.png` †
- `assets/units/guardians/storm_cantor/rear/foot_far.png` †
- `assets/units/guardians/storm_cantor/rear/foot_near.png` †
- `assets/units/guardians/storm_cantor/rear/hand_far.png` †
- `assets/units/guardians/storm_cantor/rear/hand_near.png` †
- `assets/units/guardians/storm_cantor/rear/head.png` †
- `assets/units/guardians/storm_cantor/rear/leg_far.png` †
- `assets/units/guardians/storm_cantor/rear/leg_near.png` †
- `assets/units/guardians/storm_cantor/rear/spear.png` †

### wick_shade

- `assets/units/guardians/wick_shade/front/arm_far.png` †
- `assets/units/guardians/wick_shade/front/arm_near.png` †
- `assets/units/guardians/wick_shade/front/body.png` †
- `assets/units/guardians/wick_shade/front/drape.png` †
- `assets/units/guardians/wick_shade/front/foot_far.png` †
- `assets/units/guardians/wick_shade/front/foot_near.png` †
- `assets/units/guardians/wick_shade/front/hand_far.png` †
- `assets/units/guardians/wick_shade/front/hand_near.png` †
- `assets/units/guardians/wick_shade/front/head.png` †
- `assets/units/guardians/wick_shade/front/leg_far.png` †
- `assets/units/guardians/wick_shade/front/leg_near.png` †
- `assets/units/guardians/wick_shade/rear/arm_far.png` †
- `assets/units/guardians/wick_shade/rear/arm_near.png` †
- `assets/units/guardians/wick_shade/rear/body.png` †
- `assets/units/guardians/wick_shade/rear/drape.png` †
- `assets/units/guardians/wick_shade/rear/foot_far.png` †
- `assets/units/guardians/wick_shade/rear/foot_near.png` †
- `assets/units/guardians/wick_shade/rear/hand_far.png` †
- `assets/units/guardians/wick_shade/rear/hand_near.png` †
- `assets/units/guardians/wick_shade/rear/head.png` †
- `assets/units/guardians/wick_shade/rear/leg_far.png` †
- `assets/units/guardians/wick_shade/rear/leg_near.png` †

### column_torch_idle

- `assets/art/tiles/column_torch_left_idle.png` †
- `assets/art/tiles/column_torch_right_idle.png` †

### column_torch_static

- `assets/art/tiles/column_torch_left.png` †
- `assets/art/tiles/column_torch_right.png` †

### campfire

- `assets/art/tiles/campfire_bonfire.png` †

### campfire_idle

- `assets/art/tiles/campfire_bonfire_idle.png` †

### door

- `assets/placeholders/tiles/door.png` †

### door_opening

- `assets/placeholders/tiles/door_opening.png` †

### watch_brazier

- `assets/props/guardians/watch_brazier_dark.png` †

### scavenger_stall

- `assets/art/tiles/scavenger_stall.png` †

### scavenger_npc

- `assets/art/npcs/scavenger.png` †

### dropped_embers

- `assets/art/tiles/dropped_embers.png` †

### emaciated_man_idle

- `assets/placeholders/units/emaciated_man_anime_trial_idle.png` †

### wooden_box

- `assets/art/tiles/wooden_box.png` †

### wooden_box_destroy

- `assets/art/tiles/wooden_box_destroy.png` †

### wooden_crate

- `assets/art/tiles/wooden_crate.png` †

### wooden_crate_destroy

- `assets/art/tiles/wooden_crate_destroy.png` †

### powder_keg

- `assets/art/tiles/powder_keg.png` †

### relic_chest

- `assets/art/tiles/relic_chest.png` †

### relic_chest_opening

- `assets/art/props/relic_chest_hinge_v1/body.png` †
- `assets/art/props/relic_chest_hinge_v1/lid_exterior.png` †
- `assets/art/props/relic_chest_hinge_v1/lid_interior.png` †
- `assets/art/props/relic_chest_hinge_v1/cavity.png` †

### pillar

- `assets/placeholders/tiles/pillar.png` †

### moss_pillar_overlay

- `assets/placeholders/tiles/moss_overlays/moss_pillar_overlay_01.png` †

### floor_tiles

- `assets/placeholders/tiles/base_floor_tile_02.png` †
- `assets/placeholders/tiles/base_floor_tile_03.png` †
- `assets/placeholders/tiles/base_floor_tile_05.png` †
- `assets/placeholders/tiles/base_floor_tile_06.png` †

### moss_floor_overlays

- `assets/placeholders/tiles/moss_overlays/moss_floor_overlay_01.png` †
- `assets/placeholders/tiles/moss_overlays/moss_floor_overlay_02.png` †

### fire_floor_overlay_01

- `assets/placeholders/tiles/element_overlays/fire/fire_floor_overlay_01.png` †

### fire_floor_overlay_02

- `assets/placeholders/tiles/element_overlays/fire/fire_floor_overlay_02.png` †

### ice_floor_overlay_01

- `assets/placeholders/tiles/element_overlays/ice/ice_floor_overlay_01.png` †

### ice_floor_overlay_02

- `assets/placeholders/tiles/element_overlays/ice/ice_floor_overlay_02.png` †

### lightning_floor_overlay_01

- `assets/placeholders/tiles/element_overlays/lightning/lightning_floor_overlay_01.png` †

### lightning_floor_overlay_02

- `assets/placeholders/tiles/element_overlays/lightning/lightning_floor_overlay_02.png` †

### air_floor_overlay_01

- `assets/placeholders/tiles/element_overlays/air/air_floor_overlay_01.png` †

### air_floor_overlay_02

- `assets/placeholders/tiles/element_overlays/air/air_floor_overlay_02.png` †

### trap_air

- `assets/art/traps/trap_air.png` †

### trap_air_sheets

- `assets/art/traps/trap_air_idle.png` †
- `assets/art/traps/trap_air_activation.png` †

### trap_earth

- `assets/art/traps/trap_earth.png` †

### trap_earth_sheets

- `assets/art/traps/trap_earth_idle.png` †
- `assets/art/traps/trap_earth_activation.png` †

### trap_fire

- `assets/art/traps/trap_fire.png` †

### trap_fire_sheets

- `assets/art/traps/trap_fire_idle.png` †
- `assets/art/traps/trap_fire_activation.png` †

### trap_ice

- `assets/art/traps/trap_ice.png` †

### trap_ice_sheets

- `assets/art/traps/trap_ice_idle.png` †
- `assets/art/traps/trap_ice_activation.png` †

### trap_lightning

- `assets/art/traps/trap_lightning.png` †

### trap_lightning_sheets

- `assets/art/traps/trap_lightning_idle.png` †
- `assets/art/traps/trap_lightning_activation.png` †

### ember_floor

- `assets/art/tiles/ember.png` †

### stone_floor_fallback

- `assets/art/tiles/stone.png` †

### hero_rear

- `assets/units/protagonist_cutout/rear/arm_l.png` †
- `assets/units/protagonist_cutout/rear/arm_r.png` †
- `assets/units/protagonist_cutout/rear/cape_drape.png` †
- `assets/units/protagonist_cutout/rear/foot_l.png` †
- `assets/units/protagonist_cutout/rear/foot_r.png` †
- `assets/units/protagonist_cutout/rear/head.png` †
- `assets/units/protagonist_cutout/rear/hips.png` †
- `assets/units/protagonist_cutout/rear/knee_cover_l.png` †
- `assets/units/protagonist_cutout/rear/knee_cover_r.png` †
- `assets/units/protagonist_cutout/rear/mantle_far.png` †
- `assets/units/protagonist_cutout/rear/mantle_near.png` †
- `assets/units/protagonist_cutout/rear/pelvis_underlay.png` †
- `assets/units/protagonist_cutout/rear/scarf.png` †
- `assets/units/protagonist_cutout/rear/shin_l.png` †
- `assets/units/protagonist_cutout/rear/shin_r.png` †
- `assets/units/protagonist_cutout/rear/thigh_l.png` †
- `assets/units/protagonist_cutout/rear/thigh_r.png` †
- `assets/units/protagonist_cutout/rear/torso.png` †

