from __future__ import annotations

import hashlib
import json
import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
ACTION_ICON_LIBRARY = REPO_ROOT / "scripts" / "action_icon_library.gd"
COMBAT_OBJECTIVE_RULES = REPO_ROOT / "scripts" / "combat_objective_rules.gd"
ROOTS = {
    "ICON_ROOT": "assets/art/icons",
    "SKILL_ICON_ROOT": "assets/art/skills",
}

EXPECTED_GRIMOIRE_TOPIC_ICONS = {
    "basic:run": "run",
    "basic:map": "map_rooms",
    "basic:loadout": "loadout",
    "basic:rewards": "rewards",
    "basic:relics": "relics",
    "combat:board": "combat_board",
    "combat:turn_clock": "turn_clock",
    "combat:card_plays": "card_play",
    "combat:health_defense": "health_defense",
    "combat:defiance": "defiance",
    "combat:targeting": "targeting",
    "combat:fatigue": "fatigue",
    "combat:traps": "traps",
    "combat:intensity": "elemental_intensity",
    "combat:lightning_strikes": "lightning_strikes",
    "combat:summons": "summon_minions",
    "combat:umbra": "umbra",
    "combat:worldspines": "worldspines",
    "combat:cinder_marks": "cinder_marks",
    "combat:hollow_gale": "gale_force",
    "combat:crystal_armor": "frost_armor",
    "combat:boss_eclipse": "umbra_eclipse",
}

# These are one player-facing concept despite differing engine direction/target
# names. Every other shared action icon is rejected.
ALLOWED_EXACT_ACTION_ALIAS_GROUPS = {
    frozenset({"heal", "heal_self"}),
    frozenset({"move", "move_toward"}),
}

EXPECTED_OBJECTIVE_ICONS = {
    "kill_all": "res://assets/art/icons/objectives/kill_all_enemies.png",
    "kill_leader": "res://assets/art/icons/objectives/kill_the_leader.png",
    "survive": "res://assets/art/icons/objectives/survive.png",
    "reach_exit": "res://assets/art/icons/objectives/reach_the_exit.png",
}

EXPECTED_CARD_ROLE_EMBLEMS = {
    "attack_melee": "res://assets/art/ui/card_role_emblems/role_attack_melee.png",
    "attack_ranged": "res://assets/art/ui/card_role_emblems/role_attack_ranged.png",
    "block": "res://assets/art/ui/card_role_emblems/role_block.png",
    "illusion": "res://assets/art/ui/card_role_emblems/role_illusion.png",
    "mobility": "res://assets/art/ui/card_role_emblems/role_mobility.png",
}


def _action_icon_paths() -> dict[str, str]:
    result: dict[str, str] = {}
    current_key = ""
    entry_pattern = re.compile(r'^\s*"([^"]+)"\s*:\s*\{')
    path_pattern = re.compile(r'"path"\s*:\s*"%s/([^"]+)"\s*%\s*([A-Z_]+)')
    for line in ACTION_ICON_LIBRARY.read_text(encoding="utf-8").splitlines():
        entry_match = entry_pattern.search(line)
        if entry_match:
            current_key = entry_match.group(1)
        path_match = path_pattern.search(line)
        if path_match and current_key:
            root_name = path_match.group(2)
            if root_name in ROOTS:
                result[current_key] = f"res://{ROOTS[root_name]}/{path_match.group(1)}"
    return result


def _action_icon_aliases() -> dict[str, str]:
    source = ACTION_ICON_LIBRARY.read_text(encoding="utf-8")
    block = re.search(
        r"const ACTION_ICON_ALIASES:\s*Dictionary\s*=\s*\{(?P<body>.*?)^\}",
        source,
        re.MULTILINE | re.DOTALL,
    )
    if block is None:
        raise AssertionError("ActionIconLibrary must declare ACTION_ICON_ALIASES")
    return dict(re.findall(r'^\s*"([^"]+)":\s*"([^"]+)"', block.group("body"), re.MULTILINE))


