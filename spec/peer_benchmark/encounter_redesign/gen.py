import base64, json, sys
P = sys.argv[1]
F = "/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/fonts/"
def face(name, file):
    b = base64.b64encode(open(F + file, "rb").read()).decode()
    return f"@font-face{{font-family:{name};src:url(data:font/ttf;base64,{b}) format('truetype');font-display:swap}}"
fonts = face("CrumbleDisplay", "LabyrinthCrumble-Display.ttf") + face("CrumbleText", "LabyrinthCrumble-Text.ttf") + face("CrumbleUI", "LabyrinthCrumble-UI.ttf")
css = """
/* Layout: one reading column of argued sections; board diagrams pair up side by side and stack on phones. */
:root {
  --ground: #14110e; --panel: #1d1814; --ink: #ece2cf; --muted: #a89880; --rule: #3a3027;
  --gold: #d9a441; --threat: #d9534a; --safe: #5fc8ac; --ice: #a9e2ff;
  --display: CrumbleDisplay, "Iowan Old Style", Georgia, serif;
  --text: CrumbleText, "Iowan Old Style", Georgia, serif;
  --ui: CrumbleUI, "Gill Sans", "Segoe UI", sans-serif;
  color-scheme: dark;
}
body { background: var(--ground); color: var(--ink); font: 18px/1.55 var(--text); }
main { max-width: 1060px; margin: 0 auto; padding-block: 36px 80px;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px));
  display: grid; gap: 56px; }
section, header { display: grid; gap: 16px; min-width: 0; }
h1 { font: clamp(36px, 6vw, 60px)/1.02 var(--display); color: #f4d48a; margin: 0; text-wrap: balance; }
h2 { font: clamp(26px, 3.4vw, 36px)/1.1 var(--display); color: #f1e3c4; margin: 0; text-wrap: balance; }
p { margin: 0; max-width: 70ch; }
.eyebrow { font: 600 13px/1 var(--ui); letter-spacing: .18em; text-transform: uppercase; color: var(--gold); }
.lede { font-size: 20px; color: #ddd0b8; }
.small { font-size: 15px; color: var(--muted); }
b { color: #f6e8c8; font-weight: 600; }
.toc { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 6px; }
.toc a { font: 600 14px/1 var(--ui); color: var(--ink); text-decoration: none; border: 1px solid var(--rule); border-radius: 999px; padding: 8px 12px; background: var(--panel); }
.toc a:hover, .toc a:focus-visible { border-color: var(--gold); color: #f4d48a; outline: none; }
ul, ol { margin: 0; padding-left: 1.25em; display: grid; gap: 8px; max-width: 72ch; }
.facts li::marker { color: var(--threat); }
.rules { counter-reset: r; list-style: none; padding: 0; gap: 10px; }
.rules li { counter-increment: r; position: relative; padding-left: 44px; }
.rules li::before { content: counter(r); position: absolute; left: 0; top: -2px; font: 28px/1 var(--display); color: var(--gold); }
.spec li::marker { color: var(--gold); font-family: var(--ui); }
.spec ul { margin-top: 6px; gap: 4px; }
.guard { border-left: 3px solid var(--safe); padding: 8px 0 8px 14px; color: #d6e9e2; max-width: 72ch; }
.tablewrap { overflow-x: auto; border: 1px solid var(--rule); border-radius: 8px; background: var(--panel); }
table { border-collapse: collapse; width: 100%; font: 15px/1.4 var(--text); font-variant-numeric: tabular-nums; }
table.wide { min-width: 900px; }
caption { text-align: left; padding: 12px 14px 4px; font: 600 13px/1.3 var(--ui); letter-spacing: .06em; color: var(--muted); }
th, td { text-align: left; vertical-align: top; padding: 10px 14px; border-top: 1px solid var(--rule); }
thead th { font: 600 13px/1.2 var(--ui); letter-spacing: .08em; text-transform: uppercase; color: var(--gold); border-top: 0; }
tbody th { font: 18px/1.15 var(--display); color: #f1e3c4; width: 150px; }
tr.hot td { color: #ffd6cf; } tr.hot td:first-child { box-shadow: inset 3px 0 0 var(--threat); }
.pair { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; }
.pair.three { grid-template-columns: repeat(3, minmax(0, 1fr)); }
@media (max-width: 760px) { .pair, .pair.three { grid-template-columns: 1fr; } }
figure { margin: 0; display: grid; gap: 10px; min-width: 0; }
figcaption { font-size: 15px; line-height: 1.45; color: #cfc2aa; }
.board svg { display: block; width: 100%; max-width: 440px; height: auto; margin: 0 auto; }
.shot img { display: block; width: 100%; height: auto; border-radius: 8px; border: 1px solid var(--rule); }
.legend { display: flex; flex-wrap: wrap; gap: 6px 16px; font: 14px/1.2 var(--ui); color: var(--muted); }
.legend span { display: inline-flex; align-items: center; gap: 6px; }
.legend i { width: 14px; height: 14px; border-radius: 50%; display: inline-block; }
.qs li { padding: 2px 0; }
/* board diagram */
.b-wall { fill: #0c0a08; stroke: #3a3027; } .b-floor { fill: #2a231d; }
.b-aura { fill: rgba(217,164,65,.20); stroke: rgba(217,164,65,.75); stroke-dasharray: 4 3; }
.b-threat { fill: rgba(217,83,74,.30); stroke: rgba(217,83,74,.8); }
.b-ice { fill: rgba(169,226,255,.18); stroke: var(--ice); stroke-dasharray: 5 3; }
.b-safe { fill: rgba(95,200,172,.22); stroke: var(--safe); }
.b-door { fill: var(--safe); } .b-entry { fill: #6b5c4a; }
.b-threshold { fill: rgba(95,200,172,.16); stroke: var(--safe); stroke-width: 1.5; }
.b-pillar { fill: #514538; stroke: #776650; } .b-crate { fill: #6b4a2a; stroke: #93683c; }
.b-path { fill: none; stroke-width: 4; stroke-linecap: round; stroke-linejoin: round; }
.b-path-short { stroke: #f0b85a; } .b-path-long { stroke: var(--safe); stroke-dasharray: 9 6; }
.b-path-blocked { stroke: var(--threat); stroke-dasharray: 3 6; }
.b-path-end { stroke: none; } .b-path-end.b-path-short { fill: #f0b85a; } .b-path-end.b-path-long { fill: var(--safe); }
.b-unit circle { stroke-width: 2.5; } .b-unit text { font: 600 15px var(--ui); fill: #fff; }
.b-hero circle { fill: #1f4f47; stroke: var(--safe); }
.b-enemy circle { fill: #4a1d1a; stroke: #b4473f; }
.b-hunter circle { fill: #4a1d1a; stroke: #ff8a5c; stroke-dasharray: 5 3; }
.b-gate circle { fill: #3a2c1a; stroke: #f0b85a; stroke-width: 4; }
.b-leader circle { fill: #4a3410; stroke: var(--gold); stroke-width: 4; }
.b-crown { fill: var(--gold); }
.b-note { font: 600 12px var(--ui); fill: #ffd6cf; }
.b-light { fill: rgba(255,214,120,.16); stroke: rgba(255,214,120,.55); }
.b-seal { fill: #8a63c9; } .b-threshold-seal { fill: rgba(138,99,201,.18); stroke: #8a63c9; stroke-width: 1.5; stroke-dasharray: 4 3; }
.b-seal-count { font: 600 22px var(--ui); fill: #c9b2f0; }
.b-binder circle { fill: #2a1d3d; stroke: #a07ee0; }
.b-hoarder circle { fill: #4a3410; stroke: #ff9f43; stroke-width: 4; stroke-dasharray: 6 3; }
.b-hidden circle { fill: rgba(40,34,48,.6); stroke: #6b6276; stroke-dasharray: 3 3; } .b-hidden text { fill: #8f879a; }
.b-brazier-iron { fill: #3b3128; stroke: #c49a5a; stroke-width: 3; stroke-linejoin: round; }
.b-brazier text { font: 700 22px var(--ui); fill: #ffcf6b; letter-spacing: 1px; }
.b-ember { fill: #ff9f43; }
.b-path-flee { stroke: #ff9f43; stroke-dasharray: 8 5; } .b-flee-head { fill: #ff9f43; }
.legend i.k-hero { background:#1f4f47; border:2px solid #5fc8ac } .legend i.k-enemy { background:#4a1d1a; border:2px solid #b4473f }
.legend i.k-leader { background:#4a3410; border:3px solid #d9a441 } .legend i.k-gate { background:#3a2c1a; border:3px solid #f0b85a }
.legend i.k-hunter { background:#4a1d1a; border:2px dashed #ff8a5c } .legend i.k-binder { background:#2a1d3d; border:2px solid #a07ee0 }
.legend i.k-hoarder { background:#4a3410; border:2px dashed #ff9f43 } .legend i.k-hidden { background:rgba(40,34,48,.6); border:2px dashed #6b6276 }
.legend i.k-brazier { border-radius:2px; background:#3b3128; border:2px solid #c49a5a } .legend i.k-light { border-radius:2px; background:rgba(255,214,120,.3) }
.legend i.k-aura { border-radius:2px; background:rgba(217,164,65,.35) } .legend i.k-threat { border-radius:2px; background:rgba(217,83,74,.45) }
.legend i.k-pillar { border-radius:2px; background:#514538 } .legend i.k-door { border-radius:2px; background:#5fc8ac }
.legend i.k-seal { border-radius:2px; background:#8a63c9 } .legend i.k-embers { background:#ff9f43; width:8px; height:8px }
.legend i.k-flee { border-radius:0; height:0; border-top:3px dashed #ff9f43 }
.board-single { max-width: 440px; }
a { color: #f4d48a; }
@media (prefers-reduced-motion: reduce) { * { scroll-behavior: auto !important; } }
"""
body = open(P + "/body.html").read()
boards = open(P + "/boards.json").read()
js = open(P + "/board.js").read()
page = f"""<meta charset="utf-8">
<title>Umbra Encounter Redesign</title>
<meta name="claude:viewport-fit-sides" content="cover">
<style>{fonts}{css}</style>
<main>{body}</main>
<script>{js}
const BOARDS = {boards};
document.querySelectorAll("[data-board]").forEach((h) => drawBoard(h, BOARDS[h.dataset.board]));
</script>"""
open(P + "/encounter_redesign.html", "w").write(page)
print(len(page))
