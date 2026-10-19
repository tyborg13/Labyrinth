# purge-02 feedback 1 — combat pile decision (director brief error)

`TODO_DESIGN_COMBAT_PILE_DUPLICATE_PRESENTATION` (decided): the brief assumed the combat pile viewer shares the Purge
cells. It doesn't: it shows one card per copy, so every copy is already visible and there is no ×N to replace. Keep the
combat pile viewer exactly as it is (no grouping, no badge, no `run_scene.gd` change). The medallion badge is
Purge-only.

- Remove the two BLOCKED combat badge checks. Keep (or add) an assertion that the combat draw/discard viewers still
  show one card per copy and draw no `PileCopyCount`.
- Check that `tests/pile_viewer_test.gd` and its helpers are registered (the registration audit passes) and that the
  contract file is used, or drop it if nothing uses it.
- Everything else stays as you built it.

Proof: the magic deck tests, the pile viewer test, text-fit, mutations, UI identity lint and the registration audit.
Give the windowed Purge probe command. No full suites.
