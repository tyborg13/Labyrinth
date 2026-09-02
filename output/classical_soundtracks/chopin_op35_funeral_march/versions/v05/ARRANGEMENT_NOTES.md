# v05 arrangement notes — approved death-screen integration

## Approved musical content

- v05 preserves the project-owner-approved v04 arrangement MIDI byte-for-byte: the contiguous source measures 93–100 selection, 66 QPM tempo, uniform three-semitone lowering into G minor, original voice order, and one-beat renderer overlap.
- It adds no cuts, reordered measures, repeats, bridges, notes, or voicing changes.
- The expressive initial melody remains structurally exact to v04. The recognizable Grave Cello and Veiled Violin lead remains suppressed only in the latter source measures 99–100.

## Integration-only revision

- v05 exists so the approved v04 music can receive fixed encoder selection, frozen output hashes, strict verification, provenance documentation, and in-game promotion without modifying the audition artifact.
- The promoted Ogg must be an exact byte-for-byte copy of the verified v05 Ogg.
- The game route is limited to terminal player defeat: combat music fades out at the start of the player death animation, this track fades in and loops through the defeat recap, and scene or run-mode exit stops or replaces it.
- Normal combat, nonterminal player defeat, enemy defeat, and boss routing remain unchanged.

## Approval

- The project owner approved the v04 musical direction for an in-game death-screen trial on 2026-08-31.
- Approval covers v05 only while its arrangement MIDI and rendered audio remain byte-for-byte identical to v04.
