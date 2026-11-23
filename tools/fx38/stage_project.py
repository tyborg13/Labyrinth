"""Mount each proof input read-only with a private Godot project and cache index."""

from pathlib import Path
import subprocess
import sys

BASE = "76aac505bcc3f1f915344a5e7b14e8e20e1e1fae"
WORKTREE = Path(__file__).resolve().parents[2]
KINDLE = Path("scripts/enemy_mechanics/kindle_view.gd")
BASE_ART = "assets/shaders/combat_art_treatment.gdshader"
DRAW = "\t\tdraw_colored_polygon(points, Color(ORANGE, alpha * pulse))"


def check_base(origin: Path) -> None:
    head = subprocess.check_output(["git", "-C", origin, "rev-parse", "HEAD"], text=True).strip()
    if head != BASE:
        raise SystemExit(f"{origin} must be at candidate 4 ({BASE})")
    subprocess.run(
        ["git", "-C", origin, "-c", "core.fsmonitor=false", "diff", "--quiet", BASE, "--",
         "project.godot", "scripts", "scenes", "assets", "addons", "data", "shaders", "tools", "tests"],
        check=True,
    )


def stage(origin: Path, destination: Path, mode: str, before: bool) -> None:
    if before:
        check_base(origin)
    folders = {Path(".godot")}
    if before:
        folders.update({Path("scripts"), KINDLE.parent, Path("tools")})
    for path in origin.iterdir():
        if not path.name.startswith(".") and Path(path.name) not in folders:
            (destination / path.name).symlink_to(path)
    for directory in sorted(folders):
        target = destination / directory
        target.mkdir()
        for path in (origin / directory).iterdir():
            relative = path.relative_to(origin)
            if relative in folders or (before and relative in {KINDLE, Path("tools/fx38")}):
                continue
            if directory == Path(".godot") and path.name not in {
                "imported", ".gdignore", "global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg",
            }:
                continue
            (target / path.name).symlink_to(path)
    if not before:
        baseline = subprocess.check_output(["git", "-C", WORKTREE, "show", f"{BASE}:{BASE_ART}"])
        (destination / ".godot/fx38_base_art.gdshader").write_bytes(baseline)
        return
    (destination / "tools/fx38").symlink_to(WORKTREE / "tools/fx38")
    source = subprocess.check_output(["git", "-C", origin, "show", f"{BASE}:{KINDLE}"], text=True)
    if mode == "plan":
        if source.count(DRAW) != 1:
            raise SystemExit("Candidate 4 Kindle polygon call changed")
        source = source.replace(
            DRAW, DRAW + '\n\t\tif get_meta("fx38_alpha", -1.0) != alpha:\n'
            '\t\t\tset_meta("fx38_alpha", alpha)\n'
            '\t\t\tprint("FX-38 BASE draw_colored_polygon %s vertices=%d alpha=%.2f" % [name, points.size(), alpha])',
        )
    (destination / KINDLE).write_text(source, encoding="utf-8")


if __name__ == "__main__":
    stage(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve(), sys.argv[3], sys.argv[4] == "before")
