# en-03 feedback 1 (director)

The windowed probe failed: "Enemy in beam has a damage preview" (real defect: an enemy standing in a telegraphed beam
must show its damage preview like the hero does) and 3× "Capture is native 1920x1080, without rescaling" (render the
probe into a 1920×1080 `SubViewport` with `UPDATE_ALWAYS` and capture its texture, exactly like
`tests/movement_undo_probe.gd` on the integration branch; keep the 100% UI scale assertion). Fix both, then:

## Decisions (replace every TODO_DESIGN)
1. Tether tooltip: "Tether: lightning strikes every tile between the two Arc Thralls for 4 and Shocks. Break the line to
   stop it."
2. Veil tooltip: "Veiled: only attacks from an adjacent tile, or area effects, can hit it."
3. Veil targeting reason (invalid-target message): "Veiled — attack from an adjacent tile."
4. Tether dash style: 2 px `#a77bf0` at 85% alpha, dash 10 px, gap 6 px, dashes scrolling along the line at 24 px/s
   (reduced motion: static).
5. Tether flicker (resolution): 3 flickers over the 0.3 s beam, alpha alternating 100% / 40%, the jagged line rebuilt
   each flicker from 8 segments with ±3 px perpendicular jitter; ends with a 0.1 s fade.
6. Veil wisps: 3 wisps per veiled stalker, `#8a6bd6` at 30% alpha fading to 0, each a small curl rising 12 px over 1.6 s,
   staggered by 0.53 s, looping while veiled (reduced motion: none).

## Encounters
7. enc-01 has landed on the integration branch; leave `data/encounters.json` alone — the director adds your groups.

## Proof
- Focused suite, full suite, icon audit green; the windowed probe command listed again (I run it).
