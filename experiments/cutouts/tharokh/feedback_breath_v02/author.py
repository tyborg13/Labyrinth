"""Tharokh v01: explicit source-pixel ownership and dragon anatomy recipe.

This case-local authoring recipe consumes retained paint; it never generates paint.
Run once after init. Further revisions belong in a new case or explicit new layout.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFilter

CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[3]

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')

def run(*args):
    subprocess.run([sys.executable, str(ROOT/'tools/cutout_workflow.py'), *map(str,args)], check=True, stdout=subprocess.DEVNULL)

# Priority follows actual painted occlusion, not a catch-all torso mask.
POLYGONS = {
 'front': [
  ('claw_fore_near', [(112,177),(130,173),(143,182),(144,198),(135,214),(116,210),(102,198),(101,186)]),
  ('claw_fore_far', [(42,162),(63,159),(72,168),(86,180),(92,191),(73,199),(49,197),(33,184),(34,170)]),
  ('claw_hind_near', [(158,177),(174,176),(186,186),(184,205),(155,205),(153,187)]),
  ('claw_hind_far', [(96,177),(105,173),(114,182),(111,194),(94,193),(92,184)]),
  ('head', [(38,91),(48,76),(55,63),(60,71),(63,52),(71,63),(80,36),(84,45),(98,28),(101,45),(111,39),(111,54),(139,48),(128,69),(125,91),(114,105),(96,115),(79,131),(75,143),(68,151),(57,146),(47,137),(41,121)]),
  ('wing_near', [(125,21),(151,10),(173,13),(215,48),(243,81),(254,116),(240,183),(219,182),(219,155),(208,139),(196,121),(183,124),(174,144),(164,165),(158,181),(153,181),(153,170),(159,147),(167,119),(150,102),(149,89),(144,69),(140,54),(131,45)]),
  ('fore_near', [(134,121),(149,116),(165,133),(167,151),(153,169),(142,180),(128,186),(111,180),(116,166),(125,150),(127,135)]),
  ('fore_far', [(80,134),(94,130),(104,143),(91,156),(78,176),(64,181),(56,169),(63,157),(67,144)]),
  ('tail', [(242,125),(254,143),(251,225),(227,254),(117,255),(65,239),(53,197),(65,185),(87,189),(95,204),(116,220),(145,222),(185,211),(204,195),(220,168)]),
  ('hind_near', [(177,142),(194,144),(204,157),(197,179),(184,190),(161,185),(158,166)]),
  ('hind_far', [(99,156),(116,158),(121,173),(112,183),(98,188),(91,175)]),
  ('wing_far', [(0,0),(125,0),(116,66),(109,85),(91,87),(74,96),(60,123),(44,158),(41,173),(24,166),(3,132)]),
  ('neck', [(91,89),(122,87),(145,108),(138,132),(133,151),(121,170),(102,161),(94,142),(85,122)]),
  ('torso', [(112,97),(161,78),(195,111),(226,157),(215,192),(181,211),(132,206),(106,185),(109,158),(104,130)]),
  ('wing_near', [(168,8),(211,31),(230,60),(211,65),(171,30)]),
  ('head', [(107,37),(127,38),(139,50),(127,75),(111,63)]),
  ('neck', [(122,56),(150,63),(156,86),(119,107)]),
  ('head', [(48,122),(91,119),(89,143),(66,153),(47,143)]),
  ('claw_fore_far', [(30,160),(50,150),(63,152),(70,171),(96,183),(93,201),(41,202),(30,182)]),
  ('fore_far', [(83,147),(101,145),(107,173),(91,183),(74,175)]),
  ('claw_fore_near', [(100,186),(145,189),(141,218),(112,218),(99,202)]),
  ('tail', [(88,191),(106,191),(124,213),(182,201),(206,179),(228,174),(216,219),(161,246),(105,234)]),
  ('neck', [(132,53),(142,53),(142,63),(132,63)]),
  ('head', [(58,148),(66,148),(66,154),(58,154)])
 ],
 'rear': [
  ('claw_fore_near', [(194,162),(203,153),(214,152),(225,159),(235,176),(229,186),(209,184),(192,175)]),
  ('claw_hind_near', [(139,181),(155,174),(170,180),(182,196),(175,204),(148,202),(137,190)]),
  ('claw_fore_far', [(85,167),(99,164),(112,174),(110,188),(90,189),(82,180)]),
  ('claw_hind_far', [(68,166),(82,162),(93,175),(89,185),(72,184),(65,176)]),
  ('wing_near', [(7,14),(108,0),(140,30),(129,61),(147,87),(142,107),(117,101),(102,89),(88,78),(88,115),(101,140),(94,151),(78,136),(60,128),(42,144),(33,168),(16,158),(6,99)]),
  ('wing_far', [(165,11),(207,14),(249,69),(255,128),(236,163),(220,157),(215,132),(214,116),(202,82),(191,65),(175,38)]),
  ('head', [(131,61),(142,57),(148,65),(152,46),(163,59),(176,57),(181,70),(192,73),(201,92),(206,108),(201,128),(190,139),(175,131),(165,114),(152,100),(143,83)]),
  ('fore_near', [(155,117),(171,121),(182,135),(202,154),(205,170),(192,171),(178,158),(163,145),(153,131)]),
  ('hind_near', [(121,144),(136,143),(151,151),(163,162),(158,177),(151,186),(166,190),(152,201),(138,191),(125,181),(122,167)]),
  ('tail', [(19,146),(49,132),(71,142),(61,161),(45,180),(63,193),(94,203),(118,207),(138,199),(153,199),(170,190),(190,187),(179,207),(196,210),(180,224),(193,229),(165,251),(93,252),(42,228),(16,190)]),
  ('fore_far', [(105,145),(114,145),(124,161),(110,178),(94,181),(89,172),(91,155)]),
  ('hind_far', [(71,144),(87,143),(98,154),(89,169),(81,177),(68,176),(64,160)]),
  ('neck', [(137,77),(160,84),(178,106),(181,130),(163,146),(139,135),(121,111)]),
  ('torso', [(53,108),(99,94),(125,83),(160,85),(181,111),(170,155),(137,185),(101,195),(66,182),(51,155)]),
  ('head', [(139,45),(166,38),(185,47),(207,87),(219,127),(207,141),(195,136),(186,112),(151,81)]),
  ('wing_far', [(139,13),(182,16),(193,45),(168,45)]),
  ('wing_near', [(84,71),(108,89),(97,105),(87,117)]),
  ('fore_near', [(174,132),(188,140),(207,162),(207,176),(196,178),(175,154)]),
  ('claw_fore_near', [(185,164),(203,160),(234,175),(239,190),(203,191),(184,179)]),
  ('hind_near', [(121,165),(161,169),(158,189),(183,197),(195,213),(160,217),(118,201)]),
  ('torso', [(63,165),(104,173),(129,189),(123,207),(101,199),(72,194),(57,181)]),
  ('head', [(126,56),(140,56),(143,70),(127,70)]),
  ('fore_near', [(176,131),(197,136),(205,155),(207,178),(170,185),(157,169),(163,151)]),
  ('claw_fore_near', [(202,147),(219,149),(223,162),(203,163)]),
  ('tail', [(44,161),(62,170),(65,185),(89,192),(127,201),(130,210),(183,194),(212,199),(213,206),(179,223),(107,231),(57,206),(41,184)])
 ]
}

JOINTS = {
 'front': {'root':(127,222,None),'torso':(151,147,'root'),'neck':(116,129,'torso'),'head':(104,101,'neck'),
   'wing_near':(143,130,'torso'),'wing_far':(96,105,'torso'),'tail_base':(203,165,'torso'),'tail_tip':(168,220,'tail_base'),
   'upper_fore_near':(144,139,'torso'),'lower_fore_near':(140,161,'upper_fore_near'),'claw_fore_near':(126,185,'lower_fore_near'),
   'upper_fore_far':(86,142,'torso'),'lower_fore_far':(77,158,'upper_fore_far'),'claw_fore_far':(58,177,'lower_fore_far'),
   'upper_hind_near':(179,157,'torso'),'lower_hind_near':(188,176,'upper_hind_near'),'claw_hind_near':(168,189,'lower_hind_near'),
   'upper_hind_far':(106,162,'torso'),'lower_hind_far':(104,174,'upper_hind_far'),'claw_hind_far':(101,185,'lower_hind_far')},
 'rear': {'root':(127,216,None),'torso':(125,135,'root'),'neck':(158,112,'torso'),'head':(177,104,'neck'),
   'wing_near':(105,106,'torso'),'wing_far':(184,93,'torso'),'tail_base':(67,150,'torso'),'tail_tip':(80,208,'tail_base'),
   'upper_fore_near':(159,127,'torso'),'lower_fore_near':(180,149,'upper_fore_near'),'claw_fore_near':(207,168,'lower_fore_near'),
   'upper_fore_far':(113,149,'torso'),'lower_fore_far':(108,161,'upper_fore_far'),'claw_fore_far':(97,175,'lower_fore_far'),
   'upper_hind_near':(136,155,'torso'),'lower_hind_near':(145,172,'upper_hind_near'),'claw_hind_near':(158,189,'lower_hind_near'),
   'upper_hind_far':(79,150,'torso'),'lower_hind_far':(78,164,'upper_hind_far'),'claw_hind_far':(77,175,'lower_hind_far')}
}
SOLES = {'front':{'fore_near':(123,210),'fore_far':(54,195),'hind_near':(167,202),'hind_far':(101,193)},
         'rear':{'fore_near':(218,183),'fore_far':(98,188),'hind_near':(163,201),'hind_far':(76,183)}}
LAYERS = {'front':{'wing_far':-8,'hind_far':-4,'claw_hind_far':-3,'hind_near':-2,'claw_hind_near':-1,'torso':0,'neck':1,'fore_far':2,'claw_fore_far':3,'head':4,'fore_near':5,'claw_fore_near':6,'wing_near':7,'tail':8},
          'rear':{'wing_far':-8,'fore_far':-6,'claw_fore_far':-5,'hind_far':-4,'claw_hind_far':-3,'torso':0,'neck':1,'head':2,'fore_near':3,'claw_fore_near':4,'hind_near':5,'claw_hind_near':6,'wing_near':7,'tail':8}}

def build(view):
    source=CASE/'source'/f'{view}_registered.png'
    own=CASE/'source'/f'{view}_ownership.json'
    overrides=[{'point':[57,167],'name':'tail'},{'point':[161,175],'name':'hind_near'}] if view=='rear' else []
    write(own,{'priority_polygons':POLYGONS[view], 'pixel_overrides':overrides})
    segment=CASE/'segmented'/view
    run('segment','--source',source,'--ownership',own,'--output',segment)
    report=json.loads((segment/'segmentation.json').read_text())
    if not report['ok']:
        raise RuntimeError(f"{view}: unowned pixels {report['unassigned_coordinates']}")
    joints={n:{'position':[x,y],'parent':p} for n,(x,y,p) in JOINTS[view].items()}
    parts=[]
    for p in report['parts']:
        name=p['name'];bone='upper_'+name if name.startswith(('fore_','hind_')) else 'tail_base' if name=='tail' else name
        parts.append({'name':name,'file':f'segmented/{view}/{name}.png','offset':p['offset'],'bone':bone,'z_index':LAYERS[view][name]})
        Path(str(segment/f'{name}.png')+'.import').write_text('[remap]\n\nimporter="keep"\n')
    # Hidden paint is confined under opaque original limbs, and follows the torso.
    # It cannot enlarge the neutral silhouette or replace any front source pixel.
    hidden=Image.open(CASE/'source'/f'{view}_underbody_generated.png').convert('RGBA').resize((255,255),Image.Resampling.LANCZOS)
    hidden.save(CASE/'source'/f'{view}_underbody_registered.png')
    original=Image.open(source).convert('RGBA')
    masks=[]
    for leg in ['fore_near','fore_far','hind_near','hind_far']:
        entry=next(p for p in parts if p['name']==leg)
        pix=Image.open(CASE/entry['file']);mask=Image.new('L',(255,255));mask.paste(pix.getchannel('A'),tuple(entry['offset']))
        threshold=255 if view=='front' else 250
        mask=mask.point(lambda a:255 if a>=threshold else 0).filter(ImageFilter.MinFilter(3))
        # Only the proximal socket needs body underpaint, never a second whole leg.
        j=JOINTS[view]['upper_'+leg];bounds=Image.new('L',(255,255));ImageDraw.Draw(bounds).ellipse((j[0]-15,j[1]-13,j[0]+15,j[1]+20),fill=255)
        import PIL.ImageChops as C
        mask=C.multiply(mask,bounds)
        patch=hidden.copy();patch.putalpha(C.multiply(hidden.getchannel('A'),mask))
        bbox=patch.getbbox()
        if bbox:
            path=CASE/'assets'/view/f'body_under_{leg}.png';path.parent.mkdir(parents=True,exist_ok=True);patch.crop(bbox).save(path)
            Path(str(path)+'.import').write_text('[remap]\n\nimporter="keep"\n')
            parts.append({'name':'body_under_'+leg,'file':str(path.relative_to(CASE)),'offset':list(bbox[:2]),'bone':'torso','z_index':-10})
            masks.append({'part':'body_under_'+leg,'source':f'source/{view}_underbody_registered.png','crop':bbox,'mask':f'original {leg} alpha >= {threshold} eroded 1px intersect 30x33px proximal ellipse','owner':'torso'})
    write(CASE/'recipes'/f'{view}_hidden_coverage.json',{'operation':'copy generated paint only; alpha constrained beneath original opaque limb owners','patches':masks})
    layout={'canvas_size':[255,255],'facing':view,'joints':joints,'parts':parts,'landmarks':{'sole_'+k:list(v) for k,v in SOLES[view].items()}}
    write(CASE/'layouts'/f'{view}.json',layout)
    fields=[]
    for leg in ['fore_near','fore_far','hind_near','hind_far']:
        upper=JOINTS[view]['upper_'+leg];lower=JOINTS[view]['lower_'+leg];claw=JOINTS[view]['claw_'+leg]
        fields.append({'name':view+'_'+leg,'parts':[leg],'bones':['upper_'+leg,'lower_'+leg,'claw_'+leg],'grid':[2,2],
                       'bands':[{'center':list(lower[:2]),'axis':[claw[0]-upper[0],claw[1]-upper[1]],'width':12},
                                {'center':list(claw[:2]),'axis':[claw[0]-lower[0],claw[1]-lower[1]],'width':8}]})
    fields.append({'name':view+'_tail','parts':['tail'],'bones':['tail_base','tail_tip'],'grid':[3,3],
                   'bands':[{'center':list(JOINTS[view]['tail_tip'][:2]),'axis':[-1,0.5] if view=='front' else [1,0.5],'width':42}]})
    recipe=CASE/'recipes'/f'{view}_skin.json'
    write(recipe,{'facing':view,'input_layout':f'layouts/{view}.json','output_layout':f'layouts/{view}_skinned.json','fields':fields})
    run('skin',CASE,'--recipe',recipe)

def finalize():
    config=json.loads((CASE/'cutout.json').read_text())
    config['clips']={'idle':{'frames':24,'duration':2.4,'loop':True,'preview_cycles':2},
                     'walk':{'frames':40,'duration':1.12,'loop':True,'preview_cycles':2,'travel':'motion'},
                     'claw':{'frames':40,'duration':1.05,'loop':False},
                     'brace':{'frames':32,'duration':0.8,'loop':False},
                     'faultline':{'frames':40,'duration':1.1,'loop':False}}
    config['rigid_bones']=['head','wing_near','wing_far']+['claw_'+k for k in SOLES['front']]
    config['contact_feet']=['claw_'+k for k in SOLES['front']]
    config['sources']=sorted(set(config.get('sources',[])+['author.py']+[str(p.relative_to(CASE)) for folder in ['source','recipes'] for p in (CASE/folder).glob('*') if p.is_file() and not p.name.endswith('.import')]))
    config['source_baseline']={'kind':'new_character','art_status':'built from preserved front and generated matching rear','front_sha256':hashlib.sha256((CASE/'source/front_original.png').read_bytes()).hexdigest()}
    write(CASE/'cutout.json',config)

if __name__=='__main__':
    for view in ['front','rear']:build(view)
    finalize()
