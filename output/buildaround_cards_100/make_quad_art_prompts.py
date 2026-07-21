from __future__ import annotations

from pathlib import Path

from render_buildaround_gallery import CARDS, ELEMENTS


ROOT = Path(__file__).resolve().parent


def prompt_for_group(group: list[dict], group_index: int) -> str:
    lines = [
        "Use case: stylized-concept",
        "Asset type: Escape the Umbra card art production sheet",
        "Primary request: Create one clean 2x2 contact sheet containing four separate Escape the Umbra card-art illustrations.",
        "Style/medium: match the current Labyrinth card art references: dark fantasy dungeon-card illustration, compact 16-bit pixel-art-inspired painted style, painterly pixel texture, high contrast, readable at tiny card size.",
        "Composition/framing: each quadrant is one independent wide 16:9 illustration with a strong central silhouette and generous safe padding; no labels, no panel titles, no numbers, no card frame, no UI, no watermark.",
        "Output layout: exact 2x2 grid. Top-left is card A, top-right is card B, bottom-left is card C, bottom-right is card D. Keep each quadrant visually self-contained.",
        "Constraints: no text anywhere in the image; no playing-card UI frame; do not crop important subjects at quadrant edges.",
        "",
        "Cards:",
    ]
    labels = ["A top-left", "B top-right", "C bottom-left", "D bottom-right"]
    for label, card in zip(labels, group):
        element = ELEMENTS[card["element"]]
        palette = f"{element['label']} palette, accent {element['accent']}"
        lines.append(f"- {label}: {card['name']} ({card['id']}), {palette}. Scene: {card['art_direction']}.")
    return "\n".join(lines)


def main() -> None:
    out_dir = ROOT / "art_prompts" / "quad_batches"
    out_dir.mkdir(parents=True, exist_ok=True)
    for index in range(0, len(CARDS), 4):
        group = CARDS[index:index + 4]
        prompt = prompt_for_group(group, index // 4 + 1)
        ids = "_".join(card["id"] for card in group)
        (out_dir / f"quad_{index // 4 + 1:02d}_{ids}.txt").write_text(prompt + "\n", encoding="utf-8")
    print(f"wrote {len(list(out_dir.glob('quad_*.txt')))} quad prompts")


if __name__ == "__main__":
    main()
