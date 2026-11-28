"""Stage production sources with observation hooks for the headless diagnostic pack."""
from pathlib import Path
import sys

IMPORT = 'const Fel32Trace = preload("res://tools/fel32/trace.gd")\n'


def inject(source, anchor, added):
    if source.count(anchor) != 1:
        raise ValueError(f"Expected one trace anchor: {anchor!r}")
    return source.replace(anchor, added)


def stage(project, output):
    output.mkdir()
    scripts = project / "scripts"
    board = (scripts / "combat_board_view.gd").read_text()
    board = inject(board, "func _draw() -> void:\n", "func _draw() -> void:\n\tFel32Trace.begin(self)\n")
    board = inject(board, "\t\t\t\tcallv(operation[0], operation[1])",
                   "\t\t\t\tFel32Trace.operation(self, operation[0], operation[1])\n\t\t\t\tcallv(operation[0], operation[1])")
    board = inject(board, "\t\tcallv(method, args)\n\nfunc _draw_slice_banner",
                   "\t\tFel32Trace.operation(self, method, args)\n\t\tcallv(method, args)\n\nfunc _draw_slice_banner")
    fill = '\tdraw_colored_polygon(inner, Color(UiPaletteTokens.DANGER, fill * alpha))'
    board = inject(board, fill, '\tFel32Trace.operation(self, "draw_colored_polygon", [inner, Color(UiPaletteTokens.DANGER, fill * alpha)])\n' + fill)
    (output / "combat_board_view.gd").write_text(board + "\n" + IMPORT)

    targeted = (scripts / "targeted_tile_threat.gd").read_text()
    targeted = inject(targeted, "func _draw() -> void:\n", "func _draw() -> void:\n\tFel32Trace.begin(self)\n")
    if "Threats.draw_tile_outline(self, _paint)" in targeted:
        source = (scripts / "threat_tiles.gd").read_text()
        draw = '\t\tcanvas.callv("draw_polyline", arguments)'
        source = inject(source, draw, '\t\tFel32Trace.operation(canvas, "draw_polyline", arguments)\n' + draw)
        (output / "threat_tiles.gd").write_text(source + "\n" + IMPORT)
    else:
        line = next(line for line in targeted.splitlines() if line.startswith("\tdraw_polyline(outline, "))
        args = line.removeprefix("\tdraw_polyline(").removesuffix(")")
        targeted = inject(targeted, line, f'\tFel32Trace.operation(self, "draw_polyline", [{args}])\n' + line)
    (output / "targeted_tile_threat.gd").write_text(targeted + "\n" + IMPORT)

    border = (scripts / "targeted_tile_highlight.gd").read_text()
    border = inject(border, "func _draw() -> void:\n", "func _draw() -> void:\n\tset_meta(Fel32Trace.BORDER, true)\n")
    (output / "targeted_tile_highlight.gd").write_text(border + "\n" + IMPORT)


if __name__ == "__main__":
    stage(*map(Path, sys.argv[1:]))
