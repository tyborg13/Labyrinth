# fnd-02 relic acquisition burst

Implemented on `codex/fnd-02` at base `3c27b676d`. The worktree changes are uncommitted.

| Requirement | Implementation and proof |
| --- | --- |
| 1. Trigger and lifetime | The burst starts on the beam's creation frame at the claimed offer icon's last displayed center. The shared stamp presents all 16 frames at 30 fps, then frees itself after 533⅓ ms. The verifier checks the stamp independently of claim settlement and exercises room exit and scene teardown during delivery. |
| 2. Draw order | The burst uses the offer icon's effective canvas z minus one. The inactive pointer fixture measured icon z 102 and burst z 101. The existing refresh dismisses the icon on frame 0, ahead of delivery on frame 1. The offer has no lift or flight, so the burst stays at its last pose while the beam and motes travel to the HUD. |
| 3. Size | The displayed 76×76 logical icon gives a wanted radius of 117.74 logical px. The shared chooser selects the nearest sheet. The source shader supplies integer cells, pixel snapping, nearest indexed sampling and regular alpha blending. |
| 4. Color | Uses the fnd-01 palette ramp from the relic accent. Venom Signet uses `#4b84d8`, Storm Crown uses `#d9862f`, and the verifier checks `#d8b25a` for an absent accent. |
| 5. Claim paths | Plain treasure offers, both Curator's Patience confirmation callbacks and Guardian trophies reach the same claim method. The proof uses the live Curator dialog and saves Storm Crown for the next offer, then exercises Ashen Reaver's Ashen Brand trophy through its production reward fixture. |
| 6. Preparation | The offer state prepares and prewarms the relic-size sheet using the existing atlas cache. The verifier checks the selected atlas is present before activation and the stamp uses the same resource with no loader active. |
| 7. Reduced motion | As with reward cards, the burst plays in full. It starts when the reduced-motion claim begins. The relic beam and motes remain suppressed by the existing reduced-motion path. In the fixture, the burst outlives the claim unlock. |
| 8. Pacing | Baseline and after traces match for beam and motes, HUD bounce, final settle, claim completion and map reveal. The sound call and existing awaits are in their original positions. The fnd-01 verifier passed for the shared card and pickup paths. |

## Claim paths found

`_on_relic_pressed` routes plain, Curator's Patience and Guardian trophy offers to `_claim_relic_with_deferred`. Dragon milestones use `_on_dragon_reward_continue` and can call the legacy flourish independently. Dragon gifts are installed on the next descent. Event relic effects call `RunEngine.claim_relic` from `EventRules`, and merchant purchases use `_on_merchant_buy_pressed`. These other paths do not call the new relic burst entry point.

## Headless size and pacing

| Exact SubViewport | Framebuffer pixels per cell | Sheet radius in cells | Sheet radius in pixels |
| --- | ---: | ---: | ---: |
| 1280×720 | 1 | 124 | 124 |
| 1920×1080 | 2 | 60 | 120 |
| 3840×2160 | 4 | 48 | 192 |

Fixed 60 fps offsets from the accepted action. A dash marks an absent effect. The probe samples before node processing, so the beam node appears one sample before its tween makes it visible. The burst skips its birth tick and the first sample after 32 playback ticks observes its removal.

| Case | Offer dismissed | Beam created / visible / removed | Motes start / end | Settlement / HUD bounce / final settle | Unlock / map | Burst start / removed |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Plain Venom Signet, Storm Crown, Curator and Guardian, base | 0 | 1 / 2 / 28 | 1 / 30 | 30 / 31 / 96 | 103 / 103 | — |
| Same four claims, after | 0 | 1 / 2 / 28 | 1 / 30 | 30 / 31 / 96 | 103 / 103 | 1 / 34 |
| Reduced motion, base | 0 | — | — | 0 / 1 / 9 | 16 / 16 | — |
| Reduced motion, after | 0 | — | — | 0 / 1 / 9 | 16 / 16 | 0 / 33 |

[Pinned base frame data](/private/tmp/labyrinth_codex/fnd-02/verify/before/pacing.json) · [After frame data](/private/tmp/labyrinth_codex/fnd-02/verify/after/pacing.json)

## Verification

