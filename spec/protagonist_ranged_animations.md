# Protagonist casting and main-hand crossbow

Combat attacks prepare the left casting hand or the right main-hand crossbow before their existing projectile feedback. The player sees the actor face the selected target, raise a straight arm, briefly charge magic or aim a clearly visible crossbow, release, then return to the front idle. During the existing shooting visibility window (phase > 0.01 and < 0.94), the main weapon yields to the crossbow and returns afterward. Equipped offhands stay visible in every action; casting retains the main weapon. This extends the shared board presentation and preserves targeting, rules text, input routes, and outcomes.

## Routing and timing

`scripts/protagonist_cutout/ranged_action.gd` owns presentation classification and the 12-frame/200ms preparation. It follows the existing ranged attack category, including targeted AoE and push/pull. Fire, earth, air, lightning, and ice use `cast`; non-elemental ranged attacks use `shoot`. Melee, self-centered weapon sweeps, defensive actions, Blink, movement, and ground detonation retain their existing paths.

Preparation displays the pre-action board state and ends before the existing effect clock or sound starts. The effect frame counts, release/contact fractions, impact feedback, resolver results, chain-hop routing, and analytics events remain unchanged. No action is resolved twice. The first lightning-chain effect gets the casting gesture; later hops originate at their struck actors or ground as before.

`renderer.gd` samples the actual hand or crossbow muzzle at release and reflects its registered source coordinate with the selected facing. The board maps this through the logical 255px body rectangle, without using the padded texture bounds. The released source stays fixed during recoil and recovery, including the final front-idle reset. Existing preview/enemy/trap effects use their original origins. Explicit remote ground origins remain remote. Earth discharge begins at the hand and enters its existing ground-spike path; the spikes remain on the floor.

Reduced motion skips preparation/charge and shows a still raised casting hand or aimed crossbow for the attack's effect frame, followed by the usual neutral idle. The attachment disappears between actions; the persistent viewport texture remains the same.

## Art and motion

The editable case is `experiments/cutouts/protagonist_ranged/v03`. It retains approved pass-nine inputs and generator provenance. Round 2 moves the production attachment to `crossbow_r`, under `hand_r`, separate from the glove and registered at the `weapon_r` joint. The retained case is historical offhand proof; production layouts and the Round 2 motion probe own the current main-hand integration. Front and rear crossbows are separately painted, 84×54 and 84×64 source pixels, with explicit grip/muzzle registration. After comparing v01 and a threefold enlargement in v02, the user requested the midpoint size. The final v03 registers both images at exactly twice v01’s native dimensions around the then-offhand grip, sampling the retained original paint. Versions v01 and v02 and their proof remain available for comparison. PNGs use raw `keep` imports and production paths; the runtime has no experiment dependency.

The requested straight reach preserves each arm's painted width and the rigid glove/weapon. Casting retains the left-arm solve, including the rear arm's foreshortening correction and charge clearance outside the cloak. Shooting uses the right arm's painted lengths and the existing raise/recoil/recovery envelopes, aiming along (-1,-0.2) front and (1,-0.3) rear. The left arm stays at its bind pose. Existing crossbow PNGs are unchanged: front grip (76,24), muzzle (12,48); rear grip (8,52), muzzle (68,6). Their source offsets are now (10,111) front and (162,95) rear. Both use the main-weapon layer 66 beneath the fist at 67. `ranged_attachment.muzzle_offset` retains the painted grip-to-muzzle vectors (-64,24) and (60,-46). Live sockets follow recoil; released sockets sample the .42 pose and retain facing/reflection through idle return. No reach correction or added preparation is needed.

Temporary attachment visibility is a bone pose property and an editable AnimationPlayer track. Unrelated 21-bone idle/walk/sword transforms and static rest/shadow artwork remain unchanged.

## Acceptance and proof

The task uses the cutout and UI skills. Proof consists of focused transform/socket/classification tests, the full Godot suite, the cutout toolkit's structural/bounds/support/rigidity and saved-scene roundtrip checks, a timed case reel, the actual `protagonist_ranged_gameplay_probe.gd` at 1920×1080/100%, and a production-only PCK in the unmodified macOS export runtime.

The gameplay probe activates actual cards through shared selection/board-target handlers: magic and physical ranged in four facings, all five elemental effects, targeted physical AoE, reduced motion, controller target/cancel, and pointer handoff. It checks exact single-application damage, pre-release socket alignment, persistent art, and restored input/idle. Existing melee and gait are protected by full-pose comparison against the retained production sampler.

Affected UI rubric rows—state/consequence, gameplay visibility, cohesion, accessibility, interaction completeness, layout resilience, and visual proof—are Pass after inspecting the final 1920×1080/100% gameplay captures, all four facings, preparation/release/recovery cycles, cloak-off anatomy, and both reduced-motion stills. No text, control layout, targeting behavior, or input mapping changed. Native controller hardware and Windows runtime certification are outside this proof; Windows-compatible typed-array assignments are retained.

Final retained proof is under `experiments/cutouts/protagonist_ranged/v03/review/`: gameplay preview with captured timing, native case reel, saved scenes, full and focused suite logs, export-runtime log, 67 real-renderer gameplay screenshots across the main and reduced-motion runs, and matching case verifier results. The complete raw native capture is `/private/tmp/protagonist-ranged-case-v03-accepted` (420 authored frames, 10 pixel-identical saved-scene roundtrips; 933 input and 1087 output hashes verified). Existing full-suite warnings about an intentionally ambiguous legacy save and exit-time ObjectDB cleanup remain; the suite result is Pass.

## Round 2 verification

`tests/suites/protagonist_ranged_suite.gd` is shared by the focused ranged runner
and protagonist cutout suite. It protects unchanged idle/walk/sword poses,
classifies actions, checks right-hand grip/muzzle registration, front/rear and
mirrored sockets, released origins through recovery, visibility and reduced
shooting stills. The gear suites additionally cover shield and dagger visibility
in every clip and the one-handed maul. The updated fixed-1920×1080 motion probe
uses actual card/board handlers for L0/L2 shots southwest/northeast, L0 reflected
southeast, front/rear casting and the kite/maul slam checkpoints. Native Round 2
proof is pending with the design owner; historical proof above does not certify
the revised poses. The production-only PCK still includes no rules/data layer.
