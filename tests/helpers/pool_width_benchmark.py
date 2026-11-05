#!/usr/bin/env python3
"""Interleaved full-suite timing with macOS descendant memory accounting.

RSS counts shared pages conservatively. Physical footprint additionally covers
compressed/private memory. The guard uses the larger aggregate and interrupts
only this invocation's task runner before the director's 14 GB suite budget.
"""
from __future__ import annotations

import argparse
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import statistics
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from godot_task_runner import terminate_process_tree
from program_suite_runner import selected_suites

TRIAL_WIDTHS = (5, 8, 11, 8, 11, 5)
TASK_ID = "test-06"
FULL_TIMEOUT_SECONDS = 3000
SAMPLE_SECONDS = 0.1
ABORT_MEMORY_BYTES = 13_000_000_000
MEMORY_BOUND_BYTES = 14_000_000_000
STOP_GRACE_SECONDS = 10
INITIAL_PID_CAPACITY = 256


class ProcessUsage(ctypes.Structure):
    # SDK sys/resource.h, rusage_info_v0; sizes are bytes, start is an identity.
    _fields_ = [("uuid", ctypes.c_uint8 * 16)] + [
        (name, ctypes.c_uint64) for name in (
            "user_time", "system_time", "idle_wakeups", "interrupt_wakeups",
            "pageins", "wired", "resident", "footprint", "start", "exit")]


class MacSuiteMemory:
    def __init__(self):
        if sys.platform != "darwin":
            raise RuntimeError("This benchmark's memory accounting requires macOS libproc")
        self.library = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
        self.library.proc_listchildpids.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_int]
        self.library.proc_listchildpids.restype = ctypes.c_int
        self.library.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
        self.library.proc_pid_rusage.restype = ctypes.c_int
        self.owned: dict[int, int] = {}

    def children(self, pid: int) -> list[int]:
        capacity = INITIAL_PID_CAPACITY
        while True:
            buffer = (ctypes.c_int * capacity)()
            count = self.library.proc_listchildpids(pid, buffer, ctypes.sizeof(buffer))
            if count < 0:
                raise OSError(ctypes.get_errno(), "Cannot enumerate suite descendants", pid)
            if count < capacity:
                # libproc returns a PID count here, unlike proc_listpids' bytes.
                return [value for value in buffer[:count] if value > 0]
            capacity *= 2

    def usage(self, pid: int) -> ProcessUsage | None:
        result = ProcessUsage()
        ctypes.set_errno(0)
        if self.library.proc_pid_rusage(pid, 0, ctypes.byref(result)) == 0:
            return result
        error = ctypes.get_errno()
        if error in (errno.ESRCH, errno.ENOENT):
            return None
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return None
        raise OSError(error, "Cannot account for live suite process", pid)

    def sample(self, root: int, *, discover: bool = True) -> dict:
        pending = [root] if discover else []
        visited = set()
        while pending:
            pid = pending.pop()
            if pid in visited:
                continue
            visited.add(pid)
            usage = self.usage(pid)
            if usage is None:
                continue
            prior = self.owned.get(pid)
            if prior is not None and prior != usage.start:
                continue  # A reused PID is not part of this invocation.
            self.owned[pid] = usage.start
            pending.extend(self.children(pid))
        rss = footprint = live = 0
        for pid, identity in list(self.owned.items()):
            usage = self.usage(pid)
            if usage is None or usage.start != identity:
                del self.owned[pid]
                continue
            live += 1
            rss += usage.resident
            footprint += usage.footprint
        return {"rss_bytes": rss, "footprint_bytes": footprint, "processes": live}


