from __future__ import annotations

import hashlib
import json
import statistics
import unittest
from pathlib import Path

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[1]
EXPECTED_ITEM_CARD_IDS = {
    "bone_ward_charm",
    "crimson_draught",
    "frost_snare",
    "grave_dust_satchel",
    "jaw_trap",
    "mossglass_elixir",
    "nail_bomb",
    "pitch_firebomb",
    "smoke_bomb",
    "storm_jar",
}


def _visible_detail_metrics(image: Image.Image) -> tuple[float, int]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size

    def luma(x: int, y: int) -> int:
        red, green, blue, _alpha = pixels[x, y]
        return (54 * red + 183 * green + 19 * blue) // 256

    neighbor_contrast: list[int] = []
    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] <= 32:
                continue
            current = luma(x, y)
            if x + 1 < width and pixels[x + 1, y][3] > 32:
                neighbor_contrast.append(abs(luma(x + 1, y) - current))
            if y + 1 < height and pixels[x, y + 1][3] > 32:
                neighbor_contrast.append(abs(luma(x, y + 1) - current))

    if not neighbor_contrast:
        return 0.0, 0
    neighbor_contrast.sort()
    percentile_90 = neighbor_contrast[int(0.90 * (len(neighbor_contrast) - 1))]
    return statistics.fmean(neighbor_contrast), percentile_90


class ItemCardArtQualityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cards = json.loads((REPO_ROOT / "data/cards.json").read_text(encoding="utf-8"))
        cls.item_cards = {card_id: card for card_id, card in cards.items() if card.get("item")}

    def test_item_cards_keep_the_reviewed_art_inventory(self) -> None:
        self.assertEqual(set(self.item_cards), EXPECTED_ITEM_CARD_IDS)

    def test_item_card_art_has_canonical_size_mask_and_unique_content(self) -> None:
        content_hashes: dict[str, str] = {}
        for card_id, card in self.item_cards.items():
            art_path = str(card.get("art_path", ""))
            self.assertTrue(art_path.startswith("res://assets/art/cards/"), f"{card_id} needs card art")
            path = REPO_ROOT / art_path.removeprefix("res://")
            self.assertTrue(path.is_file(), f"{card_id} art is missing: {path}")
            with Image.open(path) as image:
                self.assertEqual(image.size, (256, 144), f"{card_id} art must remain at the native card-art size")
                self.assertEqual(image.mode, "RGBA", f"{card_id} art must preserve the ragged alpha window")
                alpha = image.getchannel("A")
                self.assertEqual(alpha.getpixel((0, 0)), 0, f"{card_id} top-left corner must be transparent")
                self.assertEqual(alpha.getpixel((255, 0)), 0, f"{card_id} top-right corner must be transparent")
                self.assertEqual(alpha.getpixel((0, 143)), 0, f"{card_id} bottom-left corner must be transparent")
                self.assertEqual(alpha.getpixel((255, 143)), 0, f"{card_id} bottom-right corner must be transparent")
                transparent_fraction = alpha.histogram()[0] / float(256 * 144)
                self.assertGreater(transparent_fraction, 0.34, f"{card_id} must retain the ragged transparent border")
                self.assertLess(transparent_fraction, 0.44, f"{card_id} art window must not collapse into a tiny cutout")
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertNotIn(digest, content_hashes, f"{card_id} duplicates {content_hashes.get(digest, 'another item')}")
            content_hashes[digest] = card_id

    def test_item_card_art_retains_crisp_local_contrast(self) -> None:
        mean_contrasts: list[float] = []
        for card_id, card in self.item_cards.items():
            path = REPO_ROOT / str(card["art_path"]).removeprefix("res://")
            with Image.open(path) as image:
                mean_contrast, percentile_90 = _visible_detail_metrics(image)
            mean_contrasts.append(mean_contrast)
            self.assertGreaterEqual(
                mean_contrast,
                4.0,
                f"{card_id} has lost too much local contrast and will read as blurred at card scale",
            )
            self.assertGreaterEqual(
                percentile_90,
                12,
                f"{card_id} lacks deliberate crisp edges in its visible art window",
            )
        self.assertGreaterEqual(
            statistics.median(mean_contrasts),
            7.0,
            "The item-art set has regressed toward uniformly low-frequency, blurry rendering",
        )


if __name__ == "__main__":
    unittest.main()
