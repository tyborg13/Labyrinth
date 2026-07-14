# Focused Test Suites

Move coherent non-scene test domains here instead of continuing to grow `tests/run_tests.gd`. A suite exposes a static `run(expect: Callable)` entry point; the full harness passes its assertion callable so failure reporting remains centralized.

Keep tests that require `SceneTree` lifecycle or frame scheduling in dedicated `tests/*_test.gd` or probe scripts.
