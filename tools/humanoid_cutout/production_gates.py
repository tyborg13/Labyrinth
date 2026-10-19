"""Production progression checks for the v2 whole-pixel idle contract."""
from .gates import bindings


def production_errors(case, manifest, compiled):
    errors=[]
    if manifest.get("ok") is False: errors.append("Production capture did not complete successfully")
    if manifest.get('inputs') != bindings(case):
        errors.append('Production input bindings differ from final case/runtime')
    for clip,definition in compiled['clips'].items():
        rows=[r for r in manifest['frames'] if r['stage']==clip and r['snapshot']['clip']==clip]
        minimum=3 if clip=='idle' else 6
        word='three' if minimum==3 else 'six'
        if len(rows)<6:errors.append(clip+': fewer than six action frames')
        if len({r.get('pose_sha256') for r in rows})<minimum:
            errors.append(clip+': fewer than '+word+' changing bone poses')
        if manifest.get('native_pixels') and len({r.get('pixels_sha256') for r in rows})<minimum:
            errors.append(clip+': fewer than '+word+' changing native frames')
        contact=definition.get('contact')
        if contact is not None and not any(abs(r['snapshot']['phase']-contact)<1e-6 for r in rows):
            errors.append(clip+': missing real contact frame')
        phases=[r['snapshot']['phase'] for r in rows]
        if clip not in ('idle','move') and any(a>b+1e-6 for a,b in zip(phases,phases[1:])):
            errors.append(clip+': clip restarted during one action')
        if not phases or max(phases)-min(phases)<.5:errors.append(clip+': phase did not progress')
        if any(r['snapshot']['rig_count']!=2 for r in rows):errors.append(clip+': missing approved view')
    if manifest.get('completions',{}).get('hit',{}).get('clip')!='idle':errors.append('hit: missing return to idle')
    if 'gait' in compiled['clips'].get('move', {}):
        from cutout_pipeline.cases import read_json
        from .anatomy import load
        from .walk_gates import report
        from pathlib import Path
        integration=load(case)['integration']
        project=Path(__file__).resolve().parents[2]
        production=project/integration['production_root']/integration['rig_directory']
        walks=manifest.get('walk_samples', {})
        for view in {r['snapshot']['facing'] for r in manifest['frames'] if r['stage']=='move'}:
            if view not in walks:
                errors.append(view+': missing production walk samples')
                continue
            layout=read_json(production/(view+'.json'))
            layout['anatomy']=load(case)
            walk=report(layout,compiled,walks[view])
            errors+=walk['errors']
    return errors


if __name__=='__main__':
    import argparse
    from pathlib import Path
    from cutout_pipeline.cases import read_json
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case',type=Path,required=True)
    parser.add_argument('--capture',type=Path,required=True)
    args=parser.parse_args()
    errors=production_errors(args.case,read_json(args.capture/'frames.json'),read_json(args.case/'compiled_motion.json'))
    print('GAIT PRODUCTION GATES: %s (%d errors)' % ('FAIL' if errors else 'PASS',len(errors)))
    for error in errors[:20]:print(error)
    raise SystemExit(int(bool(errors)))
