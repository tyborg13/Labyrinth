#!/usr/bin/env python3
"""Developer-facing card scoring heuristic for balance exploration.

This tool intentionally lives outside the gameplay runtime. It gives the team a
stable, reviewable baseline for valuing cards in "health saved equivalent"
terms without coupling the live game to the balance model.

Current encounter assumptions that shape the coefficients but are not directly
scored here: a complete run contains six four-depth sequences with 3/4/5
standard-enemy density before each boss gate. The first five gates use the five
non-shadow elemental dragons in seeded random order, including Zekarion, while
Noctyrax is fixed at depth 24. Boss health, attacks, support, and authored arena
mechanics use the same completed-sequence scaling as normal rooms. Lateral rooms
remain deck-building route choices, but a guaranteed outward route appears after
three visited rooms at the current depth when no outward route is otherwise
available. The local combat band is wider: depth 1 enemies have 85% HP, depth 2
uses base stats, and depth 3 enemies have 112% HP. Standard depths share the same normal-room roster
eligibility; depth controls density and scaling instead of gating enemy types.
The first combat remains a kill-all tutorial. Later standard rooms use a seeded
25/25/25/25 mix of kill-all, kill-leader, survive, and reach-exit objectives;
boss rooms always use kill-leader without generic leader stat scaling.
Survival targets initiative 42/46/50 by local depth with one reinforcement every
16 time; reach-exit rooms add 1/2/2 enemies and three crates while favoring
control intents and blocking routes. These objective-dependent pressures are
reported as analytics cohorts rather than baked into every card's intrinsic
coefficient: movement and control matter more for exits, AOE matters more for
reinforcement density, and execute damage matters most against leaders.
Each player activation also grants a shared two-tile movement pool that can be
split before, between, or after printed card plays without spending a play or
initiative Time. Because it is turn-shared rather than card-owned, this tool
reports that positioning resource but does not add it to every card's intrinsic
reach or movement value.
Cinder Oozes join fire rooms and split into summoned, rewardless Cinder
Droplets rather than extra ember or death-card-play payouts. Frostglass Lancers
join ice rooms as precision four-tile line-thrust enemies that can move sideways
to set up a lane. Chainbound Gaolers join air rooms as mid-slow
pull/immobilize control anchors without stacking with wardens in their seeded
compositions. Grave surgeons join frontline pools as low-damage support enemies
that heal or guard the most injured/threatened nearby enemy on the same support
scaling curve as enemy block/healing. Warden Bulwark grants its scaled Block to
every other living enemy but not the Warden, making focus fire, Pierce, Sunder,
and broad damage especially valuable in Warden compositions without changing
their intrinsic coefficients. Bile bloomers join earth rooms near the
slow attrition end at about 19 initiative and use a radius-2 poison diamond for
their main area-denial intent. Generic enemies keep their printed intent actions
instead of being rewritten to match the room element. Tunnel Crawler claw
attacks and the Bone Harrier's spear shot now add light one-turn bleed pressure.
Normal enemies refresh intents through explicit frontliner, artillery,
skirmisher, protector, controller, or support profiles. Tactically dead options
such as stationary out-of-range shots, irrelevant retreats, unavailable heals,
and distant defensive turns are rejected; seeded weighted variation remains
only among near-best legal choices. Supports prioritize injured or threatened
allies and hold a legal back-line support position, while protectors guard an
exposed squad and otherwise advance to screen it. This increases realized enemy
pressure and support reliability relative to full-list weighted roulette but
does not change any printed card coefficient.
Revealed enemy execution is deterministic: advancing attack intents stop at the
first reachable attack-enabling tile with safe paths breaking equal-length
ties; retreat attacks preserve their follow-up, attackless retreats maximize
safe separation, and equal-distance player-side target ties prefer illusions.
Future-turn route scoring treats destructible terrain as finite clearing time,
allied congestion as a current hard blocker while crediting open current-turn
detours, and traps as high-cost but traversable when no safe route exists. It
compares true total cost before open-prefix length and uses strongest immediate
progress to break equal-cost route ties, delaying detours until a blocker is
actually near instead of producing an early U-shaped movement.
Conservative threat unions are supplemented by the exact current route,
destination, and projected attack, including action-denying statuses and
deterministic lightning-strike tiles.
Bleed pressure only opens on resolved move or attack actions, not skipped or
blocked no-op action entries. Later sequences keep the local curve while raising
enemy HP by 8% per completed sequence. Damaging intents add
0/1/1/2/2/3 points and support intents add 0/0/1/1/2/2 points across the six
sequences. Zekarion's 2x2
footprint makes printed reach feel larger, so Tempest Breath is capped at range
3 after its one-tile advance to preserve safe boss-room repositioning. Large
enemies use actor-level targeting: one legal visible footprint tile makes the
whole footprint clickable, but the action still counts as one target and one
hit for scoring.
Elemental combat rooms seed 2-3 traps across eligible passable floor tiles,
including the playable edge band, and those traps blast adjacent tiles when
stepped on or attacked. Their authored damage is multiplied by the live matching
element's intensity curve (72/94/124/162/208/262/324 percent at intensity
0-6), so spending intensity can also calm the battlefield. Elemental specialist
enemies build the same shared resource, gate extra effects on it, or consume it
for stronger intents.
First-sequence standard trap damage is 6/7/8 natural damage at depths
1/2/3, first-boss traps hit for 5 to avoid one-shotting full-health lightning
wisps, and later sequences add 0/1/1/2/2/3 damage.
Depth 1-2 fire traps use shallow burn before depth-3 fire/earth trap statuses
cap at 2. Combat and boss rooms scatter 0/1/2 consumable item cards at
15/65/20 percent, spacing them away from equipment and each other. A free item
slot grants the pickup to hand (or the top of draw at the seven-card hand cap);
full item slots store it only in reserve. Pickup access is encounter context,
not an intrinsic draw or tempo bonus. Equipment drop eligibility/rates are
unchanged. Combat rooms scatter 5-7 low-HP boxes/crates across eligible
passable floor tiles, including edge-band tiles when connectivity stays intact.
Those crates block movement without blocking line of sight and take damage from
area effects, deterministic lightning strikes, and adjacent trap blasts. The
existing AOE tile multiplier represents that conditional clearing upside rather
than adding a layout-independent terrain coefficient.
Enemies killed by a card add a bonus card play for the turn, so large damage and
broad damage get a small execute-tempo premium.
Player flow assumes 2 cards per turn, 2 draw per turn, and a 7-card max hand;
the scorer values printed draw without simulating current hand occupancy.
Permanent progression uses qualitative skills and leaves player base initiative
fixed at 9. Every fourth character level grants one bounded Defiance charge,
through five charges at level 20; each charge restores 25% maximum health after
otherwise-lethal damage and does not refill within a run. The scorer uses a
no-skill, no-Defiance reference profile; skill and Defiance effects remain
separate cohort dimensions in local analytics instead of changing intrinsic
printed-card coefficients.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CARDS_PATH = REPO_ROOT / "data" / "cards.json"
DEFAULT_EQUIPMENT_PATH = REPO_ROOT / "data" / "equipment.json"

DEPTHS_PER_SEQUENCE = 4
SEQUENCES_PER_RUN = 6
RANDOMIZED_ELEMENTAL_BOSSES = 5
FINAL_BOSS_DEPTH = DEPTHS_PER_SEQUENCE * SEQUENCES_PER_RUN
PLAYER_BASE_INITIATIVE = 9
BASE_CARDS_PER_TURN = 2
BASE_DRAW_PER_TURN = 2
BASE_PLAYER_MOVEMENT = 2
MAX_HAND_SIZE = 7
COMBAT_OBJECTIVE_WEIGHTS_PERCENT = {
    "kill_all": 25,
    "kill_leader": 25,
    "survive": 25,
    "reach_exit": 25,
}
SURVIVAL_TARGET_CLOCK_BY_LOCAL_DEPTH = [42, 46, 50]
SURVIVAL_REINFORCEMENT_INTERVAL = 16
REACH_EXIT_EXTRA_ENEMIES_BY_LOCAL_DEPTH = [1, 2, 2]
REACH_EXIT_TERRAIN_BONUS = 3
SKILL_SCORE_PROFILE = "no_skills"
ENEMY_HP_SCALE_PER_SEQUENCE = 0.08
ENEMY_HP_FLAT_BONUS_PER_SEQUENCE = 0
ENEMY_DAMAGE_BONUS_BY_SEQUENCE = [0, 1, 1, 2, 2, 3]
ENEMY_SUPPORT_BONUS_BY_SEQUENCE = [0, 0, 1, 1, 2, 2]
DEFIANCE_LEVEL_INTERVAL = 4
DEFIANCE_MAX_CHARGES = 5
DEFIANCE_RESTORE_FRACTION = 0.25
ELEMENTS = {"fire", "ice", "lightning", "air", "earth"}
SOURCE_FILTERS = (
    "all",
    "reward-pool",
    "elemental-reward",
    "neutral-reward",
    "equipment",
    "item",
    "starter",
)

BOSS_ENCOUNTER_ROLES = {
    "zekarion": "summoned lightning wisps",
    "tharokh": "attackable Worldspines and delayed rupture",
    "vyraketh": "attackable cinder marks and forced detonation",
    "vaeloryx": "arena-wide damage and forced movement",
    "iskaldra": "hit-count frost crystal armor",
    "noctyrax": "Eclipse damage against actors outside Radiance",
}

ENEMY_TACTICAL_ROLES = {
    "frontliner": "close distance and convert reachable attacks",
    "artillery": "hold useful range and establish legal shots",
    "skirmisher": "kite at close range and advance only to establish pressure",
    "protector": "guard exposed allies or advance to screen the back line",
    "controller": "establish range for control and pressure actions",
    "support": "heal or guard relevant allies and avoid unnecessary melee pursuit",
}


def encounter_assumptions() -> dict[str, Any]:
    """Return the run structure that contextualizes card-score coefficients."""
    return {
        "depths_per_sequence": DEPTHS_PER_SEQUENCE,
        "sequences_per_run": SEQUENCES_PER_RUN,
        "randomized_elemental_bosses": RANDOMIZED_ELEMENTAL_BOSSES,
        "final_boss_depth": FINAL_BOSS_DEPTH,
        "boss_encounter_roles": BOSS_ENCOUNTER_ROLES,
        "large_enemy_targeting": "one legal visible footprint tile makes the actor's full footprint clickable; still one target and one hit",
        "enemy_tactical_ai": {
            "roles": ENEMY_TACTICAL_ROLES,
            "selection": "reject tactically dead intents, then retain seeded weighted variation among near-best legal choices",
            "path_tie_break": "true total cost first; equal routes prefer strongest immediate current-activation progress",
            "score_policy": "raises realized encounter pressure without changing intrinsic printed-card coefficients",
        },
        "warden_bulwark": "grants scaled Block to every other living enemy and never to the acting Warden",
        "player_flow": {
            "base_initiative": PLAYER_BASE_INITIATIVE,
            "cards_per_turn": BASE_CARDS_PER_TURN,
            "draw_per_turn": BASE_DRAW_PER_TURN,
            "independent_movement_per_turn": BASE_PLAYER_MOVEMENT,
            "movement_timing": "may be split before, between, or after printed card plays without spending a play or initiative Time",
            "movement_score_policy": "turn-shared positioning context; do not add it to every card's intrinsic reach or movement value",
            "max_hand_size": MAX_HAND_SIZE,
        },
        "combat_objectives": {
            "first_combat": "kill_all",
            "later_combat_weights_percent": COMBAT_OBJECTIVE_WEIGHTS_PERCENT,
            "boss_objective": "kill_leader_with_authored_boss_stats",
            "survival_target_clock_by_local_depth": SURVIVAL_TARGET_CLOCK_BY_LOCAL_DEPTH,
            "survival_reinforcement_interval": SURVIVAL_REINFORCEMENT_INTERVAL,
            "reach_exit_extra_enemies_by_local_depth": REACH_EXIT_EXTRA_ENEMIES_BY_LOCAL_DEPTH,
            "reach_exit_terrain_bonus": REACH_EXIT_TERRAIN_BONUS,
            "score_policy": "keep intrinsic coefficients neutral; compare movement, control, AOE, and execute results by objective_type analytics cohort",
        },
        "qualitative_progression": {
            "score_profile": SKILL_SCORE_PROFILE,
            "cohort_field": "progression_skills",
            "coefficient_policy": "exclude skill effects from intrinsic printed-card scores",
            "defiance": {
                "level_interval": DEFIANCE_LEVEL_INTERVAL,
                "max_charges": DEFIANCE_MAX_CHARGES,
                "restore_fraction": DEFIANCE_RESTORE_FRACTION,
                "score_policy": "exclude Defiance from intrinsic printed-card scores",
            },
        },
        "elemental_intensity": {
            "matching_room_start": 1,
            "trap_scale_percent_at_intensity_0_to_6": [72, 94, 124, 162, 208, 262, 324],
            "shared_with_elemental_enemies": True,
        },
        "sequence_scaling": {
            "enemy_hp_multiplier_per_completed_sequence": ENEMY_HP_SCALE_PER_SEQUENCE,
            "enemy_hp_flat_per_completed_sequence": ENEMY_HP_FLAT_BONUS_PER_SEQUENCE,
            "enemy_damage_bonus_by_sequence": ENEMY_DAMAGE_BONUS_BY_SEQUENCE,
            "enemy_support_bonus_by_sequence": ENEMY_SUPPORT_BONUS_BY_SEQUENCE,
        },
    }


@dataclass(frozen=True)
class HeuristicWeights:
    damage_per_point: float = 0.45
    execute_per_point_sq: float = 0.012
    block_per_point: float = 0.25
    stoneskin_per_point: float = 0.40
    heal_per_point: float = 0.90
    draw_per_point: float = 0.85
    card_play_per_point: float = 0.75
    flurry_expected_plays: int = 2
    flurry_saved_card_value: float = 0.85
    flurry_saved_time_payment_value: float = 0.75
    flurry_retargeting_value: float = 0.25
    flurry_extra_play_penalty: float = 0.55
    intensity_gain_per_point: float = 0.70
    intensity_spend_per_point: float = 0.35
    intensity_spend_retention_floor: float = 0.68
    intensity_same_element_synergy: float = 0.18
    intensity_gate_synergy: float = 0.30
    kill_card_play_value: float = 0.45
    illusion_health_per_point: float = 0.48
    illusion_range_per_tile: float = 0.12
    illuminate_radius_per_tile: float = 0.55
    illuminate_duration_per_activation: float = 0.25
    illuminate_range_per_tile: float = 0.06
    vision_per_radius_activation: float = 0.50
    truesight_per_activation: float = 1.40
    dispel_umbra_per_stage: float = 2.20
    umbra_relevance: float = 0.75
    pure_move_per_tile: float = 0.25
    pure_blink_per_tile: float = 0.33
    attack_move_followthrough_per_tile: float = 0.08
    attack_blink_followthrough_per_tile: float = 0.12
    health_cost_per_point: float = 1.00
    burn_card_penalty: float = 0.55
    burn_card_draw_offset_per_card: float = 0.18
    aoe_base_target_multiplier: float = 1.20
    aoe_extra_tile_multiplier: float = 0.10
    aoe_rotatable_orientation_bonus: float = 0.05
    chain_extra_targets: float = 0.45
    pierce_value: float = 0.75
    bleed_damage_value: float = 0.65
    expose_value_per_point: float = 0.32
    sunder_value_per_point: float = 0.20
    freeze_value: float = 3.8
    shock_value: float = 2.5
    immobilize_value: float = 1.7
    push_value_per_tile: float = 0.28
    pull_value_per_tile: float = 0.14
    directed_force_bonus_per_tile: float = 0.03
    move_pull_bonus_per_tile: float = 0.08
    attack_move_synergy: float = 0.40
    attack_defense_synergy: float = 0.25
    attack_status_synergy: float = 0.25
    draw_synergy: float = 0.25
    card_play_synergy: float = 0.20
    draw_card_play_synergy: float = 0.40
    move_push_pull_synergy: float = 0.20
    move_defense_synergy: float = 0.40
    illusion_move_synergy: float = 0.30
    illusion_before_move_synergy: float = 0.25
    baseline_card_time: float = 5.0
    # Calibrated against early enemy first/repeat cycles of roughly 11-20 initiative.
    time_delta_value: float = 0.45


@dataclass
class ScoreBreakdown:
    offense: float = 0.0
    control: float = 0.0
    defense: float = 0.0
    flow: float = 0.0
    elemental_intensity: float = 0.0
    intensity_spend_cost: float = 0.0
    mobility: float = 0.0
    radiance: float = 0.0
    synergy: float = 0.0
    health_cost: float = 0.0
    burn_card_penalty: float = 0.0
    flurry_compression_bonus: float = 0.0
    flurry_commitment_penalty: float = 0.0
    tempo: float = 0.0
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
        if bool(action.get("rotate", True)) and tile_count > 1:
            multiplier += weights.aoe_rotatable_orientation_bonus
    return multiplier


def immediate_damage_value(damage: int, playability: float, targets: float, weights: HeuristicWeights) -> float:
    base_value = (damage * weights.damage_per_point + damage * damage * weights.execute_per_point_sq) * playability * targets
    kill_proxy = max(0.0, min(0.85, (damage - 5) / 14.0)) * playability * min(1.45, targets)
    return base_value + kill_proxy * weights.kill_card_play_value


def action_intensity_requirement(action: dict[str, Any], card_element: str) -> dict[str, Any]:
    raw = action.get("requires_intensity", {})
    if not isinstance(raw, dict):
        return {}
    element = str(raw.get("element", action.get("element", card_element)))
    threshold = int(raw.get("amount", raw.get("threshold", 0)))
    if element not in ELEMENTS or threshold <= 0:
        return {}
    return {"element": element, "amount": threshold}


def _intensity_requirement_availability(requirement: dict[str, Any], intensity_context: dict[str, int]) -> float:
    if not requirement:
        return 1.0
    current = int(intensity_context.get(str(requirement["element"]), 0))
    gap = int(requirement["amount"]) - current
    if gap <= 0:
        return 1.0
    if gap == 1:
        return 0.62
    if gap == 2:
        return 0.44
    if gap == 3:
        return 0.28
    return 0.18


def intensity_availability(action: dict[str, Any], intensity_context: dict[str, int], card_element: str) -> float:
    return _intensity_requirement_availability(action_intensity_requirement(action, card_element), intensity_context)


def action_intensity_bonus(action: dict[str, Any], card_element: str) -> dict[str, Any]:
    raw = action.get("intensity_bonus", {})
    if not isinstance(raw, dict):
        return {}
    element = str(raw.get("element", action.get("element", card_element)))
    threshold = int(raw.get("threshold", raw.get("amount", raw.get("requires", 0))))
    if element not in ELEMENTS or threshold <= 0:
        return {}
    bonus = dict(raw)
    bonus["element"] = element
    bonus["threshold"] = threshold
    return bonus


def intensity_bonus_availability(bonus: dict[str, Any], intensity_context: dict[str, int]) -> float:
    if not bonus:
        return 0.0
    return _intensity_requirement_availability(
        {"element": str(bonus.get("element", "")), "amount": int(bonus.get("threshold", 0))},
        intensity_context,
    )


def card_intensity_cost(card: dict[str, Any], card_element: str) -> dict[str, Any]:
    raw = card.get("intensity_cost", {})
    if not isinstance(raw, dict):
        return {}
    element = str(raw.get("element", card_element))
    amount = int(raw.get("amount", raw.get("cost", 0)))
    if element not in ELEMENTS or amount <= 0:
        return {}
    return {"element": element, "amount": amount}


def score_card(card_id: str, card: dict[str, Any], weights: HeuristicWeights) -> ScoreBreakdown:
    breakdown = ScoreBreakdown()
    actions = card.get("actions", [])
    card_element = str(card.get("element", "none"))
    intensity_context = {element: 0 for element in ELEMENTS}
    if card_element in ELEMENTS:
        intensity_context[card_element] = 1
    intensity_cost = card_intensity_cost(card, card_element)

    pre_attack_reach = 0
    move_tiles = 0.0
    blink_tiles = 0.0
    draw_amount = 0
    has_attack = False
    has_move = False
    has_defense = False
    has_draw = False
    has_card_play = False
    has_illusion = False
    illusion_before_move = False
    has_status = False
    has_push_pull = False
    has_intensity_gain = False
    has_intensity_gate = False

    for action in actions:
        action_type = str(action.get("type", ""))
        action_scale = intensity_availability(action, intensity_context, card_element)
        if action_scale < 1.0:
            has_intensity_gate = True

        illuminate_radius = max(0, int(action.get("illuminate_radius", 0)))
        if illuminate_radius > 0:
            illuminate_duration = int(action.get("illuminate_duration", 1))
            illuminate_duration_value = 3 if illuminate_duration < 0 else max(1, illuminate_duration)
            breakdown.radiance += (
                illuminate_radius * weights.illuminate_radius_per_tile
                + illuminate_duration_value * weights.illuminate_duration_per_activation
            ) * weights.umbra_relevance * action_scale

        if action_type == "move":
            if has_illusion:
                illusion_before_move = True
            move_tiles += int(action.get("range", 0)) * action_scale
            pre_attack_reach += int(round(int(action.get("range", 0)) * action_scale))
            has_move = True
            continue

        if action_type == "blink":
            if has_illusion:
                illusion_before_move = True
            blink_tiles += int(action.get("range", 0)) * action_scale
            pre_attack_reach += int(round((int(action.get("range", 0)) + 1) * action_scale))
            has_move = True
            continue

        if action_type in {"melee", "ranged", "aoe", "push", "pull"}:
            has_attack = True
            base_range = int(action.get("range", 1))
            effective_reach = pre_attack_reach + (1 if action_type == "aoe" and base_range <= 0 else base_range)
            playability = playability_for_attack(action_type, effective_reach, base_range)
            targets = target_multiplier(action, weights)
            damage = int(action.get("damage", 0))

            base_damage_value = immediate_damage_value(damage, playability, targets, weights)
            breakdown.offense += base_damage_value * action_scale

            if bool(action.get("pierce", False)) and damage > 0:
                breakdown.offense += weights.pierce_value * playability * targets * action_scale

            sunder = int(action.get("sunder", 0))
            if sunder > 0:
                breakdown.control += sunder * weights.sunder_value_per_point * playability * targets * action_scale

            burn = int(action.get("burn", 0))
            if burn > 0:
                breakdown.control += burn_effective_damage(burn) * weights.damage_per_point * playability * targets * action_scale
                has_status = True

            bleed = int(action.get("bleed", 0))
            if bleed > 0:
                breakdown.control += bleed * weights.bleed_damage_value * playability * targets * action_scale
                has_status = True

            expose = int(action.get("expose", 0))
            if expose > 0:
                breakdown.control += expose * weights.expose_value_per_point * playability * targets * action_scale
                has_status = True

            poison = int(action.get("poison", 0))
            if poison > 0:
                breakdown.control += poison_effective_damage(poison) * weights.damage_per_point * playability * targets * action_scale
                has_status = True

            freeze = int(action.get("freeze", 0))
            if freeze > 0:
                breakdown.control += weights.freeze_value * freeze * playability * targets * action_scale
                has_status = True

            shock = int(action.get("shock", 0))
            if shock > 0:
                breakdown.control += weights.shock_value * shock * playability * targets * action_scale
                has_status = True

            if bool(action.get("immobilize", False)):
                breakdown.control += weights.immobilize_value * playability * targets * action_scale
                has_status = True

            push = int(action.get("push", 0))
            if action_type == "push":
                push += int(action.get("amount", 0))
            if push > 0:
                breakdown.control += push * (weights.push_value_per_tile + weights.directed_force_bonus_per_tile) * playability * targets * action_scale
                has_push_pull = True

            pull = int(action.get("pull", 0))
            if action_type == "pull":
                pull += int(action.get("amount", 0))
            if pull > 0:
                pull_value = weights.pull_value_per_tile + weights.directed_force_bonus_per_tile
                if has_move:
                    pull_value += weights.move_pull_bonus_per_tile
                breakdown.control += pull * pull_value * playability * targets * action_scale
                has_push_pull = True

            intensity_bonus = action_intensity_bonus(action, card_element)
            if intensity_bonus:
                bonus_scale = intensity_bonus_availability(intensity_bonus, intensity_context) * action_scale
                if bonus_scale < action_scale:
                    has_intensity_gate = True
                bonus_damage = int(intensity_bonus.get("damage", 0))
                if bonus_damage > 0:
                    boosted_damage_value = immediate_damage_value(damage + bonus_damage, playability, targets, weights)
                    breakdown.offense += max(0.0, boosted_damage_value - base_damage_value) * bonus_scale

                if bool(intensity_bonus.get("pierce", False)) and damage + bonus_damage > 0:
                    breakdown.offense += weights.pierce_value * playability * targets * bonus_scale

                bonus_sunder = int(intensity_bonus.get("sunder", 0))
                if bonus_sunder > 0:
                    breakdown.control += bonus_sunder * weights.sunder_value_per_point * playability * targets * bonus_scale

                bonus_burn = int(intensity_bonus.get("burn", 0))
                if bonus_burn > 0:
                    breakdown.control += burn_effective_damage(bonus_burn) * weights.damage_per_point * playability * targets * bonus_scale
                    has_status = True

                bonus_bleed = int(intensity_bonus.get("bleed", 0))
                if bonus_bleed > 0:
                    breakdown.control += bonus_bleed * weights.bleed_damage_value * playability * targets * bonus_scale
                    has_status = True

                bonus_expose = int(intensity_bonus.get("expose", 0))
                if bonus_expose > 0:
                    breakdown.control += bonus_expose * weights.expose_value_per_point * playability * targets * bonus_scale
                    has_status = True

                bonus_poison = int(intensity_bonus.get("poison", 0))
                if bonus_poison > 0:
                    breakdown.control += poison_effective_damage(bonus_poison) * weights.damage_per_point * playability * targets * bonus_scale
                    has_status = True

                bonus_freeze = int(intensity_bonus.get("freeze", 0))
                if bonus_freeze > 0:
                    breakdown.control += weights.freeze_value * bonus_freeze * playability * targets * bonus_scale
                    has_status = True

                bonus_shock = int(intensity_bonus.get("shock", 0))
                if bonus_shock > 0:
                    breakdown.control += weights.shock_value * bonus_shock * playability * targets * bonus_scale
                    has_status = True

                if bool(intensity_bonus.get("immobilize", False)):
                    breakdown.control += weights.immobilize_value * playability * targets * bonus_scale
                    has_status = True

                bonus_push = int(intensity_bonus.get("push", 0))
                if action_type == "push":
                    bonus_push += int(intensity_bonus.get("amount", 0))
                if bonus_push > 0:
                    breakdown.control += bonus_push * (weights.push_value_per_tile + weights.directed_force_bonus_per_tile) * playability * targets * bonus_scale
                    has_push_pull = True

                bonus_pull = int(intensity_bonus.get("pull", 0))
                if action_type == "pull":
                    bonus_pull += int(intensity_bonus.get("amount", 0))
                if bonus_pull > 0:
                    pull_value = weights.pull_value_per_tile + weights.directed_force_bonus_per_tile
                    if has_move:
                        pull_value += weights.move_pull_bonus_per_tile
                    breakdown.control += bonus_pull * pull_value * playability * targets * bonus_scale
                    has_push_pull = True

                bonus_chain = int(intensity_bonus.get("chain", 0))
                if bonus_chain > 0:
                    breakdown.control += bonus_chain * weights.chain_extra_targets * weights.damage_per_point * max(1, damage + bonus_damage) * playability * bonus_scale

            continue

        if action_type == "block":
            breakdown.defense += int(action.get("amount", 0)) * weights.block_per_point * action_scale
            has_defense = True
            continue

        if action_type == "stoneskin":
            breakdown.defense += int(action.get("amount", 0)) * weights.stoneskin_per_point * action_scale
            has_defense = True
            continue

        if action_type == "heal":
            breakdown.defense += int(action.get("amount", 0)) * weights.heal_per_point * action_scale
            has_defense = True
            continue

        if action_type == "draw":
            draw = int(action.get("amount", 0))
            draw_amount += draw
            breakdown.flow += draw * weights.draw_per_point * action_scale
            has_draw = True
            continue

        if action_type == "card_play":
            card_plays = int(action.get("amount", 0))
            breakdown.flow += card_plays * weights.card_play_per_point * action_scale
            has_card_play = True
            continue

        if action_type == "intensity":
            amount = max(0, int(action.get("amount", 0)))
            element = str(action.get("element", card_element))
            if element in ELEMENTS and amount > 0:
                breakdown.elemental_intensity += amount * weights.intensity_gain_per_point
                if element == card_element:
                    breakdown.synergy += weights.intensity_same_element_synergy
                intensity_context[element] = int(intensity_context.get(element, 0)) + amount
                has_intensity_gain = True
            continue

        if action_type == "illusion":
            breakdown.defense += int(action.get("health", action.get("amount", 0))) * weights.illusion_health_per_point * action_scale
            breakdown.control += int(action.get("range", 0)) * weights.illusion_range_per_tile * action_scale
            has_illusion = True
            has_defense = True
            continue

        if action_type == "illuminate":
            radius = max(1, int(action.get("radius", action.get("amount", 1))))
            duration = int(action.get("duration", 1))
            duration_value = 3 if duration < 0 else max(1, duration)
            breakdown.radiance += (
                radius * weights.illuminate_radius_per_tile
                + duration_value * weights.illuminate_duration_per_activation
                + int(action.get("range", 0)) * weights.illuminate_range_per_tile
            ) * weights.umbra_relevance
            continue

        if action_type == "vision":
            amount = max(0, int(action.get("amount", 0)))
            duration = int(action.get("duration", 1))
            duration_value = 3 if duration < 0 else max(1, duration)
            breakdown.radiance += amount * duration_value * weights.vision_per_radius_activation * weights.umbra_relevance
            continue

        if action_type == "truesight":
            duration = int(action.get("duration", action.get("amount", 1)))
            duration_value = 3 if duration < 0 else max(1, duration)
            breakdown.radiance += duration_value * weights.truesight_per_activation * weights.umbra_relevance
            continue

        if action_type == "dispel_umbra":
            breakdown.radiance += max(0, int(action.get("amount", 1))) * weights.dispel_umbra_per_stage * weights.umbra_relevance
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
    if has_card_play and (has_attack or has_move or has_defense):
        breakdown.synergy += weights.card_play_synergy
    if has_draw and has_card_play:
        breakdown.synergy += weights.draw_card_play_synergy
    if has_move and has_push_pull:
        breakdown.synergy += weights.move_push_pull_synergy
    if has_move and has_defense and not has_attack:
        breakdown.synergy += weights.move_defense_synergy
    if has_move and has_illusion:
        breakdown.synergy += weights.illusion_move_synergy
    if illusion_before_move:
        breakdown.synergy += weights.illusion_before_move_synergy
    if has_intensity_gain and has_intensity_gate:
        breakdown.synergy += weights.intensity_gate_synergy

    flurry_multiplier = weights.flurry_expected_plays if bool(card.get("flurry", False)) else 1
    if flurry_multiplier > 1:
        for field in (
            "offense",
            "control",
            "defense",
            "flow",
            "elemental_intensity",
            "mobility",
            "synergy",
        ):
            setattr(breakdown, field, getattr(breakdown, field) * flurry_multiplier)
        extra_copies = flurry_multiplier - 1
        breakdown.flurry_compression_bonus = extra_copies * (
            weights.flurry_saved_card_value
            + weights.flurry_saved_time_payment_value
            + weights.flurry_retargeting_value
        )
        breakdown.flurry_commitment_penalty = (flurry_multiplier - 1) * weights.flurry_extra_play_penalty

    if intensity_cost:
        raw_availability = _intensity_requirement_availability(intensity_cost, intensity_context)
        retained_card_availability = weights.intensity_spend_retention_floor + (
            1.0 - weights.intensity_spend_retention_floor
        ) * raw_availability
        for field in (
            "offense",
            "control",
            "defense",
            "flow",
            "elemental_intensity",
            "mobility",
            "radiance",
            "synergy",
        ):
            setattr(breakdown, field, getattr(breakdown, field) * retained_card_availability)
        breakdown.flurry_compression_bonus *= retained_card_availability
        breakdown.intensity_spend_cost = int(intensity_cost["amount"]) * weights.intensity_spend_per_point

    breakdown.health_cost = int(card.get("health_cost", 0)) * weights.health_cost_per_point * flurry_multiplier
    if bool(card.get("burn", False)):
        breakdown.burn_card_penalty = max(
            0.0,
            weights.burn_card_penalty - draw_amount * weights.burn_card_draw_offset_per_card,
        )
    card_time = max(1, min(10, int(card.get("time", weights.baseline_card_time))))
    breakdown.tempo = (weights.baseline_card_time - card_time) * weights.time_delta_value

    breakdown.total = round(
        breakdown.offense
        + breakdown.control
        + breakdown.defense
        + breakdown.flow
        + breakdown.elemental_intensity
        + breakdown.mobility
        + breakdown.radiance
        + breakdown.synergy
        + breakdown.tempo
        + breakdown.flurry_compression_bonus
        - breakdown.intensity_spend_cost
        - breakdown.health_cost
        - breakdown.burn_card_penalty
        - breakdown.flurry_commitment_penalty,
        4,
    )
    return breakdown


def load_cards(cards_path: Path) -> dict[str, Any]:
    with cards_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"Expected dictionary JSON in {cards_path}")
    return data


def equipment_card_sources(equipment_path: Path) -> dict[str, list[str]]:
    with equipment_path.open("r", encoding="utf-8") as handle:
        equipment = json.load(handle)
    if not isinstance(equipment, dict):
        raise ValueError(f"Expected dictionary JSON in {equipment_path}")

    sources: dict[str, list[str]] = {}
    for equipment_id, item in equipment.items():
        if not isinstance(item, dict):
            continue
        cards = item.get("cards", [])
        if not isinstance(cards, list):
            continue
        for card_id in cards:
            sources.setdefault(str(card_id), []).append(str(equipment_id))
    for equipment_ids in sources.values():
        equipment_ids.sort()
    return sources


def card_source_metadata(card_id: str, card: dict[str, Any], equipment_sources: dict[str, list[str]]) -> dict[str, Any]:
    equipment_ids = equipment_sources.get(card_id, [])
    is_equipment_granted = len(equipment_ids) > 0
    is_item = bool(card.get("item", False))
    consume_on_play = bool(card.get("consume_on_play", False))
    is_starter = bool(card.get("starter", False)) or str(card.get("rarity", "")) == "starter"
    is_equipment = is_equipment_granted and not is_item and not is_starter
    is_reward_pool = bool(card.get("reward_pool", True)) and not is_equipment_granted and not is_item and not is_starter
    element = str(card.get("element", "none"))
    is_elemental_reward = is_reward_pool and element in ELEMENTS
    is_neutral_reward = is_reward_pool and not is_elemental_reward

    source_tags: list[str] = []
    if is_reward_pool:
        source_tags.append("reward-pool")
    if is_elemental_reward:
        source_tags.append("elemental-reward")
    if is_neutral_reward:
        source_tags.append("neutral-reward")
    if is_equipment:
        source_tags.append("equipment")
    if is_item:
        source_tags.append("item")
    if consume_on_play:
        source_tags.append("consumable")
    if is_starter:
        source_tags.append("starter")
    if not source_tags:
        source_tags.append("off-pool")

    return {
        "source_tags": source_tags,
        "is_reward_pool": is_reward_pool,
        "is_elemental_reward": is_elemental_reward,
        "is_neutral_reward": is_neutral_reward,
        "is_equipment": is_equipment,
        "is_equipment_granted": is_equipment_granted,
        "is_item": is_item,
        "consume_on_play": consume_on_play,
        "is_starter": is_starter,
        "equipment_ids": list(equipment_ids),
    }


def scored_rows(
    cards: dict[str, Any],
    weights: HeuristicWeights,
    equipment_sources: dict[str, list[str]],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for card_id, card in cards.items():
        breakdown = score_card(card_id, card, weights)
        source_metadata = card_source_metadata(card_id, card, equipment_sources)
        rows.append(
            {
                "card_id": card_id,
                "name": card.get("name", card_id),
                "rarity": card.get("rarity", "common"),
                "element": card.get("element", "none"),
                "burn": bool(card.get("burn", False)),
                "flurry": bool(card.get("flurry", False)),
                "consume_on_play": bool(card.get("consume_on_play", False)),
                "health_cost": int(card.get("health_cost", 0)),
                "intensity_cost": card_intensity_cost(card, str(card.get("element", "none"))),
                "time": int(card.get("time", weights.baseline_card_time)),
                "description": card.get("description", ""),
                "score": breakdown.total,
                "breakdown": asdict(breakdown),
                **source_metadata,
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
        "--equipment-path",
        type=Path,
        default=DEFAULT_EQUIPMENT_PATH,
        help="Path to equipment JSON for card source annotation. Defaults to data/equipment.json.",
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
        "--show-assumptions",
        action="store_true",
        help="Emit the encounter assumptions behind the coefficients as JSON and exit.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit the number of returned cards after sorting. 0 means all cards.",
    )
    parser.add_argument(
        "--show-source",
        action="store_true",
        help="Include card source tags in text output. Source tags are always present in JSON output.",
    )
    source_group = parser.add_mutually_exclusive_group()
    source_group.add_argument(
        "--source",
        dest="source_filter",
        choices=SOURCE_FILTERS,
        help="Filter cards by source view.",
    )
    source_group.add_argument(
        "--reward-pool",
        "--normal-rewards",
        dest="source_filter",
        action="store_const",
        const="reward-pool",
        help="Only normal card rewards: reward_pool cards excluding equipment and starters.",
    )
    source_group.add_argument(
        "--elemental-rewards",
        "--elemental-reward",
        dest="source_filter",
        action="store_const",
        const="elemental-reward",
        help="Only elemental cards from the normal reward pool.",
    )
    source_group.add_argument(
        "--neutral-rewards",
        "--neutral-reward",
        dest="source_filter",
        action="store_const",
        const="neutral-reward",
        help="Only neutral cards from the normal reward pool.",
    )
    source_group.add_argument(
        "--equipment",
        dest="source_filter",
        action="store_const",
        const="equipment",
        help="Only equipment-only cards, excluding starters granted by starting gear.",
    )
    source_group.add_argument(
        "--items",
        "--item",
        dest="source_filter",
        action="store_const",
        const="item",
        help="Only consumable item cards found in combat or sold by the Scavenger.",
    )
    source_group.add_argument(
        "--starters",
        "--starter",
        dest="source_filter",
        action="store_const",
        const="starter",
        help="Only starter cards, using starter metadata or legacy starter rarity.",
    )
    parser.set_defaults(source_filter="all")
    return parser


def select_rows(rows: list[dict[str, Any]], args: argparse.Namespace) -> list[dict[str, Any]]:
    selected = rows
    source_filter = str(args.source_filter)
    if source_filter != "all":
        selected = [row for row in selected if bool(row[f"is_{source_filter.replace('-', '_')}"])]
    if args.card_id:
        selected = [row for row in rows if row["card_id"] == args.card_id]
        if source_filter != "all":
            selected = [row for row in selected if bool(row[f"is_{source_filter.replace('-', '_')}"])]
    if args.limit > 0:
        selected = selected[: args.limit]
    return selected


def print_text(rows: list[dict[str, Any]], show_breakdown: bool, show_source: bool) -> None:
    for index, row in enumerate(rows, start=1):
        tag_bits = []
        if row["element"] != "none":
            tag_bits.append(str(row["element"]))
        tag_bits.append(str(row["rarity"]))
        if show_source:
            tag_bits.append("source=" + "/".join(str(tag) for tag in row["source_tags"]))
        if row["burn"]:
            tag_bits.append("exhaust-card")
        if row["flurry"]:
            tag_bits.append("flurry")
        if row["health_cost"] > 0:
            tag_bits.append(f"hp-cost={row['health_cost']}")
        if row["intensity_cost"]:
            tag_bits.append(
                f"intensity-cost={row['intensity_cost']['element']}:{row['intensity_cost']['amount']}"
            )
        tag_bits.append(f"time={row['time']}")
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
                        f"intensity={breakdown['elemental_intensity']:.2f}",
                        f"intensity_spend={breakdown['intensity_spend_cost']:.2f}",
                        f"mobility={breakdown['mobility']:.2f}",
                        f"radiance={breakdown['radiance']:.2f}",
                        f"synergy={breakdown['synergy']:.2f}",
                        f"tempo={breakdown['tempo']:.2f}",
                        f"health_cost={breakdown['health_cost']:.2f}",
                        f"exhaust_penalty={breakdown['burn_card_penalty']:.2f}",
                        f"flurry_compression={breakdown['flurry_compression_bonus']:.2f}",
                        f"flurry_commitment={breakdown['flurry_commitment_penalty']:.2f}",
                    ]
                )
            )


def main() -> int:
    args = build_parser().parse_args()
    if args.show_assumptions:
        print(json.dumps(encounter_assumptions(), indent=2))
        return 0
    cards = load_cards(args.cards_path)
    equipment_sources = equipment_card_sources(args.equipment_path)
    weights = HeuristicWeights()
    all_rows = scored_rows(cards, weights, equipment_sources)
    rows = select_rows(all_rows, args)

    if args.card_id and not any(row["card_id"] == args.card_id for row in all_rows):
        raise SystemExit(f"Unknown card id: {args.card_id}")

    if args.json:
        print(json.dumps(rows, indent=2))
    else:
        print_text(rows, args.show_breakdown, args.show_source or args.source_filter != "all")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
