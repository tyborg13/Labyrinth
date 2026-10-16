# Demo comparison fixture

`weaver_reference.json.gz` contains the sanitized headless event/board report
used to review the Thornwall presentation wait. Gzip uses a fixed timestamp.
The tests reconstruct native timing from the exact pairs in
`tools/demo_clips/comparison_exemptions.json`; no ignored owner output is read.

The reference payload matches the policy fingerprint. Tests independently
change matching payloads, each source fingerprint, and each frame coordinate
to ensure every exemption guard rejects unreviewed cases.

`weaver_fingerprints.json` retains the reviewed capture's source fingerprints.
Portable comparison tests supply these committed fingerprints at the source-read
boundary, so unrelated merged source changes do not invalidate historical test
data. Production still hashes the actual source files and requires an exact
match with the reviewed policy; these fixtures never update that policy.

The guard fixture fingerprint binds to the committed reference gzip. A separate
test copies it into a temporary source root and exercises real file hashing:
the reviewed bytes allow all 96 exact exemptions, and changing those bytes
rejects the +47-frame event. Policy-hash, payload and frame-coordinate mutations
remain rejected independently.
