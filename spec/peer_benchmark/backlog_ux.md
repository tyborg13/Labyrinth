# Playability / UX backlog (owner-raised; schedule after the running wave)

1. **Start room → map** (owner, 2026-10-12): after the Emaciated Man's opening text in the starting room, go straight to
   the section map instead of asking the player to pick a door in the room with no indication of where it leads.
   (Pre-existing.) Design note: the Threshold room's doors are meaningless without the map; the map is where the route
   choice lives.
2. **Threats-at-rest presentation** (owner, 2026-10-12): floating intent pills over heads don't look right; keep the
   per-enemy order number but present it differently; AoE danger tiles shown at rest without any indication of the
   source look out of place. → director mockups A/B before any implementation.
3. **SFX loudness** (owner, 2026-10-12): volumes all over the place; card hover inaudible. Mix pass applied a2f97f63e;
   three transient-heavy cues still short of target (hit.blade.light, status.shatter, status.freeze) → need a build
   limiter/compressor stage in sfx_lab, then re-render those.
4. **Enemy-turn speed** (owner, 2026-10-12): undecided, needs more testing.
