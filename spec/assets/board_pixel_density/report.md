# Board pixel-density report

All measurements are at native resolution; orphan share uses alpha > 0 and threshold 24.
Native is the untouched front rest (rig) or first frame of the first path (prop).
Before/after are arithmetic means over the first frame of each registered painted part/path.
After is derived from sources in memory; it does not claim a GPU rest rebake or visual approval.
Horizontal runs are multiplied by r for the relative on-screen block size.

| Entry | r | t | grid | mode | Native orphan / run | Before orphan / run | After orphan / run | Screen run before → after |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: |
| Hero front (reference, untouched) | 1 | — | — | reference | 7.30% / 2.321 | 7.30% / 2.321 | 7.30% / 2.321 | 2.321 → 2.321 |
| warden | 1.180000 | 1.5 | 1.27 | regrid | 17.25% / 1.613 | 23.15% / 1.553 | 6.84% / 2.071 | 1.832 → 2.444 |
| crawler | 0.640000 | 1.0 | 1.56 | regrid | 7.14% / 2.110 | 9.74% / 2.228 | 5.29% / 2.741 | 1.426 → 1.754 |
| acolyte | 1.000000 | 1.0 | 1.00 | clean | 5.01% / 2.359 | 8.49% / 2.378 | 5.32% / 2.468 | 2.378 → 2.468 |
| bile_bloomer | 0.860000 | 1.5 | 1.74 | regrid | 35.69% / 1.334 | 36.58% / 1.314 | 7.13% / 2.332 | 1.130 → 2.006 |
| chainbound_gaoler | 0.900000 | 1.0 | 1.11 | clean | 7.17% / 2.271 | 11.57% / 2.082 | 5.12% / 2.300 | 1.874 → 2.070 |
| cinder_droplet | 0.560000 | 1.5 | 2.68 | regrid | 18.38% / 1.700 | 20.69% / 1.602 | 4.12% / 3.339 | 0.897 → 1.870 |
| cinder_ooze | 0.820000 | 1.5 | 1.83 | regrid | 18.28% / 1.707 | 19.23% / 1.891 | 5.32% / 2.929 | 1.550 → 2.402 |
| frostglass_lancer | 1.000000 | 1.0 | 1.00 | clean | 6.65% / 2.077 | 15.29% / 1.680 | 6.91% / 1.851 | 1.680 → 1.851 |
| grave_surgeon | 0.980000 | 1.5 | 1.53 | regrid | 20.19% / 1.670 | 21.78% / 2.897 | 4.84% / 3.570 | 2.839 → 3.499 |
| harrier | 1.000000 | 1.5 | 1.50 | regrid | 34.33% / 1.325 | 47.36% / 1.239 | 18.76% / 1.770 | 1.239 → 1.770 |
| iskaldra | 1.780000 | 1.5 | 0.84 | clean | 50.65% / 1.181 | 58.18% / 1.153 | 32.64% / 1.364 | 2.052 → 2.427 |
| lightning_wisp | 0.680000 | 1.5 | 1.50 | regrid | 39.71% / 1.523 | 61.45% / 1.217 | 27.96% / 1.679 | 0.827 → 1.142 |
| noctyrax | 1.860000 | 1.5 | 0.81 | clean | 26.67% / 1.484 | 31.17% / 1.456 | 15.10% / 1.726 | 2.708 → 3.211 |
| tharokh | 1.780000 | 1.5 | 0.84 | clean | 29.52% / 1.395 | 30.36% / 1.406 | 12.20% / 1.705 | 2.502 → 3.036 |
| vaeloryx | 1.820000 | 1.5 | 0.82 | clean | 39.54% / 1.312 | 49.68% / 1.224 | 27.73% / 1.462 | 2.227 → 2.661 |
| veilbound_acolyte | 1.000000 | 1.0 | 1.00 | clean | 5.01% / 2.359 | 7.33% / 2.756 | 4.41% / 2.839 | 2.756 → 2.839 |
| vyraketh | 1.760000 | 1.5 | 0.85 | clean | 38.27% / 1.316 | 37.71% / 1.424 | 21.72% / 1.673 | 2.506 → 2.944 |
| zekarion | 1.920000 | 1.5 | 0.78 | clean | 42.08% / 1.288 | 43.41% / 1.268 | 27.92% / 1.452 | 2.435 → 2.788 |
| ash_hound | 0.750000 | 1.0 | 1.33 | regrid | 10.16% / 1.703 | 12.87% / 1.656 | 4.80% / 2.121 | 1.242 → 1.591 |
| ashen_reaver | 1.150000 | 1.0 | 0.87 | clean | 8.26% / 1.902 | 7.50% / 1.939 | 3.96% / 2.035 | 2.230 → 2.341 |
| bell_tender | 0.750000 | 1.0 | 1.33 | regrid | 7.24% / 1.843 | 11.39% / 1.765 | 4.42% / 2.207 | 1.324 → 1.655 |
| craghide | 1.150000 | 1.0 | 0.87 | clean | 9.09% / 1.779 | 9.85% / 1.781 | 3.74% / 1.918 | 2.049 → 2.205 |
| gallows_roc | 1.150000 | 1.5 | 1.30 | regrid | 21.73% / 1.455 | 33.26% / 1.308 | 9.76% / 1.837 | 1.504 → 2.113 |
| last_lamplighter | 1.150000 | 1.5 | 1.30 | regrid | 18.34% / 1.430 | 19.88% / 1.396 | 5.49% / 1.777 | 1.605 → 2.043 |
| rime_spitter | 0.750000 | 1.0 | 1.33 | regrid | 6.38% / 1.829 | 8.81% / 1.756 | 4.54% / 2.088 | 1.317 → 1.566 |
| rime_whelp | 0.750000 | 1.0 | 1.33 | regrid | 4.57% / 1.887 | 5.99% / 1.901 | 3.53% / 2.222 | 1.426 → 1.666 |
| rimejaw | 1.150000 | 1.5 | 1.30 | regrid | 20.17% / 1.448 | 23.54% / 1.425 | 7.12% / 1.911 | 1.639 → 2.198 |
| roc_fledgling | 0.750000 | 1.0 | 1.33 | regrid | 8.51% / 1.891 | 25.01% / 1.524 | 8.52% / 2.032 | 1.143 → 1.524 |
| stoneback_mite | 0.750000 | 1.0 | 1.33 | regrid | 1.54% / 2.221 | 2.91% / 1.916 | 2.59% / 2.034 | 1.437 → 1.525 |
| storm_cantor | 1.150000 | 1.5 | 1.30 | regrid | 28.86% / 1.335 | 35.89% / 1.276 | 15.14% / 1.687 | 1.467 → 1.940 |
| wick_shade | 0.750000 | 1.0 | 1.33 | regrid | 2.76% / 2.081 | 6.33% / 1.898 | 2.68% / 2.220 | 1.424 → 1.665 |
| column_torch_idle | 0.351510 | 1.0 | 2.84 | regrid | 0.00% / 5.130 | 0.00% / 5.130 | 0.00% / 4.939 | 1.803 → 1.736 |
| column_torch_static | 1.406039 | 1.5 | 1.07 | clean | 29.83% / 1.266 | 30.41% / 1.258 | 10.85% / 1.495 | 1.769 → 2.101 |
| campfire | 0.322568 | 1.0 | 3.10 | regrid | 0.00% / 7.181 | 0.00% / 7.181 | 0.00% / 7.341 | 2.316 → 2.368 |
| campfire_idle | 0.322568 | 1.0 | 3.10 | regrid | 0.00% / 7.181 | 0.00% / 7.181 | 0.00% / 7.341 | 2.316 → 2.368 |
| door | 1.359223 | 1.0 | 0.74 | clean | 6.81% / 2.200 | 6.81% / 2.200 | 1.19% / 2.441 | 2.991 → 3.318 |
| door_opening | 0.649288 | 1.0 | 1.54 | regrid | 1.45% / 3.888 | 1.45% / 3.888 | 0.43% / 4.859 | 2.525 → 3.155 |
| watch_brazier | 0.582524 | 1.0 | 1.72 | regrid | 3.33% / 3.184 | 3.33% / 3.184 | 0.28% / 4.067 | 1.855 → 2.369 |
| scavenger_stall | 1.114078 | 1.5 | 1.35 | regrid | 34.46% / 1.368 | 34.46% / 1.368 | 4.46% / 2.158 | 1.524 → 2.404 |
| scavenger_npc | 0.920000 | 1.5 | 1.00 | clean | 29.14% / 1.426 | 29.14% / 1.426 | 8.26% / 1.799 | 1.312 → 1.655 |
| dropped_embers | 0.876820 | 1.5 | 1.71 | regrid | 51.95% / 1.236 | 51.95% / 1.236 | 3.77% / 2.244 | 1.084 → 1.967 |
| emaciated_man_idle | 0.230000 | 1.0 | 4.35 | regrid | 0.00% / 9.280 | 0.00% / 9.280 | 0.00% / 10.552 | 2.135 → 2.427 |
| wooden_box | 1.237864 | 1.0 | 0.81 | clean | 10.71% / 1.868 | 10.71% / 1.868 | 1.76% / 2.181 | 2.312 → 2.700 |
| wooden_box_destroy | 1.237864 | 1.0 | 0.81 | clean | 10.32% / 2.170 | 10.32% / 2.170 | 2.14% / 2.593 | 2.687 → 3.209 |
| wooden_crate | 1.237864 | 1.0 | 0.81 | clean | 12.55% / 1.819 | 12.55% / 1.819 | 3.03% / 2.125 | 2.251 → 2.631 |
| wooden_crate_destroy | 1.237864 | 1.0 | 0.81 | clean | 10.48% / 2.043 | 10.48% / 2.043 | 2.02% / 2.467 | 2.529 → 3.054 |
| powder_keg | 1.237864 | 1.5 | 1.21 | clean | 21.82% / 1.630 | 21.82% / 1.630 | 6.23% / 2.015 | 2.018 → 2.495 |
| relic_chest | 1.753641 | 1.5 | 0.86 | clean | 26.64% / 1.522 | 26.64% / 1.522 | 8.24% / 1.878 | 2.668 → 3.293 |
| relic_chest_opening | 1.753641 | 1.5 | 0.86 | clean | 23.91% / 1.548 | 23.65% / 2.129 | 9.77% / 2.622 | 3.734 → 4.598 |
| pillar | 1.376746 | 1.0 | 0.73 | clean | 3.64% / 2.940 | 3.64% / 2.940 | 0.55% / 3.222 | 4.047 → 4.435 |
| moss_pillar_overlay | 1.888109 | 1.0 | 0.53 | clean | 13.47% / 1.705 | 13.47% / 1.705 | 11.92% / 1.737 | 3.220 → 3.280 |
| floor_tiles | 2.029285 | 1.0 | 0.49 | clean | 3.58% / 4.779 | 4.97% / 4.246 | 1.14% / 5.080 | 8.617 → 10.310 |
| moss_floor_overlays | 2.029285 | 1.5 | 0.74 | clean | 25.25% / 1.357 | 19.18% / 1.527 | 13.74% / 1.608 | 3.099 → 3.264 |
| fire_floor_overlays | 2.029285 | 1.5 | 0.74 | clean | 67.28% / 1.164 | 64.08% / 1.175 | 50.60% / 1.307 | 2.384 → 2.652 |
| ice_floor_overlays | 2.029285 | 1.5 | 0.74 | clean | 74.32% / 1.094 | 54.68% / 1.440 | 48.86% / 1.541 | 2.922 → 3.126 |
| lightning_floor_overlays | 2.029285 | 1.5 | 0.74 | clean | 17.93% / 1.688 | 26.19% / 1.513 | 21.37% / 1.584 | 3.069 → 3.214 |
| air_floor_overlays | 2.029285 | 1.5 | 0.74 | clean | 33.33% / 1.352 | 26.51% / 1.575 | 20.76% / 1.689 | 3.196 → 3.428 |
| trap_air | 2.029285 | 1.5 | 0.74 | clean | 33.42% / 1.455 | 33.42% / 1.455 | 6.80% / 2.062 | 2.953 → 4.184 |
| trap_air_sheets | 2.029285 | 1.5 | 0.74 | clean | 33.43% / 1.454 | 33.42% / 1.455 | 6.85% / 2.060 | 2.952 → 4.179 |
| trap_earth | 2.029285 | 1.5 | 0.74 | clean | 28.70% / 1.616 | 28.70% / 1.616 | 4.90% / 2.265 | 3.280 → 4.596 |
| trap_earth_sheets | 2.029285 | 1.5 | 0.74 | clean | 28.82% / 1.613 | 28.80% / 1.614 | 4.99% / 2.261 | 3.276 → 4.588 |
| trap_fire | 2.029285 | 1.5 | 0.74 | clean | 35.08% / 1.450 | 35.08% / 1.450 | 10.11% / 2.018 | 2.942 → 4.095 |
| trap_fire_sheets | 2.029285 | 1.5 | 0.74 | clean | 34.14% / 1.453 | 33.85% / 1.460 | 8.80% / 2.033 | 2.963 → 4.126 |
| trap_ice | 2.029285 | 1.5 | 0.74 | clean | 30.81% / 1.549 | 30.81% / 1.549 | 4.94% / 2.251 | 3.143 → 4.568 |
| trap_ice_sheets | 2.029285 | 1.5 | 0.74 | clean | 30.49% / 1.591 | 30.79% / 1.569 | 5.46% / 2.253 | 3.183 → 4.572 |
| trap_lightning | 2.029285 | 1.5 | 0.74 | clean | 35.89% / 1.431 | 35.89% / 1.431 | 9.19% / 2.002 | 2.904 → 4.062 |
| trap_lightning_sheets | 2.029285 | 1.5 | 0.74 | clean | 35.51% / 1.438 | 35.53% / 1.435 | 9.58% / 1.977 | 2.912 → 4.013 |
| ember_floor | 2.029285 | 1.5 | 0.74 | clean | 38.05% / 1.435 | 38.05% / 1.435 | 16.38% / 1.836 | 2.912 → 3.726 |
| stone_floor_fallback | 2.029285 | 1.5 | 0.74 | clean | 38.13% / 1.365 | 38.13% / 1.365 | 11.88% / 1.828 | 2.769 → 3.710 |
| hero_rear | 1.000000 | 1.0 | 1.00 | clean | 7.63% / 2.216 | 8.91% / 2.221 | 3.02% / 2.418 | 2.221 → 2.418 |

