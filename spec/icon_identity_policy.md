# Player-facing Icon Identity Policy

Every distinct player-facing concept owns a distinct icon. This includes named abilities and skills, relics, equipment, action keywords, statuses, resources, and future icon-bearing content families.

## Required identity rules

- One concept may reuse its own icon everywhere that same concept appears. For example, the Chilled condition should remain visually consistent on units and rules detail.
- Two different concepts may not resolve to the same icon path or to byte-identical copied assets. A renamed file, recolor, badge overlay, or generic category symbol does not establish a new identity.
- Named abilities may use a keyword inside their artwork, but each ability still needs a purpose-built composition and silhouette. Ability data must not point directly at a generic keyword icon.
- Relics and equipment each require their own purpose-built icon asset. Placeholder and category icons are not shippable identity art.
- Distinct keyword keys require distinct assets unless the keys are aliases for the exact same player-facing concept and the alias is explicitly documented in data and in the test exception list.
- Action types and grimoire topics must resolve through the central `ActionIconLibrary` registry. A direct-path fallback, a procedural substitute, or consumer-local remapping can otherwise bypass the identity audit and is prohibited.
- A presentation variant for the same concept stays in its central registry and
  uniqueness audit. `map_rooms.toolbar_path` is the folded line-art map used by
  the utility toolbar; its detailed Grimoire art keeps the default path.
- Combat objectives must resolve through the central `CombatObjectiveRules` registry so their preview, live HUD, board markers, and tooltips share one audited purpose-built identity.
- Icons must remain distinguishable by silhouette at their smallest shipped display size; hue alone is not identity.
- New icon-bearing collections must join `tests/test_icon_identity_policy.py` in the same change that introduces the collection.

## Current exact-concept aliases

- `move` and `move_toward` are both the player-facing Move action.
- `heal` and `heal_self` are both the player-facing Heal action.
- `move_away` uses Retreat, which is its own icon identity. Ally-targeted Guard and Heal actions also retain their own identities.

## Acceptance proof

- Run `python3 tests/test_icon_identity_policy.py` to reject missing files, shared paths, copied bytes, generic skill-icon keys, incomplete action/grimoire inventories, consumer-local fallbacks, and undocumented aliases.
- Inspect a native-size contact sheet and the real UI surface. Automated uniqueness cannot prove that two different images still read differently at 20–32 pixels.
- Document any intentional alias as a narrow exception naming both identifiers and why players experience them as one concept. There are no blanket family/category exceptions.

Element identity (`element_fire`, `element_ice`, `element_lightning`, `element_air`, `element_earth`) is distinct from a persistent surface (`surface_fire`, `surface_ice`, `surface_electrified`, `surface_rubble`). Chilled, Freeze, Detonate, surface relocation and surface consumption also have purpose-built, separate silhouettes. An element icon never stands in for its ground effect.
