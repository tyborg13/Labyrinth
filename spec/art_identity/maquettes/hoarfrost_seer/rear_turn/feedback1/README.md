# Superseded feedback 1 diagnostics

The original depth decision was resolved by feedback 1. Its strict clay/individual-label pixel gate stopped this diagnostic; feedback 2 replaces that gate with the humanoid v2 piece unions. Read [the current report](../feedback2/README.md).

The feedback 1 prototype also used region labels as native leg bone names: diagnostic joints reached the floor, but the actual bound far foot did not move. These files must not certify a corrected body, floor contact, or rear fit. The later native implementation uses validated actual bone names and reports its remaining collision failure explicitly.

For historical reference, that prototype changed 19.385354% of front clay pixels and 2.266% of part-map pixels; front joints stayed at 0 px displacement. Its composite has been hashed and discarded. The retained JSON and logs document the superseded stop only.
