#!/usr/bin/env python3
"""Compile protected director channels to rigid 2D tracks; never edit the input."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

import numpy as np

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT / "tools"))
from cutout_pipeline.cases import CutoutError, read_json
from maquette_cutout import projected, shape_center

CLIPS = ["idle", "move", "dive", "talon_rake", "hover", "hit", "death"]
FLIGHT_SECONDS = 0.35  # Existing DiveView clock, checked by motion_metadata.gd.
RECOVERY_FRAMES = 6
RECOVERY_FRAME_SECONDS = 1 / 30  # Director round 1.
CONTACT = FLIGHT_SECONDS / (FLIGHT_SECONDS + RECOVERY_FRAMES * RECOVERY_FRAME_SECONDS)


def source_path(case: Path) -> Path:
    staged = PROJECT / "spec/peer_benchmark/staged/rr-03/motion_tracks.json"
    delivered = case.parent / "motion_tracks_director.json"
    if staged.is_file() and delivered.is_file() and staged.read_bytes() != delivered.read_bytes():
        raise CutoutError("Two different director motion files; select the intended source before building")
    source = staged if staged.is_file() else delivered
    if not source.is_file():
        raise CutoutError("Missing protected director motion data")
    return source


def projection(spec: dict, view: str) -> dict:
    zero = np.array(projected(spec, [0, 0, 0], view))
    def vector(point): return np.array(projected(spec, point, view)) - zero
    def sign_toward(origin, toward):
        cross = origin[0] * toward[1] - origin[1] * toward[0]
        if abs(cross) < 1e-8: raise CutoutError("Ambiguous projected motion axis: " + view)
        return float(np.sign(cross))
    forward, up, far = vector([1, 0, 0]), vector([0, 0, 1]), vector([0, -1, 0])
    result = {"forward": (forward / np.linalg.norm(forward)).tolist(),
              "pitch_sign": sign_toward(forward, -up), "roll_sign": sign_toward(up, far),
              "tail_sign": sign_toward(-forward, up)}
    # Native hip-to-ankle displacement from the supplied shrike proxy.
    foot = np.array(spec["joints"]["root"]) - spec["joints"]["legs"]
    result["legs_sign"] = sign_toward(vector(foot), forward)
    for wing in ["wing_near", "wing_far"]:
        centres = [shape_center(s, spec["joints"]) for s in spec["shapes"] if s["part"] == wing]
        ray = np.mean(centres, axis=0) - spec["joints"][wing]
        result[wing + "_sign"] = sign_toward(vector(ray), up)
    return result


def key(at, value, interpolation="smoothstep"):
    return {"at": float(at), "value": float(value), "interpolation": interpolation}


def rows_tracks(rows, mapping):
    """Missing pose fields are neutral; scales retain their neutral value one."""
    result = {}
    for field in sorted(set().union(*(set(row) for row in rows)) - {"t", "frame", "interp"}):
        if field not in mapping: raise CutoutError("Unknown director pose field: " + field)
        for channel in mapping[field]:
            neutral = 1.0 if channel in ["body.squash", "wings.span"] else 0.0
            result[channel] = [key(row["t"], row.get(field, neutral), row.get("interp", "smoothstep")) for row in rows]
    return result


def semantic_tracks(data: dict, interpretation: dict) -> tuple[dict, dict]:
    result = {}
    todos = {}
    idle = {}
    for channel, keys in data["idle"]["keys"].items():
        if channel == "head": continue
        idle[channel] = [key(k["t"], k["v"]) for k in keys]
    head = data["idle"]["keys"]["head"]
    if head["interp"] != "step2": raise CutoutError("Unrecognized director head interpolation")
    rate = interpretation.get("head_snap_fps", 0)
    placement = interpretation.get("head_snap_placement", "")
    if rate <= 0 or placement not in ["start", "finish"]:
        todos["TODO_DESIGN_head_snap_clock"] = "Director must specify step2 frame rate and whether snaps start or finish at the authored key times."
    else:
        span = 2 / rate / data["idle"]["seconds"]
        for field in ["tilt_deg", "turn_px", "lift_px"]:
            poses = head["keys"]
            values = [key(poses[0]["t"], poses[0].get(field, 0), "linear")]
            for previous, current in zip(poses, poses[1:]):
                if placement == "finish":
                    values += [key(current["t"] - span, previous.get(field, 0), "hold"),
                               key(current["t"], current.get(field, 0), "linear")]
                else:
                    # The pose named at t starts its two-frame transition at t.
                    # The final t=1 key is the looping first pose.
                    if current["t"] < 1:
                        values += [key(current["t"], previous.get(field, 0), "hold"),
                                   key(current["t"] + span, current.get(field, 0), "linear")]
            if placement == "start":
                # Loop return starts at phase zero, with the last held pose.
                values[0] = key(0, poses[-2].get(field, 0), "linear")
                values.insert(1, key(span, poses[0].get(field, 0), "linear"))
                values.append(key(1, poses[-2].get(field, 0), "hold"))
            idle["head." + field] = values
    result["idle"] = idle
    mapping = {"lift_px": ["body.lift_px"], "lift": ["body.lift_px"],
               "wings_raise": ["wing_near.raise_deg", "wing_far.raise_deg"],
               "tail": ["tail.lift_deg"], "legs": ["legs.reach_deg"],
               "pitch": ["body.pitch_deg"], "roll": ["body.roll_deg"],
               "squash": ["body.squash"], "span": ["wings.span"],
               "forward": ["body.forward_px"], "head_tilt": ["head.tilt_deg"],
               "recoil_px": ["recoil"]}
    for clip in ["move", "talon_rake", "hover", "hit", "death"]:
        result[clip] = rows_tracks(data[clip]["keys"], mapping)
    # The impact boundary starts recovery frame 1. Flight's terminal hold
    # extends to that boundary, then the director's contact flare takes over.
    # Frames 3 and 6 occur two and five 1/30s ticks later; frame 6 is held.
    duration = FLIGHT_SECONDS + RECOVERY_FRAMES * RECOVERY_FRAME_SECONDS
    flight = [dict(row, t=row["t"] * CONTACT) for row in data["dive"]["flight"][:-1]]
    recovery = [dict(row, t=(FLIGHT_SECONDS + (row["frame"] - 1) * RECOVERY_FRAME_SECONDS) / duration)
                for row in data["dive"]["recovery_frames"]]
    recovery[0]["interp"] = "hold"
    result["dive"] = rows_tracks(flight + recovery + [dict(recovery[-1], t=1)], mapping)
    return result, todos


def view_tracks(semantic: dict, axes: dict) -> dict:
    result = {}
    for clip, channels in semantic.items():
        tracks = []
        def add(source, target, multiplier=1.0):
            if source in channels:
                tracks.append({"channel": target, "keys": [dict(k, value=k["value"] * multiplier) for k in channels[source]]})
        add("body.lift_px", "body_y", -1)
        add("body.forward_px", "body_forward")
        add("body.pitch_deg", "body_pitch", axes["pitch_sign"])
        add("body.roll_deg", "body_roll", axes["roll_sign"])
        add("body.squash", "body_scale_y")
        add("head.tilt_deg", "head_angle", axes["pitch_sign"])
        add("head.turn_px", "head_forward")
        add("head.lift_px", "head_y", -1)
        add("tail.lift_deg", "tail_angle", axes["tail_sign"])
        add("legs.reach_deg", "legs_angle", axes["legs_sign"])
        add("recoil", "recoil")
        for wing in ["wing_near", "wing_far"]:
            add(wing + ".raise_deg", wing + "_angle", axes[wing + "_sign"])
            add("wings.span", wing + "_span")
        result[clip] = tracks
    return result


def compile_data(case: Path, output: Path, interpretation: dict, proof_scale: float = 1.0) -> dict:
    source = source_path(case)
    data = read_json(source)
    spec = read_json(case.parent / "maquette/spec.json")
    spec["view_transforms"] = read_json(case.parent / "maquette/view_transforms.json")
    semantic, todos = semantic_tracks(data, interpretation)
    axes = {v: projection(spec, v) for v in ["front", "rear"]}
    tracks = {v: view_tracks(semantic, axes[v]) for v in axes}
    # Keep the brief's numeric constants, without making this generated module
    # depend on experiments or a JSON loader in an exported game.
    prefix = output.read_text().split("const TODO_DESIGN_DIVE_RECOVERY_FRAME_SECONDS")[0].split("# Generated director mapping")[0]
    prefix = prefix.replace("Pixels are native 255px source pixels; positive Y points down.",
                            "Translations are board pixels, converted by the actual draw scale; positive Y points down.")
    if "const IDLE_SECONDS" not in prefix: raise CutoutError("Missing numeric brief constants")
    content = prefix + "# Generated director mapping; edit the protected input only through its owner.\n"
    constants = {"HEAD_SNAP_FPS": interpretation.get("head_snap_fps", 0),
                 "HEAD_SNAP_PLACEMENT": interpretation.get("head_snap_placement", ""),
                 "HEAD_SNAP_SECONDS": 2 / interpretation["head_snap_fps"] if interpretation.get("head_snap_fps", 0) > 0 else -1,
                 "DIVE_RECOVERY_FRAME_SECONDS": RECOVERY_FRAME_SECONDS,
                 "CONTACT_PHASES": {"dive": CONTACT, "talon_rake": data["talon_rake"]["contact_phase"]},
                 "DIRECTOR_SHA256": hashlib.sha256(source.read_bytes()).hexdigest(),
                 "PROOF_PIXEL_SCALE": proof_scale, "PROJECTION": axes,
                 "TRACKS": {clip: [] for clip in CLIPS}, "VIEW_TRACKS": tracks, "TODO_DESIGN": todos}
    for name, value in constants.items():
        content += "const " + name + " = " + gd_literal(value) + "\n"
    output.write_text(content)
    (case / "director_motion.json").write_bytes(source.read_bytes())
    return {"source": str(source.relative_to(PROJECT)), "sha256": constants["DIRECTOR_SHA256"],
            "projection": axes, "interpretation": interpretation, "proof_pixel_scale": proof_scale,
            "design_complete": not todos}


def gd_literal(value, depth=0):
    if not isinstance(value, dict): return json.dumps(value, separators=(", ", ": "))
    return "{\n" + "".join("\t" * (depth + 1) + json.dumps(k) + ": " + gd_literal(v, depth + 1) + ",\n"
                            for k, v in value.items()) + "\t" * depth + "}"
