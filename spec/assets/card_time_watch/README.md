# Card time-cost watch: source and provenance

`watch_source.png` is the original painting behind the card time-cost badge
(`assets/art/ui/card_time_watch.png`). It was generated on 2026-09-30 with
Codex's built-in image generation tool (`codex exec`), as the first of three
variants, and copied here unchanged (1024×1024 RGB PNG on flat chroma green). It
lives under `spec/` so it is excluded from exports.

| File | SHA-256 |
| --- | --- |
| `watch_source.png` | `b949552f817bf35c68bf42119bfa87cc5adbf72d14a3273ef06d9d53e40d8806` |

Prompt:

> A single ornate antique brass pocket-watch body seen perfectly face-on,
> centered, filling about 70% of the frame, for a dark-fantasy deckbuilding
> card game UI. Hand-painted, painterly game-icon style matching the
> bronze-and-wood card frames in the reference card: warm aged brass and bronze
> with burnished highlights on the upper-left and deep shadow lower-right,
> slight wear, rich but not glossy, crisp readable silhouette at very small
> sizes. The dial must be EMPTY: no clock hands, no numerals, no text, no
> logos; the centre is a plain, dark enamel. Around the rim of the dial: 12
> small brass hour markers (slightly bolder at 12, 3, 6, 9) and a fine minute
> track. A thick brass bezel ring with a fine knurled/milled outer edge. A small
> winding crown with a bow loop at the top of the case. Background: perfectly
> flat, uniform pure chroma green (#00FF00), no shadow. Variant: classic polished
> brass hunter-case pocket watch, dark brown-black enamel dial.

The production texture is keyed, un-mixed from the green, cropped and
downscaled with premultiplied alpha by:

    python3 tools/process_card_time_watch.py spec/assets/card_time_watch/watch_source.png

which also writes `assets/art/ui/card_time_watch.json` (dial centre and case
radius). `TimeCostBadge` in `scripts/card_widget.gd` mirrors those numbers and
draws the hands, crystal sheen and cost numeral over the painting;
`tests/test_card_time_watch_asset.py` keeps the two in step.
