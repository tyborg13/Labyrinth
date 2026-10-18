"""Read-only coordinate diagnostics for failed native cold/replay builds."""
import json
from pathlib import Path
import sys

import bpy


def main(folder,output):
    snapshots={}
    for label in ('cold','replay','independent_cold'):
        path=Path(folder)/label
        report=json.loads((path/'build_report.json').read_text())
        bpy.ops.wm.open_mainfile(filepath=str(path/'maquette.blend'))
        snapshots[label]={name:{'matrix':[x for row in bpy.data.objects[name].matrix_world for x in row],
            'vertices':[[float(x) for x in v.co] for v in bpy.data.objects[name].data.vertices]}
            for name in report['mesh_hashes']}
    results={}
    for name,cold in snapshots['cold'].items():
        entries={}
        for label in ('replay','independent_cold'):
            value=snapshots[label][name]
            differences=[abs(a-b) for p,q in zip(cold['vertices'],value['vertices']) for a,b in zip(p,q)]
            entries[label]={'matrix_max_delta':max(abs(a-b) for a,b in zip(cold['matrix'],value['matrix'])),
                'vertex_max_delta':max(differences,default=0),'changed_coordinates':sum(d>0 for d in differences),
                'first_vertex':[cold['vertices'][0],value['vertices'][0]]}
        results[name]=entries
    Path(output).write_text(json.dumps(results,indent=2)+'\n')
    for name,values in results.items():
        if any(v['vertex_max_delta'] or v['matrix_max_delta'] for v in values.values()):print(name,values)


if __name__=='__main__':main(*sys.argv[sys.argv.index('--')+1:])
