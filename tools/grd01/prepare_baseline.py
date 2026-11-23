"""Generate disposable timing wrappers using perf-107's original-body method."""
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(os.environ.get("LABYRINTH_GRD01_OUTPUT", "/private/tmp/labyrinth_codex/grd-02")).resolve() / "profile"
METRICS = 'preload("res://tools/grd01/surface_metrics.gd")'
LAYERS = ("fire", "ice", "electric", "rubble")
DRAW = re.compile(r"^(\t*)func _draw\(\) -> void:", re.MULTILINE)
CONFIGURE = re.compile(r"^func configure\(([^\n]+)\) -> void:", re.MULTILINE)
SURFACE = "func _draw_board_surface(tile: Vector2i) -> void:"


def draw_wrapper(match, kind):
    indent = match[1]
    return (
        f"{indent}func _draw() -> void:\n"
        f"{indent}\tvar started: int = Time.get_ticks_usec()\n"
        f"{indent}\t_grd01_original_draw()\n"
        f'{indent}\t{METRICS}.record("{kind}_draw", started)\n\n'
        f"{indent}func _grd01_original_draw() -> void:"
    )


def configure_wrapper(match, kind):
    parameters = match[1]
    args = ", ".join(parameter.split(":", 1)[0].strip() for parameter in parameters.split(","))
    return (
        f"func configure({parameters}) -> void:\n"
        "\tvar started: int = Time.get_ticks_usec()\n"
        f"\t_grd01_original_configure({args})\n"
        f'\t{METRICS}.record("{kind}_configure", started)\n\n'
        f"func _grd01_original_configure({parameters}) -> void:"
    )


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    board = (ROOT / "scripts/combat_board_view.gd").read_text()
    board = board.replace("class_name CombatBoardView\n", "", 1)
    for kind in LAYERS:
        name = f"board_surface_{kind}_layer.gd"
        source = (ROOT / "scripts" / name).read_text()
        wrapped, entries = DRAW.subn(lambda match: draw_wrapper(match, kind), source)
        expected = {"fire": 2, "ice": 2, "electric": 0, "rubble": 1}[kind]
        if entries != expected:
            raise ValueError(f"{name}: found {entries} draw methods, expected {expected}")
        wrapped, entries = CONFIGURE.subn(lambda match: configure_wrapper(match, kind), wrapped)
        if entries != 1:
            raise ValueError(f"{name}: found {entries} top-level configure methods, expected one")
        path = OUTPUT / name
        path.write_text(wrapped)
        path_ref = f"res://scripts/{name}"
        if board.count(path_ref) != 1:
            raise ValueError(f"Expected one board preload of {name}")
        board = board.replace(path_ref, path.as_posix())
    if board.count(SURFACE) != 1:
        raise ValueError("Expected one board surface draw entry point")
    board = board.replace(
        SURFACE,
        SURFACE + "\n"
        "\tvar started: int = Time.get_ticks_usec()\n"
        "\t_grd01_original_surface(tile)\n"
        f'\t{METRICS}.record("tile_submission", started)\n\n'
        "func _grd01_original_surface(tile: Vector2i) -> void:",
    )
    pixel_name = "board_pixel_surface_layer.gd"
    pixel_path = OUTPUT / pixel_name
    pixel = (ROOT / "scripts" / pixel_name).read_text()
    for signature, method, args, section in (
        ("func _process(delta: float) -> void:", "_process", "delta", "pixel_clock"),
        ("func _project() -> void:", "_project", "", "pixel_project"),
        ("func _request_update() -> void:", "_request_update", "", "pixel_update"),
    ):
        if pixel.count(signature) != 1:
            raise ValueError(f"Expected one pixel layer method {method}")
        original = method.replace("_", "_profiled_", 1)
        pixel = pixel.replace(signature, (
            signature + "\n"
            "\tvar started: int = Time.get_ticks_usec()\n"
            f"\t{original}({args})\n"
            f'\t{METRICS}.record("{section}", started)\n\n'
            + signature.replace(method, original)
        ))
    pixel_path.write_text(pixel)
    board = board.replace(f"res://scripts/{pixel_name}", pixel_path.as_posix(), 1)
    path = OUTPUT / "combat_board_view.gd"
    path.write_text(board)
    print(f"GRD-02 PROFILE: prepared {path}")


if __name__ == "__main__":
    main()
