"""Production progression checks for the v2 whole-pixel idle contract."""
from .gates import bindings


def production_errors(case, manifest, compiled):
    errors=[]
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
    return errors
