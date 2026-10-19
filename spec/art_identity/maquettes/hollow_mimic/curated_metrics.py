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
