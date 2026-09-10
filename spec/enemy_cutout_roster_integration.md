# Enemy cutout roster integration

All 17 user-inspected enemy cutouts are integrated together. Their production art, rigs, motion code, attack routing and editable authoring cases match the tested combined implementation. Shared renderer lookup, motion registration, attack timing, projectile origins and padded death textures retain every actor. Legacy idle-sheet assertions now check the new cutout registration and the existing 2×2 dragon footprint.

## Evidence archive and compact history

The publication branch starts at `01c7dccbc931ae7dddf3eb8f797fb3d1d33def3e` and deliberately does not merge the original proof-heavy branch history. Deleting captured files in a later commit would still upload that history. It retains production assets, authoring cases and compact verification records; 42,812 generated/historical artifact paths stay in the external archive.

Archive ID: `enemy-cutout-roster-2026-09-09`. Local storage: the `Labyrinth-archives/enemy-cutout-roster-2026-09-09` directory beside the main Labyrinth checkout. The archive has a README with restoration commands and a SHA-256 index. Its bundle includes the complete original paths referenced by each actor specification and all 17 original source heads.

- Bundle: `reviewed-roster-with-proofs.bundle`
- Bundle bytes: 10486064868
- SHA-256: `4e86b528df6b339b8fcc66b7e2bc49d1ae03d58ae7b78a7e3d478d8db360c230`
- Archived combined HEAD: `3f6d2f2e162222153ecb1b5842c56f56508bcb97`
- Prerequisite: `01c7dccbc931ae7dddf3eb8f797fb3d1d33def3e` (already in the game's history)

The bundle passed `git bundle verify`. The fresh integration capture is also archived in `combined-native-proof/`; the original 271 PNGs and the full 22,457-sample trace remain available there. No proof history was pushed before the user requested this archive.

Generated cutout proof, runtime capture and native render directories are ignored so regenerating them does not add them to Git. Authoring cases are retained, including segmented paint, layouts, skin recipes, motion code and source provenance. All 18 retained cases validate after the archived directories are removed (17 current cases plus the earlier Harrier case).

## Verification

- Full Godot regression suite: PASS in the complete integration and again in this compact checkout.
- All 17 focused cutout suites: PASS.
- Cutout workflow and visual-probe tooling: 16 + 16 Python tests PASS.
- Production-only PCK: all 17 renderers load both rigs, paint and unique persistent textures with the unmodified Godot 4.6.1 macOS export template (`editor=false`). The test package includes Lightning Wisp's production alpha shader and has no legacy-art, authoring-tool or experiment dependency.
- Fresh native Metal proof: 1920×1080, 100% UI scale; actual Pass Turn/resolver/wall-clock animation playback for all 59 intents, 17 reduced-motion sequences, 68 facing views and 17 death views, always with a different actor type on the board. All outcome, texture identity, facing, removal and padded dissolve checks pass.

A focused native supplement covers valid targets for Cinder Bloom, Shatterstorm and Night Coil; those fixed-pattern attacks miss in the broad sweep fixture. All three distinct attack clips and AoE effects pass, with exact resolver outcomes and independent Lightning Wisp textures. Its nine original 1920×1080 screenshots and full sample trace are archived in `supplemental-aoe-proof/`; their hashes and the probe source hash are in the verification index. Cinder Bloom also preserves its existing 3-damage Fire tick at the next player turn.

The compact checkout has identical runtime and native-probe blob hashes to the captured implementation. [The runtime witness](proofs/enemy-cutout-roster/runtime-blobs.json) binds that evidence to the publication inputs; [the verification index](proofs/enemy-cutout-roster/verification.json) retains clip summaries, screenshot hashes, original source heads and archive metadata.

[Contact sheet 1](proofs/enemy-cutout-roster/roster-contact-1.jpg) · [Contact sheet 2](proofs/enemy-cutout-roster/roster-contact-2.jpg) · [Contact sheet 3](proofs/enemy-cutout-roster/roster-contact-3.jpg)

These contact sheets are labeled crops of the archived native screenshots. Full-size screenshots were rendered and validated at 1920×1080. Visual proof is from macOS; Windows rendering and physical-controller checks were not repeated during integration. Existing neutral shadows and the user's deferred art polish remain as accepted.

## Original reviewed sources

| Enemy | Archived source HEAD | Editable case |
| --- | --- | --- |
| Dust Acolyte | `a35397555fad80d7be3ff2874ff5011a252d4004` | `experiments/cutouts/acolyte/v01` |
| Shale Bloomer | `adbb0189791a0df1ef31ba00ec01e9108a323459` | `experiments/cutouts/bile_bloomer/v01` |
| Chainbound Gaoler | `3b9d973c865d79d176dd63a0b3c84cda19c8d7cc` | `experiments/cutouts/chainbound_gaoler/v01` |
| Cinder Droplet | `5c9e5154e94e7f206f104cf018117348e0bccdf3` | `experiments/cutouts/cinder_droplet/v01` |
| Cinder Ooze | `c27339224a486d2fea9a287e91ce7131a0364110` | `experiments/cutouts/cinder_ooze/v01` |
| Tunnel Crawler | `9ab3c0355aca5d05edee7938e325412b49d3c2f1` | `experiments/cutouts/crawler/v01` |
| Frostglass Lancer | `050d5d95346ca64161120c2cb17f444d1b12105c` | `experiments/cutouts/frostglass_lancer/v01` |
| Grave Surgeon | `d5cf1ff542a352af335d76c2b109179d604d863b` | `experiments/cutouts/grave_surgeon/v01` |
| Bone Harrier | `88aced154837c5a92255810ed70d4e31fae7c023` | `experiments/cutouts/harrier/v02` |
| Iskaldra, the Rime Tyrant | `da370a7da73a0e9736d8b6b3dc2000d127d5be5e` | `experiments/cutouts/iskaldra/v01` |
| Lightning Wisp | `82bfac2373775bcb56330de75b25b66017b0ef51` | `experiments/cutouts/lightning_wisp/v01` |
| Noctyrax, the Last Eclipse | `df47004ef70be5bb95cc74d58d12e8861e3d752c` | `experiments/cutouts/noctyrax/v01` |
| Tharokh, the Worldspine | `9dbc19cfeae0088d9464859b6c8e00ead3f78b89` | `experiments/cutouts/tharokh/v01` |
| Vaeloryx, the Hollow Gale | `50f8ab239e7aff637c8038581d06a9e6b22c1a94` | `experiments/cutouts/vaeloryx/v01` |
| Veilbound Acolyte | `9661f4c5d7ccf0148c47f413cf2c65b71bdc8c18` | `experiments/cutouts/veilbound_acolyte/v01` |
| Vyraketh, the Cinder Crown | `43ec3547af9f8f8094fee2580eeb7ec4619f78e2` | `experiments/cutouts/vyraketh/v01` |
| Zekarion, the Raging Tempest | `f2eda18cd93fcadc792e18735d9ebff02589ee09` | `experiments/cutouts/zekarion/v01` |
