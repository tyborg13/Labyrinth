# ev-02 feedback 1 (director native run; captures in output/peer-benchmark-2026-10-12/proof/ev-02/)

1. **Painting brightness (blocker).** In-game the event painting renders far darker than the approved art and the
   mockup (compare `proof/ev-02/cmp_mock.png`: top = in-game, bottom = mockup; frozen_champion is less affected
   because its art is brighter). The painting must show the source colours at full brightness; only the edge fades
   (right 18%, top 7%, bottom 10%) may darken it. Find the root cause (modulate/self_modulate, a scrim or panel layer
   drawn over the art, the alpha mask multiplying the whole image, a shader, colour space, or the processing tool) and
   fix it. Add an assertion: the mean luminance of the painting's central 40% region in the capture is within 8% of
   the same region of `assets/art/events/<id>.png` scaled to the drawn size.
2. **Reduced motion** fails natively ("no rise", "no painting zoom"): with reduced motion on, the panel must not rise
   and the painting must not scale (fades only). Fix and keep the assertions.
3. **TODO_DESIGN values accepted**: painting fade-in 0.22 s, outcome-row fade 0.18 s. Rename the constants without
   the prefix.
4. **Ownership granted**: update `tests/suites/event_rules_suite.gd` legacy UI test that calls the removed
   `_refresh_event` so it exercises the new EventView instead (or remove only that obsolete UI step, keeping every
   rules assertion). The event_rules suite must run clean.
5. Keep everything else; the choice plates, tones, result page and omen badges/tooltip look right.
Rerun: event_view suite, event_rules suite, section_map suite, full suite; the director reruns the native probe.
