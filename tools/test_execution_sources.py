"""Non-default entrypoints used by the full Godot and Python suites."""
from __future__ import annotations

import ast
from pathlib import Path

PARTITIONED_PROGRAMS = {
    "tests/encounter_tables_test.gd": (
        "tests/suites/encounter_rules_program.gd",
        "tests/suites/encounter_placement_0_program.gd",
        "tests/suites/encounter_placement_1_program.gd",
        "tests/suites/encounter_placement_summary_program.gd",
    ),
}
PYTHON_PROGRAMS = {"tests/program_suite_runner_test.gd": "tests/test_program_suite_runner.py"}


def python_program_coverage(root: Path) -> dict[str, str]:
    """Require an actual subprocess command in a reachable unittest method.

    The scheduler's Godot driver must use injected children in Python's full
    suite; running its default entrypoint inside itself would recurse forever.
    Mere path mentions or unused helper methods cannot count as coverage.
    """
    covered = {}
    for program, driver in PYTHON_PROGRAMS.items():
        path = root / driver
        if not path.is_file():
            continue
        module = ast.parse(path.read_text(encoding="utf-8"))
        for cls in (node for node in module.body if isinstance(node, ast.ClassDef)):
            methods = {node.name: node for node in cls.body if isinstance(node, ast.FunctionDef)}
            pending = [name for name in methods if name.startswith("test_")]
            reached = set()
            while pending:
                name = pending.pop()
                if name in reached or name not in methods:
                    continue
                reached.add(name)
                method = methods[name]
                commands = set()
                executed = set()
                for node in ast.walk(method):
                    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
                        receiver = node.func.value
                        if isinstance(receiver, ast.Name) and receiver.id == "self":
                            pending.append(node.func.attr)
                        if isinstance(receiver, ast.Name) and receiver.id == "subprocess" and node.func.attr in ("run", "Popen"):
                            if node.args and isinstance(node.args[0], ast.Name):
                                executed.add(node.args[0].id)
                    if isinstance(node, ast.Assign) and isinstance(node.value, ast.List):
                        values = [element.value if isinstance(element, ast.Constant) else None for element in node.value.elts]
                        if any(a == "--script" and b == program for a, b in zip(values, values[1:])):
                            commands.update(target.id for target in node.targets if isinstance(target, ast.Name))
                if commands & executed:
                    covered[program] = "Python full suite: %s::%s.%s" % (driver, cls.name, name)
    return covered
