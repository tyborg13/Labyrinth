"""Explicit rear anatomy and source-pixel owners; generated rear is registered once."""
from pathlib import Path
import json,subprocess
CASE=Path('experiments/cutouts/noctyrax/v01')
def save(p,v):(CASE/p).write_text(json.dumps(v,indent=2)+'\n')
polygons=[
 ['tail',[[111,200],[136,198],[149,203],[158,212],[166,225],[143,235],[120,231]]],
 ['claw_fore_near',[[189,185],[207,181],[226,189],[229,214],[188,213]]],
 ['claw_hind_near',[[147,188],[163,184],[180,187],[189,213],[142,214]]],
 ['claw_hind_far',[[78,190],[99,188],[110,198],[113,215],[74,214]]],
 ['fore_near',[[171,139],[180,141],[189,161],[200,180],[212,184],[210,190],[192,195],[185,185],[175,174],[166,163],[167,149]]],
 ['hind_near',[[135,140],[157,142],[172,157],[169,170],[156,182],[161,186],[175,185],[178,196],[155,201],[138,190],[133,182],[123,187],[128,171]]],
 ['hind_far',[[99,139],[124,138],[125,164],[117,180],[104,193],[99,199],[86,201],[76,193],[78,179],[84,170],[83,154]]],
 ['head',[[136,15],[173,8],[197,24],[204,78],[191,91],[176,88],[162,79],[142,73],[133,59]]],
 ['wing_near',[[2,0],[147,0],[148,31],[123,49],[124,72],[134,92],[143,103],[141,111],[119,116],[93,135],[111,154],[98,156],[75,146],[58,153],[33,180],[1,181]]],
 ['wing_far',[[189,2],[225,5],[255,73],[255,199],[214,190],[202,180],[190,159],[173,155],[161,162],[154,145],[164,125],[157,114],[175,98],[186,80],[197,52]]],
 ['tail',[[67,148],[95,137],[104,148],[93,158],[72,178],[57,190],[79,212],[110,212],[141,219],[142,216],[121,205],[112,198],[140,193],[165,204],[171,236],[143,252],[55,252],[20,221],[20,176],[30,159]]],
 ['neck',[[136,64],[162,68],[179,79],[187,111],[177,133],[153,141],[131,130],[125,111]]],
 ['torso',[[87,114],[132,103],[166,117],[177,141],[169,165],[146,180],[113,183],[75,155]]]
]
# Individually audited contour gaps (same owner, first polygon still wins).
for name,box in [('claw_fore_near',(181,185,190,207)),('tail',(55,167,85,208)),
 ('hind_near',(124,181,141,195)),('hind_near',(155,167,176,186)),
 ('fore_near',(187,157,203,183)),('wing_far',(180,8,193,20)),
 ('wing_near',(122,58,134,85)),('hind_far',(104,181,121,195)),
 ('tail',(113,200,145,220)),('tail',(139,191,143,195))]:
 x0,y0,x1,y1=box;polygons.append([name,[[x0,y0],[x1,y0],[x1,y1],[x0,y1]]])
save(Path('source/rear_ownership.json'),{'priority_polygons':polygons,'pixel_overrides':[]})
subprocess.run(['python3','tools/cutout_workflow.py','segment','--source',str(CASE/'source/rear_registered.png'),'--ownership',str(CASE/'source/rear_ownership.json'),'--output',str(CASE/'segmented/rear')],check=True,stdout=subprocess.DEVNULL)
points={'body':(132,143),'neck':(156,111),'head':(177,67),'wing_near':(103,138),'wing_near_tip':(77,81),'wing_far':(166,126),'wing_far_tip':(220,90),'tail':(76,158),'tail_mid':(62,218),'tail_tip':(125,228)}
parents={k:'body' for k in points};parents['body']=None;parents['head']='neck';parents['wing_far_tip']='wing_far';parents['wing_near_tip']='wing_near';parents['tail_mid']='tail';parents['tail_tip']='tail_mid'
for side,pts in {'fore_near':[(174,147),(184,171),(205,192)],'fore_far':[(158,139),(178,158),(190,177)],'hind_near':[(148,149),(141,177),(162,194)],'hind_far':[(111,149),(97,173),(94,196)]}.items():
 for i,n in enumerate(['upper_'+side,'lower_'+side,'claw_'+side]):points[n]=pts[i];parents[n]='body' if i==0 else ('upper_' if i==1 else 'lower_')+side
joints={k:{'position':v,'parent':parents[k]} for k,v in points.items()}
seg=json.loads((CASE/'segmented/rear/segmentation.json').read_text())
order={'wing_far':0,'wing_near':8,'tail':3,'torso':5,'neck':6,'head':7,'fore_far':1,'fore_near':4,'hind_far':2,'hind_near':7,'claw_fore_far':2,'claw_fore_near':5,'claw_hind_far':3,'claw_hind_near':8}
layout={'canvas_size':[255,255],'facing':'rear','joints':joints,'parts':[]}
for part in seg['parts']:
 name=part['name'];bone=name if name in joints else 'body' if name=='torso' else 'upper_'+name
 layout['parts'].append({'name':name,'file':'segmented/rear/'+name+'.png','offset':part['offset'],'bone':bone,'z_index':order[name]})
save(Path('layouts/rear.json'),layout)
