#!/usr/bin/env python3
"""Per-segment clip/facing summary of a reel_frames.json log."""
import json, sys, itertools
d = json.load(open(sys.argv[1]))
rows = d["rows"]
for seg, group in itertools.groupby(rows, key=lambda r: r["seg"]):
    group = list(group)
    runs = []
    for key, g in itertools.groupby(group, key=lambda r: (r.get("clip"), r.get("facing"), r.get("mirrored"))):
        g = list(g)
        runs.append("%s/%s%s x%d [%s..%s] tiles %s->%s" % (key[0], key[1], "/M" if key[2] else "", len(g), g[0].get("phase"), g[-1].get("phase"), g[0]["tile"], g[-1]["tile"]))
    print(seg, "frames", len(group), "hero", group[0]["hero"], "->", group[-1]["hero"])
    for r in runs: print("   ", r)
