# Dragon inspection fixture receipt review — 2026-09-27

Reviewer: reward/NPC worker. Scoped result: accepted generation/reload receipts
and corrected recipe consistency for all 15 current fixtures; no actionable
finding. This is a read-only review of root-created inspection evidence, not an
independent approval of my earlier reward/trophy code, live usability proof, or
exact-HEAD closure. No Godot/native process was launched and no production
source or fixture was changed by this review.

Evidence root: `/private/tmp/dragon-feedback-inspection/final-v1/`.
Recipes: [inspection handoff](dragon_feedback_inspection_20260927.md).

## Reconciliation and contracts

For every current case I checked schema version 2, `verified: true`, task/run
identity, expected worktree and binary, exact fixture arguments, summary,
manifest path, scenario and documented reset command. All 15 run namespaces are
unique. Manifest reset commands keep generation followed by reload verification
and launch; their extra explicit project/home-root defaults agree with the
shorter documented commands. No command targets the normal player profile.

Each current generation transcript contains one successful
`INSPECTION_FIXTURE_RESULT` and one `INSPECTION_FIXTURE_VERIFIED`, using the same
isolated namespace and save path. Current save/profile files exist. The contracts
have the expected combat/reward/room mode, profile level, hand/enemy content and
64-character run/profile hashes. Current transcripts have no script errors,
errors or warnings. The generator and verifier source confirms that verification
compares the complete serialized state contract after reloading; this review did
not independently rerun that Godot variant-hash calculation.

`generation-results.json` deliberately preserves the initial partial batch and
its failed Hourglass case. It is not the final aggregate. Reconcile its first 13
successful cases with the two exit-0 entries in `generation-corrections.json`.
The corrected `*-generation-02.log` transcripts and current manifests are the
accepted receipts for Hourglass/Coil and Gust/Worldheart. This yields 15 current
exit-0 cases, without erasing the failed or superseded attempts.

The Man profile independently reads as 100 Embers, two Moltshards, and awakening
not yet seen, matching the first-story/service recipe. The Noctyrax reward profile
contains the retained earlier Moltshard receipt, one Eclipse Mantle starting gift
and its matching award ID, with no completed result; that is consistent with the
unclaimed final milestone's already durable gift preparation.

## Corrected interaction recipes

The initial Hourglass surface request at `(4,3)` failed generation with
“Surface tile 4:3 must be passable floor.” The initial Gust recipe serialized
successfully but its route was obstructed, so serialization alone was correctly
not treated as sufficient interaction evidence. The original plan/logs and
superseded Gust manifest remain retained.

Current plan, manifests and documentation agree on clear row 1:

- Hourglass/Coil: hero `(2,1)`, Electrified relay `(4,1)`, Crawler `(6,1)`;
  Frostbolt/Pale Spark/Brace and exactly the two named trophies.
- Gust/Worldheart: hero `(2,1)`, Warden `(5,1)`;
  Gust Step/Brace/Stone Plate and Worldheart.

I read the actual `*-interaction-check.log` records and their
`/private/tmp/dragon-feedback-inspection/check_interactions.gd` producer. The
helper loads and duplicates the saved combat state, checks ordinary legal
engine targets, applies actions in memory and rereads the saved combat state.
Both records report `passed: true` and `save_unchanged: true`.

The Hourglass record shows legal Frostbolt and Pale Spark, both with the route
`(2,1) → (4,1) → (6,1)`. Frostbolt costs 4 and leaves reserve 3; Pale Spark costs
1 and leaves reserve 1. The Gust record shows a legal move to `(3,1)`, a legal
Pull against `(5,1)`, and enemy arrival at `(4,1)`.

These are engine-path/reserve checks in the generated fixture, not a native
pointer/controller inspection. The Gust helper does not invoke RunScene's
one-click shortcut, finish Gust, play Brace, Pass, or assert the Worldheart
conversion/pulse. Those retain their separate focused/renderer evidence; this
receipt review does not claim them as newly performed live fixture checks.

## Remaining limits

The 15 native inspection openings and their live input/usability have not been
exercised by this reviewer. Generation/reload and the two targeted engine checks
are accepted within the scope above. The final cutout capture gate, independent
committed exact-HEAD composite review, user inspection and publication approval
remain separate. No approval to publish is implied.

