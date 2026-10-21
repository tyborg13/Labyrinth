"""Canonical production gates once for both real headless resolver streams."""
import heapq
from rr30_case import CASE
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.production_gates import production_errors


def run():
    data = read_json(CASE / 'compiled_motion.json')
    sources = [read_json(CASE / ('proof/logs/' + name + '/logic_frames.json'))
               for name in ('production_logic','production_logic_rear')]
    merged = dict(sources[0], frames=[], walk_samples={})
    for source in sources:
        if source['inputs'] != merged['inputs'] or source.get('native_pixels') is not False:
            raise ValueError('Expected matching headless production input bindings')
        if not source['ok'] or source['errors']:
            raise ValueError('Production logic capture failed')
        for view, samples in source['walk_samples'].items():
            if view in merged['walk_samples'] and merged['walk_samples'][view] != samples:
                raise ValueError('Conflicting actual production walk samples: '+view)
            merged['walk_samples'][view] = samples
        if source['completions'].get('hit',{}).get('clip') != 'idle':
            raise ValueError('Production hit did not return to idle')
    for clip in data['clips']:
        streams = ([row for row in source['frames'] if row['stage']==clip] for source in sources)
        merged['frames'].extend(heapq.merge(*streams,key=lambda row:row['snapshot']['phase']))
    errors=production_errors(CASE,merged,data)
    report=dict(ok=not errors,errors=errors,native_pixels=False,
                frame_count=len(merged['frames']),views=['front','rear'])
    write_json(CASE/'proof/production_gates.json',report)
    print('RR30 PRODUCTION LOGIC GATES: %s (%d frames; %d errors; both views)' %
          ('FAIL' if errors else 'PASS',report['frame_count'],len(errors)))
    for error in errors: print(error)
    return report


if __name__=='__main__': raise SystemExit(not run()['ok'])
