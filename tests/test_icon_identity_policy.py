from __future__ import annotations

import hashlib
import json
import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
ACTION_ICON_LIBRARY = REPO_ROOT / "scripts" / "action_icon_library.gd"
ROOTS = {
    "ICON_ROOT": "assets/art/icons",
    "SKILL_ICON_ROOT": "assets/art/skills",
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

    def test_policy_is_mandatory_for_ui_work(self) -> None:
        agents = (REPO_ROOT / "AGENTS.md").read_text(encoding="utf-8")
        skill = (REPO_ROOT / ".codex/skills/create-labyrinth-ui/SKILL.md").read_text(encoding="utf-8")
        rubric = (REPO_ROOT / "spec/game_ui_rubric.md").read_text(encoding="utf-8")
        for source in (agents, skill, rubric):
            self.assertIn("spec/icon_identity_policy.md", source)


if __name__ == "__main__":
    unittest.main()
