# demo-01 — Scripted demo clips with game audio (owner request after playtest 9)

## Header
- Owner (playtest 9): "I haven't really hit some of the specific cases we want to test. Can you create some specific
  fixtures and just provide me short video clips... the sounds and pixelated magic effects can be tested by
  looking/listening without playing."
- Base: `codex/peer-benchmark` (playtest 9 content, 44500665e + docs). Protected director data:
  `spec/peer_benchmark/staged/demo-01/clips.json` (21 clips in 3 reels: setups, actions, captions, caption style,
  speeds, volumes). Import it byte-for-byte; never edit it. If a clip cannot be staged as written, leave
  `TODO_DESIGN_<clip id>` and report why — do not substitute other cards, enemies or positions.
- Owned: new `tools/demo_clips/**`, new tests for it, `output/demo-clips-2026-10-15/**` (git-ignored outputs).
  Read-only reuse of `tests/sfx_sync_harness.gd`, `tests/sfx_sync_*.gd`, `tools/steam_trailer_capture.gd`,
  `tools/inspection_fixture*.gd`, `tests/pixel_fx_fixture.gd`. Game scripts under `scripts/` are not owned; see R4.

## Change
1. **Clip runner** `tools/demo_clips/demo_clip.gd(.tscn)`: builds each clip in the real run scene (`scenes/run_scene.tscn`)
   from clips.json — room, hero, enemies at the given offsets, traps, the listed hand, forced intents, combat speed,
   music bus volume 0 and every other bus at game default — then drives the listed actions through the same input
   entry points a player uses (card pressed/drag + board tile click, end-turn button, real mouse hover), never by
   calling effect/sound functions directly. Pre-roll 0.6 s before the first input; stop `tail_s` after the last visual
   and audio settle (fixed 1.4 s unless the clip's note says otherwise).
2. **Recording**: Godot Movie Maker (`--write-movie`, fixed 60 fps, 1920x1080, real renderer, windowed) so audio and
   frames are mixed in lockstep. One clip per Godot process. Record losslessly (PNG frames + WAV, or MJPEG at
   quality 1.0) into the git-ignored output folder.
3. **Encoding** `tools/demo_clips/encode.py`: per clip and per reel MP4 — H.264 CRF 16 preset slow yuv420p 60 fps,
   AAC 192 kbit 48 kHz. Burn the caption (title + subtitle) per `caption_style` for the first 2.2 s of each clip with
   a 0.3 s fade. Reels are the clips in listed order, hard cuts, 6 ms audio fades at each cut. ffmpeg `-threads 2`,
   at most 2 ffmpeg processes at once (machine limit). Outputs: `output/demo-clips-2026-10-15/reels/<reel>.mp4`,
   `.../clips/<clip>.mp4`, and `manifest.json` (clip id, duration, frame count, input hashes, sync table).
4. **Clock honesty**: verify the sfx-04 sync scheduler stays correct under Movie Maker's fixed-step time (it uses
   presentation-clock deadlines with wall-time conversion). If it reads wall time, drive it through the existing
   injectable clock seam used by `tests/sfx_sync_harness.gd`; any change under `scripts/` must be behaviour-identical
   when not recording, minimal, covered by a test, and reported. Do not alter cue timing, lengths or mixing.
5. **Sync table**: for every clip with a hit (all except air_pull's pull-only frames are fine to include), measure in
   the recorded WAV + logged frames: visual climax frame time vs audio peak time per cue, and each trap/status cue's
   audible duration (−40 dBFS tail). Report per cue; flag any offset outside the sfx-04 tolerance or any status/trap
   cue longer than 1.2 s. A clip that misrepresents the game (desynced by recording) is a failure, not a footnote.
6. **Determinism**: two recordings of the same clip produce the same event log (actions, cues, frame indices).
7. **Fixture validation** before recording: assert each clip's staged state (positions, hand, intents, traps, speed)
   and that each listed action produced its expected gameplay event (card resolved, trap triggered, Thornwall cast,
   Weaver showed a non-empty intent on the following turn).

## Keep
- No gameplay, art, audio, timing or UI changes. Combat speed names: settings_store COMBAT_NORMAL / COMBAT_FASTEST.

## Proof
- Headless: fixture validation for all 21 clips, determinism check, encode.py unit tests on synthetic frames/WAV,
  full Godot suite PASS.
- Windowed (design owner runs): list the exact command sequence to record all 21 clips and encode the 3 reels.

## Out of scope
- Trailer tooling changes, new cards/enemies, any taste choice not in clips.json.
