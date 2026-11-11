"""Extract the approved base into task-local scratch for repeatable before proof."""
from pathlib import Path
import subprocess

BASE_REF = "7cf181c7e"
OUTPUT_DIR = Path("/private/tmp/labyrinth_codex/ptf-02/baseline")
PROJECT_ROOT = Path(__file__).resolve().parents[2]


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    graph = subprocess.check_output(
        ["git", "show", f"{BASE_REF}:scripts/section_map_graph.gd"], cwd=PROJECT_ROOT
    ).decode()
    fallback = subprocess.check_output(
        ["git", "show", f"{BASE_REF}:data/section_map_v7_fallbacks.json"], cwd=PROJECT_ROOT
    )
    fallback_path = OUTPUT_DIR / "fallbacks.json"
    fallback_path.write_bytes(fallback)
    # Avoid a duplicate registered global class. Only the data path and
    # observational diagnostics differ; RNG and generation rules are untouched.
    graph = graph.replace("class_name SectionMapGraph\n", "")
    graph = graph.replace("res://data/section_map_v7_fallbacks.json", str(fallback_path))
    marker = '\t\tif revision >= 6 and not Specials.place(layout, rng, count, Bosses.element_for_boss(boss_id), {}, revision):\n'
    assert graph.count(marker) == 1
    graph = graph.replace(marker, marker + '\t\t\t_diagnostic_v5(section_diagnostics, "fallback")\n')
    target = OUTPUT_DIR / "section_map_graph.gd"
    target.write_text(graph)
    print(f"PTF02 BASELINE: {BASE_REF} -> {target}")


if __name__ == "__main__":
    main()
