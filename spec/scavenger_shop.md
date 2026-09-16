# Scavenger shop presentation

## Design statement

Surface: fullscreen merchant encounter. The player asks what helps their run, whether they can afford it, and what they can sell. The primary action is inspect a ware, then commit one clearly priced trade. Persistent hierarchy is the painted stall and Scavenger, ember balance, category shelves, Browse/Sell mode, and Leave. Contextual inspection contains only the item name, an exact native card, pagination for every granted equipment card, and the clearly priced trade action. Card type, rarity and ownership helper text are deliberately omitted because the card and trade already communicate them. Optional pinned inspection stays available. Dialogue belongs to the stall, never the underlying board; choosing a ware also dismisses the welcome without an extra gate.

Pack selling uses a category-filtered grid in the central shelf area instead of a two-item strip. Inventory objects are selection surfaces, not stretched command buttons. Warm leather, brass edges and restrained amber selection light match the stall. At the user’s explicit request, bespoke Scavenger leather-and-brass art replaces generic action skins; native Buttons preserve input semantics. UiTypography and the Graftwright shaded text material supply matching typography. No detached taglines or redundant card descriptions.

Mouse hover, click/pressed, selected, unaffordable and keyboard/controller focus remain distinct. Controller Accept moves from a ware to its exact trade action; a second Accept commits. The controller hint strip sits below the actions. Directional focus crosses mode tabs, categories, inventory, exact-card pagination, trade and Leave. Purchases and sales commit/save immediately; self-owned presentation effects may overlap, cannot double-apply a trade, and disappear on exit. Reduced motion keeps static receipts and exact balances without travel or idle movement.

Proof: fresh native 1920×1080/100% entry, shelves, filtered pack, card inspection, pointer/pressed/controller states, purchase/sale, unaffordable/empty and reduced motion; actual trade/save semantics; full Godot suite; standalone cutout render and exported runtime; peer review and verified pre-action Continue fixture.

## Cutout

`experiments/cutouts/scavenger/v02` registers the existing 255px painting unchanged in seven semantic paint parts and eleven joints. The hood lifts and gently nods while the separate shoulders, elbows, occupied grip, hanging hand and carried pack settle against that breath. A shared anatomical weight field across every part boundary preserves continuous original paint coverage; the root and lower body stay planted. No whole-portrait translation or traveling cloth ripple. The retained `recipes/articulate.py` reproduces the layout and partitions from source paint; the older v01 recipe is historical baseline material. The shop counter is painted above the actor. Production art and sampler live in `assets/units/scavenger_cutout` and `scripts/scavenger_cutout`; runtime never loads an experiment.

## Bespoke materials and text

`materials_v3.png` retains the built-in ImageGen atlas unchanged; its adjacent generation record preserves the actual prompt, reference and SHA-256. Runtime nine-part registration keeps strap/corner proportions independent of the center, with selection wares, action clasps and dialogue folios serving distinct roles. Text is real text, never baked into the art. `scavenger_materials.gd` reuses the exact Graftwright bevel shader and shadow treatment. Every action retains hover light/lift, a depressed held state, selected underline, disabled desaturation and native keyboard/controller focus. Reduced motion suppresses displacement.

## Inspection and trade receipts

The right folio uses explicit art-safe rectangles: the item-name header stays inside its upper leather inset, the exact card stays in the center, and the trade action clears the lower brass ornament. Its single card counter is only a position, such as `1 / 2`; there is no repeated type, rarity or reserve/equipment destination copy.

Receipts group the action and signed ember total along the top of the dialogue folio, separated from an item image and name below. Sales use a green positive amount; purchases use a red negative amount. The currency uses the existing ember icon identity. This makes the object and balance change readable as two groups, rather than a stack of unrelated labels. The receipt hides the welcome title while visible, and rapid trades replace the receipt without delaying the committed economy.
