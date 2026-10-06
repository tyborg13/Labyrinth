# Visible-gear slice painted assets: sources and provenance

Generated 2026-10-05 with Codex's built-in image generation tool (`codex exec`,
Codex CLI 0.160.0) in three dedicated image runs (hands, armor, feet and
trinkets), each supplied with the hero at 6× (front and rear), the item's
inventory icon, and either a placement guide (attachments: the exact angle,
proportions and bounding box on the rest pose) or the replaced part's own
silhouette at 12–16× on green (armor and boots). Claude, the slice's design
owner, reviewed every output composited on the hero at native and board scale
before approving it.

`sources/` holds the untouched image-run outputs under their canonical names.
Revised items ship their second take: the Cracked Lantern (v1 vanished against
the leather; v2 has a blackened cage and a strong amber core), the Parrying Dagger
(v1 reduced to a 2-px line; v2 has a broad blade and full-width guard) and the
rear far sleeve of Undertaker Plate (v1 was pale sky-blue; v2 matches the
gunmetal set). `sources/concepts/` keeps the four armor concept repaints that
fixed each set's look before its pieces were painted; they do not ship.

**Round 2 (owner review 2026-10-06).** The shields and the parrying dagger
were repainted: the shields are strapped side-on to the forearm and larger, and
the dagger's grip runs through the fist with the pommel above and the guard
below. The new sources replace the round-1 files of the same names. Each boot
gained shin pieces carrying the full boot shaft, painted from new lower-leg
concepts so the whole boot changes. The round-2 prompts are in
`provenance/hands_round2_provenance.md` and
`provenance/boots_round2_provenance.md`. Every texture is then consolidated at
native size to match the hero's pixel density (posterise to 24 colours, 3×3
mode filter, orphan cleanup; see the tool's `consolidate`). The owner found the
raw reductions too fine and "high res" beside the chunky hero, and chose this
treatment over a Kuwahara filter after comparing both on the hero. Shields ship at 1.5×
their round-2 size.

**Full pass (2026-10-06).** Every one of the 72 items now has art: 16 more image runs, the per-run records under `provenance/full_*`. Redone after design-owner review:
- Galewhip: the cord was too thin.
- Parrying Dagger: now gripped through the fist, with the fist cut out at derivation.
- Basalt Pavise: read as a lattice.
- Grapple Hook: too small.
- Trapdoor Spurs and Cloudstep Sandals: too close to other boots.
- The long weapons: they now take the owner's steep outward carry, and the lance was redesigned as a grim lance.

Native sizes live in `native_sizes.json`, and the tool reads output paths from the registry.

