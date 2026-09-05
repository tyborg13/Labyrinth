# Wishlist cut — editorial contract

The promise is tactile card-driven tactics in an atmospheric labyrinth: turn the room into a weapon, choose new cards, illuminate danger, spend the run's earnings, and combine elemental attacks. The opening communicates a real card action and its outcome without sound. The revision makes the trailer copy large and centered, adds real card rewards and a shop purchase, and trades lingering combat aftermath for air, earth, and lightning mechanics.

Valve recommends predominantly gameplay from the player’s perspective, retaining useful HUD elements, and communicating quickly because a viewer may decide within ten seconds or watch muted. Steam’s microtrailers sample the first store video at multiple points, so meaningful game imagery should occupy most of the cut. Source: [Steamworks trailer guidance](https://partner.steamgames.com/doc/store/trailer).

The visual baseline is informed by official store media for [Shogun Showdown](https://store.steampowered.com/app/2084000/Shogun_Showdown/), [Alina of the Arena](https://store.steampowered.com/app/1668690/Alina_of_the_Arena/), and [Into the Breach](https://store.steampowered.com/app/590380/Into_the_Breach/). The useful comparison is clarity: strong actor silhouettes, an identifiable action control, and an outcome that remains readable at store-player size. This is an editorial assessment, not a claim of measured conversion or equal commercial quality.

| Beat | Source | Viewer should understand | Reading and action hold |
| --- | --- | --- | --- |
| Opening | `trap_combo` | A card moves an enemy into an environmental trap and clears the cluster. | Large centered two-line title clears by source f43; the real center-card commitment starts f44. Cut after the enemy collapse, without waiting on an empty room. |
| Card rewards | `spell` | Choose one new spell from real card rewards. | A top-center headline leaves the live reveal and complete card faces visible; include the actual claim and learned-spell result. |
| Darkness | `umbra` | A light attack reveals enemies hidden in the Umbra. | The centered title clears before commitment. Every actor and health bar stays in frame. Cut after the reveal and natural hand draw. |
| Route | `route` | A run branches through connected rooms. | 1.5 seconds, with no editorial caption or extra reading burden. |
| Shop | `merchant` | Spend embers on a stronger build. | Complete production stock and prices, actual purchase, and the changed balance. Top-center headline clears before the purchase. |
| Gear | `equipment` | Equip the run's gear. | A motivated cut skips room waiting. The complete menu swap plays at 0.8× for readability. |
| Air | `air` | Push an enemy across the board. | Trim repeated aiming lead-in and show the complete real displacement with a brief settled result. |
| Earth | `earth` | Send earth spikes through the room to immobilize a distant enemy. | Keep the full traveling-spike animation, damage, and root outcome; trim repeated initial aiming lead-in and inert tail. |
| Lightning | `lightning` | Chain an attack through multiple targets. | Keep the whole chain and its results. The title dissolve begins after the action has resolved. |
| Title | Existing key art / title | Remember Escape the Umbra and wishlist it on Steam. | Centered game title and enlarged Steam CTA remain together for almost four seconds. |

Exact source trims, durations, playback rates, and sound cues live in `SHOTS` in `src/Trailer.tsx`; `START` is derived from the ordered shots and final twelve-frame dissolve. `sourceCue` maps a source event through its trim and playback speed to an edit frame. Recheck cues and final source bounds after recapture; do not infer effect timing solely from the engine's awaited completion marker. The `impact` field marks the sound/effect onset: Air path f63 (hit f68), Earth crack f65 (travel f68–72, damage/light f73), and Lightning chain f57 (damage f58).

Trailer headlines use the exact game font rendered at 128px, rather than small peripheral labels. Inspect the master at 390px wide as well as at 1080p. Headlines must remain immediately legible, and combat overlays must be fully gone when the played card takes center stage. The reward headline sits above the cards; the shop headline clears within its first second, leaving the browse and purchase unobscured.

Review fresh source footage for complete HUD and shop bounds, card reveal/claim, legal combat effects, complete actor and health-bar framing, readable outcomes, and equipment destination. Inspect master frames at every action and on both sides of each cut, then review complete normal-speed playback and a muted phone-size pass. Confirm 1920×1080/30 fps, H.264/AAC stereo, no black gaps, no frozen padding, and no audio clipping. Record any limits of auditory review accurately in the proof.
