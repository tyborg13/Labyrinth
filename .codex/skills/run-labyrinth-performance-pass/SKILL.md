---
name: run-labyrinth-performance-pass
description: Profile and optimize Labyrinth frame pacing with matched measurements and unchanged gameplay and visual quality.
---

# Run Labyrinth Performance Pass

Turn reported frame drops into reproducible workloads and measured optimizations. Preserve gameplay, visual order, animation cadence, input, assets, and effects. Performance work does not authorize reducing quality or hiding work through lower update rates.

Use `$parallel-labyrinth-task` for substantive changes. Record the affected workload, measurable acceptance criteria, proof, and inspection expectation. Capture the base before editing; compare base and candidate with the same viewport, renderer, workload, duration, warmup, and machine state.

Load only the references needed now:

- [Profiling](references/profiling.md): reproduce the reported workload and identify hot spots before choosing changes.
- [Metric contract](references/metric_contract.md): author a benchmark or interpret a comparison; distinguish frame intervals, input latency, and action duration.
- [Steam telemetry](references/steam-telemetry.md): investigate a Steam-build report with relevant target-hardware samples.
- [Optimization and proof](references/optimization-proof.md): change a measured hot spot, compare candidates, prove equivalence, and prepare handoff.

Use native rendering for rendering measurements. Report median and tail frame times, threshold misses, memory/node effects, and measured hardware. For rendering changes inspect fresh native `1920x1080`/`100%` proof of the affected states. Follow risk-tier test breadth and separate peer review; finish with a verified playable fixture or a concrete not-applicable reason before user inspection.
