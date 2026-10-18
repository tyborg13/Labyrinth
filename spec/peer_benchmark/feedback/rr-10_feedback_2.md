# rr-10 feedback 2 — exact rope mask (TODO_DESIGN_rope_colour_connectivity decided)

The colour rule caught only the rope's bright highlights. The director authored the exact mask instead, as protected
data: `spec/peer_benchmark/staged/rr-10/rope_mask_front.png` on `codex/peer-benchmark` (integration worktree
`/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark`).
- It is a 255×255 RGBA image in the approved front painting's source pixels (`jobs/hoarfrost_seer/mq5_front/processed.png`).
- Opaque white pixels (465) are the whole rope: the belt band, the pale knot ring, the pale left tail and the brown
  right tail down to their tips, plus their 1 px dark outline. It is one connected component.

Copy it byte for byte into your case inputs, hash-bound, and use it as the exact ownership override:
- every masked pixel belongs to `torso`;
- unmasked pixels keep their current owner;
- the robe beneath the tails gets the painted cloth continuation (dark-slab gate), so the 2 px idle bob reveals cloth.

The rear rope mask comes with the rear repaint. Keep the rear rule data-driven (`rope_mask_rear.png` when supplied).
Drop the colour rule and its TODO.

After this, stop. The director runs `rest`, `native` and `sheets` on the real renderer and reviews them before the
rear arrives.
