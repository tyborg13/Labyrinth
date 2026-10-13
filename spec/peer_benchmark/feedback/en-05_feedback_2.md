# en-05 feedback 2 (director) — float numbers, probe output path, integration sync

Dive rules and telegraphs are approved (captures copied to output/peer-benchmark-2026-10-12/proof/en-05/r2/).

1. **Float numbers**: the Dive intent shows "4.0" (07, 10, 11). Every intent/badge/chip number is an integer. Use the
   shared integer formatting that en-06 added on integration (after the sync below) at the source where Dive's damage
   is computed, and check Refraction, Talon Rake, Hover and Crystal Guard the same way. Regression: no displayed intent
   number of either enemy contains a ".".
2. **Probe output path**: the probe writes PNGs to `res://output/en05-enemies/<ts>/`, but `visual_probe_runner.py`
   looks in the isolated `user://` namespace and rejected the run ("Expected at least 11 PNG(s), found 0"). Write
   captures under `user://` like `tests/threats_at_rest_probe.gd` so the result manifest accepts them.
3. **Integration sync**: the director merged `codex/peer-benchmark` (en-04, en-06 and itb-03 threats-at-rest v2)
   into this worktree (14 conflicted files). Resolve every conflict keeping both sides: registries and data are unions; itb-03's presentation
   wins (no floating pills or compass at rest), and Dive's telegraph and side-push previews are expressed through its
   chips, discs and zone tags (Dive = the `dive` icon in the chip; the dashed path line stays). Mechanic dispatch is a
   union. Shadow cache: take integration's copy, then regenerate. Do not commit.

4. **Threat display for wave E2**: add one state to `tests/threats_at_rest_probe.gd` (and its contract) with the briar
   weaver (Thornwall), slag mortar (Lob Slag), glacial mirror (Refraction) and gust shrike (Dive) at rest around the
   hero, showing their order discs, chips at the feet and zone tags; suite assertions that each of the four gets a disc
   and a chip with its own icon (`bramble`, `lob`, the refraction/aoe icon, `dive`).

The merge is in progress in this worktree; your sandbox cannot write the git index, so leave the resolved files unstaged
(the director stages and commits).

## Proof
en05 suites, en04/en06/threats_at_rest/en01..03 suites, density `--check`, icon test, full suite; list the probe command.