def _card_role_emblem_paths() -> dict[str, str]:
    source = ACTION_ICON_LIBRARY.read_text(encoding="utf-8")
    block = re.search(
        r"const CARD_ROLE_EMBLEM_PATHS:\s*Dictionary\s*=\s*\{(?P<body>.*?)^\}",
        source,
        re.MULTILINE | re.DOTALL,
    )
    if block is None:
        raise AssertionError("ActionIconLibrary must declare CARD_ROLE_EMBLEM_PATHS")
    return dict(re.findall(r'^\s*"([^"]+)":\s*"([^"]+)"', block.group("body"), re.MULTILINE))


def _declared_action_types(filename: str) -> set[str]:
    payload = json.loads((REPO_ROOT / "data" / filename).read_text(encoding="utf-8"))
    result: set[str] = set()

    def visit(value: object) -> None:
        if isinstance(value, dict):
            actions = value.get("actions")
            if isinstance(actions, list):
                for action in actions:
                    if isinstance(action, dict) and isinstance(action.get("type"), str):
                        result.add(action["type"])
                    visit(action)
            for key, child in value.items():
                if key != "actions":
                    visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    visit(payload)
    return result


def _gd_function(source: str, function_name: str) -> str:
    match = re.search(
        rf"^func {re.escape(function_name)}\(.*?(?=^func |\Z)",
        source,
        re.MULTILINE | re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"Missing GDScript function: {function_name}")
    return match.group(0)


