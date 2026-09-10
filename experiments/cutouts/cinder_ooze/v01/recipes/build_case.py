"""Cinder Ooze v01's explicit registration/ownership recipe.

This version owns only its derived segmented/assets/layout files. Untouched
source paint and generation requests are retained separately. Run from any cwd.
"""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

CASE = Path(__file__).resolve().parents[1]
REPO = CASE.parents[3]
TOOL = REPO / 'tools/cutout_workflow.py'

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')

def run(*args):
    subprocess.run([sys.executable, str(TOOL), *map(str, args)], cwd=REPO, check=True)

# Every polygon is an explicit semantic distal soft lobe. All shell plates,
# face paint and proximal lobe crust remain on the one rigid mass owner.
# Values are registered pixels, never independently fitted part rectangles.
VIEWS = {
    'front': [
        {'name': 'left_outer', 'root': [38,174], 'tip': [19,198], 'polygon': [[0,170],[39,162],[45,174],[39,187],[43,207],[8,212]], 'axis': [-0.55,1]},
        {'name': 'front_left', 'root': [69,185], 'tip': [68,214], 'polygon': [[47,187],[62,176],[78,185],[85,225],[49,224]], 'axis': [0,1]},
        {'name': 'front_mid', 'root': [103,188], 'tip': [101,212], 'polygon': [[85,185],[96,179],[110,182],[127,221],[85,226]], 'axis': [0,1]},
        {'name': 'near_right', 'root': [177,178], 'tip': [159,226], 'polygon': [[175,161],[190,174],[187,192],[179,205],[175,223],[162,238],[133,232],[136,215],[150,207],[153,192],[166,184]], 'axis': [-0.35,1]},
        {'name': 'right_outer', 'root': [202,178], 'tip': [200,201], 'polygon': [[192,167],[212,170],[224,198],[208,213],[185,216],[177,203],[187,192]], 'axis': [0.25,1]},
        {'name': 'far_right', 'root': [220,161], 'tip': [235,178], 'polygon': [[210,151],[231,150],[253,165],[251,194],[219,194],[210,177]], 'axis': [0.7,1]},
    ],
    'rear': [
        {'name': 'left_outer', 'root': [38,174], 'tip': [18,188], 'polygon': [[0,160],[33,159],[48,171],[40,188],[27,198],[0,197]], 'axis': [-0.8,1]},
        {'name': 'front_left', 'root': [58,179], 'tip': [44,196], 'polygon': [[38,177],[55,167],[68,170],[72,197],[53,211],[30,208]], 'axis': [-0.55,1]},
        {'name': 'front_mid', 'root': [86,187], 'tip': [100,225], 'polygon': [[73,170],[91,177],[103,190],[115,193],[132,217],[117,232],[90,239],[74,223],[71,205]], 'axis': [0.25,1]},
        {'name': 'near_right', 'root': [165,187], 'tip': [186,217], 'polygon': [[151,174],[170,175],[180,186],[188,198],[203,203],[204,224],[170,233],[156,217],[151,198]], 'axis': [0.5,1]},
        {'name': 'right_outer', 'root': [202,179], 'tip': [212,200], 'polygon': [[187,167],[207,171],[222,185],[230,207],[200,216],[181,203],[183,186]], 'axis': [0.35,1]},
        {'name': 'far_right', 'root': [225,179], 'tip': [236,190], 'polygon': [[214,170],[244,177],[255,196],[244,205],[219,198],[210,184]], 'axis': [0.8,1]},
    ],
}

