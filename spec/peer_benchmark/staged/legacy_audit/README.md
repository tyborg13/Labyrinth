# Legacy enemy art audit (2026-10-13)

Independent judge (fresh subagent, rubric spec/art_identity/judge_rubric.md) audited 31 legacy subjects (12 cutout
regulars, 13 guardian rigs, 6 dragons; gust_shrike skipped) against the 11 owner-approved art-02 enemies at in-game
scale. Result: 15 High, 14 Medium, 2 Low; only grave_surgeon is at the standard. Every audited id draws its cutout
rest on the board (static `art_path` sprites are loader fallbacks only).

Key finding: `spec/art_identity/canon.json` still lists 16 of the failing rigs as reference art (e.g. the head-on
Chainbound Gaoler and Frostglass Lancer); the kit feeds canon peers into new paintings.

Files: `verdicts_2026-10-13.json` (per id: severity, failed criteria, smallest fix), `metrics_2026-10-13.json`.
Images: output/peer-benchmark-2026-10-12/identity_gate/legacy_audit/ (summary_high_normals_vs_standard.png,
boss_zoom.png, wings.png, p1-p5/b1-b2 pair sheets, lineup rows).