## Accepted current receipts

All rows below have verified contracts and reconciled process exit 0. Run hashes
are the canonical hashes emitted by the actual reload verifier; manifest hashes
bind the files inspected here.

| Case | Mode | Run contract SHA-256 | Manifest SHA-256 |
| --- | --- | --- | --- |
| vyraketh-encounter | combat | `0a5edec508c3ed5be4f3265618b02ed7743c7c6ddbedf9486d17859008fc73ad` | `0aacfae64924afc0e4972c1e9615df53460bdb07c633b31e1111c43883913ede` |
| vyraketh-reward | reward | `7e3f268243e75c2493577201f41555aa34cbe5000a9dd591aea7a19457364983` | `96e91da4fdb634a2dbf4bbec7e36bd9b6427d9e993b9145edc40f68b95899f8f` |
| tharokh-encounter | combat | `fab6e1b1b585ede1e12f3c7abcf04fcfc1303424f49a59136f71c3779adc0394` | `b9a3acff957d2f29d449bd47e90f985ed8ac3817b50ac634fd5cdb4859c5aa17` |
| tharokh-reward | reward | `ac590424df2eea3509db7b79953ba866cf613ed5b4f7c70acf3d4e2dac6629a6` | `eca366b3064b676bb9ba8a0461c0e51b4683861969866ce7c9cab9c787af0cce` |
| iskaldra-encounter | combat | `8f7b79a0b517e88ceded8f1c17e469900de14defd832a5499a2c02d7fd5474eb` | `d485d34e97ddfd3152c38831e5818f163be33340173b8171cfe6d9c4b1614053` |
| iskaldra-reward | reward | `c0b4755ef077361ecc56fc54b25d1324e8b6d28c56fbb63e0deb5fbafedf9b72` | `e36c2e84bd309ee429e47ea78f80323661e4d771ed2255464f52ecc3ccb775a1` |
| vaeloryx-encounter | combat | `c4b20e1eb4131f8126b6d735cf2206239ae14513db8ef3abbb8c245ab979e76a` | `fa86d05db884f0261afcd1a57fae845992eff7eee01b1bf7e9903713ddf46568` |
| vaeloryx-reward | reward | `9aeebb41ae5a0fd98a86cf73b419211efe9ace371ae2c43f30fca9b6a06fc24d` | `723b61afb328c02c5387422067a527d6791b76b7e9f908dd52068346b9f174d5` |
| zekarion-encounter | combat | `b3fb671f0d94e813f868291c3059bf64fa9ee79d9c48d76f80aca5df1d91f31b` | `e625efc23df3b617a2d49cf29af700cebde4cdebba0bf78d6b4cb4f05950185d` |
| zekarion-reward | reward | `15b3c0fef68e57b3a5cc644f43fb3f702b2a483dcb67a34ac7b6020041438ac4` | `03ce7f500233a0bcc9231a3346b97f9177b9acc16bc2d8247a2ad0ad8a24522f` |
| noctyrax-encounter | combat | `7236135ff3abb5bcb406061e2788c17f6781fac318e0eefcb822c41e7cc69dd9` | `f18f8a6bf3a777c3b6398cb6606dd31580635320ac34d90030b3d0e954c74f21` |
| noctyrax-reward | reward | `a793ffa5dc1f6e4e58e1672c8c0437a3d466681826844afdb54ab2979931b455` | `cb1019a948028f46e444360d0ca6af65be6a5f7eae5982dd99738530c51d4f39` |
| man | room | `58a4644a0aaa3f980e84de843e2388f35b191791f8ba6f31bea83e2d0b04d9f8` | `6f5e9aede8f7dbd7295b98cc18486792124ee32b34d6a774e2bc4cf5791524a5` |
| hourglass-coil | combat | `d6f8efa63bd660fceee40b454e9a11a6777cb54f7bffc41b1c7edd198274e1c2` | `0d918c445db6d9f45b33be876f7418fa9417ce98fafa78134a29b08d4dd4095a` |
| gust-worldheart | combat | `0f341005b1caf60c26082e914879e6747dbc0fa6fb65e5ae6b086fee02c31562` | `10ffeffe713095c494a7be58f1e5730cb143a983d093ea68967dcd6ed810090d` |
