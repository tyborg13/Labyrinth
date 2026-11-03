"""On-demand admissible cloth budget search on an observed failing witness."""
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from build import CASE
from cutout_pipeline.cases import read_json,write_json
from cpu_sweep import measure


def candidate(row):
    data=read_json(CASE/'proof/budget_samples.json');data['samples']=[row]
    result=measure(data)
    return {'ratio':row['budget_ratio'],'ok':result['ok'],'counts':dict(Counter(r['kind'] for r in result['errors'])),
            'cloth_detached_components':sum(r.get('logical_part')=='cloak' for r in result['errors']),
            'errors':result['errors']}


if __name__=='__main__':
    rows=read_json(CASE/'proof/budget_samples.json')['samples']
    with ProcessPoolExecutor(max_workers=4) as pool:results=list(pool.map(candidate,rows))
    clean=[r for r in results if r['ok']]
    write_json(CASE/'proof/budget_search.json',{'candidates':results,'clean_candidates':len(clean),'native_pixels':False,
        'witness':'rear/move/26','rule':'Reaver 1/60 grid, 60-100% of supplied cloth follow-through; all other director channels unchanged',
        'selected_ratio':max((r['ratio'] for r in clean),default=None)})
    print('RR56 CLOTH BUDGET SEARCH: %d clean of %d admissible candidates; director motion unchanged'%(len(clean),len(results)))
