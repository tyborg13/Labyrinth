# purge-01 feedback 2 — text-fit coverage (test-only)

The Codex review of e3192dc20 found one Medium gap; everything else passed (pile viewer byte-identical, rules, input,
9/10 mutations caught).

- `tests/magic_deck_ui_probe.gd` ~line 43 checks only the service plate's line count and height, and the recursive
  text-fit checker (~line 168) receives only the modal. Making `ScavengerPurge._label` non-wrapping, clipped and 1 px
  wide still passes.
- Fix: after layout, run `Presentation.text_fit_failures(...)` over the Scavenger "Purge a spell" plate and its price
  tag descendants too (and the disabled empty-deck plate). Add a nested clipping mutation on the service plate that
  must fail.

Tests only; no production or visual change (the director accepted the windowed captures). Run the magic deck tests,
the text-fit test and the mutation; no full suites.
