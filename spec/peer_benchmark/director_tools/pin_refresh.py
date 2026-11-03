#!/usr/bin/env python3
"""Refresh one owner-approved unit's content pins after its native proof. usage: pin_refresh.py <path substring>. Run in the worktree."""
import json, subprocess, sys
p = "tests/approved_asset_pins.json"
s = open(p).read(); key = sys.argv[1]; n = 0
def walk(o):
    global s, n
    if isinstance(o, dict):
        for k, v in o.items():
            if isinstance(v, str) and key in k and len(v) == 40:
                cur = subprocess.run(["git", "hash-object", k], capture_output=True, text=True).stdout.strip()
                if cur and cur != v: s = s.replace(f'"{k}": "{v}"', f'"{k}": "{cur}"'); n += 1
            else: walk(v)
walk(json.loads(s))
open(p, "w").write(s); print("refreshed", n)
