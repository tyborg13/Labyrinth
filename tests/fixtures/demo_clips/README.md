# Demo comparison fixture

`weaver_reference.json.gz` contains the sanitized headless event/board report
used to review the Thornwall presentation wait. Gzip uses a fixed timestamp.
The tests reconstruct native timing from the exact pairs in
`tools/demo_clips/comparison_exemptions.json`; no ignored owner output is read.

The reference payload matches the policy fingerprint. Tests independently
change matching payloads, each source fingerprint, and each frame coordinate
to ensure every exemption guard rejects unreviewed cases.
