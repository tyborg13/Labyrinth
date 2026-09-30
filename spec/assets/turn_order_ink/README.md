# Turn-order brush strokes: sources and provenance

These five paintings are the originals behind the painted initiative rail
(`assets/art/ui/turn_order_ink/`). They were generated on 2026-09-30 with
Codex's built-in image generation tool (`codex exec`, Codex CLI 0.159.2), one
generation per stroke, and copied here unchanged (1536×1024 RGB PNG, white
paint on black). They live under `spec/` so they are excluded from exports.

| Source | SHA-256 |
| --- | --- |
| `brush_a.png` | `21fdf489c9fd216c6e217154abd2eeab380f185da56bdc31615326eb60c09591` |
| `brush_b.png` | `ddf2c79bd87523725eb822f39591757e742ae59cf14138490a35b82337359209` |
| `brush_c.png` | `900e5cf58d1987bc4ea22e1ae572d553b9bcff39bcccdecf715316bb1a27c6f5` |
| `brush_d.png` | `8bcf0bf7811a5b8371b6215f1c5b16b52f84860e7810e81c335814ae35caab05` |
| `brush_hero.png` | `8f6ef610ebc1605a6454e9fb37bf713330b02bbc861e03c8bafcda592b3c7ac0` |

Shared prompt (followed by one line per stroke):

> A single bold, confident dry-brush paint stroke made with a wide flat brush,
> pure white paint on a pure solid black background, no other elements, no
> text, no shadows, no gradients in the background, high contrast. Visible
> bristle streaks and dry-brush breakup along the stroke, frayed ragged ends
> with a few small paint flecks, painterly like the hand-painted UI of the game
> Clair Obscur: Expedition 33. Landscape 3:2 composition with generous black
> margin on all sides so no paint touches the image edges.

1. `brush_a`: a wide horizontal stroke, slightly rising to the right, thick in
   the middle, tapering with a flicked end on the right.
2. `brush_b`: a horizontal stroke with a heavier loaded start on the left and a
   dry, streaky, broken tail on the right.
3. `brush_c`: two overlapping horizontal passes of the brush, one slightly above
   the other, slightly tilted downward to the right.
4. `brush_d`: a short, very thick horizontal stroke with a hooked flick at the
   right end and dry bristle gaps through the middle.
5. `brush_hero`: a dramatic sweeping diagonal-ish horizontal swash, very bold and
   energetic, with a thick loaded body, a sharp flick and a few splatter
   droplets off the tail — the most stylish of the set.

Production textures are derived with:

```bash
python3 tools/process_turn_order_brushes.py spec/assets/turn_order_ink
```

The tool maps luminance to alpha (black point 18, white point 225, gamma 0.9),
crops to the paint with 4% padding, fills RGB with pure white so in-engine
tinting has no fringes, and resizes to 512 px wide. The rail tints each stroke
gold (acting unit), teal (allies) or crimson (enemies).
