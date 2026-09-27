# Dragon reward and Emaciated Man feedback revision

## Design and acceptance

Reward surface: after Continue, the player sees the trophy travel through the standard relic-room beam/motes and HUD settlement; only then does the reward panel fade and the map fade in. Ownership/analytics commit before presentation. A next-run trophy points to its explicit next-run receipt instead of implying present-run ownership. Pointer and keyboard/controller activation share one guarded callback; motion reduction keeps a brief static receipt and fades.

Entrance dialogue: Speak remains ordinary narrative. After the first dragon, the next encounter with the Emaciated Man gives a three-line awakening introduction. Reading the final line saves its acknowledgment once, revealing the separate Awaken Power room action. That action opens the existing wallet offers. Trade, level-up, Leave, focus/back, affordability, and profile-first transaction semantics stay shared with the existing controls. Fresh 1920x1080/100% proof covers introduction, revealed actions, funded/disabled offers, controller focus, acquisition, map fade, and reduced motion. Legacy dragon/Shards profiles receive the introduction once.

Acceptance: no automatic service page after ordinary Speak; no premature unlock on interrupted introduction; permanent service survives spending Shards and resume; failed persistence does not consume the introduction; double Continue cannot duplicate rewards; map stays hidden throughout delivery/settlement; scene cancellation cleans transient motion without altering saved claim.

## Verification

Focused `tests/dragon_reward_feedback_test.gd`: PASS. Covers pre-dragon gate, durable first-dragon receipt after spending, ordinary narrative without service options, persistent/idempotent acknowledgment, profile/run revision recovery, and legacy progression compatibility.

`tests/dragon_reward_feedback_probe.gd`: PASS through the task visual runner, 14 validated 1920×1080 images at 100% scale. Proof copied to `/private/tmp/dragon-reward-feedback-proof-v3`; every PNG inspected at original resolution. Covers interrupted introduction, failed profile save/retry, final acknowledgment, separate room controls, keyboard focus, controller candidate reachability/activation, funded and disabled trade/level state, live credit, repeated Speak, repeated Continue, saved claim before delivery, standard beam/motes, HUD settlement before map, fade midpoint/final map, reduced motion, next-run trophy destination, and interrupted-delivery resume.

Command (from this task worktree):

```sh
python3 tools/godot_task_runner.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --stream -- godot --headless --path . --script tests/dragon_reward_feedback_test.gd
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 60 --expect-size 1920x1080 tests/dragon_reward_feedback_probe.gd --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange
```

The 60-second probe budget covers fourteen captures, multiple full RunScene loads, and four sequential delivery/cancellation paths. Initial probe discovered a stale controller candidate after rebuilding the room action row: fixed by clearing candidates before freeing their controls. The room action row now participates in controller navigation, and NPC focus says Speak.

Existing `dragon_rewards_test.gd`: PASS after the Worldheart fixture correction. The fresh task-runner run `dragon-boss-encounters-milestone-rewards-1790532351673761000-28398` exited 0; the persistence/outbox error lines are deliberate recovery tests. Transcript: `/private/tmp/dragon-relay-fixed-dragon_rewards_test.gd.txt`.

Rubric: immediate comprehension, gameplay visibility, compact/precise copy, state/consequence, interaction completeness, visual cohesion, accessibility, layout resilience, and visual proof PASS. Visual hierarchy also passes after the prompt correction below. Shared UiSkin buttons, standard dialogue panel, relic acquisition beam/motes/settlement, inline relic rules, and map panel are reused. No icon identity change.

Final v3 rerender suppresses the room's “Choose Door” board prompt throughout dialogue, including after transaction refresh. All fourteen final frames were inspected again at original resolution; no clipping or overlap remains. Full regression, exact-HEAD independent peer review and final resettable inspection fixtures remain owned by root.
