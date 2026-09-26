# Treasure presentation

Treasure rooms first show the planted chest, then its rigid lid opens and settles before the existing relic offers become available. The choices retain their layout, exact descriptions and native pointer/keyboard/controller paths. A harmless UI rebuild keeps the current opening progress and cannot replay a completed reveal. A saved treasure resumed in a fresh scene gets one new room-entry reveal. Guardian trophies, which use treasure choice mode in a combat room, skip the physical chest introduction.

The closed source, stationary body, new underside/interior and back-hinge registration are recorded in `experiments/cutouts/relic_chest/v01`. Production uses four small transparent layers under `assets/art/props/relic_chest_hinge_v1` through `RelicChestProp`. Every opening tick updates only the retained chest tile; stage layout and room state are not rebuilt. No character animation is changed.

A claim still commits ownership, persistence and the existing analytics boundary before presentation. The next route map is gated while the relic beam and all staggered motes travel, then while the destination performs its existing three bounces and final settle. The map appears immediately after that final settle, with no extra timer. Both automatic presentation and manual map requests respect the gate. Duplicate claim attempts cannot grant a second relic.

A scene-local generation guard cancels old motion on a loaded state or scene exit, clears temporary effects, and prevents obsolete continuations from opening a map in a new state. Reduced Motion uses the same static open chest, skips traveling particles and bounce, and gives a short destination tint confirmation. Input remains gated during the short reveal/claim sequence; completion restores focus only for actual keyboard/controller navigation, preserving pointer-idle appearance.

Proof: `tests/treasure_presentation_probe.gd` exercises opening/rebuild/no-replay, native focus and claim, saved ownership before delivery, early/manual map rejection, completion order, Reduced Motion, and reload during opening/delivery. Its temporal native screenshots use a fixed 1920×1080 viewport at UI100.