| Check | Observed result |
| --- | --- |
| Real RunScene on pinned base | `FND-02 VERIFY BASE: 35 checks, 0 failures` and `TEST RESULT: PASS` |
| Real RunScene after implementation | `FND-02 VERIFY AFTER: 194 checks, 0 failures` and `TEST RESULT: PASS` |
| Existing fnd-01 card and gear verifier | `FND-01 VERIFY: 111 checks, 0 failures` and `TEST RESULT: PASS` |
| Treasure presentation | `TREASURE PRESENTATION PROBE: PASS` |
| Deck element rewards | `DECK ELEMENT REWARDS: 0 failures` |
| Dragon rewards | `Dragon rewards, gifts, wallet recovery and relic hooks passed.` |
| Deferred reward dialog | `SKILL UI DEFERRED CHOICE: PASS (0 failures)` and `SKILL UI TEST: PASS` |
| UI identity lint | `Ran 25 tests in 7.491s` and `OK` |
| Python default group | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 41.060s`, `FAILED (failures=1)`. The sole failure is the existing Git inventory finding for missing `tools/qa131/{board_effects,live_effects,relic_glossary}.gd.uid` already absent from the pinned base. Rules text printed `PASS: Rules text lint (16 existing hits)`. |
| Godot parse checks | `--check-only` exited 0 for the two runtime scripts, the verifier and the native capture script through the task runner. |
| Capture plan | Four `TEST RESULT: PASS` receipts, `FND-02 CAPTURE PACING PASS venom`, `FND-02 CAPTURE PACING PASS storm`, and `FND-02 CLIP PLAN: 240 frames at 60 fps with audio`. |
| Tooling | Shell syntax, Python encoder compilation, proof-contract parsing and `git diff --check` exited 0. Three Godot UID sidecars were generated for the new proof scripts. |

[Check logs](/private/tmp/labyrinth_codex/fnd-02/logs) · [Headless capture receipts](/private/tmp/labyrinth_codex/fnd-02/plan)

## Proof for the design owner

Run the following from a WindowServer session.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fnd-02 && /private/tmp/labyrinth_codex/fnd-02/native.sh
```

The launcher uses `tools/visual_probe_runner.py`, the exact 1920×1080 SubViewport, 100% UI scale and the existing cel variants with `LABYRINTH_CEL_LOOK=all`. It writes:

- `/private/tmp/labyrinth_codex/fnd-02/native/{before,after}/{venom,storm}/strip.png`, with six 640×640 crops at +0, +66, +133, +233, +366 and +500 ms.
- `/private/tmp/labyrinth_codex/fnd-02/native/{before,after}/{venom,storm}/{native-evidence.png,take.json,manifest.json}`.
- `/private/tmp/labyrinth_codex/fnd-02/native/relic-claims.mp4`, a 4-second 1920×1080, 60 fps montage of the after claims with the in-game audio mix.

## Files changed

- `scripts/run_scene.gd` snapshots the offer pose and launches the burst at the delivery boundary.
- `scripts/acquisition_burst.gd` prepares and launches the relic stamp through the shared controller.
- `tools/fnd02/{relic_take,verify,native_capture}.gd` and their UID sidecars provide the fixtures, verifier and recorder.
- `tools/fnd02/{native.sh,encode_clip.py,proof_contract.json,result.md}` provide the launch, encoding, proof validation and this handoff. The requested scratch launcher invokes the repository launcher.

## TODO_DESIGN placeholders

None.

## Chosen defaults

- Storm Crown supplies the second accent. Ashen Reaver supplies the Guardian trophy. The Curator fixture repairs a legal skill selection at maximum fixture level and defers Storm Crown. Both native takes use the QA seed 131011. The room-exit case uses the first available adjacent room.
- The verifier allows 240 frames for each stage and gives the audio thread 100 ms of wall time at teardown. Fixture settings disable background muting so proof audio survives window focus changes.
- The MovieWriter launcher requests fnd-01's 64×64 sink for the audio sync reference. Each 120-frame take includes a 12-frame lead. The native runner allows 120 seconds per capture. Output is encoded as H.264 with AAC.

## Open issues

- Windowed captures and renderer review are pending. The dry run exercised the scene, timing and output paths.
- The supplied worktree lacked 48 generated Godot texture artifacts. The matching candidate import cache restored them locally. Both headless verifier runs printed `ERROR: 1 resources still in use at exit.` and identified `res://scripts/run_scene.gd (GDScript)`. The Python default group's QA-131 sidecar finding is recorded above.
