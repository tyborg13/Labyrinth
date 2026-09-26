# Contextual dragon cutout motions

The six established dragon rigs retain their painted identity, idle policy, travel
cadence, action phases and combat result boundaries. Each now implements `hit`
and `death` through its own `sample_pose` function. These are presentation-only
clips; shared routing lives in `scripts/cutout_context.gd`.

Hit peaks at authored phase 0.15, settles into the support limbs and recovers to
bind pose at phase 1. Playback lasts 0.36 seconds. Death starts at bind pose,
loads the supports before the torso gives way, settles by phase 0.86 and holds
that final pose. Its 0.64232-second authored span is 62% of the unchanged
28 × 0.037-second enemy shadow dissolve. Facing remains fixed during death.

| Rig | Hit gesture | Death gesture |
| --- | --- | --- |
| Zekarion | Shoulder/neck recoil, small wing check, four planted claws | Forequarters buckle, neck bows, wings close while hindquarters and tail hold their registration |
| Vyraketh | Low body recoil with restrained neck withdrawal | Chest sinks first, followed by the long neck and folding wings; all claws stay planted |
| Iskaldra | Pelvis recoil with supporting hind feet and rigid crystal panels | Hind legs fold under the body, head bows and rigid wing panels lower |
| Noctyrax | Low shoulder recoil and wing check | Chest settles, neck droops and wings close over the body |
| Vaeloryx | Whole hovering body yields before its wings stabilize it | Flight fails, the body descends and the wings fold; no invented planted-foot gait |
| Tharokh | Short, rock-heavy recoil absorbed by four claws | One heavy trunk collapse with a delayed head settle |

The five grounded rigs solve their existing supporting chains against unchanged
source-space foot targets during both reactions. Terminal claws keep a rigid
world basis; the independent segment projection preserves painted width. The
hovering Vaeloryx moves as a coherent suspended body. No independent idle
rotation, ripple or shimmer was added.

## Zekarion jaw hinge repair

Tempest Breath exposed a diagonal gap at the proximal jaw/cheek because the entire
jaw crop rotated rigidly away from the skull. The existing `jaw` and `cap_jaw`
paint now share one head-to-jaw skin field per facing. The proximal cheek stays
with `head`, the distal jaw follows `jaw`, and the blend is confined to the hinge.

| Facing | Bones | Band center | Band axis | Blend width | Mesh grid |
| --- | --- | --- | --- | --- | --- |
| Front | head, jaw | (85, 126) | (-1, 0) | 14 px | 1 × 1 px |
| Rear | head, jaw | (174, 81) | (1, 0) | 8 px | 1 × 1 px |

This is an ownership/deformation repair using the original cropped paint and
concealed cap. It adds no overlay or new painted pixels and preserves the
accepted jaw rotation, release phase and neutral registration. Both `Skin_jaw`
and `Skin_cap_jaw` use the same field, so their coincident source points deform
together. The resulting production layouts retain explicit original parts for
editing and add these two replacement meshes.

## Reproduce the fresh cases

Run `python3 tools/prepare_contextual_dragon_cases.py --output <fresh-directory>`.
An optional repeated `--actor` selects a subset. The recipe forks each original
`experiments/cutouts/<actor>/v01` case with the maintained workflow, replaces its
runtime closure with current production layout/PNG/motion files, snapshots actual
idle/walk/reaction playback timing, retains original source provenance, and records
new production hashes plus a baseline. It never runs a historical art builder.

Then run the maintained `validate --protect all`, `render`, `verify-render` and
`inspect` commands on each generated case. For animation iteration,
`validate --protect art` protects the synchronized art baseline. The historical
case walk speeds differ from current production, which is why synchronization is
required before judging cadence.

The working audit cases for this pass are in
`/tmp/contextual-dragon-cases-v2/<actor>`. Raw native audits and full-cycle contact
sheets are retained under `/tmp/dragon-audit`; final proof belongs with the task's
`output/contextual-animation-polish/dragons` evidence. The case preview is a
character study. The task's shared RunScene proof establishes actual hit/death
triggers, current facing, reduced motion and the preserved shadow dissolve.
