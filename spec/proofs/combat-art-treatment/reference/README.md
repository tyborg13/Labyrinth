# Native lighting reference

Fifteen 1920×1080 / 100% UI captures from the passing September 17 Warm-default probe. `lighting-capture.json` binds profile names and exact numeric values to the comparison images. These files are retained for offline reconstruction; they are not runtime game textures (`.gdignore` prevents imports).

- `00_untreated.png`, `01_gentle.png` through `05_dramatic.png`: identical generated Hollow Grotto fixture, fixed poses/camera, five stored looks.
- `default_warm.png`: live loaded default without selecting a profile. The probe requires its entire lighting-input dictionary to equal explicit Warm. Wall-clock torch embers and deferred startup can differ across full-frame captures; the recorded mean image error is diagnostic, not the equality gate.
- `06_flicker_a.png`, `07_flicker_b.png`, `08_reduced_motion.png`: Warm's shared-light animation and stable reduced-motion endpoint.
- `09_targeting.png`, `10_moving_actor.png`: live legal movement selection/controller focus and an interpolated engine-resolved step.
- `room_01_warm.png` through `room_03_warm.png`: the same RunScene reused across three naturally entered generated combats. These are independent encounter replacements, not a simulated three-win playthrough.

Rebuild using the commands and ownership map in [the lighting guide](../../../combat_art_treatment.md). Verification, limitations and current inspection setup are recorded in [the Warm-default report](../warm-default-verification.md).
