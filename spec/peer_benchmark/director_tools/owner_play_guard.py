#!/usr/bin/env python3
"""While the owner's game is open, demote background work to macOS background QoS.

Director tool (2026-11-06). The owner plays the Steam build and demo on the dev Mac;
three times (10-22, 10-30, 11-06) concurrent Codex runs and headless suites made
their session hitch. This loop checks `owner_game_open.sh` every 30 s. While it
reports the game open, every Codex process and its descendants, plus every
headless Godot, gets `taskpolicy -b` (efficiency cores, low I/O priority). When
the game closes, those processes get `taskpolicy -B` again. Nothing is stopped
or killed; windowed Godot (the owner's fixture launches, director captures) is
never touched. usage: owner_play_guard.py [--once]
"""
import subprocess, sys, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
OPEN = HERE / "owner_game_open.sh"


def _ps(field):
    # One field per call: ps truncates comm to 16 characters when other columns follow it.
    out = subprocess.run(["ps", "-axo", "pid=,ppid=," + field + "="], capture_output=True, text=True).stdout
    rows = {}
    for line in out.splitlines():
        parts = line.split(None, 2)
        if len(parts) == 3:
            rows[int(parts[0])] = (int(parts[1]), parts[2])
    return rows


def processes():
    comms, commands = _ps("comm"), _ps("command")
    return {pid: (ppid, comm, commands.get(pid, (ppid, ""))[1]) for pid, (ppid, comm) in comms.items()}


def background_targets(rows):
    roots = {pid for pid, (_, comm, cmd) in rows.items() if comm.endswith("/codex") and " exec " in f" {cmd} "}
    children = {}
    for pid, (ppid, _, _) in rows.items():
        children.setdefault(ppid, []).append(pid)
    targets, stack = set(), list(roots)
    while stack:
        pid = stack.pop()
        if pid in targets:
            continue
        targets.add(pid)
        stack.extend(children.get(pid, []))
    for pid, (_, comm, cmd) in rows.items():
        if "godot" in comm.lower() and "--headless" in cmd:
            targets.add(pid)
    # Never the owner's game or a windowed Godot.
    return {pid for pid in targets if "Escape the Umbra" not in rows[pid][1]
            and not ("godot" in rows[pid][1].lower() and "--headless" not in rows[pid][2])}


def set_policy(pids, flag):
    done = 0
    for pid in pids:
        if subprocess.run(["taskpolicy", flag, "-p", str(pid)], capture_output=True).returncode == 0:
            done += 1
    return done


def main():
    demoted = set()
    while True:
        playing = subprocess.run(["sh", str(OPEN)], capture_output=True).returncode == 0
        rows = processes()
        if playing:
            fresh = background_targets(rows) - demoted
            if fresh:
                n = set_policy(fresh, "-b")
                demoted |= fresh
                print(time.strftime("%H:%M"), f"OWNER PLAYING: {n} processes to background QoS", flush=True)
        elif demoted:
            alive = {pid for pid in demoted if pid in rows}
            n = set_policy(alive, "-B")
            print(time.strftime("%H:%M"), f"OWNER DONE: {n} processes restored", flush=True)
            demoted.clear()
        if "--once" in sys.argv:
            return 0
        time.sleep(30)


if __name__ == "__main__":
    sys.exit(main())
