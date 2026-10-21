"""Existing identity-sheet layout with metadata from each view's owning job.

The shared tool assumes one size class for a pair. These supplied source views
straddle its drawn-height boundary at the unchanged production art scale.
No sprite, draw size, layout, colour or font changes from the shared sheet.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps
from art_identity_gate import (ROOT, IDENTITY, SHEET_DEFAULTS, RESAMPLE, read_json,
    canon_entries, matching_view, coverage, rgba, repo_path, sheet_backdrop,
    render_board_row, proof_font, measure, lateral_axis, metric_bands, in_band,
    processed_fit_scale, rear_consistency, pixel_digest, sha, alpha_bbox,
    base_fits, draw_landmarks)


def make_sheet(front: Path, rear: Path, kit_path: Path, out: Path, art_scale: float = 1.0,
               landmarks: dict = None, root: Path = ROOT) -> None:
    kit = read_json(kit_path)
    canon = canon_entries(root, include_retired=True)
    references = [matching_view(canon, canon[p], False) for p in kit["peers"]]
    meta = coverage(root)
    def scale_for(path: str) -> float:
        return meta.get(path, {}).get("art_scale", 1.0)
    candidate = rgba(front)
    candidate_path = str(front.resolve().relative_to(root.resolve())) if root.resolve() in front.resolve().parents else ""
    candidate_meta = meta.get(candidate_path, next((m for m in meta.values() if m["id"] == kit["id"]), {}))
    rear_image = rgba(rear) if rear is not None else None
    subjects = [(rgba(repo_path(root, canon["hero_front"]["path"])), 1.0, "hero"),
                (rgba(repo_path(root, references[0]["path"])), scale_for(references[0]["path"]), references[0]["id"]),
                (candidate, art_scale, "candidate front"), (rear_image, art_scale, "candidate rear (absent)" if rear_image is None else "candidate rear"),
                (ImageOps.mirror(candidate), art_scale, "candidate mirrored"),
                (rgba(repo_path(root, references[1]["path"])), scale_for(references[1]["path"]), references[1]["id"])]
    backdrop, slots = sheet_backdrop(root)
    if len(slots) < 6:
        raise ValueError("backdrop needs six ordered review slots")
    row = render_board_row(backdrop, slots[:6], subjects)
    font = proof_font()
    metric_rows = []
    bands = read_json(root / IDENTITY / "bands.json")
    for facing, path in (("front", front), ("rear", rear)):
        if path is None:
            continue
        measured = measure(path, art_scale, kit["kind"], kit["anatomy"])
        annotation = (landmarks.get(facing) if ('front' in landmarks or 'rear' in landmarks) else landmarks) if landmarks else None
        if annotation:
            measured["lateral_axis"] = lateral_axis(annotation)
        entry = dict(kit, art_scale=art_scale, landmarks=annotation or {}, boss=candidate_meta.get("boss", False),
                     facing=facing)
        # Each supplied view has its own projected drawn-height classification.
        view_kit = read_json(kit_path.parent.parent / ('mq11_' + facing) / 'kit.json')
        entry['size_class'] = view_kit['size_class']
        limits = metric_bands(entry, bands)
        measured["art_scale"] = art_scale
        for metric, value in measured.items():
            limit = limits.get(metric)
            status = "INFO" if limit is None else ("PASS" if in_band(value, limit) else "FAIL")
            metric_rows.append((facing + "." + metric, "%0.4f" % value, str(limit) if limit else "unbanded", status))
        fit_scale = processed_fit_scale(path)
        metric_rows.append((facing + ".fit_scale", "%0.4f" % fit_scale if fit_scale is not None else "N/A", "unbanded", "INFO"))
        if "lateral_axis" in limits and not annotation:
            metric_rows.append((facing + ".lateral_axis", "MISSING", str(limits["lateral_axis"]), "FAIL"))
    if rear is not None and kit["kind"] == "creature":
        for metric, value in rear_consistency(front, rear).items():
            limit = bands["rear_consistency"][metric + "_max"]
            metric_rows.append(("rear_consistency." + metric, "%0.4f" % value, str((0, limit)),
                                "PASS" if value <= limit else "FAIL"))
    line_height = SHEET_DEFAULTS["table_line_height"]
    provenance = ["kit_version " + kit["kit_version"], "front pixels " + pixel_digest(candidate),
                  "rear pixels " + (pixel_digest(rear_image) if rear_image else "absent"),
                  "kit file sha256 " + sha(kit_path.read_bytes()), "prompt sha256 " + kit["prompt_sha256"]]
    provenance.extend(ref["file"] + " pixels " + ref["pixel_sha256"] for ref in kit["refs"])
    table_height = (len(metric_rows) + len(provenance) + 3) * line_height
    output = Image.new("RGBA", (row.width * 2, row.height * 3 + SHEET_DEFAULTS["detail_height"] + table_height), "#14100c")
    output.alpha_composite(row, (0, 0))
    output.alpha_composite(row.resize((row.width * 2, row.height * 2), RESAMPLE.NEAREST), (0, row.height))
    detail_y = row.height * 3
    draw = ImageDraw.Draw(output)
    for index, (label, sprite) in enumerate((("front", candidate), ("rear", rear_image))):
        x = SHEET_DEFAULTS["margin"] + index * SHEET_DEFAULTS["detail_step_x"]
        y = detail_y + SHEET_DEFAULTS["detail_offset_y"]
        draw.text((x, detail_y), label, font=font, fill="#c9a25e")
        if sprite is None:
            continue
        output.alpha_composite(sprite.resize((sprite.width * 2, sprite.height * 2), RESAMPLE.NEAREST), (x, y))
        annotation = (landmarks.get(label) if ('front' in landmarks or 'rear' in landmarks) else landmarks) if landmarks else None
        if annotation:
            draw_landmarks(draw, annotation, (x, y))
        if kit["view"] == "object_plinth":
            bb = alpha_bbox(sprite)
            mask = np.asarray(sprite.crop(bb))[..., 3] > 128
            for fit in base_fits(mask):
                points = [(x + 2 * (bb[0] + px), y + 2 * (bb[1] + fit["slope"] * px + fit["intercept"]))
                          for px in (fit["x0"], fit["x1"])]
                draw.line(points, fill="#e0483c", width=2)
    table_y = detail_y + SHEET_DEFAULTS["detail_height"]
    draw.text((SHEET_DEFAULTS["margin"], table_y), "metric                         value       band                  status", font=font, fill="#c9a25e")
    for index, (metric, value, band, status) in enumerate(metric_rows, 1):
        draw.text((SHEET_DEFAULTS["margin"], table_y + index * line_height), "%-30s %-11s %-21s %s" % (metric, value, band, status), font=font,
                  fill="#e0483c" if status == "FAIL" else ("#5fae62" if status == "PASS" else "#c9a25e"))
    for index, text in enumerate(provenance, len(metric_rows) + 2):
        draw.text((SHEET_DEFAULTS["margin"], table_y + index * line_height), text, font=font, fill="#c9a25e")
    out.parent.mkdir(parents=True, exist_ok=True)
    output.convert("RGB").save(out)
