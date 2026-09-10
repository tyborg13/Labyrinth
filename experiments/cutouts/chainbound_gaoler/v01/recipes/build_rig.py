"""Gaoler v01 authoring recipe. Semantic masks and joints are measured on its repaint."""
from pathlib import Path
import json, subprocess, hashlib
from PIL import Image,ImageDraw
R=Path(__file__).resolve().parents[1]; REPO=R.parents[3]
def write(p,v):
 p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2)+'\n')
def poly(name,points):return [name,points]
def rect(name,x0,y0,x1,y1):return poly(name,[[x0,y0],[x1,y0],[x1,y1],[x0,y1]])
# Weapon metal and each gripping hand have separate explicit owners. First owner wins.
front=[
 rect('hook',20,144,73,216),rect('chain_a',35,78,46,102),rect('chain_b',35,103,48,123),rect('chain_c',34,124,49,143),
 poly('hand_hook',[[46,62],[70,62],[79,77],[78,86],[71,98],[56,96],[46,85]]),
 rect('hand_fist',187,136,218,162),
 poly('wrist_strap',[[65,96],[73,99],[75,141],[66,141]]),
 poly('drape_a',[[74,98],[80,99],[86,119],[78,123],[74,112]]),
 poly('drape_b',[[78,121],[86,117],[99,132],[94,141],[84,133]]),
 poly('drape_c',[[93,133],[111,132],[114,139],[106,143],[94,143]]),
 poly('drape_d',[[110,132],[123,122],[129,122],[127,130],[113,142]]),
 poly('head',[[125,8],[163,8],[164,56],[154,62],[138,65],[121,56],[120,24]]),
 poly('torso',[[115,45],[165,45],[166,55],[180,64],[177,82],[174,98],[177,110],[116,111],[115,99],[112,85],[107,76],[98,69],[104,63],[113,61]]),
 rect('belt',111,110,179,121),
 poly('tabard',[[129,122],[161,121],[158,167],[152,205],[143,227],[134,215],[128,175]]),
 poly('coat_hook',[[113,121],[130,122],[128,170],[126,215],[119,207],[112,184],[109,178],[105,180],[98,181],[90,187],[78,204],[77,193],[85,171],[96,151],[105,133]]),
 poly('coat_fist',[[162,121],[178,122],[187,149],[201,181],[206,203],[199,197],[192,185],[179,180],[176,184],[169,190],[165,211],[161,201],[158,174]]),
 poly('arm_hook',[[93,72],[101,72],[112,82],[116,100],[109,109],[96,114],[82,111],[72,104],[70,99],[78,87],[89,83]]),
 poly('arm_fist',[[177,73],[187,77],[191,89],[203,102],[209,113],[215,132],[209,139],[191,139],[185,129],[185,116],[178,108],[172,97]]),
 rect('foot_hook',62,217,113,253),rect('foot_fist',168,217,215,254),
 poly('leg_hook',[[96,168],[119,160],[123,187],[118,218],[108,224],[82,219],[79,211],[88,194]]),
 poly('leg_fist',[[163,161],[181,169],[192,194],[204,211],[200,222],[174,222],[168,208],[166,188]])
]
rear=[
 rect('hook',212,143,254,213),rect('chain_a',229,83,241,103),rect('chain_b',229,104,242,124),rect('chain_c',228,125,242,142),
 poly('hand_hook',[[214,65],[232,64],[241,75],[240,83],[230,91],[222,95],[208,89],[207,77]]),
 rect('hand_fist',66,137,101,158),
 poly('wrist_strap',[[210,103],[219,101],[214,133],[208,137]]),
 poly('drape_a',[[204,105],[211,103],[208,119],[199,125],[195,119]]),
 poly('drape_b',[[196,120],[203,125],[192,137],[182,142],[178,135]]),
 poly('drape_c',[[165,135],[183,135],[184,143],[169,144],[161,139]]),
 poly('drape_d',[[151,123],[157,123],[168,133],[164,140],[155,133]]),
 poly('head',[[126,7],[158,7],[164,29],[160,53],[124,53],[118,43],[119,24]]),
 poly('torso',[[119,44],[160,44],[166,55],[172,65],[172,79],[163,88],[163,110],[107,111],[108,98],[105,87],[101,79],[97,72],[104,63],[114,59]]),
 rect('belt',105,110,164,123),
 poly('tabard',[[122,124],[151,124],[151,161],[146,204],[138,226],[130,213],[122,176]]),
 poly('coat_hook',[[155,123],[165,125],[172,148],[188,174],[201,198],[198,206],[184,188],[176,184],[171,189],[160,206],[156,197],[155,170]]),
 poly('coat_fist',[[106,123],[121,124],[122,165],[123,205],[117,209],[113,187],[109,180],[103,183],[99,183],[91,192],[78,202],[77,193],[84,174],[95,148]]),
 poly('arm_hook',[[170,69],[183,79],[191,86],[204,90],[210,82],[217,88],[220,102],[208,111],[195,116],[186,114],[177,110],[165,100],[160,91]]),
 poly('arm_fist',[[97,77],[106,83],[109,96],[102,109],[96,118],[95,137],[86,141],[69,138],[66,130],[71,116],[81,100],[88,86]]),
 rect('foot_fist',73,217,112,250),rect('foot_hook',166,218,213,254),
 poly('leg_fist',[[93,171],[115,166],[119,192],[114,211],[107,224],[83,222],[82,209],[86,190]]),
 poly('leg_hook',[[155,169],[179,171],[191,192],[200,210],[199,223],[173,225],[166,212],[161,194]])
]
# Native source-space skeleton. Hook/fist names denote anatomical sides, not screen sides.
joints_by_view={
 'front':{'root':([128,245],None),'pelvis':([141,132],'root'),'torso':([141,109],'pelvis'),'head':([142,58],'torso'),
 'upper_hook':([108,79],'torso'),'fore_hook':([91,101],'upper_hook'),'hand_hook':([63,85],'fore_hook'),
 'upper_fist':([178,84],'torso'),'fore_fist':([193,110],'upper_fist'),'hand_fist':([200,146],'fore_fist'),
 'thigh_hook':([112,150],'pelvis'),'shin_hook':([100,192],'thigh_hook'),'foot_hook':([98,222],'shin_hook'),
 'thigh_fist':([165,150],'pelvis'),'shin_fist':([179,194],'thigh_fist'),'foot_fist':([188,224],'shin_fist'),
 'tabard':([144,124],'pelvis'),'coat_hook':([119,125],'pelvis'),'coat_fist':([167,125],'pelvis'),
 'chain_a':([43,82],'hand_hook'),'chain_b':([43,103],'chain_a'),'chain_c':([43,124],'chain_b'),'hook':([43,144],'chain_c'),
 'drape_a':([76,101],'root'),'drape_b':([82,121],'root'),'drape_c':([96,136],'root'),'drape_d':([112,136],'root'),'wrist_strap':([69,97],'hand_hook')},
 'rear':{'root':([128,245],None),'pelvis':([137,132],'root'),'torso':([137,109],'pelvis'),'head':([141,50],'torso'),
 'upper_hook':([170,83],'torso'),'fore_hook':([191,104],'upper_hook'),'hand_hook':([223,81],'fore_hook'),
 'upper_fist':([104,84],'torso'),'fore_fist':([91,111],'upper_fist'),'hand_fist':([84,146],'fore_fist'),
 'thigh_hook':([163,151],'pelvis'),'shin_hook':([181,193],'thigh_hook'),'foot_hook':([182,224],'shin_hook'),
 'thigh_fist':([110,151],'pelvis'),'shin_fist':([101,193],'thigh_fist'),'foot_fist':([98,223],'shin_fist'),
 'tabard':([137,125],'pelvis'),'coat_hook':([159,126],'pelvis'),'coat_fist':([114,126],'pelvis'),
 'chain_a':([234,84],'hand_hook'),'chain_b':([234,104],'chain_a'),'chain_c':([234,125],'chain_b'),'hook':([234,143],'chain_c'),
 'drape_a':([208,106],'root'),'drape_b':([200,124],'root'),'drape_c':([182,139],'root'),'drape_d':([165,136],'root'),'wrist_strap':([215,104],'hand_hook')}
}
for view,owners in [('front',front),('rear',rear)]:
 ownership=R/'recipes'/f'{view}_ownership.json'
 # Boundary supplements are named by anatomy, never a catch-all torso owner.
 if view=='front':
  supplements=[rect('torso',100,44,174,63),rect('torso',98,61,115,78),rect('torso',165,58,180,79),rect('torso',111,98,121,110),
   rect('chain_a',32,63,60,102),rect('chain_b',35,103,60,123),rect('chain_c',34,124,58,143),
   rect('hand_hook',47,84,75,100),rect('arm_hook',75,77,99,111),rect('wrist_strap',60,100,77,142),
   rect('drape_a',80,110,92,120),rect('drape_b',88,120,103,134),rect('drape_d',99,120,125,133),
   rect('coat_hook',88,139,100,152),rect('tabard',126,174,160,228),rect('coat_fist',160,185,172,217),rect('coat_fist',188,184,209,209),
   rect('leg_hook',79,188,119,216),rect('arm_fist',180,61,217,142)]
 else:
  supplements=[rect('torso',107,43,125,62),rect('torso',92,60,113,82),rect('torso',162,99,179,120),rect('torso',100,98,110,119),rect('arm_hook',172,62,188,81),rect('arm_hook',178,80,222,119),rect('hand_hook',201,62,229,93),rect('chain_a',223,94,244,103),rect('chain_b',222,104,244,124),rect('chain_c',222,125,244,143),rect('arm_fist',63,103,103,136),rect('drape_b',187,119,208,141),rect('drape_c',177,137,187,143),rect('coat_hook',159,121,181,133),rect('coat_hook',171,143,201,196),rect('tabard',122,127,158,227),rect('leg_hook',162,199,170,218),rect('leg_fist',81,203,85,218),rect('arm_fist',89,82,94,85),rect('drape_c',168,133,176,136),rect('drape_b',186,140,191,143)]
 owners=owners+supplements
 write(ownership,{'priority_polygons':owners,'pixel_overrides':[]})
 out=R/'segmented'/(view+'_v05')
 subprocess.run(['python3',str(REPO/'tools/cutout_workflow.py'),'segment','--source',str(R/'source'/f'{view}_registered.png'),'--ownership',str(ownership),'--output',str(out)],check=True)
 report=json.loads((out/'segmentation.json').read_text())
 if not report['ok']:raise SystemExit(f'{view}: finish unassigned ownership before authoring')
 parts=[]
 for p in report['parts']:
  n=p['name'];bone=n
  if n.startswith('arm_'):bone='upper_'+n[4:]
  if n.startswith('leg_'):bone='thigh_'+n[4:]
  if n=='belt':bone='pelvis'
  z=15 if n.startswith(('chain_','hook','drape_','wrist_strap','hand_')) else 11 if n.startswith('arm_') else 12 if n=='torso' else 13 if n=='head' else 10 if n=='belt' else 7 if n.startswith(('coat_','tabard')) else 4
  parts.append({'name':n,'file':f'segmented/{view}_v05/'+p['file'],'offset':p['offset'],'bone':bone,'z_index':z,'equipment_slot':'cloak' if n.startswith(('coat_','tabard')) else ''})
 layout={'canvas_size':[255,255],'facing':view,'joints':{n:{'position':p,'parent':parent} for n,(p,parent) in joints_by_view[view].items()},'parts':parts,'landmarks':{'sole_hook':[86,246] if view=='front' else [185,250],'sole_fist':[198,250] if view=='front' else [95,247], 'chain_tip':[43,210] if view=='front' else [237,208]}}
 write(R/'layouts'/f'{view}.json',layout)
print('Semantic ownership and fresh Gaoler joints created')
