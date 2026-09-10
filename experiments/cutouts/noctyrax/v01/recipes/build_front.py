"""Noctyrax v01 explicit source-space registration/ownership; no generated paint.
Run from repository root. Existing output must be removed deliberately to rebuild.
"""
from pathlib import Path
import json, subprocess
CASE=Path('experiments/cutouts/noctyrax/v01')
def save(p,v): (CASE/p).write_text(json.dumps(v,indent=2)+'\n')
polygons=[
 ['tail',[[70,211],[98,211],[110,223],[110,228],[70,228]]],
 ['claw_fore_near',[[98,193],[105,185],[120,181],[140,185],[149,201],[143,216],[104,214],[94,202]]],
 ['claw_fore_far',[[24,182],[45,177],[57,178],[69,191],[62,207],[21,209]]],
 ['claw_hind_near',[[162,189],[178,184],[188,190],[191,207],[157,210]]],
 ['claw_hind_far',[[72,184],[95,176],[109,181],[108,197],[70,200]]],
 ['fore_near',[[142,129],[158,129],[165,138],[153,160],[146,179],[140,189],[120,186],[118,178],[127,161],[132,148]]],
 ['fore_far',[[77,143],[90,147],[84,159],[70,170],[60,184],[49,187],[47,178],[61,163]]],
 ['hind_near',[[173,136],[185,137],[193,151],[198,166],[189,177],[187,193],[178,200],[168,191],[174,177],[165,174],[163,162]]],
 ['hind_far',[[100,156],[127,157],[121,174],[111,183],[102,191],[92,191],[89,184],[99,175],[84,177],[82,169],[89,160]]],
 # The scaly proximal tail occludes the near wing; keep its paint on the tail.
 ['tail',[[193,137],[213,149],[225,174],[229,221],[195,247],[104,251],[43,246],[44,213],[73,198],[86,204],[70,215],[78,228],[105,224],[129,222],[158,224],[186,218],[204,198],[198,180],[190,160]]],
 ['head',[[59,119],[47,108],[47,73],[54,48],[73,22],[85,23],[86,43],[98,33],[102,16],[122,20],[125,57],[118,70],[103,82],[86,99],[76,115]]],
 ['wing_far',[[2,8],[99,0],[97,21],[69,35],[49,77],[55,124],[65,178],[37,183],[0,164]]],
 ['wing_near',[[127,20],[144,16],[157,26],[152,0],[196,0],[255,69],[255,196],[221,193],[198,172],[185,146],[176,145],[163,178],[149,174],[145,162],[159,130],[147,126],[136,130],[131,129],[140,110],[145,88],[159,72],[153,43]]],
 ['neck',[[120,62],[141,68],[150,81],[144,105],[128,122],[121,139],[102,154],[87,143],[81,130],[86,109],[101,92],[109,79]]],
 ['torso',[[77,108],[163,108],[195,129],[204,168],[153,187],[105,183],[75,170],[67,143]]],
]
# Small contour completions retain explicit semantic ownership rather than
# handing unassigned pixels to the torso.
polygons += [
 ['tail',[[43,210],[213,201],[237,213],[229,247],[40,254]]],
 ['claw_fore_near',[[89,189],[101,179],[146,181],[152,218],[89,219]]],
 ['fore_far',[[43,168],[78,142],[89,152],[72,180],[61,189]]],
 ['neck',[[73,112],[124,61],[149,72],[149,122],[94,145]]],
 ['wing_near',[[140,74],[161,49],[165,82],[147,96]]],
 ['torso',[[72,122],[159,124],[169,152],[165,186],[97,182],[71,155]]]
]
# Audited antialiased edge clusters, each within its named contour.
for name,box in [
 ('head',(97,17,101,23)),('head',(124,48,126,52)),
 ('wing_near',(125,18,157,28)),('wing_near',(150,42,155,61)),
 ('neck',(123,57,139,68)),('neck',(61,115,75,131)),
 ('wing_far',(53,116,60,132)),('fore_far',(61,143,70,154)),
 ('claw_fore_far',(20,190,24,197)),('claw_fore_far',(51,206,55,210)),
 ('claw_hind_far',(64,182,72,196)),('claw_hind_far',(82,198,87,201)),
 ('hind_far',(78,171,92,180)),('claw_fore_near',(146,185,152,189)),
 ('claw_hind_near',(152,184,170,205)),('hind_near',(170,178,173,183)),
 ('tail',(188,169,206,205)),('tail',(226,191,234,205))]:
 x0,y0,x1,y1=box
 polygons.append([name,[[x0,y0],[x1,y0],[x1,y1],[x0,y1]]])
save(Path('source/front_ownership.json'), {'priority_polygons':polygons,'pixel_overrides':[]})
subprocess.run(['python3','tools/cutout_workflow.py','segment','--source',str(CASE/'source/front_registered.png'),'--ownership',str(CASE/'source/front_ownership.json'),'--output',str(CASE/'segmented/front')],check=True,stdout=subprocess.DEVNULL)
# Native global coordinates. Four contact points are separately projected.
points={'body':(133,145),'neck':(111,131),'head':(88,91),'wing_far':(69,104),'wing_far_tip':(42,64),'wing_near':(153,122),'wing_near_tip':(185,72),'tail':(198,168),'tail_mid':(207,214),'tail_tip':(111,232)}
parents={k:'body' for k in points};parents['body']=None;parents['head']='neck';parents['wing_far_tip']='wing_far';parents['wing_near_tip']='wing_near';parents['tail_mid']='tail';parents['tail_tip']='tail_mid'
for side,pts in {'fore_near':[(145,139),(137,165),(128,189)],'fore_far':[(80,149),(65,169),(46,185)],'hind_near':[(179,147),(176,172),(177,193)],'hind_far':[(111,158),(97,172),(94,187)]}.items():
 for i,n in enumerate(['upper_'+side,'lower_'+side,'claw_'+side]): points[n]=pts[i];parents[n]='body' if i==0 else ('upper_' if i==1 else 'lower_')+side
joints={k:{'position':v,'parent':parents[k]} for k,v in points.items()}
seg=json.loads((CASE/'segmented/front/segmentation.json').read_text())
print(seg.keys())
layout={'canvas_size':[255,255],'facing':'front','joints':joints,'parts':[]}
# The ownership map makes visible arm/chest and wing/body boundaries explicit.
order={'wing_far':0,'wing_near':3,'tail':1,'torso':5,'neck':6,'head':7,'fore_far':4,'fore_near':9,'hind_far':2,'hind_near':4,'claw_fore_far':5,'claw_fore_near':10,'claw_hind_far':3,'claw_hind_near':5}
for part in seg['parts']:
 name=part['name'];bone=name if name in joints else 'body' if name=='torso' else 'upper_'+name
 layout['parts'].append({'name':name,'file':'segmented/front/'+name+'.png','offset':part['offset'],'bone':bone,'z_index':order[name]})
save(Path('layouts/front.json'),layout)
