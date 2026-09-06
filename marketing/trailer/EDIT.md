# Wishlist cut — revision 3

The promise is card-driven tactics with visible cause and effect. Two continuous turns frame the run's choices: push an enemy into a cross-shaped area attack, then in another room reveal enemies with Earth and connect them with lightning. Planning and movement stay wide; the second payoff receives one restrained camera move. Every action plays at its captured speed. The 40.6-second cut gives decisions time to register without adding inert post-action holds.

The reference study in [RESEARCH.md](RESEARCH.md) preceded implementation. It covers ten official Steam trailers across deckbuilders, 2D tactics and hybrids, and separates observed frames from inferred editorial techniques. It informed both production changes and the edit.

| Beat | Source / trim at 30 fps | Purpose |
| --- | --- | --- |
| Push, move, AOE | `push_bloom`, 0–351 | Updraft pushes a full-health crawler two tiles into a three-target cross. Two movement tiles bring Cinder Bloom into range. Fire intensity rises through the real card; the eight-damage attack kills the wounded crawler and burns the two survivors. The objective and Turn Clock settle together. |
| Card reward | `spell`, 0–137 | Read three complete card faces, choose one, and see the production acquisition. Large copy sits above the cards. |
| Route | `route`, 8–49 | A 1.4-second glimpse of the connected run, including the real transition. |
| Shop | `merchant`, 0–125 | Browse actual stock and buy a spell. Currency and ownership update immediately while the new acquisition proxy lifts and travels toward the pack. |
| Equipment | `equipment`, 97–189 | Swap Grave Greatsword for an owned Duelist Rapier, see its three deck cards and the displaced Greatsword in reserve. A fixed 1.08× frame keeps the complete panel visible. |
| Earth, move, chain | `root_chain`, 0–347 | Root Snare damages and immobilizes a visible enemy, revealing two hidden neighbors. Reposition, then Chain Bolt reaches all three. Bolts and damage arrive in actual resolver order. One eased 1.60× framing move begins at the Chain Bolt commitment and settles before lightning contact. |
| Title | Existing menu illustration | Twelve-frame dissolve, centered title and large Steam wishlist call to action. |

Exact durations and camera keys live in `SHOTS` in `src/Trailer.tsx`; `START` and composition length derive from that one table. Captures have adjacent `.cues.json` manifests containing source frames, actual engine state, audio provenance and timing markers. Both tactical scenes start at full native health with two card plays and two movement points. Capture setup validates passability, targeting, visibility, damage and native encounter intensity. Distinct legal rooms and positions replace the prior attack catalogue.

Headlines use the game's font rendered at 128px. Opening copy clears by frame 43, before the actual card commitment. Reward copy sits above the card faces; shop copy clears before purchase. Verify at 390px width as well as 1920×1080. The last tactical crop keeps every relevant actor, health bar and lightning hop in frame; full HUD and cards are visible during the preceding planning segment.

## Audio

Sources retain the actual game SFX recorded by Godot; only music is muted during capture. The editor reads audio from the same MP4 and source trim as its video. Reward and purchase releases continue naturally across the next cut for 90 frames. The production boss score provides one continuous bed. There are no manually placed substitute attacks or acquisition cues. In particular the obsolete `reward_collect.wav` used in revision 2 is gone; production rewards and the shop use `run/reward_accepted.wav`.

Wall-clock telemetry checks the movie capture against encoded frames. Final opening Bloom effect is 22 frames / 0.733s versus 0.714s observed wall time and 0.720s authored duration. Native timing quantization is small; the old multi-second dead time came from sequential game responses. Battlefield defeat and Turn Clock now animate concurrently.

## Targeting follow-up

The approved edit stays unchanged. Updraft and Cinder Bloom now show one hand-origin arrow; AOE footprints, forced-movement floor cues, actual projectiles and enemy intent arcs remain. Only `push_bloom` was recaptured. Every recognition, aim, commitment, movement and impact cue matches revision 3 exactly. Final input readiness is source339 instead of340, and the existing cut through351 still includes the settled result. The corrected encoded master remains1219frames /40.633seconds. Previous approved footage, cues, editor and master are archived in ignored proof before replacement.

## Review

Inspect fresh source frames, all cut boundaries, consecutive impact frames, the complete master at normal speed, and phone-size copy. Check source bounds including audio tails, no frozen padding, complete menu panels, readable actor silhouettes and real acquisition results. Validate 1920×1080, 30fps, H.264 High/AAC stereo, limited-range Rec.709, black gaps and audio peaks. Record actual review limits: browser playback and sampled video frames are visual evidence; audio provenance and measured levels do not substitute for a subjective listening review.
