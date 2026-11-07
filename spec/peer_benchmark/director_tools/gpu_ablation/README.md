# GPU ablation census (sd-12, 2026-11-06)

sd-12's tools: native Vulkan (MoltenVK) GPU timestamps per arm. Each arm hides or disables one rendering system; baselines A/B bracket the arms. `.gd` files carry a `.txt` suffix; drop it when copying into a tools folder.
- **Run:** `proof.py --native --run-dir <dir>` against a bound scratch project (see `prepare.py`), then `report.py --run-dir <dir>`.
- **Unfocused samples are accepted** (director, 2026-11-06). Focus can't be forced without OS window control, and A/B pairs showed no focus bias.
- **UI scale** is compared within 1e-4, because Godot reports it as float32.
- **Result:** `sd-12_tables_2026-11-06.md`. On the Mac, the whole frame takes about 1.5 ms of GPU time. hud_hand (UiRoot, card proxies, board HudRenderLayer and the hand-cache viewport) is the top cost in every fight state: 0.6-1.4 ms, above noise in dragon action, Skills and fight idle. Nothing else clears the 0.4-1.4 ms baseline drift.
