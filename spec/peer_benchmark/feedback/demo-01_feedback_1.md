# demo-01 — round 1 (director decisions for both TODO_DESIGN placeholders)

The protected clip list is updated (spec/peer_benchmark/staged/demo-01/clips.json, copied over
tools/demo_clips/clips.json byte-for-byte):
1. `caption_style.subtitle_top_px = 84` (title top 40 px, 34 px title, 10 px gap; subtitle x = title x = 48). Read it
   from caption_style; delete the `TODO_DESIGN_caption_subtitle_y` placeholder and its file entry.
2. dragon_breath: Vyraketh's next intent reveal during the 1.4 s tail is fine and stays in. Remove the
   next-intent-before-tail check; keep "ends 1.4 s after the breath settles".
Then rerun `pipeline.py validate` (all 21 must pass) and the affected tests. Do not commit. Repeat the windowed list.
