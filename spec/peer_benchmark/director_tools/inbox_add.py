#!/usr/bin/env python3
"""Add items to the inbox's state from a just-read live page. usage: inbox_add.py <live index.html> <scratch dir> <items.json> [done.json]
items.json: a list of inbox items. done.json: {id: reply}, for items whose thread was already answered. Writes <scratch>/inbox.html."""
import json, subprocess, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent; TOOL = HERE.parent / "review_inbox"
live, scratch, items = sys.argv[1:4]; done = json.load(open(sys.argv[4])) if len(sys.argv) > 4 else {}
state_path = Path(scratch) / "inbox_state.json"
subprocess.run(["python3", str(TOOL / "inbox.py"), "extract", live, str(state_path)], check=True)
state = json.load(open(state_path))
print("answered:", [i["id"] for i in state["items"] if i.get("status") == "answered"])
for item in state["items"]:
    if item["id"] in done and item.get("status") != "done":
        item["status"] = "done"; item.setdefault("reply", done[item["id"]])
known = {i["id"] for i in state["items"]}
for item in json.load(open(items)):
    assert item["id"] not in known, item["id"]
    state["items"].append(item)
json.dump(state, open(state_path, "w"))
subprocess.run(["python3", str(TOOL / "inbox.py"), "render", str(state_path), str(Path(scratch) / "inbox.html"), str(TOOL / "reset.css")], check=True)
print(len(state["items"]))
