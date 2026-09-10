"""Zekarion v01's explicit registration, ownership and skin recipe.

Only rebuilds this fresh case. No production writes or historical builders.
The maintained segment and skin commands own extraction and mesh construction.
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw

CASE = Path(__file__).resolve().parents[1]
REPO = CASE.parents[3]

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')

def run(*args):
    subprocess.run([sys.executable, str(REPO/'tools/cutout_workflow.py'), *map(str,args)], check=True, stdout=subprocess.DEVNULL)

def polygon(*points):
    return list(points)

# First owner wins. Boundaries follow anatomical paint, never a residual catch-all.
OWNERS = {
 'front': [
  ['jaw', polygon((57,136),(79,126),(96,119),(99,126),(94,136),(80,145),(59,149))],
  ['head', polygon((49,58),(64,57),(69,80),(84,59),(98,52),(108,66),(108,83),(111,94),(105,108),(101,122),(89,134),(75,147),(57,152),(43,139),(37,119),(38,97),(46,74))],
  ['claw_far', polygon((30,159),(46,151),(59,154),(66,163),(74,164),(88,171),(90,187),(77,198),(49,201),(31,192))],
  ['claw_near', polygon((108,173),(124,171),(138,175),(148,178),(159,189),(157,201),(143,207),(136,208),(124,219),(113,220),(102,208),(103,186))],
  ['foot_far', polygon((91,170),(103,174),(109,182),(102,192),(92,205),(80,204),(82,191))],
  ['foot_near', polygon((168,179),(183,176),(190,192),(192,202),(174,208),(166,196))],
  ['foreleg_far', polygon((82,134),(98,134),(111,146),(111,157),(101,163),(90,168),(79,173),(62,175),(53,163),(62,153),(62,142))],
  ['foreleg_near', polygon((139,135),(153,136),(165,147),(162,159),(151,170),(139,184),(125,187),(111,181),(118,169),(131,161),(138,151))],
  ['hindleg_far', polygon((109,156),(122,162),(125,173),(114,185),(101,190),(92,178),(97,165))],
  ['hindleg_near', polygon((174,144),(189,145),(199,163),(195,178),(185,192),(171,195),(166,183),(164,166))],
  ['tail', polygon((188,128),(212,132),(229,148),(235,170),(243,202),(233,233),(216,248),(173,254),(85,254),(55,232),(55,186),(85,182),(98,201),(118,207),(146,199),(166,190),(183,179),(185,162))],
  ['wing_far', polygon((0,0),(111,0),(116,44),(113,56),(108,66),(105,80),(91,94),(74,120),(70,142),(55,157),(38,174),(21,158),(7,133),(0,108))],
  ['wing_near', polygon((137,0),(254,0),(254,181),(228,181),(221,166),(202,136),(190,133),(178,140),(170,151),(154,155),(136,144),(128,137),(130,121),(135,107),(139,88),(149,76),(152,54),(138,48),(131,40))],
  ['neck', polygon((101,40),(154,40),(154,92),(141,109),(146,141),(155,158),(142,169),(121,169),(103,156),(94,140),(97,119),(105,103),(108,83),(94,69))],
  ['neck', polygon((90,126),(101,122),(101,139),(90,139))],
  ['hindleg_far', polygon((86,162),(101,160),(103,176),(88,182))],
  ['claw_near', polygon((142,172),(161,174),(164,184),(158,190))],
  ['foot_near', polygon((162,179),(168,179),(173,198),(161,201))],
  ['torso', polygon((113,96),(157,96),(179,113),(198,136),(193,158),(182,177),(168,183),(152,175),(140,177),(124,185),(109,183),(105,167),(111,153),(122,145))],
 ],
 'rear': [
  ['jaw', polygon((171,78),(180,79),(183,85),(180,92),(175,91),(169,84))],
  ['head', polygon((128,35),(140,44),(150,48),(153,27),(161,38),(170,49),(178,60),(184,69),(186,79),(180,88),(171,86),(164,78),(151,74),(143,74),(136,77),(130,65),(119,64),(122,56),(132,53))],
  ['claw_far', polygon((197,158),(209,158),(219,165),(218,178),(208,181),(200,174))],
  ['claw_near', polygon((175,174),(188,173),(198,180),(204,185),(201,194),(190,191),(181,189),(171,184))],
  ['foot_near', polygon((137,192),(153,191),(165,196),(174,197),(176,206),(164,211),(152,207),(138,203))],
  ['foot_far', polygon((74,174),(86,177),(92,185),(90,194),(83,200),(70,194),(65,185))],
  ['foreleg_far', polygon((176,135),(187,139),(198,147),(207,156),(208,168),(197,172),(186,166),(177,158),(168,148))],
  ['foreleg_near', polygon((163,140),(175,142),(183,153),(188,169),(186,181),(177,184),(169,175),(165,164),(159,155))],
  ['hindleg_near', polygon((136,142),(156,145),(165,158),(168,169),(162,179),(151,188),(151,197),(139,204),(128,196),(125,188),(133,175),(130,164))],
  ['hindleg_far', polygon((76,150),(94,153),(106,162),(103,177),(93,188),(77,190),(68,176),(68,163))],
  ['tail', polygon((111,137),(128,136),(138,146),(135,163),(123,183),(109,196),(94,207),(77,211),(69,204),(64,195),(60,179),(63,162),(69,149),(78,140),(80,132),(66,132),(51,141),(40,158),(31,175),(27,193),(29,212),(35,227),(44,241),(78,254),(157,254),(198,235),(200,207),(189,190),(175,187),(164,190),(167,201),(177,210),(175,219),(155,224),(133,221),(111,216),(100,211),(112,201),(125,190),(136,174),(140,159))],
  ['wing_far', polygon((0,0),(127,0),(127,36),(110,39),(110,56),(116,76),(124,89),(122,105),(113,115),(101,131),(92,144),(91,155),(78,149),(68,135),(55,117),(43,115),(30,147),(36,166),(23,167),(0,134))],
  ['wing_near', polygon((176,0),(254,0),(254,194),(233,193),(221,177),(219,156),(214,145),(198,137),(191,135),(181,139),(170,150),(161,153),(156,146),(164,130),(171,115),(177,98),(183,88),(182,67),(177,47),(168,46),(168,34))],
  ['neck', polygon((138,70),(153,68),(164,78),(161,88),(166,100),(166,113),(155,123),(143,125),(133,117),(129,101),(133,87))],
  ['neck', polygon((110,60),(139,63),(149,87),(144,125),(123,134),(109,116),(110,91))],
  ['neck', polygon((164,91),(180,90),(180,113),(164,115))],
  ['tail', polygon((107,136),(137,145),(136,173),(119,199),(99,211),(69,211),(59,193),(66,181),(83,189),(94,186),(105,173))],
  ['tail', polygon((88,194),(137,202),(175,207),(184,216),(174,225),(128,224),(94,215))],
  ['hindleg_near', polygon((149,168),(174,165),(173,188),(148,194))],
  ['foot_near', polygon((127,194),(154,192),(178,200),(178,213),(139,215),(127,206))],
  ['foreleg_near', polygon((187,162),(207,161),(206,182),(188,182))],
  ['wing_near', polygon((177,129),(207,128),(208,145),(177,145))],
  ['claw_far', polygon((211,172),(226,170),(225,188),(209,188))],
  ['claw_near', polygon((197,174),(213,176),(212,193),(197,192))],
  ['wing_far', polygon((22,151),(40,152),(43,178),(27,177))],
  ['tail', polygon((22,170),(43,164),(53,140),(72,130),(82,131),(73,144),(52,164),(45,193),(44,214),(22,216))],
  ['head', polygon((116,26),(166,25),(182,60),(184,85),(176,96),(158,86),(148,62),(125,57))],
  ['tail', polygon((23,122),(75,119),(89,138),(79,156),(76,178),(55,178),(27,156))],
  ['neck', polygon((106,112),(121,112),(122,127),(106,128))],
  ['head', polygon((108,33),(116,33),(119,64),(108,64))],
  ['foreleg_far', polygon((201,152),(220,151),(225,167),(208,168))],
  ['tail', polygon((56,172),(73,171),(74,190),(57,190))],
  ['tail', polygon((20,227),(33,227),(35,245),(19,245))],
  ['hindleg_near', polygon((120,179),(131,179),(131,205),(120,205))],
  ['foot_near', polygon((155,188),(174,188),(174,201),(154,201))],
  ['claw_near', polygon((168,178),(205,182),(208,201),(171,197))],
  ['torso', polygon((135,100),(164,103),(178,123),(181,145),(169,161),(149,170),(129,167),(110,159),(92,171),(79,160),(85,141),(103,129),(117,115))],
 ]
}

JOINTS = {
 'front': {
  'root':(137,170,None), 'torso':(137,156,'root'),
  'neck':(127,151,'torso'),'head':(111,99,'neck'),'jaw':(93,126,'head'),
  'wing_far':(107,99,'torso'),'wing_near':(145,135,'torso'),
  'upper_far':(95,148,'torso'),'lower_far':(77,160,'upper_far'),'claw_far':(68,168,'lower_far'),
  'upper_near':(149,145,'torso'),'lower_near':(139,165,'upper_near'),'claw_near':(122,188,'lower_near'),
  'thigh_far':(117,166,'root'),'shin_far':(105,179,'thigh_far'),'foot_far':(96,190,'shin_far'),
  'thigh_near':(180,160,'root'),'shin_near':(178,177,'thigh_near'),'foot_near':(178,196,'shin_near'),
  'tail_base':(200,157,'root'),'tail_mid':(203,205,'tail_base'),'tail_tip':(137,224,'tail_mid')
 },
 'rear': {
  'root':(121,164,None),'torso':(137,135,'root'),
  'neck':(146,118,'torso'),'head':(148,74,'neck'),'jaw':(172,81,'head'),
  'wing_far':(107,126,'torso'),'wing_near':(164,142,'torso'),
  'upper_far':(180,149,'torso'),'lower_far':(193,157,'upper_far'),'claw_far':(207,168,'lower_far'),
  'upper_near':(170,151,'torso'),'lower_near':(178,165,'upper_near'),'claw_near':(183,181,'lower_near'),
  'thigh_far':(87,160,'root'),'shin_far':(80,174,'thigh_far'),'foot_far':(80,188,'shin_far'),
  'thigh_near':(145,159,'root'),'shin_near':(146,177,'thigh_near'),'foot_near':(147,198,'shin_near'),
  'tail_base':(113,167,'root'),'tail_mid':(57,212,'tail_base'),'tail_tip':(143,230,'tail_mid')
 }
}

def main():
    # Rear is uniformly fit with six native pixels of padding, no per-part fitting.
    rear=Image.open(CASE/'source/rear_alpha_generated.png').convert('RGBA')
    scaled=rear.resize((243,243),Image.Resampling.LANCZOS)
    registered=Image.new('RGBA',(255,255));registered.paste(scaled,(6,3))
    registered.save(CASE/'source/rear_registered.png')
    # The explicit rear landmarks above were authored against the 255px whole image;
    # transform those coordinates by the same registration before extracting parts.
    scale=243/255
    owners=json.loads(json.dumps(OWNERS)); joints=json.loads(json.dumps(JOINTS))
    for _,poly in owners['rear']:
        for p in poly:
            p[0]=round(p[0]*scale+6);p[1]=round(p[1]*scale+3)
    for value in joints['rear'].values():
        value[0]=round(value[0]*scale+6);value[1]=round(value[1]*scale+3)
    all_sources=[]
    for facing in ['front','rear']:
        definition={'priority_polygons':owners[facing],'pixel_overrides':[]}
        write(CASE/f'source/{facing}_ownership.json',definition)
        out=CASE/f'segmented/{facing}'
        if out.exists(): shutil.rmtree(out)
        run('segment','--source',CASE/f'source/{facing}_registered.png','--ownership',CASE/f'source/{facing}_ownership.json','--output',out)
        report=json.loads((out/'segmentation.json').read_text())
        if not report['ok']:
            print(facing,'UNASSIGNED',report['unassigned_pixels'],report['unassigned_coordinates'][:30]);return
        joint_defs={name:{'position':v[:2],'parent':v[2]} for name,v in joints[facing].items()}
        layer={'wing_far':0,'foreleg_far':3,'claw_far':4,'hindleg_far':1,'foot_far':2,
               'torso':5,'neck':8,'head':9,'jaw':10,'wing_near':11,
               'hindleg_near':6,'foot_near':7,'foreleg_near':12,'claw_near':13,'tail':14}
        bone={'foreleg_far':'upper_far','foreleg_near':'upper_near','hindleg_far':'thigh_far','hindleg_near':'thigh_near','tail':'tail_base'}
        parts=[]
        for p in report['parts']:
            p=dict(p);name=p['name'];p.update(file=f'segmented/{facing}/{name}.png',bone=bone.get(name,name),z_index=layer[name]);parts.append(p)
        # Concealed caps copy generated scale paint. They are entirely under opaque
        # original paint in rest, with explicit small anatomical extents and owners.
        caps=[]
        for name,radius in [('upper_near',11),('upper_far',8),('head',9),('jaw',5),('wing_near',9),('wing_far',8),('tail_base',10)]:
            cx,cy=joints[facing][name][:2];radius=int(radius)
            bounds=(cx-radius,cy-radius,cx+radius+1,cy+radius+1)
            mask=Image.new('L',(255,255));ImageDraw.Draw(mask).ellipse(bounds,fill=255)
            alpha=Image.open(CASE/f'source/{facing}_registered.png').getchannel('A')
            opaque=alpha.point(lambda p:255 if p==255 else 0)
            mask=ImageChops.multiply(mask,opaque)
            crop=mask.getbbox()
            if not crop: continue
            tex=Image.open(CASE/'source/concealed_scales_generated.png').convert('RGBA').resize((64,64),Image.Resampling.LANCZOS)
            # Same one-to-one registered texture sampling, no anisotropic stretches.
            cap=tex.crop((12,12,12+crop[2]-crop[0],12+crop[3]-crop[1]));cap.putalpha(mask.crop(crop))
            cap_path=CASE/f'assets/{facing}/cap_{name}.png';cap_path.parent.mkdir(parents=True,exist_ok=True);cap.save(cap_path)
            parent=joint_defs[name]['parent']
            parts.append({'name':f'cap_{name}','file':str(cap_path.relative_to(CASE)),'offset':list(crop[:2]),'bone':parent,'z_index':-2})
            caps.append({'name':name,'center':[cx,cy],'radius':radius,'clip':'registered source alpha == 255','owner':parent,'texture_registration':'whole generated material uniformly resized to 64px; crop begins at [12,12]'})
        layout={'canvas_size':[255,255],'facing':facing,'joints':joint_defs,'parts':parts,
                'landmarks':{'floor_contacts':{n:joints[facing][n][:2] for n in ['claw_far','claw_near','foot_far','foot_near']}}}
        write(CASE/f'layouts/{facing}.json',layout)
        fields=[]
        def field(name,part_names,bones,bands,grid=(2,2)):
            fields.append({'name':name,'parts':part_names,'bones':bones,'grid':list(grid),'bands':bands})
        def band(center,axis,width): return {'center':center,'axis':axis,'width':width}
        for side in ['near','far']:
            upper,lower,tip='upper_'+side,'lower_'+side,'claw_'+side
            a,b,c=(joints[facing][n][:2] for n in [upper,lower,tip])
            axis=[c[0]-a[0],c[1]-a[1]]
            length=(axis[0]**2+axis[1]**2)**0.5
            terminal=[c[i]-axis[i]/length*10 for i in [0,1]]
            field('fore_'+side,['foreleg_'+side],['torso',upper,lower,tip],[band(a,axis,16),band(b,axis,14),band(terminal,axis,12)],(2,1))
            upper,lower,tip='thigh_'+side,'shin_'+side,'foot_'+side
            a,b,c=(joints[facing][n][:2] for n in [upper,lower,tip]);axis=[c[0]-a[0],c[1]-a[1]]
            length=(axis[0]**2+axis[1]**2)**0.5
            terminal=[c[i]-axis[i]/length*10 for i in [0,1]]
            field('hind_'+side,['hindleg_'+side],['root',upper,lower,tip],[band(a,axis,24),band(b,axis,12),band(terminal,axis,12)],(2,1))
        # The neck bends from the fixed chest and blends into the rigid head.
        neck=joints[facing]['neck'][:2];head=joints[facing]['head'][:2]
        axis=[head[0]-neck[0],head[1]-neck[1]]
        field('neck',['neck'],['torso','neck','head'],[band(neck,axis,14),band(head,axis,20)])
        # Wings keep terminal membranes rigid; only the small root collar blends.
        for side in ['near','far']:
            origin=joints[facing]['wing_'+side][:2]
            field('wing_'+side,['wing_'+side],['torso','wing_'+side],[band([origin[0],origin[1]-10],[0,-1],18)])
        # Tail's source curve receives two broad, non-overlapping spatial bands.
        field('tail',['tail'],['tail_base','tail_mid','tail_tip'],[
            band(joints[facing]['tail_mid'][:2],[0,1],34),
            band(joints[facing]['tail_tip'][:2],[-1,0] if facing=='front' else [1,0],38)])
        skinned=CASE/f'layouts/{facing}_skinned.json'
        if skinned.exists(): skinned.unlink()
        recipe=CASE/f'recipes/{facing}_skinned.skin.json'
        write(recipe,{'facing':facing,'input_layout':f'layouts/{facing}.json','output_layout':f'layouts/{facing}_skinned.json','fields':fields})
        run('skin',CASE,'--recipe',recipe)
        write(CASE/f'recipes/{facing}_concealed_caps.json',caps)
    config=json.loads((CASE/'cutout.json').read_text())
    durations={'idle':(24,1.8,True),'walk':(32,0.96,True),'claw':(32,0.90,False),'breath':(32,1.30,False),'charge':(32,1.10,False),'call':(32,1.10,False)}
    config['clips']={k:{'frames':v[0],'duration':v[1],'loop':v[2],**({'preview_cycles':2} if v[2] else {}),**({'travel':'motion'} if k=='walk' else {})} for k,v in durations.items()}
    # Match renderer.gd's real playback/result boundaries, separately from poses.
    for clip,contact in [('claw',0.42),('charge',0.38),('call',0.50)]:
        config['clips'][clip]['phase_curve']=[[0,0],[contact*.75,.30],[contact*.90,.42],[contact,.55],[contact+(1-contact)*.30,.68],[1,1]]
    release=4/30
    config['clips']['breath']['phase_curve']=[[0,0],[release*.65,.30],[release*.85,.42],[release,.55],[8/30,.68],[1,1]]
    config['rigid_bones']=['head','jaw','claw_far','claw_near','foot_far','foot_near']
    config['contact_feet']=['claw_far','claw_near','foot_far','foot_near']
    config['sources']=[str(p.relative_to(CASE)) for folder in ['source','recipes'] for p in sorted((CASE/folder).rglob('*')) if p.is_file() and p.suffix!='.import'] + ['layouts/front.json','layouts/rear.json']
    config['source_baseline']={'kind':'new_character','art_status':'registered original front plus generated matching rear; explicit semantic parts and concealed caps'}
    write(CASE/'cutout.json',config)
    for png in CASE.rglob('*.png'):
        Path(str(png)+'.import').write_text('[remap]\n\nimporter="keep"\n')
    write(CASE/'recipes/registration.json',{'source_size':[255,255],'front':'byte-identical original; no transforms','rear':{'untouched_source':'source/rear_alpha_generated.png','uniform_scale':243/1254,'destination':[6,3],'size':[243,243]},'projection':'2:1 board floor; individual limb contacts recorded in layouts','digests':{str(p.relative_to(CASE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (CASE/'source').glob('*.png')}})
    print('Built Zekarion case from recorded source paint and ownership.')

if __name__=='__main__': main()
