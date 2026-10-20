"""Shared helpers for board mockups: iso tile polygons as SVG."""
def tile(cx, cy, w, h, i, j, scale=1.0):
    x = cx + (i - j) * w / 2; y = cy + (i + j) * h / 2
    a, b = w / 2 * scale, h / 2 * scale
    return x, y, f"{x:.1f},{y-b:.1f} {x+a:.1f},{y:.1f} {x:.1f},{y+b:.1f} {x-a:.1f},{y:.1f}"
def poly(cx, cy, w, h, i, j, cls, scale=0.84):
    return f'<polygon class="{cls}" points="{tile(cx, cy, w, h, i, j, scale)[2]}"/>'
FONTS = """
@font-face { font-family: CrumbleDisplay; src: url('file:///Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/fonts/LabyrinthCrumble-Display.ttf'); }
@font-face { font-family: CrumbleText; src: url('file:///Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/fonts/LabyrinthCrumble-Text.ttf'); }
@font-face { font-family: CrumbleUI; src: url('file:///Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/fonts/LabyrinthCrumble-UI.ttf'); }
"""
ICONS = "file:///Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/assets/art/icons/"
BASE_CSS = FONTS + """
html, body { margin: 0; width: 1920px; height: 1080px; overflow: hidden; background: #000; }
.stage { position: relative; width: 1920px; height: 1080px; }
.stage > img.bg { position: absolute; inset: 0; }
svg.ov { position: absolute; inset: 0; }
.threat { fill: rgba(199,69,59,.24); stroke: #d9534a; stroke-width: 2.2; }
.shelter { fill: rgba(86,200,170,.26); stroke: #6fe0c2; stroke-width: 2.6; }
.callout { position: absolute; background: linear-gradient(#211912f2, #16110cf2); border: 2px solid #9c7438;
  border-radius: 7px; box-shadow: 0 10px 30px #000a, inset 0 0 0 1px #3a2a18; color: #eadfc8; font-family: CrumbleText; }
.callout .eyebrow { font: 600 13px/1 CrumbleUI; letter-spacing: .14em; color: #c79a52; text-transform: uppercase; }
.callout h4 { margin: 6px 0 8px; font: 30px/1.05 CrumbleDisplay; color: #f0c76a; }
.callout p { margin: 0 0 7px; font-size: 18px; line-height: 1.32; }
.callout .foot { margin-top: 8px; font: 13px/1 CrumbleUI; color: #9b8d75; letter-spacing: .06em; }
.note { position: absolute; font: 600 15px/1.2 CrumbleUI; color: #ffd98a; background: #000b; padding: 6px 10px; border: 1px dashed #ffd98a88; border-radius: 4px; }
"""
