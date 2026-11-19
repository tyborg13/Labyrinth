#!/usr/bin/env python3
"""Run one QA-113 targeted lane through the isolated runner."""

import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def run(probe, destination, *, args=(), env=None, project=ROOT, timeout=300, engine_args=()):
    destination.mkdir(parents=True, exist_ok=True)
    log = destination / "godot.log"
    engine = [sys.executable, "tools/godot_task_runner.py", "--task-id", "qa-113", "--timeout", str(timeout),
              "--stream", "--", "godot", "--headless", "--path", str(project), *engine_args,
              "--script", probe, "--", *args]
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(engine, cwd=ROOT, env={**os.environ, **(env or {})},
                                stdout=stream, stderr=subprocess.STDOUT, check=False)
    print(f"QA113 PROBE exit={result.returncode} {log}", flush=True)
    return result.returncode


def run_text(out):
    scenes = out / "text-scenes"
    status = run("tests/text_audit_capture_probe.gd", scenes, args=("--validate-only",))
    status |= run("tools/qa112/collect.gd", out / "text-collect")
    folders = [Path(line) for line in (scenes / "godot.log").read_text().splitlines()
               if line.endswith("/1920x1080")]
    if not folders or not (folders[-1] / "observations.json").exists():
        print("QA113 TEXT: scene observation file missing", flush=True)
        return 1
    status |= subprocess.run(
        [sys.executable, "-B", "tools/qa112/audit.py", "--runtime-log", str(out / "text-collect/godot.log"),
         "--observations", str(folders[-1] / "observations.json"), "--output-dir", str(out / "text")],
        cwd=ROOT, check=False).returncode
    return status


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "tools/qa113/out/targeted")
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("probes", nargs="+", choices=("text", "rules", "hands", "loops", "sounds", "focus"))
    args = parser.parse_args()
    out = args.out.resolve()
    status = 0
    for probe in args.probes:
        if probe == "text":
            status |= run_text(out)
        elif probe in ("rules", "hands"):
            for profile in ("desktop", "deck"):
                destination = out / f"{probe}-{profile}"
                environment = {"QA107_PROFILE": profile, "QA107_OUTPUT": str(destination)}
                status |= run(f"tools/qa113/{probe}.gd", destination, env=environment, project=args.project)
                if probe == "rules" and profile == "deck":
                    destination = out / "undo-deck"
                    environment |= {"QA107_OUTPUT": str(destination), "UI33_CASE": "reach_exit/undo"}
                    status |= run("tools/qa113/rules.gd", destination, env=environment, project=args.project)
        else:
            destination = out / probe
            script = f"tools/qa113/{probe}.gd"
            flags = [f"--out={destination}"]
            environment = {"LABYRINTH_CEL_LOOK": "off"}
            if probe == "focus":
                script = "tools/qa110/interruptions.gd"
                flags.extend(("--route=focus_loss_drag", "--route=application_pause_drag"))
                witness = out / "pass-with-loop"
                status |= run(script, witness, args=(f"--out={witness}", "--case=tharokh-mouse-pass_with_loop"),
                              env=environment, project=args.project)
            if probe == "loops":
                environment["TOOLTIP_LOOP_CAPTURE_OUT"] = str(destination)
                flags.clear()
            diagnostic_args = ("--verbose",) if probe == "sounds" else ()
            status |= run(script, destination, args=flags, env=environment, project=args.project, timeout=420,
                          engine_args=diagnostic_args)
    return status


if __name__ == "__main__":
    raise SystemExit(main())
