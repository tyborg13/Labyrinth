# Arc Thrall — current mq7b cutout

The current humanoid-v2 production case is `rr11/`, re-cut for rr-24 from the
director's final mq7b paintings. Rebuild it with `rr24_build.py`, then
`rr11_density.py --refresh-sources`; the older builders are revision-specific.
See [the rr-24 feedback 2 handoff](rr24/feedback2.md) for ownership, proof,
current results and director capture commands. `rr24/baseline/` freezes the prior
gait-01 geometry; `rr24/raw/` preserves the exact approved source partition.

## Historical rr-07 case

The production rig, native-source case, director decisions, features, hidden
requests/fills, connected crops, seam underlays and headless proofs are implemented.
See the [shared rr-07 implementation/evidence record](../hoarfrost_seer/README.md)
for every requirement, mask count/crop, defaults, test results and native commands.

`mq5/rig_recipe.json` preserves the director's torso/collar/loincloth hierarchy;
`club` follows `hand_near`. The full protected director file is copied byte for
byte. Native acceptance and two density rest records remain director-owned.

```sh
sh experiments/cutouts/hoarfrost_seer/rr07_proof.sh arc_thrall
```