## Scale mismatches for owner decision

Entries with r > 1.25 already draw larger pixels than the hero. They receive native cleanup;
only a higher-resolution repaint could match the hero exactly. No draw-code change is made.

- `iskaldra`: r = 1.780000, clean.
- `noctyrax`: r = 1.860000, clean.
- `tharokh`: r = 1.780000, clean.
- `vaeloryx`: r = 1.820000, clean.
- `vyraketh`: r = 1.760000, clean.
- `zekarion`: r = 1.920000, clean.
- `column_torch_static`: r = 1.406039, clean.
- `door`: r = 1.359223, clean.
- `relic_chest`: r = 1.753641, clean.
- `relic_chest_opening`: r = 1.753641, clean.
- `pillar`: r = 1.376746, clean.
- `moss_pillar_overlay`: r = 1.888109, clean.
- `floor_tiles`: r = 2.029285, clean.
- `moss_floor_overlays`: r = 2.029285, clean.
- `fire_floor_overlays`: r = 2.029285, clean.
- `ice_floor_overlays`: r = 2.029285, clean.
- `lightning_floor_overlays`: r = 2.029285, clean.
- `air_floor_overlays`: r = 2.029285, clean.
- `trap_air`: r = 2.029285, clean.
- `trap_air_sheets`: r = 2.029285, clean.
- `trap_earth`: r = 2.029285, clean.
- `trap_earth_sheets`: r = 2.029285, clean.
- `trap_fire`: r = 2.029285, clean.
- `trap_fire_sheets`: r = 2.029285, clean.
- `trap_ice`: r = 2.029285, clean.
- `trap_ice_sheets`: r = 2.029285, clean.
- `trap_lightning`: r = 2.029285, clean.
- `trap_lightning_sheets`: r = 2.029285, clean.
- `ember_floor`: r = 2.029285, clean.
- `stone_floor_fallback`: r = 2.029285, clean.

## Production files per entry

Listed paths are regenerated. A † marks an image whose decoded pixels change from its source.

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
- `assets/units/chainbound_gaoler_cutout/rear/wrist_strap.png` (pixels unchanged)

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

### fire_floor_overlays

- `assets/placeholders/tiles/element_overlays/fire/fire_floor_overlay_01.png` †
- `assets/placeholders/tiles/element_overlays/fire/fire_floor_overlay_02.png` †

### ice_floor_overlays

- `assets/placeholders/tiles/element_overlays/ice/ice_floor_overlay_01.png` †
- `assets/placeholders/tiles/element_overlays/ice/ice_floor_overlay_02.png` †

### lightning_floor_overlays

- `assets/placeholders/tiles/element_overlays/lightning/lightning_floor_overlay_01.png` †
- `assets/placeholders/tiles/element_overlays/lightning/lightning_floor_overlay_02.png` †

### air_floor_overlays

- `assets/placeholders/tiles/element_overlays/air/air_floor_overlay_01.png` †
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

