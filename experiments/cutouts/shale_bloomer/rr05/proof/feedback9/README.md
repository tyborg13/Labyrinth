# rr-05 final acceptance implementation (feedback 9)

Final seam rules are implemented: lower-drawn sibling owner/donor, per-side separation +1px capped at 4px, independent connected components with <3px components discarded, and trunk/core moving interior references. Full-silhouette backing remains removed. The 1,376 accepted bleed texels, original paint, feature data and director motion remain unchanged.

Interior tears, natural negative space and underlay protrusion are report-only through derive, pixel/native verification and promotion. Detached components, exact features, rest identity, temporal shimmer and CPU/native agreement remain blocking. Promotion also validates derived material before writing anything. The director judges both fresh native MP4s.

The current blocker list is in [results.json](results.json). The cross-root-tip pair has different immediate parents; the supplied sibling rule does not specify its owner. Literal zero boundary residual enforcement also exposes 15 residual pixels in the previously accepted Wisp native proof (old threshold 1%). Clarifications are pending; the owner script cannot honestly be claimed to run end to end yet.

Numbered director decisions:

1. Same-parent siblings use the lower-drawn owner and paint donor (stable layout order breaks equal-z ties). The different-parent root-tip pair remains explicitly unresolved.
2. Each retained 8-connected band component is one node. Components under 3px are dropped. `front/seam_trunk_root_tip_c` now has independent 68px and 62px nodes; `rear/seam_trunk_core` is connected at the approved per-side width (182px).
3. Reach on each side is `min(ceil(maximum sampled separation) + 1, 4)` source pixels. Features are excluded from paint and coverage; exact rest identity remains zero in all four views.
4. Interior reference follows trunk/core through the same source transform and alpha packing. Every sampled clip/view retains all three report-only measurements and their maxima.

Original unit requirements: all 14 feature/view declarations pass (one node per visible feature, preserved pixels, owner bone, 504 Bloomer or 375 Wisp poses per view). Both creatures retain the authored motion and stepped presentation. Fresh review MP4s and production captures remain owner-only windowed work; commands are below.

- [Per-clip CPU seam maxima](per_clip.md), [feature results](features.json), [blocking results](results.json).
- [Exact test result lines and commands](verification.json), [preservation](preservation.json).
- [Windowed commands and capture paths](owner_commands.md), [chosen defaults](chosen_defaults.json).
- [Archived evidence manifest](archive_manifest.json), [repo size delta](repo_size.json), [files changed](files.md). Earlier evidence is preserved byte-for-byte under `output/rr-05/archive/` and removed from the tracked tree. Reproducible current samples remain with each case.

Feedback 9 changes are uncommitted. No peer review, publication, promotion, adoption or windowed run was performed by this worker.
