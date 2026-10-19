"""Record exact curated bytes alongside the before/after fit and turn values."""
import json
from .batch_proof import ROOT,FIGURES
from spec.art_identity.maquettes.blender.curate_delivery import inventory,verify,write

METRICS_DEFAULTS={'maximum_rewrites':5}


def main():
    output=ROOT/'hollow_mimic/delivery/review'
    before=json.loads((output/'form_revision_before.json').read_text())
    reports={n:json.loads((ROOT/n/'delivery/fit_report.json').read_text()) for n in FIGURES}
    for _ in range(METRICS_DEFAULTS['maximum_rewrites']):
        sizes={n:sum(p.stat().st_size for p in inventory(ROOT/n)) for n in FIGURES}
        rows=['| Figure | Front IoU before → after | Rear IoU before → after | Shoulder observed / expected (error) px | Front near / far | Rear near / far | Curated bytes |',
              '|---|---:|---:|---:|---:|---:|---:|']
        for name,report in reports.items():
            pose=report['pose'];old=before[name]['fit_report']['views'];turn=report['true_turn']['observations']
            front,rear=(turn[v]['body_side_pixels_over_torso'] for v in ('front','rear'))
            rows.append(f"| {name} | {old['front']['iou']:.9f} → {report['views']['front']['iou']:.9f} | "
                        f"{old['rear']['iou']:.9f} → {report['views']['rear']['iou']:.9f} | "
                        f"{pose['observed_far_above_near_px']:.6f} / {pose['expected_far_above_near_px']:.6f} "
                        f"({pose['shoulder_error_px']:.6f}) | {front['near']} / {front['far']} | "
                        f"{rear['near']} / {rear['far']} | {sizes[name]} |")
        shapes={n:json.loads((ROOT/n/'delivery/validation/shape_measurements.json').read_text()) for n in FIGURES}
        hair=shapes['hollow_mimic']['hair'];hood=shapes['briar_weaver']['rear_hood'];cup=shapes['slag_mortar']['vessel']
        rows += ['', '| Measured feedback-3 form | Native result | Requirement |',
                 '|---|---|---|',
                 f"| Mimic front silhouette spike tips | {hair['count']} | ≥8; each valley prominence ≥12 px |",
                 f"| Weaver rear hood top | {hood['top_px']:.6f} px; painting {hood['painting_top_px']:.6f}; error {hood['top_error_px']:.6f} | ±16 px at 1024; thorn excluded |",
                 f"| Mortar total height / outer rim diameter | {cup['height_diameter_ratio']:.9f} | ≤0.8, including rolled rim |",
                 f"| Mortar native raised bands | {cup['band_count']} | 2 |"]
        for band in cup['bands']:
            visible=band['visible_outer_samples']
            rows.append(f"| {band['object']} | width {band['width_height_ratio']:.6%} of height; relief {band['raised_m']:.6f} m; visible samples front/rear {visible['front']}/{visible['rear']} | width ≥4%; raised and visible both views |")
        (output/'fit_table.md').write_text('\n'.join(rows)+'\n')
        write(output/'curated_metrics.json',{'curated_bytes':sizes,'budget_bytes_each':6000000,
            'figure_files':{n:len(inventory(ROOT/n)) for n in FIGURES},
            'fit_reports_sha256_bound_in':'../acceptance_binding.json and each figure delivery binding'})
        if sizes=={n:sum(p.stat().st_size for p in inventory(ROOT/n)) for n in FIGURES}:
            for name in FIGURES:verify(ROOT/name)
            print('MQ09_CURATED_METRICS: PASS; '+json.dumps(sizes,sort_keys=True))
            return 0
    raise ValueError('Curated byte report did not reach a stable byte count')


if __name__=='__main__':
    raise SystemExit(main())
