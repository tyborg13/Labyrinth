# TODO_DESIGN_NEAR_PALETTE

All entries remain unchanged. No new palette tokens were invented. Nearest token uses CIE76 ΔE*ab in CIELAB (D65, sRGB transfer function), computed from the original uncomposited RGB; alpha is preserved in the value column but excluded from perceptual distance. HDR tint channels above 1 use the same transfer function without clamping. This inventories every non-neutral literal RGB occurrence, including dynamic-alpha colours which the lint does not count. Repeated occurrences have separate rows.

`Color("090706")` differs from `TEXT_OUTLINE` (`#0a0706`) by exactly one red-channel step. It is retained because it is a different hex value and replacing it would violate the brief's zero-pixel-difference requirement. The director can decide whether to authorize that change in a follow-up.

Existing outline rectangles remain: `labyrinth_map_view.gd:1255` (badge outline), `skill_tree_view.gd:238` and `skill_tree_view.gd:386` (lock glyph outlines). The available gilded/plate helpers add geometry, fills, or different antialiasing; no pixel-equivalent replacement exists within the owned helper scope.

| File:line | Unchanged value | Nearest UiPalette token | ΔE76 |
| --- | --- | --- | ---: |
| `scripts/labyrinth_map_view.gd:14` | `Color("d8b96f")` | `GOLD_BRIGHT` | 8.6937 |
| `scripts/labyrinth_map_view.gd:15` | `Color("8c7462")` | `TEXT_3` | 5.3759 |
| `scripts/labyrinth_map_view.gd:16` | `Color("d9854c")` | `EMBER` | 12.6959 |
| `scripts/labyrinth_map_view.gd:17` | `Color("89a862")` | `SUCCESS` | 17.7069 |
| `scripts/labyrinth_map_view.gd:18` | `Color("b75643")` | `DANGER` | 14.0968 |
| `scripts/labyrinth_map_view.gd:19` | `Color("b47a4e")` | `GOLD` | 18.7241 |
| `scripts/labyrinth_map_view.gd:21` | `Color("5f6462")` | `TEXT_3` | 13.2088 |
| `scripts/labyrinth_map_view.gd:22` | `Color(0.70, 0.73, 0.69, 0.78)` | `TEXT_2` | 14.7219 |
| `scripts/labyrinth_map_view.gd:23` | `Color("d8c79d")` | `EVENT_GAIN` | 12.3730 |
| `scripts/labyrinth_map_view.gd:58` | `Color("ff9d39")` | `EMBER` | 11.2896 |
| `scripts/labyrinth_map_view.gd:61` | `Color("ff9d39")` | `EMBER` | 11.2896 |
| `scripts/labyrinth_map_view.gd:62` | `Color("ffe39a")` | `GOLD_BRIGHT` | 7.1050 |
| `scripts/labyrinth_map_view.gd:63` | `Color("fff0b8")` | `EVENT_GAIN` | 12.9521 |
| `scripts/labyrinth_map_view.gd:73` | `Color(0.84, 0.77, 0.69, 0.88)` | `TEXT` | 11.0076 |
| `scripts/labyrinth_map_view.gd:74` | `Color(0.70, 0.64, 0.59, 0.72)` | `TEXT_2` | 7.7515 |
| `scripts/labyrinth_map_view.gd:76` | `Color("b88b4a")` | `GOLD` | 8.7075 |
| `scripts/labyrinth_map_view.gd:77` | `Color("dbc9a6")` | `TEXT` | 10.3561 |
| `scripts/labyrinth_map_view.gd:78` | `Color(0.030, 0.022, 0.020, 0.94)` | `TEXT_OUTLINE` | 0.5396 |
| `scripts/labyrinth_map_view.gd:781` | `Color("090706")` | `TEXT_OUTLINE` | 0.2833 |
| `scripts/labyrinth_map_view.gd:810` | `Color(0.012, 0.009, 0.008, veil_alpha)` | `TEXT_OUTLINE` | 1.5636 |
| `scripts/labyrinth_map_view.gd:812` | `Color(0.11, 0.055, 0.018, 0.026)` | `INK_2` | 4.6469 |
| `scripts/labyrinth_map_view.gd:879` | `Color(0.025, 0.018, 0.014, 0.68)` | `TEXT_OUTLINE` | 0.8059 |
| `scripts/labyrinth_map_view.gd:1005` | `Color(0.035, 0.018, 0.004, 0.66)` | `TEXT_OUTLINE` | 1.2658 |
| `scripts/labyrinth_map_view.gd:1009` | `Color(1.0, 0.70, 0.27, 0.18 + 0.30 * _travel_progress)` | `EMBER` | 19.1081 |
| `scripts/labyrinth_map_view.gd:1017` | `Color(1.0, 0.74, 0.28, alpha)` | `EVENT_BLESSING` | 22.9029 |
| `scripts/labyrinth_map_view.gd:1021` | `Color(1.0, 0.34, 0.08, 0.18 + 0.16 * flare)` | `EMBER` | 33.4770 |
| `scripts/labyrinth_map_view.gd:1027` | `Color(1.0, 0.54, 0.13, 0.42)` | `EMBER` | 15.7923 |
| `scripts/labyrinth_map_view.gd:1064` | `Color(1.0, 0.76, 0.39, 0.22)` | `EVENT_BLESSING` | 14.4412 |
| `scripts/labyrinth_map_view.gd:1066` | `Color(1.0, 0.73, 0.30, 0.30)` | `EVENT_BLESSING` | 21.9555 |
| `scripts/labyrinth_map_view.gd:1080` | `Color("1b1917")` | `INK_2` | 3.4625 |
| `scripts/labyrinth_map_view.gd:1085` | `Color(0.012, 0.010, 0.009, 0.98)` | `TEXT_OUTLINE` | 1.5444 |
| `scripts/labyrinth_map_view.gd:1087` | `Color(0.58, 0.56, 0.53, 0.58)` | `TEXT_3` | 12.4360 |
| `scripts/labyrinth_map_view.gd:1089` | `Color(1.10, 1.06, 0.98, 1.0)` | `TEXT` | 15.4815 |
| `scripts/labyrinth_map_view.gd:1172` | `Color(0.035, 0.030, 0.028, 0.94)` | `INK_0` | 0.4946 |
| `scripts/labyrinth_map_view.gd:1173` | `Color(0.62, 0.56, 0.49, 0.72)` | `TEXT_2` | 9.4925 |
| `scripts/labyrinth_map_view.gd:1175` | `Color(0.72, 0.64, 0.55, 0.78)` | `TEXT_2` | 2.7550 |
| `scripts/labyrinth_map_view.gd:1176` | `Color(0.72, 0.64, 0.55, 0.78)` | `TEXT_2` | 2.7550 |
| `scripts/labyrinth_map_view.gd:1191` | `Color("17120d")` | `INK_1` | 1.2990 |
| `scripts/labyrinth_map_view.gd:1195` | `Color("8c7462")` | `TEXT_3` | 5.3759 |
| `scripts/labyrinth_map_view.gd:1208` | `Color(0.055, 0.050, 0.045, 0.88)` | `INK_0` | 1.0739 |
| `scripts/labyrinth_map_view.gd:1220` | `Color(0.06, 0.035, 0.02, 0.92)` | `TEXT_OUTLINE` | 1.7710 |
| `scripts/labyrinth_map_view.gd:1254` | `Color(0.035, 0.025, 0.020, 0.94)` | `TEXT_OUTLINE` | 0.2635 |
| `scripts/labyrinth_map_view.gd:1275` | `Color(0.86, 0.73, 0.52, 0.94)` | `EVENT_GAIN` | 8.7116 |
| `scripts/labyrinth_map_view.gd:1292` | `Color("d9cbb2")` | `TEXT` | 8.4091 |
| `scripts/labyrinth_map_view.gd:1296` | `Color(0.86, 0.73, 0.52, 0.94)` | `EVENT_GAIN` | 8.7116 |
| `scripts/labyrinth_map_view.gd:1316` | `Color("d9cbb2")` | `TEXT` | 8.4091 |
| `scripts/labyrinth_map_view.gd:1325` | `Color(0.72, 0.65, 0.55, 0.78)` | `TEXT_2` | 1.1803 |
| `scripts/labyrinth_map_view.gd:1326` | `Color(0.72, 0.65, 0.55, 0.78)` | `TEXT_2` | 1.1803 |
| `scripts/labyrinth_map_view.gd:1373` | `Color(0.024, 0.018, 0.016, 0.985)` | `TEXT_OUTLINE` | 0.8636 |
| `scripts/labyrinth_map_view.gd:1380` | `Color("fff0ce")` | `TEXT` | 5.8832 |
| `scripts/labyrinth_map_view.gd:1388` | `Color(0.70, 0.62, 0.51, 0.92)` | `TEXT_2` | 3.0333 |
| `scripts/labyrinth_map_view.gd:1389` | `Color("d9cbb2")` | `TEXT` | 8.4091 |
| `scripts/labyrinth_map_view.gd:1563` | `Color(0.025, 0.020, 0.016, 0.66)` | `TEXT_OUTLINE` | 0.7847 |
| `scripts/labyrinth_map_view.gd:1564` | `Color("d4a052")` | `GOLD` | 8.3862 |
| `scripts/labyrinth_map_view.gd:1564` | `Color("bd8140")` | `GOLD` | 14.9308 |
| `scripts/labyrinth_map_view.gd:1564` | `Color("8b7860")` | `TEXT_3` | 6.0187 |
| `scripts/labyrinth_map_view.gd:1565` | `Color(0.27, 0.23, 0.20, 0.50)` | `LINE` | 5.5685 |
| `scripts/labyrinth_map_view.gd:1570` | `Color(0.02, 0.014, 0.008, 0.88)` | `TEXT_OUTLINE` | 1.1352 |
| `scripts/labyrinth_map_view.gd:1571` | `Color("d4a052")` | `GOLD` | 8.3862 |
| `scripts/labyrinth_map_view.gd:1572` | `Color(1.0, 0.88, 0.62, 0.84)` | `GOLD_BRIGHT` | 6.4175 |
| `scripts/labyrinth_map_view.gd:1574` | `Color(0.02, 0.014, 0.008, 0.82)` | `TEXT_OUTLINE` | 1.1352 |
| `scripts/labyrinth_map_view.gd:1575` | `Color("bd8140")` | `GOLD` | 14.9308 |
| `scripts/labyrinth_map_view.gd:1577` | `Color(0.02, 0.018, 0.016, 0.72)` | `TEXT_OUTLINE` | 1.0705 |
| `scripts/labyrinth_map_view.gd:1578` | `Color(0.48, 0.40, 0.31, 0.78)` | `TEXT_3` | 7.1530 |
| `scripts/labyrinth_map_view.gd:1580` | `Color(0.39, 0.35, 0.31, 0.56)` | `TEXT_3` | 10.7163 |
| `scripts/skill_tree_view.gd:46` | `Color("d7a85d")` | `GOLD` | 5.8449 |
| `scripts/skill_tree_view.gd:47` | `Color("d17a72")` | `EVENT_COST` | 8.3174 |
| `scripts/skill_tree_view.gd:48` | `Color("79b9a5")` | `ALLY` | 10.2210 |
| `scripts/skill_tree_view.gd:49` | `Color("b994d0")` | `EVENT_BANE` | 22.3012 |
| `scripts/skill_tree_view.gd:50` | `Color("e7c85f")` | `EVENT_BLESSING` | 9.0538 |
| `scripts/skill_tree_view.gd:51` | `Color("e5cf9b")` | `EVENT_GAIN` | 6.4637 |
| `scripts/skill_tree_view.gd:83` | `Color("4a434d")` | `LINE` | 16.1914 |
| `scripts/skill_tree_view.gd:85` | `Color(0.025, 0.02, 0.027, 0.95)` | `TEXT_OUTLINE` | 1.3402 |
| `scripts/skill_tree_view.gd:96` | `Color(1.0, 0.87, 0.57, confirmation_strength * 0.65)` | `GOLD_BRIGHT` | 6.1129 |
| `scripts/skill_tree_view.gd:168` | `Color("4a434d")` | `LINE` | 16.1914 |
| `scripts/skill_tree_view.gd:170` | `Color(0.025, 0.02, 0.027, 0.98)` | `TEXT_OUTLINE` | 1.3402 |
| `scripts/skill_tree_view.gd:211` | `Color("68636d")` | `TEXT_3` | 16.8775 |
| `scripts/skill_tree_view.gd:221` | `Color(0.025, 0.02, 0.03, 0.98)` | `TEXT_OUTLINE` | 1.6010 |
| `scripts/skill_tree_view.gd:248` | `Color("b99a6b")` | `GOLD` | 12.0977 |
| `scripts/skill_tree_view.gd:285` | `Color("fff4d8")` | `TEXT` | 5.8707 |
| `scripts/skill_tree_view.gd:287` | `Color("ffd47a")` | `EVENT_BLESSING` | 5.0974 |
| `scripts/skill_tree_view.gd:289` | `Color("8ce1d5")` | `ALLY` | 15.3228 |
| `scripts/skill_tree_view.gd:290` | `Color(0.02, 0.015, 0.02, 0.94)` | `TEXT_OUTLINE` | 1.3842 |
| `scripts/skill_tree_view.gd:296` | `Color(1.0, 0.76, 0.32, confirmation_strength * 0.20)` | `EVENT_BLESSING` | 19.1189 |
| `scripts/skill_tree_view.gd:297` | `Color(1.0, 0.94, 0.73, confirmation_strength * 0.88)` | `EVENT_GAIN` | 13.4023 |
| `scripts/skill_tree_view.gd:303` | `Color("77737b")` | `TEXT_3` | 14.5956 |
| `scripts/skill_tree_view.gd:305` | `Color(0.02, 0.015, 0.02, 0.98)` | `TEXT_OUTLINE` | 1.3842 |
| `scripts/skill_tree_view.gd:320` | `Color(0.015, 0.012, 0.019, 0.80)` | `TEXT_OUTLINE` | 1.7209 |
| `scripts/skill_tree_view.gd:373` | `Color(0.025, 0.02, 0.03, 0.98)` | `TEXT_OUTLINE` | 1.6010 |
| `scripts/skill_tree_view.gd:413` | `Color("e6b85f")` | `EVENT_BLESSING` | 10.7394 |
| `scripts/skill_tree_view.gd:415` | `Color("7dd7ca")` | `ALLY` | 11.5002 |
| `scripts/skill_tree_view.gd:417` | `Color("70b9f2")` | `STEEL` | 12.8851 |
| `scripts/skill_tree_view.gd:419` | `Color("dc7186")` | `EVENT_COST` | 18.4479 |
| `scripts/skill_tree_view.gd:421` | `Color("68636d")` | `TEXT_3` | 16.8775 |
| `scripts/skill_tree_view.gd:426` | `Color("65461f")` | `GOLD_DIM` | 12.4395 |
| `scripts/skill_tree_view.gd:428` | `Color("173a35")` | `LINE` | 19.5931 |
| `scripts/skill_tree_view.gd:430` | `Color("174665")` | `LINE` | 32.8082 |
| `scripts/skill_tree_view.gd:432` | `Color("3c1b25")` | `INK_3` | 16.1369 |
| `scripts/skill_tree_view.gd:434` | `Color("17151a")` | `INK_1` | 5.6468 |
| `scripts/skill_tree_view.gd:865` | `Color("756245")` | `GOLD_DIM` | 4.7390 |
| `scripts/skill_tree_view.gd:866` | `Color("756245")` | `GOLD_DIM` | 4.7390 |
| `scripts/skill_tree_view.gd:889` | `Color("f2e6d1")` | `TEXT` | 3.3281 |
| `scripts/skill_tree_view.gd:894` | `Color("d6bc87")` | `EVENT_GAIN` | 8.3897 |
| `scripts/skill_tree_view.gd:1057` | `Color("8c6f49")` | `GOLD_DIM` | 5.8830 |
| `scripts/skill_tree_view.gd:1090` | `Color("f5ead4")` | `TEXT` | 3.6540 |
| `scripts/skill_tree_view.gd:1101` | `Color("ddcfb7")` | `TEXT` | 7.0489 |
| `scripts/skill_tree_view.gd:1111` | `Color("c9b998")` | `TEXT_2` | 7.8025 |
| `scripts/skill_tree_view.gd:1119` | `Color("c9b998")` | `TEXT_2` | 7.8025 |
| `scripts/skill_tree_view.gd:1126` | `Color("a8c9c1")` | `TEXT` | 22.4536 |
| `scripts/skill_tree_view.gd:1251` | `Color("413b43")` | `LINE` | 13.4724 |
| `scripts/skill_tree_view.gd:1541` | `Color("b99a6b")` | `GOLD` | 12.0977 |
| `scripts/skill_tree_view.gd:1546` | `Color("e6b85f")` | `EVENT_BLESSING` | 10.7394 |
| `scripts/skill_tree_view.gd:1548` | `Color("7dd7ca")` | `ALLY` | 11.5002 |
| `scripts/skill_tree_view.gd:1550` | `Color("dc7186")` | `EVENT_COST` | 18.4479 |
| `scripts/skill_tree_view.gd:1552` | `Color("57535b")` | `TEXT_3` | 19.6324 |
| `scripts/skill_tree_view.gd:1922` | `Color(0.055, 0.042, 0.052, 0.97)` | `INK_0` | 1.7563 |
| `scripts/section_map_node.gd:82` | `Color(1.0, 0.73, 0.33, 0.19 - ring * 0.04)` | `EVENT_BLESSING` | 20.0545 |
| `scripts/section_map_node.gd:83` | `Color("21190f")` | `INK_2` | 3.1454 |
| `scripts/section_map_node.gd:84` | `Color("ffda8d")` | `GOLD_BRIGHT` | 5.8057 |
| `scripts/section_map_node.gd:89` | `Color("ffdfa0")` | `EVENT_GAIN` | 6.5847 |
| `scripts/section_map_node.gd:91` | `Color("0c0b0e")` | `INK_0` | 1.9000 |
| `scripts/section_map_node.gd:91` | `Color("0c0b0e")` | `INK_0` | 1.9000 |
| `scripts/section_map_node.gd:92` | `Color(1.2, 1.08, 0.86)` | `TEXT` | 23.5974 |
| `scripts/section_map_node.gd:92` | `Color("d5b877")` | `EVENT_GAIN` | 8.3059 |
| `scripts/section_map_node.gd:92` | `Color("9b8c70")` | `TEXT_2` | 9.6110 |
| `scripts/section_map_node.gd:93` | `Color("5b5961")` | `TEXT_3` | 18.3568 |
| `scripts/section_map_node.gd:94` | `Color("7a7880")` | `TEXT_3` | 14.9522 |
| `scripts/section_map_node.gd:102` | `Color("ffe4a2")` | `EVENT_GAIN` | 7.4804 |
| `scripts/section_map_node.gd:102` | `Color("686471")` | `TEXT_3` | 18.4625 |
| `scripts/section_map_node.gd:102` | `Color("45424d")` | `LINE` | 16.7041 |
| `scripts/section_map_node.gd:106` | `Color("fff0c0")` | `TEXT` | 11.4557 |
| `scripts/section_map_node.gd:106` | `Color("9c94a4")` | `STEEL` | 20.3494 |
| `scripts/section_map_node.gd:106` | `Color("625c6a")` | `TEXT_3` | 20.0832 |
| `scripts/section_map_node.gd:109` | `Color("090c0c")` | `INK_0` | 1.5829 |
| `scripts/section_map_node.gd:110` | `Color("b7c1ad")` | `TEXT_2` | 13.9841 |
| `scripts/section_map_node.gd:112` | `Color("18211d")` | `INK_2` | 8.7309 |
| `scripts/section_map_node.gd:113` | `Color("b7c1ad")` | `TEXT_2` | 13.9841 |
| `scripts/section_map_node.gd:114` | `Color("e0e6cf")` | `TEXT` | 7.0715 |
| `scripts/section_map_node.gd:118` | `Color("100f15")` | `INK_0` | 4.4930 |
| `scripts/section_map_node.gd:119` | `Color("fff0c0")` | `TEXT` | 11.4557 |
| `scripts/section_map_node.gd:120` | `Color("100f15")` | `INK_0` | 4.4930 |
| `scripts/section_map_node.gd:121` | `Color("fff0c0")` | `TEXT` | 11.4557 |
| `scripts/section_map_node.gd:124` | `Color(1.0, 0.94, 0.76, 1.0 - activation_progress * 0.7)` | `TEXT` | 10.4942 |
| `scripts/section_map_node.gd:128` | `Color("fff2cd")` | `TEXT` | 7.1044 |
| `scripts/section_map_node.gd:130` | `Color("f8dfaa")` | `EVENT_GAIN` | 8.3365 |
| `scripts/section_map_node.gd:131` | `Color("f8dfaa")` | `EVENT_GAIN` | 8.3365 |
| `scripts/section_map_node.gd:134` | `Color("160b05")` | `INK_1` | 3.0764 |
| `scripts/section_map_node.gd:135` | `Color("e1a457")` | `GOLD` | 11.7381 |
| `scripts/section_map_node.gd:144` | `Color("89868c")` | `TEXT_3` | 15.4981 |
| `scripts/section_map_node.gd:146` | `Color("bbb1a8")` | `TEXT_2` | 11.1468 |
| `scripts/section_map_node.gd:147` | `Color("99948c")` | `TEXT_2` | 13.2486 |
| `scripts/section_map_node.gd:148` | `Color("504e56")` | `LINE` | 18.4115 |
