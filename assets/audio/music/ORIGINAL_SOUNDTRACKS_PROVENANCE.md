# Original soundtrack integration

The project owner approved these four original compositions for in-game audition
on 2026-09-24. `ORIGINAL_SOUNDTRACKS_APPROVAL.json` records the selected versions,
exact Ogg/FLAC/MIDI hashes, source manifests and authorization. Production Oggs are
byte-for-byte copies of the approved previews; no remixing or re-encoding occurs
during promotion. Earlier audition source/approval snapshots remain immutable.

| Scene | Music |
| --- | --- |
| Opening room, campfire, treasure, cleared rooms, rewards, victory | Lanterns Below v02 |
| Pre-battle, map/events, pause/settings, character/loadout, grimoire, card piles, merchant rooms | The Turning Key v02 |
| Standard combat, including elemental encounters | Ashen Pursuit v03 (violin ensemble) |
| Guardians/mini-bosses and non-dragon boss-bar enemies | Thorns in the Dark v02 (violin ensemble) |
| Dragon bosses (Zekarion, Tharokh, Vyraketh, Vaeloryx, Iskaldra, Noctyrax) | Each dragon's own theme v01 (awaiting audition) |
| Main menu and its submenus | Existing Old Castle v07, unchanged |
| Defeat | Existing Chopin Funeral March v05, unchanged |

The selection is context-based: full in-run planning surfaces temporarily use
The Turning Key and closing them restores the underlying room/combat cue once
the destination is settled. Automatic travel, reward/relic delivery, and scene
bridges retain the current playback through their complete animation; an
automatically opening map owns the destination cue. Deliberate navigation has
no minimum-duration delay. Escape transitions retain the preceding cue until
the next scene settles. A HUD minimap or small tooltip does not change music. Terminal defeat/victory outrank
open menus. Each dragon boss plays its own theme; guardians keep Thorns. Merchant choice
screens use planning music; incidental room dialogue keeps its room's cue.

The four sources are original symbolic compositions authored for this project.
The detailed provenance files in their source packages document mathematical
instrument synthesis, seeded noise and the project's generated bowed samples.
No external recording, commercial MIDI, SoundFont, sample pack, ROM/rip or
audio-generation model supplied the music. This is not a public-domain classical
transcription, so the classical-source clearance/promotion command is not used.
The equivalent original-work provenance, owner approval, source hash and exact
artifact checks are recorded here and tested by `test_original_soundtrack_assets.py`.

The files are native Vorbis loops at 32 kHz stereo, targeting -20 LUFS before
in-game volume. Quiet/planning cues use -7 dB playback gain, combat cues -5.5 dB.
Old Castle remains -6.5 dB and Chopin -7 dB; existing bus volume/reverb controls
remain active. Context changes use a short sequential 0.25-second fade-out and
0.65-second fade-in; the existing slower terminal-death transition is retained.

## Dragon themes and stingers (2026-09-30, awaiting audition)

`DRAGON_THEMES_AND_STINGERS_AUDITION.json` records six looping dragon boss
themes and three one-shot stingers from
`output/original_soundtracks/dragon_themes_and_stingers/versions/v01` and `v02`.
After the first audition the owner kept themes 01–05 (v01) and asked for a more
epic final-boss theme and darker stingers: Noctyrax plays v02 take A ("Eclipse
Requiem") pending an A/B choice against take B, and the stingers are v02. As with
the four tracks above, the production Oggs are byte-for-byte copies of the
verified previews, and the source package keeps its own provenance. The themes
are -20 LUFS loops played at the -5.5 dB combat gain. The stingers are -18 LUFS
one-shots on the dry UI SFX path. When the level-up overlay opens, a rare
reward with an epic or legendary card is revealed, or a dragon falls, a
stinger plays while a `MusicDuck` amplify stage on the Music bus dips the score
by 9 dB beneath it and then recovers. Stingers never stack, and a rare-find
stinger fades out the ordinary victory cue's tail. The owner has not yet auditioned them. Approval turns the manifest
`status` to `approved_for_game_integration`.

Inspection and hearing the mix in play are the next step; this integration does
not claim final balancing approval. Technical proof and fixture commands are in
`spec/proofs/original_soundtrack_integration.md`.
