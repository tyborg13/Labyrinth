# Performance log

Invisible performance fixes merged on the director's review (owner rule, decisions 2026-11-04). One line each: what got faster, before → after, commit on `codex/release`. Owner-approved perf units from before the rule are listed for context.

**Standing goal:** the game runs smoothly on the Steam Deck (1280x800, Zen 2 CPU, RDNA 2 GPU, Vulkan).

## Before the rule (owner approved in the inbox)
- perf-15: walking through a door hitches much less: worst door frame 275 → ~90 ms headless (ff9a2be22).
- perf-16: New Run and Continue get you playing faster (6925730ee).
- perf-17: an enemy's first appearance doesn't hitch; cold rig construction moved off the critical frame (11ac26d45).
- perf-18: the worst recurring in-fight spike removed (a48d91a7f).
- perf-19: reward and HUD refreshes keep their controls (c44a4db49).

## Since the rule
