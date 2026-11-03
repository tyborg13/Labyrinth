# The polish slot

Owner, 2026-11-01: "a 5th slot ... claude-only (except using codex for imagegen as needed) ... permanently dedicated to self-identified polish items. Visual, audio, feel, balance, UI/UX etc. Whenever it finishes an item, just throw it in the queue like our codex threads for me to approve/reject/request rework, and then look for something else to pick up."

**Paused (owner, 2026-11-02):** "Let's pause the claude only polish thread on picking up new tasks for now. We can still close out anything I approve and start it up later after I ask." Don't start new items until the owner asks. Approved branches still merge as below.

This file is the slot's standing brief. Each item is one fresh Claude agent, which reads this file and the ledger.

## The loop
1. **Pick** the item you believe most raises the game's quality for its size, from what you see in the real game. Look at it, don't guess: capture real screens and clips, listen, read the numbers. Take from `LEDGER.md` under "Spotted" if something there is still the best choice. Add anything else you notice to "Spotted" in your report. Don't let an item wait on the owner: pending items never block the next one.
2. **Build** it on your own branch, committed. **Keep it small:** one point the owner can judge in one look or listen, one diff I can read in one skim. If it's growing, cut it down and report the rest under "Spotted". You make the taste calls; that's the point of this slot.
3. **Prove** it in the real game and prepare the inbox entry. Then stop and report. The director reviews, posts it to the queue and starts the next item. You do not post to the inbox and you do not merge.

Anything goes: visuals, animation, audio, game feel, balance, UI/UX, text. Good sources: first-time readability, moments that feel flat or abrupt, screens with less finish than their neighbours, missing feedback on an action, inconsistent timing or wording, sound gaps, numbers that make a card or item obviously right or obviously useless.

## Not this slot's work
- Anything a running Codex unit owns. Run `python3 ~/.claude/skills/orchestrate-codex/scripts/codex_unit.py status` and read `spec/peer_benchmark/STATUS.md`; stay out of their files.
- Enemy repaints and rigs (their own pipeline), dragon rework, Last Light and the Hoarder (on hold), save formats, new mechanics, new enemies, whole new screens. Fix or finish what exists.
- Anything the owner already rejected or decided. Read `LEDGER.md`, skim `spec/peer_benchmark/decisions.md`, and grep it for your topic first.

## Read before picking
Memory, in `/Users/borgerding/.claude/projects/-Users-borgerding-workspace-Labyrinth/memory/`: `owner-aesthetic-taste.md`, `design-no-one-off-rules.md`, `review-inbox.md`, `test-time-budget.md`, `events-no-dice.md`, `priority-gameplay-over-repaints.md`, `store-copy-voice.md`, `visual-identity-gate.md`, `windowed-capture-visibility.md`, `owner-plays-on-dev-mac.md`, `machine-resource-limits.md`, `disk-hygiene.md`.
Project: `AGENTS.md`, `spec/visual_design_system.md`, `spec/ui_identity_gate.md`, `spec/visual_identity_gate.md`, `spec/icon_identity_policy.md`, `spec/card_balance_heuristic.md`, `spec/analytics.md`. Read the ones your item touches.

## Rules
- **Worktree.** `python3 ~/.claude/skills/orchestrate-codex/scripts/codex_unit.py new pol-NN --base codex/peer-benchmark`, next free number from the ledger; if the id is taken, use the next one. Work in `/Users/borgerding/workspace/Labyrinth.worktrees/pol-NN`, branch `codex/pol-NN`. Then `python3 tools/parallel_task.py contract ...` and `preflight`. Commit on your branch, ending each message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push, never touch `master`, integration or another worktree, and don't edit `STATUS.md` or `LEDGER.md` (the director owns them).
- **Godot** through `tools/godot_task_runner.py --task-id pol-NN --stream -- godot ...`; visual probes through `tools/visual_probe_runner.py`. Follow `AGENTS.md` for typed arrays and player-facing work.
- **Tests.** No full suites. Focused tests for what you touch, and `tools/run_python_suite.py --shards 4` if you touched data or tools. No new permanent guards, except a failing-first regression for a real bug, or rules, saves and progression. Run `tests/test_ui_identity_lint.py` for UI, `tests/test_art_identity_gate.py` for board art, `tests/test_icon_identity_policy.py` for icons.
- **Balance** changes get scored with the heuristic. Rules text stays precise. **No one-off rules:** build from existing primitives.
- **Art and audio.** Claude authors; image generation goes through `python3 ~/.claude/skills/orchestrate-codex/scripts/codex_unit.py imagegen <job> --prompt-file p.md --ref a.png b.png` and is a detached run: arm nothing yourself, tell the director if you need to wait. Board art goes through the identity gate. Downloaded assets only if licence-clean, with provenance.
- **Windowed runs and the owner.** Before every windowed capture, run `sh /Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/spec/peer_benchmark/director_tools/owner_game_open.sh`. Exit 0 means a game is open and the owner may be playing: stop and report `BLOCKED: owner playing`. (Don't grep full command lines yourself: shells that mention the game give false positives. The bare editor process is not a game.) Run windowed jobs under `python3 ~/.claude/skills/orchestrate-codex/scripts/codex_unit.py locked -- ...`. Never use osascript. If a capture makes no new frames for a minute, the window is hidden: stop and report it. At most 4 ffmpeg, `-threads 2`. Don't start a background loop. Don't kill anything you didn't start.
- **Disk.** Keep 40 GB free (`df -g /`). The director removes your worktree after posting.

## Evidence
Real game, real renderer, 1920x1080, 100% UI scale, normal HUD. Never a synthetic probe board. Sound where sound matters. Real-time clips: the movie writer via `spec/peer_benchmark/director_tools/fb18_clip.py` and `fb18_clip_probe.gd` (saving a PNG per frame distorts timing). Stills: see `event_gallery_probe.gd` in the same folder. `tools/inspection_fixture.gd` builds real rooms. Before and after, side by side or as two clips, when the change is subtle. Each file at most 15 MB, under `output/polish/pol-NN/` in the primary checkout (`/Users/borgerding/workspace/Labyrinth/output/`). Look at every image and at frames from every clip yourself before reporting; a broken capture wastes the owner's time.

## The report (your final message)
```
ITEM: pol-NN  BRANCH: codex/pol-NN  HEAD: <sha>
TITLE: <under 70 characters, what the player now gets>
LOOK: <2 to 5 plain sentences for the owner: what was wrong, what changed. No system names, no jargon. Say if something is uncertain.>
QUESTIONS: <1 to 3 specific questions the owner can answer from the media>
MEDIA: <absolute path | caption>, one per line
AREA: Polish: <visual|audio|feel|balance|UI|text>
PROOF: <the tests and commands you ran, with their results>
FILES: <files changed, one line>
SPOTTED: <other things you noticed, one line each, worst first>
```
If you stop early, say why in the first line (`BLOCKED: ...`) and leave the branch committed.

## Director's side
On a report: skim the diff, look at the media, then upload and post one inbox entry (`id` = `pol-NN`, `area` = the report's AREA, `status: open`), remove the worktree but keep the branch, update the ledger, and start the next item right away. Add a launch command only if the owner would want to feel it in play.
On a verdict: **approved** → merge the branch into integration (`WT` set to a fresh or removed worktree path as needed; `SKIP_SUITES=1`), update the ledger. **Rejected** → delete the branch, write the reason in the ledger's "Owner said no" so the slot learns. **Needs changes** → a fresh agent reworks that branch (at most 3 rounds), alongside new items.
Items wait on their branches until approved, so nothing unapproved reaches a playtest.
