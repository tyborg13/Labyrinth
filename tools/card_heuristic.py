#!/usr/bin/env python3
"""Developer-facing card scoring heuristic for balance exploration.

This tool intentionally lives outside the gameplay runtime. It gives the team a
stable, reviewable baseline for valuing cards in "health saved equivalent"
terms without coupling the live game to the balance model.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CARDS_PATH = REPO_ROOT / "data" / "cards.json"


@dataclass(frozen=True)
class HeuristicWeights:
    damage_per_point: float = 0.45
    execute_per_point_sq: float = 0.012
    block_per_point: float = 0.25
    stoneskin_per_point: float = 0.40
    heal_per_point: float = 0.90
    draw_per_point: float = 0.85
    pure_move_per_tile: float = 0.25
    pure_blink_per_tile: float = 0.33
    attack_move_followthrough_per_tile: float = 0.08
    attack_blink_followthrough_per_tile: float = 0.12
    health_cost_per_point: float = 1.00
    burn_card_penalty: float = 0.55
    burn_card_draw_offset_per_card: float = 0.18
    aoe_base_target_multiplier: float = 1.20
    aoe_extra_tile_multiplier: float = 0.10
    chain_extra_targets: float = 0.45
    freeze_value: float = 3.8
    shock_value: float = 2.5
    push_value_per_tile: float = 0.28
    pull_value_per_tile: float = 0.14
    move_pull_bonus_per_tile: float = 0.08
    attack_move_synergy: float = 0.40
    attack_defense_synergy: float = 0.25
    attack_status_synergy: float = 0.25
    draw_synergy: float = 0.25
    move_push_pull_synergy: float = 0.20
    move_defense_synergy: float = 0.40


@dataclass
class ScoreBreakdown:
    offense: float = 0.0
    control: float = 0.0
    defense: float = 0.0
    flow: float = 0.0
    mobility: float = 0.0
    synergy: float = 0.0
    health_cost: float = 0.0
    burn_card_penalty: float = 0.0
    total: float = 0.0


def burn_effective_damage(stacks: int) -> float:
    return 0.75 * stacks + 0.12 * stacks * stacks


def poison_effective_damage(stacks: int) -> float:
    return 0.70 * stacks


def melee_playability(total_reach: int) -> float:
    if total_reach <= 1:
        return 0.35
    if total_reach == 2:
        return 0.55
    if total_reach == 3:
        return 0.72
    if total_reach == 4:
        return 0.86
    return 0.95


def ranged_playability(base_range: int) -> float:
    if base_range <= 4:
        return 0.80
    if base_range == 5:
        return 0.88
    if base_range == 6:
        return 0.95
    return 0.98


def playability_for_attack(action_type: str, total_reach: int, base_range: int) -> float:
    if action_type == "melee" or (action_type == "aoe" and base_range <= 0):
        return melee_playability(total_reach)
    if action_type in {"ranged", "aoe", "push", "pull"}:
        return ranged_playability(base_range)
    return 1.0


def aoe_pattern_tile_count(action: dict[str, Any]) -> int:
    pattern = action.get("pattern", [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]])
    if not isinstance(pattern, list):
        return 1
    unique_offsets: set[tuple[int, int]] = set()
    for offset in pattern:
        if isinstance(offset, (list, tuple)) and len(offset) >= 2:
            unique_offsets.add((int(offset[0]), int(offset[1])))
        elif isinstance(offset, dict):
            unique_offsets.add((int(offset.get("x", 0)), int(offset.get("y", 0))))
    return max(1, len(unique_offsets))


def target_multiplier(action: dict[str, Any], weights: HeuristicWeights) -> float:
    multiplier = 1.0
    if int(action.get("chain", 0)) > 0:
        multiplier += weights.chain_extra_targets
    if str(action.get("type", "")) == "aoe":
        tile_count = aoe_pattern_tile_count(action)
        multiplier *= weights.aoe_base_target_multiplier + max(0, tile_count - 1) * weights.aoe_extra_tile_multiplier
    return multiplier


def immediate_damage_value(damage: int, playability: float, targets: float, weights: HeuristicWeights) -> float:
    return (damage * weights.damage_per_point + damage * damage * weights.execute_per_point_sq) * playability * targets


def score_card(card_id: str, card: dict[str, Any], weights: HeuristicWeights) -> ScoreBreakdown:
    breakdown = ScoreBreakdown()
    actions = card.get("actions", [])

    pre_attack_reach = 0
    move_tiles = 0
    blink_tiles = 0
    draw_amount = 0
    has_attack = False
    has_move = False
    has_defense = False
    has_draw = False
    has_status = False
    has_push_pull = False

    for action in actions:
        action_type = str(action.get("type", ""))

        if action_type == "move":
            move_tiles += int(action.get("range", 0))
            pre_attack_reach += int(action.get("range", 0))
            has_move = True
            continue

        if action_type == "blink":
            blink_tiles += int(action.get("range", 0))
            pre_attack_reach += int(action.get("range", 0)) + 1
            has_move = True
            continue

        if action_type in {"melee", "ranged", "aoe", "push", "pull"}:
            has_attack = True
            base_range = int(action.get("range", 1))
            effective_reach = pre_attack_reach + (1 if action_type == "aoe" and base_range <= 0 else base_range)
            playability = playability_for_attack(action_type, effective_reach, base_range)
            targets = target_multiplier(action, weights)
            damage = int(action.get("damage", 0))

            breakdown.offense += immediate_damage_value(damage, playability, targets, weights)

            burn = int(action.get("burn", 0))
            if burn > 0:
                breakdown.control += burn_effective_damage(burn) * weights.damage_per_point * playability * targets
                has_status = True

            poison = int(action.get("poison", 0))
            if poison > 0:
                breakdown.control += poison_effective_damage(poison) * weights.damage_per_point * playability * targets
                has_status = True

            freeze = int(action.get("freeze", 0))
            if freeze > 0:
                breakdown.control += weights.freeze_value * freeze * playability * targets
                has_status = True

            shock = int(action.get("shock", 0))
            if shock > 0:
                breakdown.control += weights.shock_value * shock * playability * targets
                has_status = True

            push = int(action.get("push", 0))
            if push > 0:
                breakdown.control += push * weights.push_value_per_tile * playability * targets
                has_push_pull = True

            pull = int(action.get("pull", 0))
            if pull > 0:
                pull_value = weights.pull_value_per_tile
                if has_move:
                    pull_value += weights.move_pull_bonus_per_tile
                breakdown.control += pull * pull_value * playability * targets
                has_push_pull = True

            continue

        if action_type == "block":
            breakdown.defense += int(action.get("amount", 0)) * weights.block_per_point
            has_defense = True
            continue

        if action_type == "stoneskin":
            breakdown.defense += int(action.get("amount", 0)) * weights.stoneskin_per_point
            has_defense = True
            continue

        if action_type == "heal":
            breakdown.defense += int(action.get("amount", 0)) * weights.heal_per_point
            has_defense = True
            continue

        if action_type == "draw":
            draw = int(action.get("amount", 0))
            draw_amount += draw
            breakdown.flow += draw * weights.draw_per_point
            has_draw = True
            continue

    if has_attack:
        breakdown.mobility += move_tiles * weights.attack_move_followthrough_per_tile
        breakdown.mobility += blink_tiles * weights.attack_blink_followthrough_per_tile
    else:
        breakdown.mobility += move_tiles * weights.pure_move_per_tile
        breakdown.mobility += blink_tiles * weights.pure_blink_per_tile

    if has_move and has_attack:
        breakdown.synergy += weights.attack_move_synergy
    if has_attack and has_defense:
        breakdown.synergy += weights.attack_defense_synergy
    if has_attack and has_status:
        breakdown.synergy += weights.attack_status_synergy
    if has_draw and (has_attack or has_move):
        breakdown.synergy += weights.draw_synergy
    if has_move and has_push_pull:
        breakdown.synergy += weights.move_push_pull_synergy
    if has_move and has_defense and not has_attack:
        breakdown.synergy += weights.move_defense_synergy

    breakdown.health_cost = int(card.get("health_cost", 0)) * weights.health_cost_per_point
    if bool(card.get("burn", False)):
        breakdown.burn_card_penalty = max(
            0.0,
            weights.burn_card_penalty - draw_amount * weights.burn_card_draw_offset_per_card,
        )

    breakdown.total = round(
        breakdown.offense
        + breakdown.control
        + breakdown.defense
        + breakdown.flow
        + breakdown.mobility
        + breakdown.synergy
        - breakdown.health_cost
        - breakdown.burn_card_penalty,
        4,
    )
    return breakdown


def load_cards(cards_path: Path) -> dict[str, Any]:
    with cards_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"Expected dictionary JSON in {cards_path}")
    return data


def scored_rows(cards: dict[str, Any], weights: HeuristicWeights) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for card_id, card in cards.items():
        breakdown = score_card(card_id, card, weights)
        rows.append(
            {
                "card_id": card_id,
                "name": card.get("name", card_id),
                "rarity": card.get("rarity", "common"),
                "element": card.get("element", "none"),
                "burn": bool(card.get("burn", False)),
                "health_cost": int(card.get("health_cost", 0)),
                "description": card.get("description", ""),
                "score": breakdown.total,
                "breakdown": asdict(breakdown),
            }
        )
    rows.sort(key=lambda row: (-row["score"], row["name"], row["card_id"]))
    return rows


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cards-path",
        type=Path,
        default=DEFAULT_CARDS_PATH,
        help="Path to a cards JSON file. Defaults to data/cards.json.",
    )
    parser.add_argument(
        "--card-id",
        help="Show only one card by id.",
    )
    parser.add_argument(
        "--show-breakdown",
        action="store_true",
        help="Include heuristic component breakdowns in text output.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit JSON instead of a text table.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit the number of returned cards after sorting. 0 means all cards.",
    )
    return parser


def select_rows(rows: list[dict[str, Any]], args: argparse.Namespace) -> list[dict[str, Any]]:
    selected = rows
    if args.card_id:
        selected = [row for row in rows if row["card_id"] == args.card_id]
    if args.limit > 0:
        selected = selected[: args.limit]
    return selected


def print_text(rows: list[dict[str, Any]], show_breakdown: bool) -> None:
    for index, row in enumerate(rows, start=1):
        tag_bits = []
        if row["element"] != "none":
            tag_bits.append(str(row["element"]))
        tag_bits.append(str(row["rarity"]))
        if row["burn"]:
            tag_bits.append("burn-card")
        if row["health_cost"] > 0:
            tag_bits.append(f"hp-cost={row['health_cost']}")
        tags = ", ".join(tag_bits)
        print(f"{index:>2}. {row['score']:>5.2f}  {row['card_id']}  {row['name']}  [{tags}]")
        print(f"    {row['description']}")
        if show_breakdown:
            breakdown = row["breakdown"]
            print(
                "    "
                + ", ".join(
                    [
                        f"offense={breakdown['offense']:.2f}",
                        f"control={breakdown['control']:.2f}",
                        f"defense={breakdown['defense']:.2f}",
                        f"flow={breakdown['flow']:.2f}",
                        f"mobility={breakdown['mobility']:.2f}",
                        f"synergy={breakdown['synergy']:.2f}",
                        f"health_cost={breakdown['health_cost']:.2f}",
                        f"burn_penalty={breakdown['burn_card_penalty']:.2f}",
                    ]
                )
            )


def main() -> int:
    args = build_parser().parse_args()
    cards = load_cards(args.cards_path)
    weights = HeuristicWeights()
    rows = select_rows(scored_rows(cards, weights), args)

    if args.card_id and not rows:
        raise SystemExit(f"Unknown card id: {args.card_id}")

    if args.json:
        print(json.dumps(rows, indent=2))
    else:
        print_text(rows, args.show_breakdown)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
