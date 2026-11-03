# mq-26 — Storm Cantor take three: forms from the original art

Opt-in compiler on top of mq-19; mq-17 and mq-19 sources, deliveries and
receipts are unchanged. Left uncommitted for the director.

## What it builds (`recipe.py`)

- **Skeleton** (`skeleton.py`): mq-19's pose solver unchanged. Only the leg chain
  scales (both bones by one factor) until the hip joint sits at 0.50 H on the
  front capture; the sash (pelvis joint) sits at the original's measured 0.534 H.
- **Head** (`body.py`): a tall faceted helm whose face plate is a downward-pointed
  shield (0.10 × 0.17 H, a ridge and two flat facets per side) with a recessed
  dark visor (0.01 × 0.07 H). Round 2: the far tine rises 0.16 H above the crown
  with a 0.04 H forward hook, the near tine 0.12 H with a 0.015 H back hook, both
  0.025 H at the base. The hood cowl follows the helm's columns to a soft point
  0.02 H above the helm's back; the mantle falls over the shoulder line onto the
  cloak with two folds (concave back, no hump).
- **Torso**: five flat lens-section rib bands per side, each arcing down 0.05 H
  from the sternum to the flank, a sternum bar, a closed back plate and spine. The
  cage grows forward from the spine (depth 0.72 of its width) so the kept bell
  (mq-17 r3 lathe, 0.09 H mouth) hangs inside: mouth on the cage's lower edge, top
  just below the sternum top; the lathe stretches only along its axis.
- **Limbs** (`limbs.py`): faceted tapered plate segments that overlap at every
  bend; pointed elbow and knee cops (generic `blender/plate_cop.py`); real hands
  (generic `blender/hand_v3.py`): the near open claw, the far hammer grip;
  three-lame pauldrons (an open top lame cups over the shoulder; two lames step
  down the outside of the upper arm) with one swept-back spike each; ankle wraps; pointed sabatons.
- **Staff** (`staff.py`): mq-19's grounded shaft, pennant and sigils; a new
  three-tine lightning fork on a faceted socket. No ring, bead or ball.
- **Garments** (`garments.py`): mq-17 r3 tabard with mq-19's five torn points on
  the new body; mq-19's cloak generator run on this body with an open-hem seam
  sampler (supports: hood mantle and pauldron caps).

`design.json` holds the brief's values, the layout heights measured on the
original, derived construction values and the provisional `TODO_DESIGN` values.

## Gates (`checks.py`, `hand_capture.py`, `mutations.py`)

Proportions are measured sprite-style on the front capture at the shared proof
scale (`proportions.py`). Joint sphericity (generic `blender/joint_sphericity.py`)
casts pixel rays through both capture cameras. Ribs, hands, cops, helm,
pauldrons, legs and fork are measured from vertices; the hand gate also reads
the delivered parts map and clay. Seven mutations run on copied arrays.

## Proof

```sh
python3 -B -m spec.art_identity.maquettes.storm_cantor.mq26.proof prove --out <fresh dir>
python3 -B -m spec.art_identity.maquettes.storm_cantor.mq26.proof regenerate --capture <prove>/capture --out spec/art_identity/maquettes/storm_cantor/mq26/proof/<run>
python3 -B -m spec.art_identity.maquettes.storm_cantor.mq26.proof stage --capture <prove>/capture --regeneration <regenerate dir>
python3 -B -m spec.art_identity.maquettes.storm_cantor.mq26.proof verify
python3 -B -m unittest tests.test_mq26_maquette -q
```
