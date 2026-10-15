#!/usr/bin/env python3
"""Measure sampled hidden exposure or collect eight REAL renderer frames/clip."""
import argparse
from pathlib import Path
import sys

import numpy as np
from PIL import Image

# All cutout commands run from the project root; the case itself may be in /tmp.
sys.path.insert(0, str(Path.cwd() / "tools"))
from cutout_pipeline.cases import CutoutError, digest, load_case, read_json, write_json
from cutout_pipeline.proof import verify_render
from maquette_cutout import PROOF_DEFAULTS, contact_sheet


def transform_mask(root, part, layout, bones, mesh=None):
    mask = Image.open(root / part["file"]).convert("RGBA").getchannel("A")
    weighted = {part["bone"]: 1.0}
    if mesh:
        # A TODO cloth skin has exactly the original rigid attachment. Reject
        # an updated deforming field rather than report a rigid approximation.
        weighted = {}
        for bone, weights in mesh["weights"].items():
            if not np.allclose(weights, weights[0]):
                raise CutoutError("Deforming cloth now needs native exposure measurement: " + mesh["name"])
            weighted[bone] = weights[0]
    matrix = np.zeros((2, 2))
    origin = np.zeros(2)
    for bone, weight in weighted.items():
        xx, xy, yx, yy, x, y = bones[bone]
        basis = np.array([[xx, yx], [xy, yy]])
        matrix += weight * basis
        origin += weight * (np.array([x, y]) - basis @ layout["joints"][bone]["position"])
    origin += matrix @ part["offset"] + PROOF_DEFAULTS["pose_offset"]
    inverse = np.linalg.inv(matrix)
    translation = -inverse @ origin
    affine = (inverse[0, 0], inverse[0, 1], translation[0], inverse[1, 0], inverse[1, 1], translation[1])
    size = PROOF_DEFAULTS["pose_canvas"]
    return np.asarray(mask.transform((size, size), Image.Transform.AFFINE, affine, Image.Resampling.NEAREST)) > 128


def exposure(root, samples_path):
    _, config = load_case(root)
    samples = read_json(samples_path)
    if not samples["ok"]:
        raise CutoutError("Headless motion sampling failed")
    if not samples.get("inputs"):
        raise CutoutError("Run a fresh sampler: input hashes are missing")
    for path, expected in samples["inputs"].items():
        if digest(root / path) != expected:
            raise CutoutError("Stale motion sample input: " + path)
    index = read_json(root / "hidden_requests/index.json")
    lookup = {(r["view"], r["part"]): r for r in index["requests"]}
    for request in index["requests"]:
        request["motions"] = []
        request["max_exposed_pixels"] = 0 if request["status"] == "measured" else None
        request["exposure_status"] = "sampled_cpu_visibility" if request["status"] == "measured" else "unknown"
    layouts = {view: read_json(root / path) for view, path in config["layouts"].items()}
    measures = {}
    for sample in samples["samples"]:
        view, clip = sample["view"], sample["clip"]
        layout = layouts[view]
        meshes = {m["replaces_part"]: m for m in layout.get("joint_meshes", [])}
        # Final painted ownership after the SAME ordered layers used by the rig.
        size = PROOF_DEFAULTS["pose_canvas"]
        visible = np.full((size, size), -1, dtype=np.int16)
        parts = sorted(layout["parts"], key=lambda p: p["z_index"])
        for number, part in enumerate(parts):
            visible[transform_mask(root, part, layout, sample["bones"], meshes.get(part["name"]))] = number
        counts = np.bincount(visible[visible >= 0], minlength=len(parts))
        for number, part in enumerate(parts):
            if not part.get("hidden_material"):
                continue
            count = int(counts[number])
            name = part.get("logical_part", part["name"])
            record = measures.setdefault((view, name, clip), {"clip": clip, "max_exposed_pixels": 0,
                                                             "frames_exposed": 0, "peak_frame": None})
            if count > record["max_exposed_pixels"]:
                record.update(max_exposed_pixels=count, peak_frame=sample["frame"])
            record["frames_exposed"] += int(count > 0)
    for (view, name, _), measure in measures.items():
        request = lookup[(view, name)]
        if measure["max_exposed_pixels"]:
            request["motions"].append(measure)
            request["max_exposed_pixels"] = max(request["max_exposed_pixels"], measure["max_exposed_pixels"])
    for request in index["requests"]:
        request["motions"].sort(key=lambda m: (-m["max_exposed_pixels"], m["clip"]))
    index["requests"].sort(key=lambda r: (r["max_exposed_pixels"] is None, -(r["max_exposed_pixels"] or 0),
                                         -(r["hidden_pixel_count"] or 0), r["view"], r["part"]))
    index["exposure_basis"] = "Maximum visible hidden pixels over the actual headless sampler frames; Pillow nearest mask rasterization, not renderer proof. Missing solos sort last, never as known zero exposure. All five requested clips sampled."
    index["samples_sha256"] = digest(samples_path)
    write_json(root / "hidden_requests/index.json", index)
    contact_sheet([(f"{r['view']}/{r['part']}\n" + (f"hidden={r['hidden_pixel_count']} peak={r['max_exposed_pixels']}" if r["status"] == "measured" else "UNKNOWN: MISSING SOLO"),
                    Image.open(root / r["image"]).convert("RGBA")) for r in index["requests"]], root / "hidden_requests/contact_sheet.png")
    print(f"MAQUETTE_EXPOSURE: PASS ({len(index['requests'])} requests; {sum(r['status'] != 'measured' for r in index['requests'])} unknown solos)")


def native(root, output):
    result = verify_render(root, output)
    if not result["ok"]:
        raise CutoutError(str(result))
    for view in read_json(root / "cutout.json")["layouts"]:
        actual = Image.open(output / f"{view}_rest.png").convert("RGBA")
        expected = Image.open(root / "source" / view / "processed.png").convert("RGBA")
        if actual.size != expected.size or actual.tobytes() != expected.tobytes():
            raise CutoutError(f"Native {view} rest does not equal the approved painting")
    manifest = read_json(output / "render_manifest.json")
    for clip in manifest["clips"]:
        count = clip["cycle_frames"]
        indices = np.rint(np.linspace(0, count - 1, PROOF_DEFAULTS["keyframes_per_clip"])).astype(int)
        items = [(f"{clip['facing']}/{clip['clip']} frame {i}", Image.open(output / clip["folder"] / f"pose_{i:04d}.png").convert("RGBA")) for i in indices]
        contact_sheet(items, root / "proof/native_keyframes" / f"{clip['folder']}_8frames.png", columns=4)
    write_json(root / "proof/native_keyframes/verification.json", {"ok": True, "capture": str(output), "render_verification": result,
               "rest_identity": "both approved RGBA paintings equal native rest", "proof_manifest_sha256": digest(output / "proof_sha256.json")})
    print(f"MAQUETTE_NATIVE_PROOF: PASS ({len(manifest['clips'])} eight-frame sheets; native rest RGBA identical)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", type=Path, required=True)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--samples", type=Path)
    action.add_argument("--native-output", type=Path)
    args = parser.parse_args()
    try:
        if args.samples:
            exposure(args.case, args.samples)
        else:
            native(args.case, args.native_output)
    except (CutoutError, OSError, ValueError, KeyError) as error:
        print("MAQUETTE_PROOF: FAIL: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
