"""Reproduce the mq27 case from protected inputs, using the rr12 modules."""
from prepare import *
from registration import install
from cutout_pipeline.cases import baseline


def build_case():
    with adapters():
        build.build(CREATURE)
        config=read_json(CASE/'cutout.json')
        config['runtime_paths']=sorted({p for p in config['runtime_paths'] if (PROJECT/p).is_file()} |
            {'tests/maquette_cutout/samples.gd'} |
            {str((CASE/name).relative_to(PROJECT)) for name in ('prepare.py','sweep.py')})
        write_json(CASE/'cutout.json',config)
        build.derive(CASE)
    path=CASE/'recipes/feature_selections.json'
    record=read_json(path)
    record['source']='Owner-approved mq27 paintings; rr55 tooth ring owned by head'
    record['selections']['maw_tooth_ring']['front']=[14,181,63,242]
    record['registered_polygon']=[[28,183],[39,181],[49,186],[57,197],[62,210],[61,223],[55,236],[45,241],[33,238],[23,229],[17,218],[14,204],[17,193]]
    record['policy']='Registered polygon selects existing tooth ring; one-pixel rim, bounded holes filled, intersect approved opaque paint'
    write_json(path,record)
    path=CASE/'hidden_fills/index.json'
    record=read_json(path)
    record['continuity']['policy']='rr55: retain four-connected immutable hidden seeds, including any seed beyond rest alpha; rr05 covered support bands unchanged'
    write_json(path,record)
    install()
    baseline(CASE)
    print('MQ27 CASE BUILD: PASS; run workflow.py headless before promotion')


if __name__=='__main__': build_case()
