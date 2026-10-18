"""Read-only, fail-closed acceptance before mq-07 discards native evidence."""
import math
from pathlib import Path

from spec.art_identity.maquettes.blender.capture_manifest import read_manifest, sha256
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.delivery_validation import REPORTS, load, proof_path, validate_delivery
from spec.art_identity.maquettes.blender.floor_contact import spec_contacts
from .tube_proof import geometry_dimensions, TUBE_PROOF_DEFAULTS

VIEWS = ('front', 'rear')
POSE_CHECKS = ('shoulder_height', 'shoulder_height_is_perspective_only', 'far_shoulder_x',
               'limb_lengths_outside_planted_leg', 'same_body_half_turn', 'lower_foot_right_in_both_views')
TUBE_CHECKS = ('shaft_width', 'mouth_offset', 'band_height', 'band_raise', 'dome_height',
               'open_annular_mouth', 'one_band_only', 'closed_shell', 'distal_tip_unchanged',
               'whole_fore_near_ownership')
NATIVE_MARGIN_PX = 8  # Owner's mq-07 framing requirement.
NATIVE_TUBE_DIAMETER_PX = 68  # Feedback 1: 17 source px, four native px per source px.


def require(condition, message):
    if not condition:
        raise ValueError('mq-07 evidence: ' + message)


def passed_checks(report, required, name):
    require(report.get('passed') is True and all(report.get('checks', {}).get(key) is True
            for key in required) and all(value is True for value in report.get('checks', {}).values()), name)


def binding(spec, capture, root):
    """The manifest binds every PNG and joint; read_manifest checks their bytes."""
    read_manifest(capture, digest(spec), ('full',))
    reports = {name: sha256(capture / name) for name in (*REPORTS, 'capture_frame.json')}
    reports.update({name: sha256(proof_path(capture, name))
                    for name in ('recipe_proof.json', 'exact_native_replay.json')})
    return {'spec_hash': digest(spec), 'recipe_sha256': sha256(root.parent / 'measurements.json'),
            'capture_manifest_sha256': sha256(capture / 'capture_manifest.json'),
            'report_sha256': reports, 'tube_receipt_sha256': sha256(root / 'tube_geometry.json'),
            'sheet_sha256': sha256(root / 'shoulder_tube_sheet.png')}


def validate_receipt(spec, recipe, capture, root, gates=None):
    """Never treat a summary boolean or an empty collection as proof."""
    validate_delivery(spec, capture)
    gates = load(root / 'gates.json') if gates is None else gates
    require(gates.get('spec_hash') == digest(spec), 'stale gates spec')
    require(gates.get('binding') == binding(spec, capture, root), 'stale gates input hashes')
    passed_checks(gates, POSE_CHECKS, 'missing or failed pose gate')
    require(gates.get('native_capture_available') is True and gates.get('native_delivery_passed') is True,
            'missing native delivery gate')
    require(not recipe.get('unresolved_design') and gates.get('unresolved_design') == {}, 'unresolved design')
    tube = load(root / 'tube_geometry.json')
    require(tube.get('spec_hash') == digest(spec), 'stale native tube receipt')
    passed_checks(tube, TUBE_CHECKS, 'missing or failed native tube geometry')
    passed_checks(gates.get('tube_geometry', {}), TUBE_CHECKS, 'missing or failed tube geometry gate')
    require(gates.get('tube_geometry') == geometry_dimensions(spec, recipe), 'missing or failed tube geometry')
    entry = tube.get('native_entry', {})
    require(gates.get('native_tube_entry_passed') is True and entry.get('passed') is True and
            entry.get('upper_near_crosses_mouth_plane') is True and
            entry.get('upper_near_vertices_inside_mouth', 0) > 0, 'missing or failed native tube entry')
    floor = gates.get('floor_guard', {})
    require(floor == spec_contacts(spec) and floor.get('passed') is True and
            floor.get('excepted_offenders') == [], 'missing or failed floor gate')
    framing = gates.get('framing', {})
    require(framing.get('passed') is True and set(framing.get('views', {})) == set(VIEWS), 'missing framing')
    fits, widths = gates.get('after_fit', {}), gates.get('tube_widths', {})
    require(set(fits) == set(VIEWS) and set(widths) == set(VIEWS), 'missing fit or tube width view')
    manifest = read_manifest(capture, digest(spec), ('full',))
    cameras = load(capture / 'capture_frame.json')
    for view in VIEWS:
        frame = framing['views'][view]
        margins = frame.get('edge_margins_px', {})
        images = {name for name in manifest['images'] if name.startswith(view + '_')}
        require(frame.get('passed') is True and frame.get('required_margin_px') == NATIVE_MARGIN_PX and
                set(margins) == images and all(len(row) == 4 and min(row) >= NATIVE_MARGIN_PX
                for row in margins.values()), 'missing or failed framing: ' + view)
        camera = cameras.get(view, {})
        require(frame.get('native_camera') == camera and frame.get('pan_px') == camera.get('pan_px', [0, 0]),
                'stale camera framing: ' + view)
        if view == 'rear':
            require(camera.get('passed') is True and camera.get('camera_rotation_unchanged') is True,
                    'missing or failed native camera framing')
        width = widths[view]
        require(width.get('passed') is True and
                len(width.get('widths_native_px', [])) == len(TUBE_PROOF_DEFAULTS['width_fractions']) and
                all(math.isfinite(value) and abs(value - NATIVE_TUBE_DIAMETER_PX) <= TUBE_PROOF_DEFAULTS['width_tolerance_px']
                    for value in width['widths_native_px']), 'missing or failed tube width: ' + view)
        fit = fits[view]
        minimum = recipe['fit'][view]['gate']['iou_min']
        require(fit.get('passed') is True and fit.get('minimum') == minimum and all(
                isinstance(fit.get(key), (int, float)) and math.isfinite(fit[key]) and fit[key] >= minimum
                for key in ('iou', 'dynamic_iou', 'fixed_original_iou')), 'missing or failed fit: ' + view)
        coverage = fit.get('per_part_coverage', {})
        require(set(coverage) == set(spec['labels']) and all(row.get('passed') is True and
                row.get('solo_pixels', 0) > 0 and row.get('clipped_at_canvas') is False and
                (row.get('pure_owner_pixels', 0) > 0 or row.get('recorded_occlusion'))
                for row in coverage.values()), 'missing or failed coverage: ' + view)
    return gates


def main():
    import argparse
    from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
    figure = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, default=figure / 'delivery')
    args = parser.parse_args()
    recipe = load(figure / 'r2/measurements.json')
    validate_receipt(compile_recipe(recipe), recipe, args.capture, figure / 'r2/proof')
    print('MQ07_EVIDENCE: PASS; spec/capture/tube hashes and every mandatory gate current')


if __name__ == '__main__':
    main()
