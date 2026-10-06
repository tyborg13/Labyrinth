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
| `cinderweave_mail_front_arm_l.png` | `4c63224b92d99a2a4c5d60dbaa74f7a3306003a63b333d0bce05c99afb4b78f1` |
| `cinderweave_mail_front_arm_r.png` | `abf106399726f6a9b348025007af21535f2b4eb30bdc0ba8df7c141834a38bc8` |
| `cinderweave_mail_front_hips.png` | `b649f4f3939c980f675ada67ac21ccb93ee994c770b920189adbefc988cc054e` |
| `cinderweave_mail_front_torso.png` | `e04c07e8b563ff777eb09ab7d47bfab05b7fa70cee645af15bbd8cede7b74c7c` |
| `cinderweave_mail_rear_arm_l.png` | `a98d35442cc6763f1ecb374f7bf4705aef0946129ceb148f5a16d870209323ad` |
| `cinderweave_mail_rear_arm_r.png` | `d1a84a40dad0875be0017eccaa2a16bffe6a7651d1edb6aed47d05323d0f0b31` |
| `cinderweave_mail_rear_hips.png` | `8043bf60176fb4c37712379b8f273c724e93069fefa5b644d6f66050225f19e4` |
| `cinderweave_mail_rear_torso.png` | `de5ef6b6ea755ddbc5197a592d6a95e5d53d0dfc1592c2d9791f1796c92471bb` |
| `cracked_lantern_front.png` | `e596d07b6cff273e1e1ac16a1f027e9f17e15ca3e51cf587d92a2a180d6c90d5` |
| `cracked_lantern_rear.png` | `a74f6a29dcf48f916bc55ffd44997a65287c979e3f8af781e56f1c98e49e2e3f` |
| `crown_of_thorns_front.png` | `542ef3a59b48e2c4009f3bca0a8166c039bff7206b7143571937d74ba81f1d30` |
| `crown_of_thorns_rear.png` | `64d9de29a960f6892eaf310777ba9940ad5d6ba410bda575da7b17fe557e3540` |
| `emberstriders_front_foot_l.png` | `771a8f727e8190ad9c6c751e69884478ee84d0a9578e0d07eae8815611d65b1d` |
| `emberstriders_front_foot_r.png` | `e6a32cce19660fca6514f905bf6127f808cfe216c31e3f5d2cd5dabe2ef0d45e` |
| `emberstriders_rear_foot_l.png` | `0d6279b352e18d7fd031e5f7556ae8e4383ed11cba19839ebb96805128dddd5d` |
| `emberstriders_rear_foot_r.png` | `5f22dd7adee56af2db6826df7861f517a88478a6501e2e612dd4ad1998dd8e0a` |
| `ironshod_sabatons_front_foot_l.png` | `ae2aad97beb8a268c3196460ae5dd89639fa11923bce4520b6d7e98a2955747b` |
| `ironshod_sabatons_front_foot_r.png` | `da5d41bc5bda9e46da2dbd722f15bfd4757cdf474f575dcd29e14f2693e84dbc` |
| `ironshod_sabatons_rear_foot_l.png` | `8dbcbb6948e61d285d9e71d62d9ac9a7cbb841a52ff1cceef019eee388d3e891` |
| `ironshod_sabatons_rear_foot_r.png` | `5d8ab81eb9ee4b14806b635d8fdb85a7841d33c0709343dd7b62b0ee6790b1bc` |
| `parrying_dagger_front.png` | `1eaa77675e48a7eb0d81e715ad2f8ebafcbc93a8dbe9a48294faec409a21fb3a` |
| `parrying_dagger_rear.png` | `5ea4523bc82c4334785748c60cd5242a268700502ff0dfdb4c7769777a9b9b95` |
| `sawtooth_knife_front.png` | `02eb836398ac28a74c4ef9dce67ebaca79264796671cbb7d7d00ea6afd855e10` |
| `sawtooth_knife_rear.png` | `f6a1f280d2674667173d698f0ea65b6caefb1756186456de9e1c35a78ee03022` |
| `splintered_shield_front.png` | `7e0b51afe922d95ec7768c043a4673c693a8936ed3e0667578e05dcfb503fac6` |
| `splintered_shield_rear.png` | `68a9f88bd6df71308ecde22f3f73727c566151de35381f450359c89557d960cf` |
| `undertaker_plate_front_arm_l.png` | `eda95b6ee298a972766e1fb053781e794a2328414db82079a4abcb8af3eca416` |
| `undertaker_plate_front_arm_r.png` | `cb9895778d0eff787cc1fa28964f739b7b3176c5ae33cb08edb2ccdcb115d626` |
| `undertaker_plate_front_hips.png` | `8e7ecfcd23b0aa9e7617b9d267325b147231b5b90e71d173371f87c989793684` |
| `undertaker_plate_front_torso.png` | `f743170fe1e9f8ac22180972a996234b7fed4b02a7e182ceb02eac307748d91d` |
| `undertaker_plate_rear_arm_l.png` | `278cb07a9279e8f7277c027a82d631620faf159bc6dcfb8e22bc64f1fcae88de` |
| `undertaker_plate_rear_arm_r.png` | `95606b018713d0c1af82df8f3ddf1bcb282efb912b632047a8f864be72fdcddd` |
| `undertaker_plate_rear_hips.png` | `7481b98aebb04c3457cd3e534349efb3c2a5c82a924544a2aab10abd0a9dffec` |
| `undertaker_plate_rear_torso.png` | `e1ffbdbafb407a04565cfd80ebbc41b6acf54ca1b7f478a0f73abc8ecaa4e114` |
| `war_dancer_sash_front.png` | `b3c8667bdd06ddfa5ecd21baead01243903ea2394cb527a7add69f08f3a389ab` |
| `war_dancer_sash_rear.png` | `c983ac079b5ee20e4b67b11317e361ad64c2e33b7d0e3f5f9321f8132869fca5` |
| `war_maul_front.png` | `390d5fda1e2f155aa58fd96ebb269f13cdc4d7fb03e068e2d2bbde87cb65e996` |
| `war_maul_rear.png` | `5718eadf9e393789f3c6fe39b88f4fe04df28d13eac0186e64bf698f8bf2e403` |
| `ward_kite_front.png` | `f3ac2aedfacb2d0707a543e1a88584cab3139e15d147214571555458266ac1fd` |
| `ward_kite_rear.png` | `338455106f6b5b35e778c356d8258a0789bd38cb8679a5d0928d1a85b30eac86` |
