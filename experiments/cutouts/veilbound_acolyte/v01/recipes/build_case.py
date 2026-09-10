"""Explicit Veilbound Acolyte v01 registration/ownership; no generated paint.

Run from the repository root. New segmentation/skin outputs are created by the
maintained cutout workflow. This recipe belongs only to this version/creature.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[3]

def save(path, value):
    (ROOT / path).parent.mkdir(parents=True, exist_ok=True)
    (ROOT / path).write_text(json.dumps(value, indent=2) + '\n')

def run(*args):
    if args[0]=='segment' and Path(args[-1]).exists():
        report=json.loads((Path(args[-1])/'segmentation.json').read_text())
        if report['ok'] and report['source_sha256']==hashlib.sha256(Path(args[2]).read_bytes()).hexdigest() and report['ownership_sha256']==hashlib.sha256(Path(args[4]).read_bytes()).hexdigest():
            return
    if args[0]=='skin':
        recipe=json.loads(Path(args[-1]).read_text())
        target=ROOT/recipe['output_layout']
        if target.exists() and json.loads((ROOT/('recipes/'+target.stem+'.skin.json')).read_text())==recipe:
            return
    subprocess.run([sys.executable, str(PROJECT / 'tools/cutout_workflow.py'), *map(str, args)], check=True, stdout=subprocess.DEVNULL)

def polygon(points):
    mask = Image.new('L', (255, 255))
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask

# Crop the substantive alpha silhouette once; discard only outside-source
# alpha-1 generation dust. Preserve the selected crop's RGB and alpha exactly.
rear = Image.open(ROOT / 'source/rear_generated.png').convert('RGBA')
rear_crop = (303, 117, 972, 1151)
rear_scale = 218 / (rear_crop[3] - rear_crop[1])
resized = rear.crop(rear_crop).resize((round((rear_crop[2]-rear_crop[0])*rear_scale), 218), Image.Resampling.NEAREST)
registered = Image.new('RGBA', (255, 255))
registered.paste(resized, (76, 19))
registered.save(ROOT / 'source/rear_registered.png')

OWNERS = {
    'front': [
        ['orb', [[54,55],[95,55],[95,93],[54,93]]],
        ['cast_hand', [[51,93],[78,93],[81,102],[81,108],[87,115],[83,122],[69,120],[52,111]]],
        ['strike_hand', [[120,114],[140,112],[146,118],[146,130],[140,135],[123,133],[119,127]]],
        ['cast_sleeve', [[65,99],[92,99],[97,93],[105,98],[108,106],[103,127],[99,148],[84,166],[75,161],[66,120],[82,122],[87,116]]],
        ['strike_sleeve', [[158,85],[185,85],[185,123],[176,155],[158,169],[145,177],[143,149],[145,132],[147,119],[140,111],[153,109]]],
        ['hood', [[97,16],[164,16],[164,72],[152,77],[139,81],[132,83],[118,82],[101,75],[95,64]]],
        ['skirt_l', [[77,160],[112,148],[127,151],[127,242],[67,242]]],
        ['skirt_r', [[128,146],[185,154],[209,211],[209,242],[128,242]]],
        ['torso', [[90,65],[180,65],[184,86],[166,120],[161,164],[146,200],[124,208],[81,204],[79,170],[99,127]]],
    ],
    'rear': [
        ['orb', [[164,54],[205,54],[205,90],[164,90]]],
        ['cast_hand', [[170,97],[181,88],[191,88],[193,84],[204,85],[205,109],[177,113],[169,106]]],
        ['cast_sleeve', [[133,84],[151,85],[161,99],[173,97],[179,110],[181,144],[172,163],[156,165],[136,140],[130,114]]],
        ['strike_sleeve', [[81,86],[90,87],[94,104],[93,125],[89,140],[82,136],[73,116],[73,99]]],
        ['hood', [[70,12],[152,12],[152,69],[145,75],[113,78],[88,73],[70,60]]],
        ['skirt_l', [[65,140],[115,140],[127,151],[127,243],[45,243],[45,180]]],
        ['skirt_r', [[128,145],[177,151],[207,180],[207,243],[128,243]]],
        ['torso', [[76,68],[138,67],[157,79],[156,91],[147,116],[148,149],[166,196],[145,204],[122,169],[88,160],[86,122]]],
    ],
}

JOINTS = {
    'front': {
        'root': [128,230], 'torso': [130,119], 'hood': [130,77],
        'cast_arm': [102,98], 'cast_hand': [81,116], 'orb': [74,78],
        'strike_arm': [163,97], 'strike_hand': [144,124],
        'support_l': [111,234], 'support_r': [169,224],
    },
    'rear': {
        'root': [128,230], 'torso': [118,116], 'hood': [118,76],
        'cast_arm': [143,99], 'cast_hand': [176,105], 'orb': [185,73],
        'strike_arm': [85,101], 'strike_hand': [88,125],
        'support_l': [91,226], 'support_r': [142,234],
    },
}
# Rear registration follows the shared grounded hem, rather than the orb-inclusive bbox.
for name, point in JOINTS['rear'].items():
    if name!='root': point[0]+=18
for _, points in OWNERS['rear']:
    for point in points: point[0]+=18

parents = {'root':None,'torso':'root','hood':'torso','cast_arm':'torso','cast_hand':'cast_arm','orb':'cast_hand','strike_arm':'torso','strike_hand':'strike_arm','support_l':'root','support_r':'root'}
part_bones = {'orb':'orb','cast_hand':'cast_hand','strike_hand':'strike_hand','cast_sleeve':'cast_arm','strike_sleeve':'strike_arm','hood':'hood','torso':'torso','skirt_l':'torso','skirt_r':'torso'}
layers = {'orb':8,'cast_hand':7,'strike_hand':9,'cast_sleeve':6,'strike_sleeve':8,'hood':10,'torso':4,'skirt_l':2,'skirt_r':3}

for facing, owners in OWNERS.items():
    save('source/'+facing+'_ownership.json', {'priority_polygons': owners, 'pixel_overrides': ([{'point':p,'name':'cast_sleeve'} for p in [[93,96],[93,97],[75,121]]] if facing=='front' else [])})
    run('segment', '--source', ROOT / ('source/'+facing+'_registered.png'), '--ownership', ROOT / ('source/'+facing+'_ownership.json'), '--output', ROOT / ('segmented/'+facing))
    report = json.loads((ROOT / ('segmented/'+facing+'/segmentation.json')).read_text())
    parts = []
    for part in report['parts']:
        name = part['name']
        parts.append(dict(part, file='segmented/'+facing+'/'+name+'.png', bone=part_bones[name], z_index=layers[name], equipment_slot='robe' if 'sleeve' in name or name in ['torso','skirt_l','skirt_r'] else name))
    # Concealed brown cloth from the generated source's central interior only.
    # No checkerboard/background is selected. Caps lie below accepted opaque
    # pixels in rest, while filling the true sleeve/torso width during reach.
    source = Image.open(ROOT / ('source/'+facing+'_registered.png')).convert('RGBA')
    cloth = Image.open(ROOT / 'source/hidden_generated.png').convert('RGBA')
    hidden = []
    patch_defs = ([('under_cast',[96,106,107,145],[580,690,635,885],'torso',1),
                   ('under_strike',[145,110,177,180],[558,710,654,920],'torso',1),
                   ('under_strike_hand',[119,112,147,139],[560,530,700,665],'torso',1),
                   ('cast_cap',[96,96,108,119],[590,690,650,805],'cast_arm',3),
                   ('strike_cap',[151,92,166,122],[585,680,660,830],'strike_arm',3)] if facing=='front' else
                  [('under_cast',[133,96,152,146],[580,680,675,930],'torso',1),
                   ('under_strike',[81,98,94,132],[580,690,645,860],'torso',1),
                   ('cast_cap',[132,87,151,113],[580,680,675,810],'cast_arm',3)])
    for name, target, crop, bone, layer in patch_defs:
        if facing=='rear':
            target[0]+=18
            target[2]+=18
        image = cloth.crop(crop).resize((target[2]-target[0],target[3]-target[1]),Image.Resampling.NEAREST)
        # Only fully opaque accepted source pixels may conceal new material.
        # Partial-alpha edges remain byte-for-byte the source's original paint.
        mask = source.getchannel('A').crop(target).point(lambda a:255 if a>=(255 if facing=='front' else 250) else 0)
        if facing=='front' and name=='under_strike':
            # Continue the torso's concealed flank under the raised sleeve,
            # without retaining a second, unmoving copy of the sleeve outline.
            body=polygon([[145,110],[159,110],[166,135],[177,180],[145,180]]).crop(target)
            from PIL import ImageChops
            mask=ImageChops.multiply(mask,body)
        image.putalpha(mask)
        path='assets/'+facing+'/'+name+'.png'
        (ROOT/path).parent.mkdir(parents=True, exist_ok=True)
        image.save(ROOT/path)
        parts.append({'name':name,'file':path,'offset':target[:2],'bone':bone,'z_index':layer,'equipment_slot':'robe'})
        hidden.append({'name':name,'source':'source/hidden_generated.png','source_crop':crop,'target_rect':target,'scale':[(target[2]-target[0])/(crop[2]-crop[0]),(target[3]-target[1])/(crop[3]-crop[1])],'alpha_rule':('clip only to original fully opaque rest coverage' if facing=='front' else 'rear interior alpha>=250 only, beneath new generated paint'),'purpose':bone+' concealed width'})
    save('recipes/'+facing+'_hidden.json',hidden)
    layout={'canvas_size':[255,255],'facing':facing,'joints':{k:{'position':v,'parent':parents[k]} for k,v in JOINTS[facing].items()},'parts':parts,
            'landmarks':{'support_l':{'position':JOINTS[facing]['support_l'],'visibility':'concealed foot beneath robe hem'},'support_r':{'position':JOINTS[facing]['support_r'],'visibility':'concealed foot beneath robe hem'}}}
    save('layouts/'+facing+'.json',layout)
    fields=[]
    for arm in ['cast','strike']:
        a=JOINTS[facing][arm+'_arm'];h=JOINTS[facing][arm+'_hand']
        axis=[h[0]-a[0],h[1]-a[1]]
        fields.append({'name':facing+'_'+arm+'_sleeve','parts':[arm+'_sleeve']+([arm+'_cap'] if any(p['name']==arm+'_cap' for p in parts) else []),
                       'bones':['torso',arm+'_arm',arm+'_hand'],'grid':[2,2],
                       'bands':[{'center':a,'axis':axis,'width':16},{'center':h,'axis':axis,'width':12}]})
    # Lower robe columns share smooth torso-to-concealed-support weights;
    # no invented knees or boots. The two source panels overlap only at edges.
    for side in ['l','r']:
        fields.append({'name':facing+'_skirt_'+side,'parts':['skirt_'+side],'bones':['torso','support_'+side],'grid':[2,2],
                       'bands':[{'center':[146 if facing=='rear' else 128,205],'axis':[0,1],'width':54}]})
    recipe={'facing':facing,'input_layout':'layouts/'+facing+'.json','output_layout':'layouts/'+facing+'_skinned.json','fields':fields}
    save('recipes/'+facing+'_skin.json',recipe)
    run('skin',ROOT,'--recipe',ROOT/('recipes/'+facing+'_skin.json'))

# Apply one continuous two-dimensional robe field after maintained skin.
# Both split paint panels use identical source-coordinate weights.
for facing in ['front','rear']:
    path=ROOT/('layouts/'+facing+'_skinned.json')
    layout=json.loads(path.read_text())
    for mesh in layout['joint_meshes']:
        if not mesh['replaces_part'].startswith('skirt_'):
            continue
        def smooth(value):
            value=max(0,min(1,value))
            return value*value*(3-2*value)
        weights={name:[] for name in ['torso','support_l','support_r']}
        for x,y in mesh['vertices']:
            lower=smooth((y-178)/54)
            right=smooth((x-(93 if facing=='rear' else 75))/110)
            weights['torso'].append(1-lower)
            weights['support_l'].append(lower*(1-right))
            weights['support_r'].append(lower*right)
        mesh['weights']=weights
        mesh['family']=facing+'_continuous_robe'
    save('layouts/'+facing+'_skinned.json',layout)

save('recipes/registration.json',{'front':{'source':'source/front_original.png','operation':'unchanged 255px copy','bounds':[53,19,202,237]},
     'rear':{'source':'source/rear_generated.png','crop':rear_crop,'uniform_scale':rear_scale,'target_origin':[76,19],'target_size':list(resized.size),'filter':'nearest; retain alpha'},
     'projection':'2:1 board; front looks down-left, rear up-right; reflection supplies the other two directions',
     'concealed_supports':'The source shows a grounded floor-length robe and no feet. Support joints are inferred beneath the hem, not a visible boot anatomy claim.'})
config=json.loads((ROOT/'cutout.json').read_text())
config['clips']={'idle':{'frames':24,'duration':1.8,'loop':True,'preview_cycles':2},
                 'walk':{'frames':32,'duration':0.68,'loop':True,'preview_cycles':2,'travel':'motion'},
                 'cast':{'frames':32,'duration':0.9,'loop':False},
                 'attack':{'frames':32,'duration':0.6,'loop':False}}
config['rigid_bones']=['hood','cast_hand','strike_hand','orb','support_l','support_r']
config['contact_feet']=['support_l','support_r']
config['sources']=sorted(str(p.relative_to(ROOT)) for directory in ['source','recipes'] for p in (ROOT/directory).rglob('*') if p.is_file())+['layouts/front.json','layouts/rear.json']
config['source_baseline']={'kind':'new_character','art_status':'preserved accepted front; generated matching rear and concealed interior cloth','base_commit':'01c7dccbc931ae7dddf3eb8f797fb3d1d33def3e','front_sha256':hashlib.sha256((ROOT/'source/front_original.png').read_bytes()).hexdigest()}
save('cutout.json',config)
for p in ROOT.rglob('*.png'):
    Path(str(p)+'.import').write_text('[remap]\n\nimporter="keep"\n')
