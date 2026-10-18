# mq-06 — accepted planted rear staged, front frozen

**Current: feedback 5 completed staging.** The director accepted the planted
rear and fixed original registration. See the [completion report](feedback5/README.md),
[staged rear SHA-256 list](feedback5/staged_rear_sha256.txt), and
[current fit report](../delivery/rear_proportion_report.json). All 21 front
files and front joints remain unchanged. Current floor, collision, coverage,
turn and independent native certificates pass. `feedback5/` owns current tests
and acceptance; the feedback 4 account below records the earlier hold.

## Historical feedback 4 hold, resolved by feedback 5

The new rear passes native collisions, floor contact, exact turn, pixel margins,
coverage and native cold/cache determinism. Staging is held because the required
dynamic rear IoU is **0.2054038784 < 0.60**. Fixed-original registration gives
**0.7609076185**. No delivery or approved painting has changed.

Read the [current implementation and acceptance report](feedback4/README.md).
Inspect the [native 1024 four-cell rear sheet](feedback4/rear_sheet.png): old rear
clay | planted rear clay | planted rear parts | old approved rear painting.
The [dynamic registration comparison](feedback4/rear_registration_comparison.png)
shows the failed gate without substituting a different registration.

The source painting's protected ground annotation is at the lower left robe edge;
the planted body's dynamic ground centroid is at its lower right foot. The
standard registration therefore translates the silhouettes apart. See
`feedback4/status.json` for the historical registration conflict, resolved by feedback 5.
No source annotation, gate, scale, direction, label or approved art was changed.

The original cause remains proved in `root_cause.json` and
`native_reproduction.json`: the delivered rear was already a proper 180° turn.
Its paired fit lifted the far ankle by **0.156967104 m**, faking screen height
with elevation instead of depth. The new rear uses the actual hip/knee/ankle
bones, preserves the source outline corrective, and solves the skirt against
the planted anatomy. The front's 21 files and all front joints remain unchanged.

Feedback 1–3 reports are historical. Their superseded previews, verbose logs,
generated specs, native models and caches were hashed into
`../discarded_proof_sha256.json` before removal. Historical test result excerpts
remain in `historical_test_result_lines.json`. The old front alpha/union gate and
its implementation TODO are removed from the active task.

The single new regression file passes on the planted candidate and the other
complete figures. It continues to fail the unchanged old Seer production rear;
that failure is retained. Changes are uncommitted. No review, publication, Git
staging, queue mutation or branch change was performed.