`tools/process_gear_visual_assets.py` keys the green, trims to alpha bounds,
area-reduces to the exact native size (mesh replacements take the bare rig
part's own size), thresholds alpha and darkens the silhouette edge toward the
rig's outline. `outputs.json` maps every shipped texture to its source and
digest; `tests/test_gear_visual_assets.py` verifies the digests and that the
shipped textures equal a fresh derivation.

The complete prompts, references and output sizes are the image tool's own
records in `provenance/hands_provenance.md`, `provenance/armor_provenance.md`
and `provenance/feet_trinkets_provenance.md`.

| Source | SHA-256 |
| --- | --- |
| `basalt_pavise_front.png` | `c3368229668757a848e5b74033ea4c1e6ed2cc538c72d37337e1d32d2434eb09` |
| `basalt_pavise_rear.png` | `156311fd421b4825d8d8d693b0cbfe7adb3183baa4f015bdf8748db656e4725b` |
| `boiled_leather_front_arm_l.png` | `aa888a7d5fbbd53e5318947025fe82f2ee73b18422327bc1519fd64190238679` |
| `boiled_leather_front_arm_r.png` | `3e4b0eeea7a810a88bd622ca4f46ffd0b7ed80d1400119c07e4c6a7359ee45cb` |
| `boiled_leather_front_hips.png` | `6685373cf4de2cf8212fd08c675fcb51f27f0b475f910b90dd6d954c0e89c02d` |
| `boiled_leather_front_torso.png` | `6b547bfd916570d1c3a2da8f3ca87ebea2b24d6d9ca1744d477c4677c8f1b876` |
| `boiled_leather_rear_arm_l.png` | `9351eb584ea5fd8e265646caaf16944f483765ad66a8530cb158d436074d80af` |
| `boiled_leather_rear_arm_r.png` | `25884323ae695ccc8e94f8712bec7c62c0a78fef35aaf2f81e35f2e6b8a5fb08` |
| `boiled_leather_rear_hips.png` | `60f4eb4a34d39a3a0623f3886782041d190c4d3e45e76b8bfe6f58e142d0578f` |
| `boiled_leather_rear_torso.png` | `e22da47fc3d413b78560e9c8590528fa6cfe5b76c33865b96cf41504beb02a3d` |
| `bone_dice_front.png` | `8713af63818cccec3af6a97d88b8010d082ef94ace28d4ed8affc59cdbd3139a` |
| `bone_dice_rear.png` | `821274f7a3c915abeb045cfbaea3b823602d8e12b4b06a268aa88b191645d1bd` |
| `buckler_of_nails_front.png` | `f240f02e4bf0d0c52f5822ebd01c15e0462f855afdb387b6845e3824a1faf415` |
| `buckler_of_nails_rear.png` | `85a835ead8e37d63854628a889ca6ece4eeb4557e517eeb9fec98984ca74390c` |
| `chain_guard_front.png` | `a4711f9dcd273f8c595b9da01c9e0107552655668dce1c6733f9a3dfd757c79a` |
| `chain_guard_rear.png` | `f29ffd7560aba6dd401457ebfbc76f46047226b906332f641cca95d1bc338816` |
| `cinderweave_mail_front_arm_l.png` | `4c63224b92d99a2a4c5d60dbaa74f7a3306003a63b333d0bce05c99afb4b78f1` |
| `cinderweave_mail_front_arm_r.png` | `abf106399726f6a9b348025007af21535f2b4eb30bdc0ba8df7c141834a38bc8` |
| `cinderweave_mail_front_hips.png` | `b649f4f3939c980f675ada67ac21ccb93ee994c770b920189adbefc988cc054e` |
| `cinderweave_mail_front_torso.png` | `e04c07e8b563ff777eb09ab7d47bfab05b7fa70cee645af15bbd8cede7b74c7c` |
| `cinderweave_mail_rear_arm_l.png` | `a98d35442cc6763f1ecb374f7bf4705aef0946129ceb148f5a16d870209323ad` |
| `cinderweave_mail_rear_arm_r.png` | `d1a84a40dad0875be0017eccaa2a16bffe6a7651d1edb6aed47d05323d0f0b31` |
| `cinderweave_mail_rear_hips.png` | `8043bf60176fb4c37712379b8f273c724e93069fefa5b644d6f66050225f19e4` |
| `cinderweave_mail_rear_torso.png` | `de5ef6b6ea755ddbc5197a592d6a95e5d53d0dfc1592c2d9791f1796c92471bb` |
| `clockwork_arrowhead_front.png` | `fdab21ab4ba42247917b74bf7e30dc7990e095a22ac25a354163efbb41436507` |
| `clockwork_arrowhead_rear.png` | `9c15755553d35f072ae50d760a5484376e8a63c0044664989d3311df9e7ba222` |
| `cloudstep_sandals_front_foot_l.png` | `e84d61f3ae3a7060e4241d102990f0ab3235ba49c0f77d72adaa79f0d0c57555` |
| `cloudstep_sandals_front_foot_r.png` | `6638477af4be165bea9138343f4f5cf5be7d0882e2069e9e3fb797a121298d40` |
| `cloudstep_sandals_front_shin_l.png` | `559654a839b9aebada52e0372ff887cb13be42b319dde6b112f368bb6f618bba` |
| `cloudstep_sandals_front_shin_r.png` | `973b3c06f8963e8a1157532fc13c58a4a163cf4853d07a586570f3b1cded9dc4` |
| `cloudstep_sandals_rear_foot_l.png` | `c90d4a83161095ca6abc0f885285f8518a861ea247b3d397ba18f8f1f76b25f6` |
| `cloudstep_sandals_rear_foot_r.png` | `0755cbb462fde77e42fcf5651938ec6ab6c6469e640421bb90c35b1165bb86f4` |
| `cloudstep_sandals_rear_shin_l.png` | `c1815b92b55e4481feacd6414963c21f806994b4a843b3c28dc8e18d58077320` |
| `cloudstep_sandals_rear_shin_r.png` | `fa428adb69fad96db076e4ef76fcb1440fd85e22acb90fbcdfc93a855ac4134e` |
| `cracked_lantern_front.png` | `e596d07b6cff273e1e1ac16a1f027e9f17e15ca3e51cf587d92a2a180d6c90d5` |
| `cracked_lantern_rear.png` | `a74f6a29dcf48f916bc55ffd44997a65287c979e3f8af781e56f1c98e49e2e3f` |
| `crown_of_thorns_front.png` | `542ef3a59b48e2c4009f3bca0a8166c039bff7206b7143571937d74ba81f1d30` |
| `crown_of_thorns_rear.png` | `64d9de29a960f6892eaf310777ba9940ad5d6ba410bda575da7b17fe557e3540` |
| `dawnlight_censer_front.png` | `0189856a0553bf9edb54ddd70ce079f27fb428fafbad659aeaf28e1caac259ba` |
| `dawnlight_censer_rear.png` | `2e5675357ec0e293cc19365dd9bd3f3950ca795f0ce070f112a1bb15c531f82e` |
| `dawnwalkers_front_foot_l.png` | `bc04c9a272c465c2afa0580477a711ea089e00a6a2d075020bfc3f31ab4e47c0` |
| `dawnwalkers_front_foot_r.png` | `4fdb091911d3b1602d5d2e4595fb6b75664f4ca8297356741d468a4a6dca9fa0` |
| `dawnwalkers_front_shin_l.png` | `916b28705f6489713a9b71fd7426ab18c7540e756063427066d68b6886a104de` |
| `dawnwalkers_front_shin_r.png` | `3b1490897e99f4bd009c8d2a05cc0d618b3ba85d102b8aa06e2c1454243dcae8` |
| `dawnwalkers_rear_foot_l.png` | `e838d09a05643c542510805a0868b7c5f326621708be8d22b333752009d5502a` |
| `dawnwalkers_rear_foot_r.png` | `39d2f1de13e67d724d6b1102c02ad3f59d66aa4328b8606a26c8ef7a2cb97840` |
| `dawnwalkers_rear_shin_l.png` | `e32e2d6966dd3eda04559989ec9f3b0b752bb3a7dad3fc826d70f3bfc223308b` |
| `dawnwalkers_rear_shin_r.png` | `30474460c53a0330b6741ad5e498686b72fe3b2310ce71eafa7498373d320697` |
| `doppel_doll_front.png` | `6f2041fdc25e04d9d8630f7a4f34817b7313e91645bc5b03a4bb4421e647a837` |
| `doppel_doll_rear.png` | `9606bc8a0ea44881592c5d418f2a1d072aaa61ae7b0fb21a5ac0882a233ac320` |
| `duelist_rapier_front.png` | `47a596444706096a5ce887460bced9ee1f4cc3c344b910aab9babbfab559b194` |
| `duelist_rapier_rear.png` | `3d55210fbf473c282ae22aa2876c16333ebb3a4673fd182f2baa73bb6eb803e9` |
| `dust_tabi_front_foot_l.png` | `ffc67c0695cb8d21280ad8d4dded41c10473e9b58fce3ad8178623affa497c50` |
| `dust_tabi_front_foot_r.png` | `02bbb9329b294086fac0381b64b015a8b1e97b3982339fd7d93eb9a7e8afb715` |
| `dust_tabi_front_shin_l.png` | `fa1b149cdbfee71e99b8061a43abf7899ca27e35703f7563b898f63c6441e87b` |
| `dust_tabi_front_shin_r.png` | `a0ccd5d849731059a7fcec24221430fb207bbbc91b03ed2226c9404f311e6356` |
| `dust_tabi_rear_foot_l.png` | `b1b4c81e8a4bfc8bddc42c66f8644e51f844b125e4b4f15f5a6e4ad61f19ad21` |
| `dust_tabi_rear_foot_r.png` | `95be790181e4a8ff4b889b43b4d63c035eed3944b6352e46d29175ecdc99c7b1` |
| `dust_tabi_rear_shin_l.png` | `5bcc868541f1a1ff1386fadc192449fc67fdc138ff9e776bfec625f92206aea6` |
| `dust_tabi_rear_shin_r.png` | `5ede69436c674957f8292553a3f5bda1461c4a2c7387eefd9ce087ae8ff4620c` |
| `ember_hourglass_front.png` | `a126a361f0e82a4d8337a05eb9629d59343e22102332e08d2c441ccbbb908b90` |
| `ember_hourglass_rear.png` | `64203bd3a5addc36870910d0f3e694af824ec1cec783d977f7702509ed846376` |
| `ember_pendant_front.png` | `615d8857f8ccf2bf40cf484a1ac579b8bfbca87a31b2478ac4ff086cd57cefce` |
| `emberstriders_front_foot_l.png` | `771a8f727e8190ad9c6c751e69884478ee84d0a9578e0d07eae8815611d65b1d` |
| `emberstriders_front_foot_r.png` | `e6a32cce19660fca6514f905bf6127f808cfe216c31e3f5d2cd5dabe2ef0d45e` |
| `emberstriders_front_shin_l.png` | `9d34faba4da60c3f17d38cf937892edd97754035a81dba8845fb77cbca27f302` |
| `emberstriders_front_shin_r.png` | `1c6be271717ed58810d6ab9408437dc925aec96289161f58ece40b522f3b1f53` |
| `emberstriders_rear_foot_l.png` | `0d6279b352e18d7fd031e5f7556ae8e4383ed11cba19839ebb96805128dddd5d` |
| `emberstriders_rear_foot_r.png` | `5f22dd7adee56af2db6826df7861f517a88478a6501e2e612dd4ad1998dd8e0a` |
| `emberstriders_rear_shin_l.png` | `6e15b1d843fc831d081c8770ef604addd3527dea9722fcd8e89c69547421b252` |
| `emberstriders_rear_shin_r.png` | `c602efd786fe9a668377323b51fd6a93f03155d36e08c978b1db952d35431b8d` |
| `frostwalkers_front_foot_l.png` | `55378041530198da29816547e122200c2b5b6c19875a24be756821d90f1b265e` |
| `frostwalkers_front_foot_r.png` | `3657cd3428be18c5b3072999d673fa1bc0c3f671f56a928b94557b72801184cf` |
| `frostwalkers_front_shin_l.png` | `639422defdb5bbc71eec96925fd6c65139c0c34249116aa5125602991671cec5` |
| `frostwalkers_front_shin_r.png` | `7cf2ba48571b968b449e57581e28e5bd59d3e91d9a747f8515ea8349c6141724` |
| `frostwalkers_rear_foot_l.png` | `10dd90bd3f7a954e2771ac9ae5c11fd33b4169286cbc5aa7e4ca9f87630c93b0` |
| `frostwalkers_rear_foot_r.png` | `337a7abb7077c4201f88eedfc11a7074cc60b152e0a213000e8cd3b20f81707b` |
| `frostwalkers_rear_shin_l.png` | `e44df2db2ae88eb29ac1ff64c35224fbde78408228f5d7b6117f3b44ea3d5a0e` |
| `frostwalkers_rear_shin_r.png` | `b0bfd36cd98597998695fbd2933ffacddea5bf8409a1ddeb613760a0697ef4fa` |
| `gale_cloak_front_arm_l.png` | `dd63f0f948fb2f85e3df888ab14086c1f0d74b3793692610f11b40b7babd1d49` |
| `gale_cloak_front_arm_r.png` | `7a5e540041260dd432e7f9d4e368af64b764cd23771fb4a70bd555517ce82db9` |
| `gale_cloak_front_hips.png` | `3fd7290efb2332d12d7dd826cac428e2d8a0659ea788f6d8c41d89b63947cce4` |
| `gale_cloak_front_torso.png` | `e1adf53f72349670925f91be086a261202f5bb291262ba5ab41113507f712095` |
| `gale_cloak_rear_arm_l.png` | `cbc7ecec3bd78df5149f6bac40ad87912ed72d9b20d653c8aafc62d73035cbdf` |
| `gale_cloak_rear_arm_r.png` | `9713c3d209f313c0db9295d97852b6ce84eade640fbf612299ccf80f57f28ef4` |
| `gale_cloak_rear_hips.png` | `e0d09805454216483dea34cf080f95956d5d0bca8f19387ac44f98eeda5b166d` |
| `gale_cloak_rear_torso.png` | `2e741ed30eb1d528c9f9842316c2e23aed7cbab4d4f6af61c288017d2f129031` |
| `galewhip_front.png` | `a8f86cc935f5e8839dbc0931b7d5a526e30a38dd15264731768ed76e10cdce41` |
| `galewhip_rear.png` | `b6204ee36e671108715439fa186a1010e971fdca3983f1efeb1d8c0a56ce7a35` |
| `gamblers_watch_front.png` | `ba8cb80090b047d38bb343e2a4c53c2fa0aa3f3ed0e26facbf2348859615464f` |
| `gamblers_watch_rear.png` | `571f8dff24cdb9f576b3d25a7883cba59650204a5998527a41e3a64eb8127df4` |
| `geode_charm_front.png` | `74f3958ae6019fa8a3add805dd33352dd7dfec6a459709ca7e6ef3183af5b0c6` |
| `geode_charm_rear.png` | `8c0a9afe8af8e300d1f69897b1b23e866f2c465435f1209545912e3f9ac7827d` |
| `glacial_bulwark_front.png` | `64cda3ee2fda6dabe7b2c93adae9c4f39228937ac303066701a96a774bfc97bb` |
| `glacial_bulwark_rear.png` | `c322fb094478b10d752fb30de9920e8bc4a7d5088175a308cfcb8d81837736b1` |
| `glassbone_cuirass_front_arm_l.png` | `39e6fc358e2aa51ea158f42a23456b20d815722135b27b9fd4fcdb76df2d47a3` |
| `glassbone_cuirass_front_arm_r.png` | `b4b7470f005b5d445adf3ec47e87c655626f54e943504bc45d4c8688d0c24686` |
| `glassbone_cuirass_front_hips.png` | `51084588ad306b247ba7a0b29b0a0869cf5474821379ade6406f7bdf8e29fd65` |
| `glassbone_cuirass_front_torso.png` | `2d33a934914e403c8e417b9eb01e25fc74683594deb1dd49a1ec3603c4f4e9f0` |
| `glassbone_cuirass_rear_arm_l.png` | `a99776df958d77d8a6113fd85c6e2711be5b5dc21010eccfd447a543ad2325e3` |
| `glassbone_cuirass_rear_arm_r.png` | `744c06da57c1634f8f7091e7f9f7b12bf93a0854df77a964f7fc2db366684759` |
| `glassbone_cuirass_rear_hips.png` | `74a35031cc2156a4f0eb7f248332d194ec72ed7058ef8946211dce0c623df295` |
| `glassbone_cuirass_rear_torso.png` | `7118c5718ba41171fe77ad0b2374836ddb8dd8aa6b50e8adbac092b91268755e` |
| `grapple_hook_front.png` | `bcbe952980285880f4475e2421867d413af67660e9e7d75afeb4cb0b2b11d802` |
| `grapple_hook_rear.png` | `8cacd171cbd63683a817f554c56b6a2717321aa4d226bf33ae4af7962b013186` |
| `grave_greatsword_front.png` | `b28afeac73431e94d9d1903fefcbb0dc58bf4403d7e1bfa1b20375488998526b` |
| `grave_greatsword_rear.png` | `f996c10491227775f5cf2fe7dd9f4509a38967e33b0e596047aca2669f5461f0` |
| `gravewind_soles_front_foot_l.png` | `529415fdce31daa134cf8ba172d6d7126640e1d67930887eee92eaa4f3c66cfb` |
| `gravewind_soles_front_foot_r.png` | `2886163b071d9a9267e942bf3f3fdab0f26e6bae0e14129c1f282b7d3d387950` |
| `gravewind_soles_front_shin_l.png` | `ce6cc17114e5bce4ecaaf66ce23afa4b4a41c6205bee3484b5a0becf580dafc5` |
| `gravewind_soles_front_shin_r.png` | `b59e19a57a8767af82834236cdeebafeb1405cd2ad2b17930b6f75e75e7da347` |
| `gravewind_soles_rear_foot_l.png` | `a4f303ca15eef8f137cba08087a18444c691b049e4d3b469a0fab6180c1c3d78` |
| `gravewind_soles_rear_foot_r.png` | `0d7893e4eaef9a83e9d21a6e928fb7b9b0ce36c9dcafb21603c9791aaf23ead8` |
| `gravewind_soles_rear_shin_l.png` | `1b1631f2b28501770628ea95f881b0524bee35f87a9633d73e560923feac1cde` |
| `gravewind_soles_rear_shin_r.png` | `5c33d1ad825c92b5fc4d069b750b84cf5fd6d964bdc886e4af14bb0169fe4744` |
| `headsmans_coin_front.png` | `36170cf3e38a0d54db81c3ae35b3a20d71999d3da3702f16e56c572b9e8c29cc` |
| `headsmans_coin_rear.png` | `bc3e00203e0727cfa21d74279bb18362e57c91b74a801f7175bd2308772cdcd2` |
| `hobnail_grips_front_foot_l.png` | `9acff8259d11964e94588c5dc494143be3b5b19a0cba8fa24b2bb3cf7c53890c` |
| `hobnail_grips_front_foot_r.png` | `bf93d8c4660f4be15abd5fda1bd7661dd9486720a7a016a2e8dc0bd6832baf2f` |
| `hobnail_grips_front_shin_l.png` | `4428914984a2fcf450d66d310bc56cfb4ec66572ea323f4bb2ab2e398988f3fc` |
| `hobnail_grips_front_shin_r.png` | `b9f291054f28fba4f5b83ce4c09f43b18de789a90edc078328cf074c21815fae` |
| `hobnail_grips_rear_foot_l.png` | `33fa7de6d72f2e55087d16db2b5dc388dc8247870c31917f974c5973c5c89cdb` |
| `hobnail_grips_rear_foot_r.png` | `7afc7ee24488cd120703d8c5fc676a7419a084ef0d5cd32a85afc04fc438f566` |
| `hobnail_grips_rear_shin_l.png` | `85af34feecf10c01d7fde50c575fb54decfcd25fb5be38517a4f3f45596da586` |
| `hobnail_grips_rear_shin_r.png` | `85d72d862f229bb8cc20e61c6af13c632d026e13c95b2abb835be319bbe98581` |
| `hookspine_halberd_front.png` | `ceadd1f47d547aca2af83b099debd56089121ba11c5da006d2db85b2a864f915` |
| `hookspine_halberd_rear.png` | `9f86a03577f0286a3521865c9096da8c51276fc8400a811e2f506b5ec3d7cb46` |
| `hunting_spear_front.png` | `321ba6be3f95cddbb4b8914b9eb3bf53ab77e82e9fd9af9dc3cb70dcf89098d0` |
| `hunting_spear_rear.png` | `86303be65949f70913a180970741536cd1f768d96e42f46f5584f9fe7c4bc29e` |
| `iron_cleaver_front.png` | `1256dbd1f7459c2be56bb8b5e1cea0fd46913abe34cc374bdc1b87878547420e` |
| `iron_cleaver_rear.png` | `9775f1122c4f6cd6aa0b8a9d674fed7f8e6c3465b5dd61c0884ecd2d8a825037` |
| `ironshod_sabatons_front_foot_l.png` | `ae2aad97beb8a268c3196460ae5dd89639fa11923bce4520b6d7e98a2955747b` |
| `ironshod_sabatons_front_foot_r.png` | `da5d41bc5bda9e46da2dbd722f15bfd4757cdf474f575dcd29e14f2693e84dbc` |
| `ironshod_sabatons_front_shin_l.png` | `9dbe9d15662876da2925bdb661594f57116acadb53d8ac2cd2615793a1b11a43` |
| `ironshod_sabatons_front_shin_r.png` | `38b9a1897841b7018242e3580fafd0334e3ba1bdca37b3455b19b3c359f891c5` |
| `ironshod_sabatons_rear_foot_l.png` | `8dbcbb6948e61d285d9e71d62d9ac9a7cbb841a52ff1cceef019eee388d3e891` |
| `ironshod_sabatons_rear_foot_r.png` | `5d8ab81eb9ee4b14806b635d8fdb85a7841d33c0709343dd7b62b0ee6790b1bc` |
| `ironshod_sabatons_rear_shin_l.png` | `a633b6ddf794939cb1253e16f8092474ed63217071e750c028b4e5c3b0013469` |
| `ironshod_sabatons_rear_shin_r.png` | `bb0a0d2205053de6cc7a19d6105608882e7c43bd0f614c246da931bfc5faf3dd` |
| `lodestone_buckler_front.png` | `c80e9c7d133a3077090acb6c2e75932675494891e65c02fc9b1d8077afc25304` |
| `lodestone_buckler_rear.png` | `0441faf02c045c87c885491efe19244455a733b6076f5079f10665b17e5a6fb7` |
| `mirror_guard_front.png` | `010e4dedc960591feba7c09801f6d7f3c3bb37598a12cfe42aa12bb93819b613` |
| `mirror_guard_rear.png` | `89bf8f82ba2748c831fbb8285623baf4c1911880acaf1b476b26786850383319` |
| `monks_wraps_front_foot_l.png` | `28611610e8ff713bf446a0f165e22b49b4deed84b4860d7d42874ff624ac217b` |
| `monks_wraps_front_foot_r.png` | `aab2ad067e06acce4373001a525fac43805dca559a0a2717486fe14162d1a922` |
| `monks_wraps_front_shin_l.png` | `39abeb253ee7e59438f3d2acfbc56f6d668a41d02ec9489163a11e5a04d7cd7e` |
| `monks_wraps_front_shin_r.png` | `77776f5edf6d2a2519d58e197105b6a1dbd226cc1a9363506115264bef007ee8` |
| `monks_wraps_rear_foot_l.png` | `d218ad973e4d15f46e1bbcce3329a4373ee4fa6e21e056b477f9e4207c3d4a0f` |
| `monks_wraps_rear_foot_r.png` | `0c5fe3770e5b037d0e88ebf7850655e11e0f4bddb7bcbb88dea407e5244b60b9` |
| `monks_wraps_rear_shin_l.png` | `9fbe4137a819b1f9813a55e5532483c79514403a6e621ab4b68f41b8311cfd74` |
| `monks_wraps_rear_shin_r.png` | `7f8a58ad8a5ead092de511a804693f501e3047578a4b1fab28113de4007c69f1` |
| `oathstone_front.png` | `f8796109326abfbc108beaa18433adab33073518bb72f6b0ac5be2bcb0c55a15` |
| `oathstone_rear.png` | `3a3f0e024e64e17076bdee10af7658cc25313c292a2df116642d8cf731bfe1de` |
| `parrying_dagger_front.png` | `b70bc74f98f57384cf1b73d43ac8aec5bb802208f18f09e28a190c9ca624b2c8` |
| `parrying_dagger_rear.png` | `a42e3c494a1a3d572bfebec9d3dfad34113289c023c1f7a7fbd4e59d5fffa7cc` |
| `phoenix_brand_front.png` | `9078602e5c69ffe8183f50222dedd91ac2fc1cefa12d1da52545cb214e1efe54` |
| `phoenix_brand_rear.png` | `78fe495e6cfdefec34362aac2007b7d75f448e48ccf6517706bf15ca6f055ccd` |
| `pilgrim_vestments_front_arm_l.png` | `6ff31005053a0a84835b39797941754833b1414998a263d664d93f8b3a2d1269` |
| `pilgrim_vestments_front_arm_r.png` | `d8336f394bfa7b98993210812998cc0848dcb689d78491b2fe069826d82ea555` |
| `pilgrim_vestments_front_hips.png` | `7c21c6e0f6453705553195edb21d3373134a0c44a4c4c04398d22a626356448a` |
| `pilgrim_vestments_front_torso.png` | `cd9f24632666fc4638121c4e526693f17db46f1bcf9d654c46ac304ed68de95b` |
| `pilgrim_vestments_rear_arm_l.png` | `19dd334feff27f27aa063a8d11c81178a18e3aeeea03ff3a082f0dc27ad0a7d5` |
| `pilgrim_vestments_rear_arm_r.png` | `a04ebb05b02a634861b86317641968441f752816047b71f0884f2ed2871ce0f5` |
| `pilgrim_vestments_rear_hips.png` | `f173156c57382f248892e01924f75edaffd19e2167ef45da7fbf2471422573d0` |
| `pilgrim_vestments_rear_torso.png` | `faf0de78e8ce0da047c7173b58aa4d549c3f97c0afad2c9529fd6ea103c659ef` |
| `quarrymail_front_arm_l.png` | `665cf65e58c6ee61e7d78a205f2c97623f738fb78177e8ecd06b2cb698016dcb` |
| `quarrymail_front_arm_r.png` | `19a847e5b5902093774b5a933240933c0d9a45e230d5bc5d79e202838eb9a741` |
| `quarrymail_front_hips.png` | `642cf41d05e64b4ccfe2f2b9b0f9703b0c761a6a636e5c856b16f452cc6fe1d5` |
| `quarrymail_front_torso.png` | `8f417dd8baaf2ff82d85d8d29796d1285e1c350faa3db5d1252b832de5e929f7` |
| `quarrymail_rear_arm_l.png` | `11bde2c5619b29a38dc7634eda368c9ab696d1216a15b6c4d97847f7f87111d9` |
| `quarrymail_rear_arm_r.png` | `52deb814d587fd546cb286fc641f06de6798420e7e86af76d45ed7ab240553ae` |
| `quarrymail_rear_hips.png` | `806a9f93ae74aa347d3a60cdf5befa4f1ac681f26a857ca2d568ab9ad4460375` |
| `quarrymail_rear_torso.png` | `50a301dd405dd5c87a59a0a3759f4f1351b9bb580a4496e2507851c432cdc342` |
| `rime_locket_front.png` | `00abe05305e1dd374f9d97537ce3c7e043255dae7444fb7c777d143d6262e019` |
| `rimebite_hatchet_front.png` | `8156ff14a534b7819a2b43de663037eb2ed4e6108445979bb24c0c40a3c794ff` |
| `rimebite_hatchet_rear.png` | `870aeefe530966d45f81301476bc26c96cf0d6293e52dd44173fa22bb225cb4e` |
| `rimeplate_harness_front_arm_l.png` | `11c134c8b9e3019530d805abb70d8335575cac70a3ed9065268a87fa26c2031b` |
| `rimeplate_harness_front_arm_r.png` | `a5858234f2fb98dddd065d98a782122a357f137f2400e2ba8562d97b3f9f2d6a` |
| `rimeplate_harness_front_hips.png` | `a56b70e07598a7661350d88b44c6d0991194f8990e5d0159fb53343e099e3ea6` |
| `rimeplate_harness_front_torso.png` | `f643f93412d71a99c4c375dfddc5fda1f1459952d86645dfa71c1814aa567650` |
| `rimeplate_harness_rear_arm_l.png` | `debc7b84cedbad4f74aba8dfa7dbdd9ad45efc66af797a6b41e8de608744fab1` |
| `rimeplate_harness_rear_arm_r.png` | `6ea4171f30ccfb1067693c5654f12e9ebfa79a13470f113a1a4380a259e98bcf` |
| `rimeplate_harness_rear_hips.png` | `1090b2924d01d72841d08d2e014246398c3ebd83570f6a2a609075ae77c22389` |
| `rimeplate_harness_rear_torso.png` | `3ff0eb1376d8096db90595c3fc86ff5d5c10c261c7108fc56b5283f0dce63595` |
| `sawtooth_knife_front.png` | `02eb836398ac28a74c4ef9dce67ebaca79264796671cbb7d7d00ea6afd855e10` |
| `sawtooth_knife_rear.png` | `f6a1f280d2674667173d698f0ea65b6caefb1756186456de9e1c35a78ee03022` |
| `sealed_cyclone_front.png` | `5c61be338c1b2b8586dd100026698b2d1d8d46a49af48ea58cbe82aeb75c4330` |
| `splintered_shield_front.png` | `764c85250cdd826e25cce85bc6b7886b1f1131ce90fe5e2ec0c9c2ac9f533c77` |
| `splintered_shield_rear.png` | `6e600fb8fff98a0437966632ef8be869a3775f6934eae4e2b30fc324804754f7` |
| `static_spurs_front_foot_l.png` | `87816458c2cc0b038af554e1e340a028d1e352eaa101dc56a315de6c3ecac585` |
| `static_spurs_front_foot_r.png` | `381bc1edb4b3e3de27c40727b20c737c99b7b943458fa4893a318e33037254b0` |
| `static_spurs_front_shin_l.png` | `fcbaa20f5255a51512c5e948460a971e7d0dc6ccd608f0d46b84224ae6afd6ed` |
| `static_spurs_front_shin_r.png` | `66f0aea281e9267c0592ca1faeafe3e0b97ff85bc613e88a880e0ae7b7efcecc` |
| `static_spurs_rear_foot_l.png` | `361472cd4451491260340a5ba52a0a5c21e47f4518e505455f7c566a161be288` |
| `static_spurs_rear_foot_r.png` | `55ff37608af502a1b595275ac4d033450d20df7eaf9fe890f8a083862683f4fb` |
| `static_spurs_rear_shin_l.png` | `ac550188e68c01f15948cc330310c1b777e815fb040c02f6c69234d7b2f75855` |
| `static_spurs_rear_shin_r.png` | `9e179ee17b781bb11ec64a1118395fc554aab03527e2823ad4127a587d184d87` |
| `stitcher_apron_front_arm_l.png` | `90f33abd80bf344074f2b9ea693b232f7eae5ba7287968b1334ff5d7f80631cb` |
| `stitcher_apron_front_arm_r.png` | `c1a75a2e98d029d54c61ecd65c3fabd093225b451c6739ca62a2df34d9c9770e` |
| `stitcher_apron_front_hips.png` | `2142e37e0103c4959601eedd02d45780a2dbfec46766ceae3cfd0fc32dc3505c` |
| `stitcher_apron_front_torso.png` | `130e00214b8a182e98552d97023f6c63897749de9b879b4db89ecd7d7bdc0832` |
| `stitcher_apron_rear_arm_l.png` | `9ce9ac4ca6539d0e598512ae44de5695882b2d3ebe51ebf3ca25d14151dd24b1` |
| `stitcher_apron_rear_arm_r.png` | `7bbd7b9538433f2187e8d11fc219020fceb6fd8ed631db9c03faa859bfd0169b` |
| `stitcher_apron_rear_hips.png` | `3e18a0a103b1e7268b8d753b86957cb8d8db58a92a583edf5094cf9f725b9de9` |
| `stitcher_apron_rear_torso.png` | `798506c654b4129ca1d93ac846a7e42aee9b93360bfc08796d7f8252ac5bbbf3` |
| `stormglass_orb_front.png` | `f1345659cc4bd7c28a92029ff1c605d320b6b643cfdc0f835990c5a11148e3ad` |
| `stormglass_orb_rear.png` | `0e307414201df73b71cdc607a57a98c755912859f4959f1e7ad3918300264a60` |
| `stormstring_bow_front.png` | `89a7c074616003b803839187dd1e4aeabefb7e9fb00597050c5e93d8c3452733` |
| `stormstring_bow_rear.png` | `f728b17991244c3b34f5c6d8fd94902858e23b6ef944ce486c991bb8a7904cde` |
| `stormweave_robe_front_arm_l.png` | `acb3435032ad83b03795312226767435b009950175f1fbae5e5d40ef621392a4` |
| `stormweave_robe_front_arm_r.png` | `b44b3ae2dde8c33fe0c9c0143c248c3db076fe9d9de38b58cce864db9278000a` |
| `stormweave_robe_front_hips.png` | `d2c922fee39b6344058a1d037230578ed342f77468c7a1ad6ac3ec99db0d340f` |
| `stormweave_robe_front_torso.png` | `f3297410b27abbc87bee35be687dcb69a266a2808bd312fefb85c9fa03709d21` |
| `stormweave_robe_rear_arm_l.png` | `696bcf658c611755cb84927917b6540445e49d2db14a1b5d888a85e44fad4dd4` |
| `stormweave_robe_rear_arm_r.png` | `da9ee628f22aacec765d9ff245d746a547464bea0a616228fdf5120687a66fcb` |
| `stormweave_robe_rear_hips.png` | `5cc34684264ceb598221128de59c70b2f2f96e99ab29a3dc684e99edd4821431` |
| `stormweave_robe_rear_torso.png` | `ea9d34c82a4f18ca06e423987eda6da75cf55101937933fb823c9ffc69813dae` |
| `sunken_anchor_front.png` | `c4c8d897186871795a24d2baaa58796a4e231350a83828facf98d0cd59bce1d6` |
| `sunken_anchor_rear.png` | `56c4ca7cf34350699cd424f820cbe95f03c790629847944a0188cc105e5b9aed` |
| `sunward_targe_front.png` | `82895c16b28c0c646166d60ed0cf59d379ed81aa952581db78b4cf0c74f9b981` |
| `sunward_targe_rear.png` | `a4ac765941917fe20d52bd814938dc286bbaa0623f3754599d275eb258bc80a8` |
| `thornmail_front_arm_l.png` | `ec7884bd5ce3804a11070c1eb58776b284e038a477a041196e4646cb33d6ba0b` |
| `thornmail_front_arm_r.png` | `b0e00a4f896dc29952987a37136f72435863c6b8a70830e89977119c86321093` |
| `thornmail_front_hips.png` | `9058652b638d56ee355aa42b7cf97f3c533a98540a273438a8b969955dc994bf` |
| `thornmail_front_torso.png` | `ff8d37bdc1352e0e90543768f92e3058e718dcdb8b661a68e9416704773d5099` |
| `thornmail_rear_arm_l.png` | `5b8a3a31b1c122b4f25409af2fcd3fdd4030487d5c298b7da8794ba54e210124` |
| `thornmail_rear_arm_r.png` | `85f2c7fb040bb1103eb8e2efb838f8a47d753f266686458751f3813392427f4d` |
| `thornmail_rear_hips.png` | `499a49ef8101b20a11769a3bb061af487869d684a866f25b1e82a884ae135a0d` |
| `thornmail_rear_torso.png` | `d0f538e714b478c2135f4d5696478f5f847efd70c1e8c705031c0821e81aa942` |
| `tinkers_knives_front.png` | `093c6d41753add0a487d642f0ee44b79d9b37b54463ab5cebff9eb7f617c8719` |
| `tinkers_knives_rear.png` | `2dea1f25ab6daee8cb187c084ee9e46b3b1f4e2fe1b9cce362caa3fb171afac9` |
| `tourney_lance_front.png` | `f14d89bea87cf555efc280448817ae82c2715b8fa23d897807743aef5535004c` |
| `tourney_lance_rear.png` | `f35403fbb7f9e2ef81074907cbd5e18583c3e5ec3d7f781daf68055758b8b051` |
| `tower_shield_front.png` | `2e1789ca17c93a358f0a4a304d29222841d179e7fcc85ab2849be93b38a835d9` |
| `tower_shield_rear.png` | `393cf2d132963a18e88a5694b2f9684ebefcc5af18fb9c1ae93395728cccce85` |
| `trapdoor_spurs_front_foot_l.png` | `391c9990976b8cc5a869b9f99e2bf069c9f4ba1fc006fb525ffe8f945c9c7837` |
| `trapdoor_spurs_front_foot_r.png` | `c274ccd52af7fbccd1a12279e7d988d5dcaf38fa5a1ccff050d7df2b356c7246` |
| `trapdoor_spurs_front_shin_l.png` | `993977b77f38975c58df0e5e628727b7e3ae04b69a549776700d9b101a56ca76` |
| `trapdoor_spurs_front_shin_r.png` | `4749a594c1e6c4162b8828161920dc993a44b1589ba0b59e451a1f823eb7655b` |
| `trapdoor_spurs_rear_foot_l.png` | `c4897c5fe7f37651e5566b5b4f67c2472dd22ac14fb3fff7eeb67ad4f0915689` |
| `trapdoor_spurs_rear_foot_r.png` | `530983cce343a5fe2c00711715619fd28126825714b6cf16ae290225eeff7a93` |
| `trapdoor_spurs_rear_shin_l.png` | `5b8e6e74fb2fd7830584b8b8789631808e0c7c8cffa905dc9d1d10d1827429b8` |
| `trapdoor_spurs_rear_shin_r.png` | `3e0d8ae3541e5a8c142c525c7b8977d310e08e229deba568ea52c41ad63f4474` |
| `undertaker_plate_front_arm_l.png` | `eda95b6ee298a972766e1fb053781e794a2328414db82079a4abcb8af3eca416` |
| `undertaker_plate_front_arm_r.png` | `cb9895778d0eff787cc1fa28964f739b7b3176c5ae33cb08edb2ccdcb115d626` |
| `undertaker_plate_front_hips.png` | `8e7ecfcd23b0aa9e7617b9d267325b147231b5b90e71d173371f87c989793684` |
| `undertaker_plate_front_torso.png` | `f743170fe1e9f8ac22180972a996234b7fed4b02a7e182ceb02eac307748d91d` |
| `undertaker_plate_rear_arm_l.png` | `278cb07a9279e8f7277c027a82d631620faf159bc6dcfb8e22bc64f1fcae88de` |
| `undertaker_plate_rear_arm_r.png` | `95606b018713d0c1af82df8f3ddf1bcb282efb912b632047a8f864be72fdcddd` |
| `undertaker_plate_rear_hips.png` | `7481b98aebb04c3457cd3e534349efb3c2a5c82a924544a2aab10abd0a9dffec` |
| `undertaker_plate_rear_torso.png` | `e1ffbdbafb407a04565cfd80ebbc41b6acf54ca1b7f478a0f73abc8ecaa4e114` |
| `voidsilk_carapace_front_arm_l.png` | `cc73ecf43a730c0eaaf7672504fd74031ca69aa4190ee7194eb3d6da7a3b61d2` |
| `voidsilk_carapace_front_arm_r.png` | `3e91bbfcd78ca505ae7c96ac3374add830cea9a7a0405b4d2e030ed6702644ab` |
| `voidsilk_carapace_front_hips.png` | `9a2e2a0fd99fac72192a7e19af587517981d058bfe8bdd808738ed7cd41216c4` |
| `voidsilk_carapace_front_torso.png` | `c00231af8621054f2f1fd6dee89cf14971f395552b76a6e4daced5afc2102b9c` |
| `voidsilk_carapace_rear_arm_l.png` | `e493f6cda6f2e1b531333c805dc5d2ad2744eba4cfc20eb723f2d364566de483` |
| `voidsilk_carapace_rear_arm_r.png` | `a9dbc22fd44f76bbb7efdc4dfbfd9668e94a3f84a0cab5b2604897741bd19da1` |
| `voidsilk_carapace_rear_hips.png` | `1e0b60b1e89203078c414feff11f6f7d70905c96f485fca0cc8b20562f225c9b` |
| `voidsilk_carapace_rear_torso.png` | `56b7ed7a39bbf60373fb116850eb7fc4b9dd4e5953b858ea998f05ea5eaee9a1` |
| `war_dancer_sash_front.png` | `b3c8667bdd06ddfa5ecd21baead01243903ea2394cb527a7add69f08f3a389ab` |
| `war_dancer_sash_rear.png` | `c983ac079b5ee20e4b67b11317e361ad64c2e33b7d0e3f5f9321f8132869fca5` |
| `war_maul_front.png` | `390d5fda1e2f155aa58fd96ebb269f13cdc4d7fb03e068e2d2bbde87cb65e996` |
| `war_maul_rear.png` | `5718eadf9e393789f3c6fe39b88f4fe04df28d13eac0186e64bf698f8bf2e403` |
| `ward_kite_front.png` | `19656a370ea54ecd7b3a7d6fcf27e21b6ba8972d5ba77fa581d0a8560307424b` |
| `ward_kite_rear.png` | `ecf211e715608338d47a493052d9c6cc0569528e90ad26f631e588f84c84d2f3` |
| `windlass_repeater_front.png` | `3a8b9555ae2b0b96c5359fea55e5cfd65e3d0bdfefea375cce3b9d1bbe747a79` |
| `windlass_repeater_rear.png` | `8cf2cf80e799a00487bbafa743ff99accb0b96aa20efad6e23b62ce1d31bb084` |
| `witchglass_aegis_front.png` | `a8ac6e33a29353bc3345e0b9416de9e56db230ef9bb012f83ce6e017f637a5f8` |
| `witchglass_aegis_rear.png` | `f6d11ad44e9f684af63379f8224a857da5ff6e62bdff6df0b39e48c83d1b5714` |
| `worldbreaker_front.png` | `192fc253c6a6fad9a1429f3423f02b0f413c58263779de50746a8ba834a5e879` |
| `worldbreaker_rear.png` | `a54b81915bcb7daba17d78eb8a589f0a7d04f41ef6184fd7c882b0c97052a676` |
| `worldroot_greaves_front_foot_l.png` | `dba4b0c9e2fd8760a373d4b9fcee6f98769af1da26775d507fde1ed675f9cf31` |
| `worldroot_greaves_front_foot_r.png` | `2d0c5ecc74b4c92a641ae7c89931fa865e2a9c4a735fc1a75b7584c36e485c64` |
| `worldroot_greaves_front_shin_l.png` | `70ad33fdf6dffd7fc6ea5539744c7cfc01c3f13048d4bd6dab96077f5b3bf15a` |
| `worldroot_greaves_front_shin_r.png` | `f2e93636106078f73ef25f979eab8aac6c97f486954841677ca53d45e737997a` |
| `worldroot_greaves_rear_foot_l.png` | `b03d49a0b15c75b7892bf0a1e4f70c149ab1ff181aa1e8bd7a327d3a40777573` |
| `worldroot_greaves_rear_foot_r.png` | `9eef62d6ff1790e9d72e6597c579863bbe4f6028e696859ca79a46eb9b5ff171` |
| `worldroot_greaves_rear_shin_l.png` | `0a029f04bee31ce70eb3105f1e6dc078df83aa4579ec5ac05bbb000690349202` |
| `worldroot_greaves_rear_shin_r.png` | `99692344af195e60743c24a193fcea52f34f5f6c180e1bf8d50f090e1eee351f` |
