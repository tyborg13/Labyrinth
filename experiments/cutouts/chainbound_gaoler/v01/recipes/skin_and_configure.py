from pathlib import Path
import json,subprocess
R=Path(__file__).resolve().parents[1];REPO=R.parents[3]
def write(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
config=json.loads((R/'cutout.json').read_text())
config['clips']={'idle':{'frames':24,'duration':1.6,'loop':True,'preview_cycles':2},'walk':{'frames':48,'duration':0.36,'loop':True,'preview_cycles':3,'travel':'motion'},'chain_reel':{'frames':31,'duration':0.24,'loop':False},'manacle_pin':{'frames':39,'duration':0.57,'loop':False},'strike':{'frames':31,'duration':0.24,'loop':False}}
config['rigid_bones']=['head','hand_hook','hand_fist','hook','foot_hook','foot_fist'];config['contact_feet']=['foot_hook','foot_fist']
config['source_baseline']={'kind':'new_character','art_status':'imagegen repaint; front style accepted before anatomy ownership; no old-paint rig'}
config['sources']=['art_phase_review.json','art_phase_sha256.json']
config['draw_order_parts']={}
write(R/'cutout.json',config)
for view in ['front','rear']:
 p=R/'layouts'/f'{view}.json';layout=json.loads(p.read_text())
 for name in ['drape_a','drape_b','drape_c','drape_d']:layout['joints'][name]['parent']='pelvis'
 layout['landmarks']['drape_end']=[125,126] if view=='front' else [155,125]
 write(p,layout)
 fields=[]
 for side in ['hook','fist']:
  knee=layout['joints']['shin_'+side]['position'];ankle=layout['joints']['foot_'+side]['position'];elbow=layout['joints']['fore_'+side]['position'];hand=layout['joints']['hand_'+side]['position']
  fields.append({'name':'leg_'+side,'parts':['leg_'+side,'thigh_'+side+'_under'],'bones':['thigh_'+side,'shin_'+side,'foot_'+side],'grid':[2,1],'bands':[{'center':knee,'axis':[0,1],'width':14},{'center':[ankle[0],ankle[1]-10],'axis':[0,1],'width':10}]})
  axis=[-1,0] if view=='front' else [1,0]
  fields.append({'name':'arm_'+side,'parts':['arm_'+side,'shoulder_'+side+'_under'],'bones':['upper_'+side,'fore_'+side,'hand_'+side],'grid':[2,1],'bands':[{'center':elbow,'axis':axis if side=='hook' else [0,1],'width':12},{'center':hand if side=='hook' else [hand[0],hand[1]-9],'axis':axis if side=='hook' else [0,1],'width':10}]})
 recipe={'facing':view,'input_layout':f'layouts/{view}.json','output_layout':f'layouts/{view}_skinned_v02.json','fields':fields}
 rp=R/'recipes'/f'{view}_skin.json';write(rp,recipe)
 subprocess.run(['python3',str(REPO/'tools/cutout_workflow.py'),'skin',str(R),'--recipe',str(rp)],check=True)
 config=json.loads((R/'cutout.json').read_text());config['draw_order_parts'][view]=['Skin_leg_hook','Skin_leg_fist','Skin_thigh_hook_under','Skin_thigh_fist_under','foot_hook','foot_fist','hand_fist'];write(R/'cutout.json',config)
config=json.loads((R/'cutout.json').read_text());config['sources']=sorted(set(config['sources']+[str(p.relative_to(R)) for folder in ['source','recipes'] for p in (R/folder).rglob('*') if p.is_file()]))
write(R/'cutout.json',config)