def build():
    config = json.loads((CASE/'cutout.json').read_text())
    config['clips'] = {
        'idle': {'frames':24,'duration':1.8,'loop':True,'preview_cycles':2},
        'walk': {'frames':36,'duration':0.62,'loop':True,'preview_cycles':2,'travel':'motion'},
        'attack': {'frames':36,'duration':0.7,'loop':False},
        'bloom': {'frames':40,'duration':0.8,'loop':False},
    }
    contacts = ['contact_'+v['name'] for v in VIEWS['front']]
    config['contact_feet'] = contacts
    config['rigid_bones'] = ['mass',*contacts]
    config['source_baseline'] = {'kind':'new_character','art_status':'accepted front preserved; matching generated rear; explicit soft-lobe ownership','front_sha256':hashlib.sha256((CASE/'source/front_original.png').read_bytes()).hexdigest()}
    hidden = Image.open(CASE/'source/hidden_generated.png').convert('RGBA')
    # Only genuine interior soft material supplies the tiny concealed bridges.
    # Deliberate crop/registration; no replication or stretched visible strips.
    hidden_crop = [560,340,1230,625]
    material = hidden.crop(hidden_crop).resize((160,68), Image.Resampling.LANCZOS)
    hidden_registered = Image.new('RGBA',(255,255))
    hidden_registered.paste(material,(46,151))
    hidden_registered.save(CASE/'source/hidden_registered.png')
    write(CASE/'recipes/hidden_registration.json', {'source':'source/hidden_generated.png','crop':hidden_crop,'resized_size':[160,68],'offset':[46,151],'usage':'Only pixels behind eroded fully opaque proximal seam bands. Never overwrites accepted source; no exposed rest silhouette change.'})
    for view,lobes in VIEWS.items():
        ownership = {'coordinate_space':'255x255 registered source','priority_polygons':[[v['name'],v['polygon']] for v in lobes]+[['crust_mass',[[0,0],[254,0],[254,254],[0,254]]]],'rationale':'Explicit distal soft-lobe outlines first; the complete remaining source is the coherent crusted mass, including eyes, shell and attached proximal plates. No independent plate rotations.'}
        write(CASE/f'source/{view}_ownership.json',ownership)
        derived=CASE/f'segmented/{view}'
        if derived.exists(): shutil.rmtree(derived)
        run('segment','--source',CASE/f'source/{view}_registered.png','--ownership',CASE/f'source/{view}_ownership.json','--output',derived)
        source=Image.open(CASE/f'source/{view}_registered.png')
        threshold = 255 if view == 'front' else 240
        opaque=source.getchannel('A').point(lambda a:255 if a>=threshold else 0).filter(ImageFilter.MinFilter(5))
        parts=[]
        joints={'root':{'position':[128,207],'parent':None},'mass':{'position':[128,137],'parent':'root'}}
        fields=[]
        layout={'canvas_size':[255,255],'facing':view,'joints':joints,'parts':parts,'contact_lobes':lobes,'grounding':'six distributed contact tendrils; 2:1 projected travel; shell is a rigid mass'}
        segmentation=json.loads((derived/'segmentation.json').read_text())
        by_name={p['name']:p for p in segmentation['parts']}
        for i,lobe in enumerate(lobes):
            name=lobe['name'];root=lobe['root'];tip=lobe['tip'];axis=lobe['axis']
            bend='bend_'+name;contact='contact_'+name
            joints[bend]={'position':root,'parent':'root'}
            joints[contact]={'position':tip,'parent':'root'}
            part=by_name[name].copy();part.update({'file':f'segmented/{view}/{name}.png','bone':bend,'z_index':12+i})
            parts.append(part)
            # A six-pixel proximal overlap sits under the original opaque drawing.
            mask=Image.new('L',(255,255));ImageDraw.Draw(mask).ellipse((root[0]-10,root[1]-7,root[0]+10,root[1]+7),fill=255)
            mask=ImageChops.multiply(mask,opaque)
            cap=hidden_registered.copy();cap.putalpha(ImageChops.multiply(cap.getchannel('A'),mask))
            box=cap.getbbox()
            cap_name='bridge_'+name
            if box:
                dest=CASE/f'assets/{view}/{cap_name}.png';dest.parent.mkdir(parents=True,exist_ok=True);cap.crop(box).save(dest)
                parts.append({'name':cap_name,'file':str(dest.relative_to(CASE)),'offset':list(box[:2]),'bone':bend,'z_index':2})
            delta=[tip[0]-root[0],tip[1]-root[1]]
            fields.append({'name':view+'_'+name,'parts':[name]+([cap_name] if box else []),'bones':['mass',bend,contact],'grid':[2,2],'bands':[{'center':root,'axis':axis,'width':16},{'center':[root[0]+delta[0]*0.6,root[1]+delta[1]*0.6],'axis':axis,'width':max(8,abs(delta[1])*.6)}]})
        mass=by_name['crust_mass'].copy();mass.update({'file':f'segmented/{view}/crust_mass.png','bone':'mass','z_index':10});parts.append(mass)
        write(CASE/f'layouts/{view}.json',layout)
        recipe={'facing':view,'input_layout':f'layouts/{view}.json','output_layout':f'layouts/{view}_skinned.json','fields':fields}
        recipe_path=CASE/f'recipes/{view}_skinned.skin.json';write(recipe_path,recipe)
        target=CASE/recipe['output_layout']
        if target.exists(): target.unlink()
        config['layouts'][view]=f'layouts/{view}.json'
        write(CASE/'cutout.json',config)
        run('skin',CASE,'--recipe',recipe_path)
        config=json.loads((CASE/'cutout.json').read_text())
    # Raw keep textures work identically without an editor/import cache.
    for folder in ['assets','segmented','source']:
        for path in (CASE/folder).rglob('*.png'):
            Path(str(path)+'.import').write_text('[remap]\n\nimporter="keep"\n')
    config['sources']=sorted(set(config.get('sources',[]))|{str(p.relative_to(CASE)) for folder in ['source','recipes'] for p in (CASE/folder).rglob('*') if p.is_file() and p.suffix not in ['.import','.pyc']})
    write(CASE/'cutout.json',config)

if __name__=='__main__': build()
