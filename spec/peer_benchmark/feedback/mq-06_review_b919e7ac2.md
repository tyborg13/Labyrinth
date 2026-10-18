**Medium — crawler exclusion can hide a biped.** [test_maquette_rear_turn.py:51](/private/tmp/labyrinth_codex/review/mq-06-b919e7ac2/tests/test_maquette_rear_turn.py:51) skips any delivery missing `front_solo_foot_near.png`. The roster assertion at line 24 omits Mirror.

Reproduction: using a labelled biped fixture copied from Seer as `glacial_mirror`, an incorrect rear fails the regression. Deleting its front near-foot solo makes the same incorrect delivery disappear; the regression passes checking five figures. Fix: restrict crawler exemptions using figure/spec identity, require biped proof files, and add this omission regression.

The previous floor-inventory Medium **is fixed**. My independent mutations caught:

- Each missing ankle, hem boundary and staff-foot row.
- All foot/prop rows omitted; empty report; empty helper input.
- An additional spec-defined ankle missing from the report.

Both root sealing and validation rejected the report mutations after child resealing and root hash refresh.

The five available bipeds remained checked. Actual Mirror/Grub/Tick deliveries are absent at this HEAD, so their filter behavior was tested with fixtures. **Survived:** the Mirror fixture’s missing-foot mutation, including with an incorrect rear.

Verification: 98 focused tests passed (2 skipped), 111 art-gate tests passed, and curation passed at 5,161,729 bytes. No GDScript typed-array hazards, new production tunables, dead code or stray files found. All mutations restored; checkout clean.

CHANGES REQUESTED