def run_trial(output: Path, width: int | None, label: str) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    log_path = output / (label + ".log")
    result_path = output / (label + ".json")
    if result_path.exists():
        raise RuntimeError("Refusing to overwrite completed trial: " + str(result_path))
    memory = MacSuiteMemory()
    # Fail before starting an engine if this environment cannot supply memory.
    memory.sample(os.getpid())
    memory.owned.clear()
    environment = os.environ.copy()
    environment.pop("LABYRINTH_TEST_POOL", None)
    if width is not None:
        environment["LABYRINTH_TEST_POOL"] = str(width)
    command = ["python3", "tools/godot_task_runner.py", "--task-id", TASK_ID,
               "--timeout", str(FULL_TIMEOUT_SECONDS), "--stream", "--", "godot",
               "--headless", "--script", "tests/run_tests.gd"]
    stop = threading.Event()
    samples = []
    guard = {"reason": "", "signalled_at": None}
    started = time.monotonic()
    # Retain measurements even if the supervising app/session is interrupted
    # before the final JSON summary. Qualification still needs a complete run.
    sample_journal = output / (label + "-memory.jsonl")
    with log_path.open("w") as log, sample_journal.open("w") as journal:
        process = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)

        def monitor() -> None:
            while not stop.is_set():
                try:
                    sample = memory.sample(process.pid)
                    sample.update(seconds=time.monotonic() - started, load=os.getloadavg())
                    samples.append(sample)
                    journal.write(json.dumps(sample) + "\n")
                    journal.flush()
                    if max(sample["rss_bytes"], sample["footprint_bytes"]) >= ABORT_MEMORY_BYTES:
                        guard["reason"] = "suite reached the 13 GB memory guard"
                except OSError as error:
                    guard["reason"] = "memory accounting failed: " + str(error)
                if guard["reason"] and process.poll() is None:
                    if guard["signalled_at"] is None:
                        guard["signalled_at"] = time.monotonic()
                        process.send_signal(signal.SIGINT)
                    elif time.monotonic() - guard["signalled_at"] > STOP_GRACE_SECONDS:
                        terminate_process_tree(process)
                stop.wait(SAMPLE_SECONDS)

        thread = threading.Thread(target=monitor)
        thread.start()
        try:
            returncode = process.wait()
            wall = time.monotonic() - started
        finally:
            if process.poll() is None:
                terminate_process_tree(process)
            stop.set()
            thread.join()
    samples_path = output / (label + "-memory.json")
    samples_path.write_text(json.dumps(samples) + "\n")
    text = log_path.read_text()
    match = re.search(r"^PROGRAM SUITE REPORT: (.+)$", text, re.M)
    report = json.loads(Path(match[1]).read_text()) if match and Path(match[1]).exists() else {}
    rows = [row for row in report.get("results", []) if row is not None]
    suite = re.search(r"FULL SUITE RUNTIME: ([\d.]+)", text)
    peak_rss = max((row["rss_bytes"] for row in samples), default=0)
    peak_footprint = max((row["footprint_bytes"] for row in samples), default=0)
    result = {
        "label": label, "requested_width": width, "actual_width": report.get("jobs"),
        "command": command, "wall_seconds": wall, "suite_seconds": float(suite[1]) if suite else None,
        "returncode": returncode, "complete": report.get("complete", False),
        "programs": len(rows), "failed_programs": [row["name"] for row in rows if row["returncode"]],
        "retries": report.get("retries", []), "guard_reason": guard["reason"],
        "peak_rss_bytes": peak_rss, "peak_footprint_bytes": peak_footprint,
        "load_min": min(row["load"][0] for row in samples),
        "load_max": max(row["load"][0] for row in samples),
        "load_mean": statistics.mean(row["load"][0] for row in samples),
        "log": str(log_path), "memory_samples": str(samples_path),
        "scheduler_report": str(Path(match[1])) if match else None,
        "runner_sha256": hashlib.sha256((ROOT / "tools/program_suite_runner.py").read_bytes()).hexdigest(),
        "registry_sha256": hashlib.sha256((ROOT / "tests/headless_test_programs.json").read_bytes()).hexdigest(),
    }
    expected_programs = set(selected_suites())
    result["passed"] = (returncode == 0 and bool(result["complete"]) and not result["failed_programs"]
                        and len(rows) == len(expected_programs)
                        and {row["name"] for row in rows} == expected_programs
                        and not guard["reason"] and max(peak_rss, peak_footprint) < MEMORY_BOUND_BYTES)
    if width is not None and result["actual_width"] is not None:
        assert result["actual_width"] == width, result
    result_path.write_text(json.dumps(result, indent=2) + "\n")
    print("%s: %s wall=%.3fs suite=%s peak RSS=%.3fGB footprint=%.3fGB load=%.2f..%.2f %s" % (
        label, "PASS" if result["passed"] else "FAIL", wall, result["suite_seconds"],
        peak_rss / 1e9, peak_footprint / 1e9, result["load_min"], result["load_max"], guard["reason"]), flush=True)
    return result


def summarize(output: Path) -> dict:
    rows = [json.loads(path.read_text()) for path in sorted(output.glob("trial-*.json"))
            if not path.name.endswith("-memory.json")]
    groups = {}
    confirmation_paths = set(output.glob("confirm-default-*.json"))
    if (output / "chosen-default.json").exists():
        confirmation_paths.add(output / "chosen-default.json")
    confirmations = [json.loads(path.read_text()) for path in sorted(confirmation_paths)
                     if not path.name.endswith("-memory.json")]
    for width in sorted(set(TRIAL_WIDTHS)):
        matches = [row for row in rows if row["requested_width"] == width]
        confirmed = [row for row in confirmations if row["actual_width"] == width]
        groups[str(width)] = {
            "runs": matches, "confirmations": confirmed,
            "eligible": len(matches) >= 2 and all(row["passed"] for row in matches + confirmed),
            "median_wall_seconds": statistics.median(row["wall_seconds"] for row in matches) if matches else None,
            "median_suite_seconds": statistics.median(row["suite_seconds"] for row in matches)
                if matches and all(row["suite_seconds"] is not None for row in matches) else None,
            "peak_rss_bytes": max((row["peak_rss_bytes"] for row in matches + confirmed), default=0),
            "peak_footprint_bytes": max((row["peak_footprint_bytes"] for row in matches + confirmed), default=0),
        }
    eligible = [int(width) for width, group in groups.items() if group["eligible"]]
    chosen = min(eligible, key=lambda width: groups[str(width)]["median_wall_seconds"]) if eligible else None
    result = {"order": TRIAL_WIDTHS, "groups": groups, "chosen_width": chosen}
    (output / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    print("POOL BENCHMARK SUMMARY: chosen=" + str(chosen), flush=True)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--measure", action="store_true")
    parser.add_argument("--summarize", action="store_true", help="Recompute selection including default confirmations; no engines run.")
    parser.add_argument("--confirm-default", action="store_true")
    args = parser.parse_args()
    output = args.output_dir.resolve()
    if args.measure:
        for index, width in enumerate(TRIAL_WIDTHS, 1):
            label = "trial-%02d-pool-%d" % (index, width)
            if (output / (label + ".json")).exists():
                print("Retaining completed " + label, flush=True)
                continue
            run_trial(output, width, label)
        summarize(output)
    if args.confirm_default:
        if not run_trial(output, None, "chosen-default")["passed"]:
            raise SystemExit(1)
    if args.summarize:
        summarize(output)


if __name__ == "__main__":
    main()
