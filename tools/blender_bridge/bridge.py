"""Director-run Blender bridge (owner-approved 2026-10-16).

Codex's sandbox blocks Metal, so Blender crashes inside it. This bridge runs OUTSIDE the sandbox only while maquette
units are active (a tracked director job, never started by Codex). It executes Blender headless for job files that
Codex drops into QUEUE, one at a time, with a timeout, and logs everything.

Job file QUEUE/<id>.json: {"script": "<abs .py>", "args": ["..."], "timeout_s": 900}
  - script must live under an allowed maquette root (see ALLOWED_SCRIPT_ROOTS) and end in .py
  - every arg that looks like a path must be under an allowed root or /private/tmp/labyrinth_codex
Result: DONE/<id>.json {"exit": int, "seconds": float, "log": "<path>", "command": [...]} and DONE/<id>.log
Stop: touch STOP, or 3 hours idle.
"""
import json, os, subprocess, sys, time
from pathlib import Path

ROOT = Path("/private/tmp/labyrinth_codex/blender_bridge")
QUEUE, DONE, STOP = ROOT / "queue", ROOT / "done", ROOT / "STOP"
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
WORKTREES = Path("/Users/borgerding/workspace/Labyrinth.worktrees")
ALLOWED_SCRIPT_ROOTS = [WORKTREES / name / "spec/art_identity/maquettes" for name in sys.argv[1:]] or []
ALLOWED_ARG_ROOTS = [Path("/private/tmp/labyrinth_codex")] + [WORKTREES / name for name in sys.argv[1:]]
IDLE_LIMIT_S, MAX_TIMEOUT_S = 3 * 3600, 1800


def under(path, roots):
    p = Path(path).resolve()
    return any(p == r.resolve() or r.resolve() in p.parents for r in roots)


def log(msg):
    with open(ROOT / "bridge.log", "a") as f:
        f.write(time.strftime("%H:%M:%S ") + msg + "\n")
    print(msg, flush=True)


def run(job_path):
    jid = job_path.stem
    try:
        job = json.loads(job_path.read_text())
        script, args = job["script"], [str(a) for a in job.get("args", [])]
        timeout = min(float(job.get("timeout_s", 900)), MAX_TIMEOUT_S)
        if not script.endswith(".py") or not under(script, ALLOWED_SCRIPT_ROOTS):
            raise ValueError("script outside allowed maquette roots: " + script)
        for a in args:
            if a.startswith("/") and not under(a, ALLOWED_ARG_ROOTS):
                raise ValueError("path arg outside allowed roots: " + a)
    except Exception as e:  # malformed or refused
        (DONE / f"{jid}.json").write_text(json.dumps({"exit": -2, "refused": str(e)}))
        job_path.unlink(missing_ok=True); log(f"REFUSED {jid}: {e}"); return
    cmd = [BLENDER, "-b", "--factory-startup", "--disable-autoexec", "--python-exit-code", "2", "-P", script, "--", *args]
    out = DONE / f"{jid}.log"; t0 = time.time(); log(f"RUN {jid}: {' '.join(cmd[6:])}")
    with open(out, "w") as f:
        try:
            code = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, timeout=timeout, cwd=str(Path(script).parent)).returncode
        except subprocess.TimeoutExpired:
            code = -1
    (DONE / f"{jid}.json").write_text(json.dumps({"exit": code, "seconds": round(time.time() - t0, 1), "log": str(out), "command": cmd}))
    job_path.unlink(missing_ok=True); log(f"DONE {jid}: exit {code} in {time.time() - t0:.1f}s")


def main():
    for d in (QUEUE, DONE): d.mkdir(parents=True, exist_ok=True)
    STOP.unlink(missing_ok=True); idle = time.time()
    log("BRIDGE START roots=" + ",".join(str(r) for r in ALLOWED_SCRIPT_ROOTS))
    while not STOP.exists():
        jobs = sorted(QUEUE.glob("*.json"), key=lambda p: p.stat().st_mtime)
        if jobs:
            run(jobs[0]); idle = time.time()
        elif time.time() - idle > IDLE_LIMIT_S:
            log("BRIDGE IDLE STOP"); break
        else:
            time.sleep(2)
    log("BRIDGE STOP")


if __name__ == "__main__":
    main()