class IconIdentityPolicyTests(unittest.TestCase):
    def test_distinct_player_facing_concepts_own_distinct_assets(self) -> None:
        registry = _action_icon_paths()
        concepts: dict[str, str] = {
            f"keyword:{key}": path
            for key, path in registry.items()
            if not key.startswith("skill_")
        }

        skills = json.loads((REPO_ROOT / "data/skills.json").read_text(encoding="utf-8"))
        for skill_id, skill in skills.items():
            icon_key = skill.get("icon", "")
            self.assertEqual(icon_key, f"skill_{skill_id}", f"{skill_id} must use its purpose-built skill icon key")
            self.assertIn(icon_key, registry, f"{skill_id} icon key must be registered")
            concepts[f"skill:{skill_id}"] = registry[icon_key]

        for filename, field, family in (
            ("relics.json", "icon_path", "relic"),
            ("equipment.json", "icon_path", "equipment"),
        ):
            payload = json.loads((REPO_ROOT / f"data/{filename}").read_text(encoding="utf-8"))
            for item_id, definition in payload.items():
                path = definition.get(field, "")
                self.assertTrue(path, f"{family}:{item_id} must declare {field}")
                concepts[f"{family}:{item_id}"] = path

        card_role_emblems = _card_role_emblem_paths()
        self.assertEqual(
            card_role_emblems,
            EXPECTED_CARD_ROLE_EMBLEMS,
            "Card role emblems must remain a small, reviewed semantic inventory",
        )
        for role, path in card_role_emblems.items():
            concepts[f"card_role:{role}"] = path

        objective_rules = COMBAT_OBJECTIVE_RULES.read_text(encoding="utf-8")
        for objective_id, path in EXPECTED_OBJECTIVE_ICONS.items():
            filename = path.rsplit("/", 1)[-1]
            self.assertIn(
                f'"icon_path": ICON_ROOT + "{filename}"',
                objective_rules,
                f"objective:{objective_id} must resolve through the central objective registry",
            )
            concepts[f"objective:{objective_id}"] = path

        paths: dict[str, str] = {}
        hashes: dict[str, str] = {}
        for concept, resource_path in concepts.items():
            self.assertTrue(resource_path.startswith("res://"), f"{concept} must use a project resource path")
            asset_path = REPO_ROOT / resource_path.removeprefix("res://")
            self.assertTrue(asset_path.is_file(), f"{concept} icon is missing: {resource_path}")
            self.assertNotIn(resource_path, paths, f"{concept} shares its icon path with {paths.get(resource_path)}")
            paths[resource_path] = concept
            digest = hashlib.sha256(asset_path.read_bytes()).hexdigest()
            self.assertNotIn(digest, hashes, f"{concept} is a byte-identical icon copy of {hashes.get(digest)}")
            hashes[digest] = concept

    def test_every_data_action_resolves_through_the_central_icon_inventory(self) -> None:
        registry = _action_icon_paths()
        aliases = _action_icon_aliases()
        declared_actions = _declared_action_types("cards.json") | _declared_action_types("enemies.json")
        dynamic_action_types = {"intensity", "intensity_spend"}
        self.assertFalse(
            declared_actions - aliases.keys() - dynamic_action_types,
            f"Action types lack a reviewed icon identity: {sorted(declared_actions - aliases.keys() - dynamic_action_types)}",
        )
        for action_type, icon_key in aliases.items():
            self.assertIn(icon_key, registry, f"{action_type} maps to an unregistered icon key: {icon_key}")

        action_types_by_icon: dict[str, set[str]] = {}
        for action_type, icon_key in aliases.items():
            action_types_by_icon.setdefault(icon_key, set()).add(action_type)
        actual_shared_groups = {
            frozenset(action_types)
            for action_types in action_types_by_icon.values()
            if len(action_types) > 1
        }
        self.assertEqual(
            actual_shared_groups,
            ALLOWED_EXACT_ACTION_ALIAS_GROUPS,
            "Shared action icons require a narrow exact-concept exception",
        )

        run_scene = (REPO_ROOT / "scripts/run_scene.gd").read_text(encoding="utf-8")
        for function_name in ("_action_step_icon_key", "_pre_battle_known_move_icon_key"):
            function = _gd_function(run_scene, function_name)
            self.assertIn(
                "ActionIcons.action_icon_key(action)",
                function,
                f"{function_name} must consume the central action icon inventory",
            )

    def test_grimoire_icons_are_registered_and_semantically_exact(self) -> None:
        registry = _action_icon_paths()
        grimoire = json.loads((REPO_ROOT / "data/grimoire.json").read_text(encoding="utf-8"))
        entries_with_icons = {
            entry["id"]: entry["icon"]
            for entry in grimoire["entries"]
            if entry.get("icon")
        }
        for entry_id, icon_key in entries_with_icons.items():
            self.assertIn(icon_key, registry, f"{entry_id} uses an unregistered icon key: {icon_key}")
            if entry_id.startswith("keyword:"):
                self.assertEqual(
                    icon_key,
                    entry_id.removeprefix("keyword:"),
                    f"{entry_id} must use its own exact keyword icon",
                )

        actual_topic_icons = {
            entry_id: icon_key
            for entry_id, icon_key in entries_with_icons.items()
            if not entry_id.startswith("keyword:")
        }
        self.assertEqual(
            actual_topic_icons,
            EXPECTED_GRIMOIRE_TOPIC_ICONS,
            "Every icon-bearing grimoire topic must join the reviewed semantic inventory",
        )

        run_scene = (REPO_ROOT / "scripts/run_scene.gd").read_text(encoding="utf-8")
        grimoire_consumer = _gd_function(run_scene, "_grimoire_entry_icon")
        self.assertIn("ActionIcons.icon_texture(icon_key)", grimoire_consumer)
        self.assertNotIn("res://assets/art/icons/%s", grimoire_consumer)
        self.assertNotIn("_grimoire_aoe_icon_texture", run_scene)

    def test_policy_is_mandatory_for_ui_work(self) -> None:
        agents = (REPO_ROOT / "AGENTS.md").read_text(encoding="utf-8")
        skill = (REPO_ROOT / ".codex/skills/create-labyrinth-ui/SKILL.md").read_text(encoding="utf-8")
        rubric = (REPO_ROOT / "spec/game_ui_rubric.md").read_text(encoding="utf-8")
        for source in (agents, skill, rubric):
            self.assertIn("spec/icon_identity_policy.md", source)

    def test_card_widget_consumes_the_central_role_emblem_inventory(self) -> None:
        source = (REPO_ROOT / "scripts/card_widget.gd").read_text(encoding="utf-8")
        self.assertIn("ActionIcons.card_role_emblem_path(card)", source)
        self.assertNotIn("ActionIcons.icon_texture(emblem", source)


if __name__ == "__main__":
    unittest.main()
