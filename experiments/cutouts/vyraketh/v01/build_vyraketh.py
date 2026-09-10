"""Vyraketh v01 registration/semantic ownership recipe; never modifies accepted paint.
Run from the repo root once for a fresh segmentation revision. The maintained
cutout_workflow commands perform all ownership extraction and shared skinning.
"""
import json, hashlib, subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps
ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[3]
def put(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def cmd(*args):
    result=subprocess.run([sys.executable, str(REPO/'tools/cutout_workflow.py'), *map(str,args)], capture_output=True,text=True,cwd=REPO)
    if args[0]=='segment':
        report=json.loads(result.stdout); print(args[-1], 'unassigned',report['unassigned_pixels'])
    elif result.returncode: print(result.stdout,result.stderr)
    return result.returncode
# Source registration is uniform and performed once before splitting.
f=Image.open(ROOT/'source/front_original.png').convert('RGBA'); f.save(ROOT/'source/front_registered.png')
r=Image.open(ROOT/'source/rear_selected.png').convert('RGBA'); bbox=r.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox(); crop=r.crop(bbox)
scale=min(231/crop.width,234/crop.height); size=(round(crop.width*scale),round(crop.height*scale)); offset=((255-size[0])//2,245-size[1]); registered=Image.new('RGBA',(255,255)); registered.alpha_composite(crop.resize(size,Image.Resampling.LANCZOS),offset)
# Unmirrored rear must follow helper delta (0,-1): screen upper RIGHT.
ImageOps.mirror(registered).save(ROOT/'source/rear_registered.png')
put(ROOT/'recipes/registration.json',{'coordinate_space':'255px source; 2:1 board projection; source offset 128:128 in fixed 512 canvas','front':{'source':'source/front_original.png','operation':'identity, unchanged accepted front pixels','sha256':sha(ROOT/'source/front_original.png')},'rear':{'source':'source/rear_selected.png','alpha_bbox_threshold':8,'crop':bbox,'uniform_scale':scale,'rounded_size':size,'offset':offset,'reflect_after_registration':True,'rationale':'Front faces lower-left; unreflected production rear faces upper-right under enemy_cutout_facing.gd; reflection creates the other two views.'}})
# Explicit polygons. Priority captures anatomical overlaps; torso has its own
# bounded outline, never a catch-all for unassigned pixels.
front=[
 ('jaw',[(61,137),(66,130),(76,124),(78,131),(74,138),(68,149),(61,147)]),
 ('head',[(45,93),(51,60),(62,83),(77,46),(83,72),(99,39),(96,74),(111,56),(120,38),(119,67),(142,49),(134,76),(144,70),(135,92),(111,96),(98,109),(86,126),(76,139),(66,153),(56,146),(54,123)]),
 ('claw_fore_far',[(40,169),(55,162),(64,166),(78,170),(79,180),(70,190),(52,192),(41,183)]),
 ('claw_fore_near',[(111,182),(119,172),(133,177),(141,182),(150,193),(146,204),(107,209),(107,193)]),
 ('claw_hind_near',[(162,182),(171,177),(185,180),(191,192),(186,202),(160,202)]),
 ('fore_far',[(54,169),(69,160),(83,146),(98,137),(109,145),(99,158),(81,169),(77,178),(62,176)]),
 ('fore_near',[(112,187),(119,172),(139,153),(148,140),(158,139),(164,149),(149,164),(135,181),(139,190),(126,193)]),
 ('hind_near',[(163,159),(172,151),(187,151),(191,166),(184,181),(184,188),(164,193),(160,181)]),
 ('wing_near',[(131,136),(136,114),(142,91),(151,64),(151,44),(135,44),(148,17),(179,7),(180,25),(219,43),(249,79),(254,134),(233,169),(207,196),(214,163),(205,132),(196,119),(183,117),(175,135),(172,152),(156,143)]),
 ('wing_far',[(5,80),(24,43),(48,17),(79,6),(105,16),(106,38),(100,56),(110,71),(121,86),(112,117),(97,133),(81,128),(73,111),(57,117),(32,124),(33,142),(42,164),(20,151),(5,120)]),
 ('neck',[(89,86),(104,76),(120,76),(136,84),(138,102),(128,113),(124,127),(139,140),(151,142),(150,158),(124,162),(104,152),(98,135),(100,117),(106,102)]),
 ('tail',[(178,119),(196,127),(218,143),(231,161),(233,191),(216,220),(188,234),(161,246),(145,248),(121,237),(90,238),(76,228),(71,214),(67,198),(80,190),(92,174),(98,170),(94,197),(92,210),(110,215),(145,215),(171,207),(194,196),(201,173),(193,154),(179,147)]),
 ('torso',[(83,138),(112,123),(131,123),(155,123),(177,137),(185,158),(180,181),(158,189),(137,186),(111,183),(94,175),(91,162)])
]
# Author rear polygons against the selected unmirrored generated study, then
# reflect every coordinate as one operation along with the complete source.
rear_raw=[
 ('jaw',[(103,64),(109,64),(114,64),(115,69),(110,74),(105,74)]),
 ('head',[(100,58),(109,44),(129,31),(141,26),(161,40),(163,52),(155,62),(139,63),(125,61),(116,67),(107,75),(101,70)]),
 ('claw_fore_far',[(88,150),(98,145),(106,152),(114,157),(114,168),(106,174),(97,170),(88,161)]),
 ('claw_hind_near',[(104,176),(116,171),(128,177),(134,184),(137,195),(126,200),(111,196),(102,186)]),
 ('claw_hind_far',[(211,187),(222,183),(233,187),(241,196),(237,207),(215,207),(209,197)]),
 ('fore_far',[(99,147),(112,135),(126,132),(130,141),(116,153),(110,161),(102,165),(94,158)]),
 ('hind_near',[(118,148),(128,139),(147,139),(155,151),(149,168),(143,179),(128,187),(114,186),(116,177),(130,171),(123,163)]),
 ('hind_far',[(179,148),(188,137),(201,139),(211,154),(213,171),(225,187),(232,194),(219,202),(204,185),(197,177),(187,165)]),
 ('wing_near',[(3,126),(20,98),(45,78),(73,57),(66,46),(84,45),(99,55),(103,76),(101,90),(112,99),(125,106),(137,116),(134,135),(124,146),(118,157),(110,171),(105,179),(83,170),(70,153),(55,130),(45,139),(35,163),(33,186),(22,189),(9,159)]),
 ('wing_far',[(153,130),(159,102),(164,70),(157,64),(156,44),(151,28),(157,27),(172,31),(176,26),(191,35),(204,46),(228,62),(249,89),(254,154),(232,187),(216,182),(220,149),(217,131),(199,126),(187,119),(183,141),(172,143)]),
 ('neck',[(118,61),(131,56),(148,56),(157,67),(160,86),(163,102),(156,119),(141,120),(125,107),(120,97),(125,80)]),
 ('tail',[(157,167),(164,158),(182,168),(196,184),(205,202),(205,218),(190,239),(165,249),(111,249),(67,235),(47,219),(44,200),(51,184),(67,174),(91,170),(102,178),(88,186),(75,193),(80,207),(100,216),(124,219),(151,216),(169,207),(173,194)]),
 ('torso',[(118,104),(136,102),(155,111),(172,122),(190,137),(192,159),(194,177),(183,193),(166,193),(151,183),(136,171),(123,158),(114,142),(118,126)])
]
rear=[(name,[(254-x,y) for x,y in points]) for name,points in rear_raw]
front += [
 ('head',[(46,93),(53,116),(58,146),(69,154),(84,135),(99,119),(112,104),(131,101),(150,57),(140,30),(106,33),(101,63),(76,70)]),
 ('neck',[(100,92),(124,87),(140,95),(139,123),(148,140),(143,151),(114,150),(98,137)]),
 ('wing_near',[(131,35),(148,9),(174,0),(212,28),(239,63),(254,99),(254,153),(239,176),(217,181),(224,156),(214,123),(183,108),(161,139),(138,139)]),
 ('wing_far',[(8,42),(65,0),(105,0),(113,62),(103,119),(55,131),(40,151),(44,173),(13,153),(0,115)]),
 ('claw_fore_far',[(36,161),(58,159),(79,162),(82,182),(73,192),(40,195)]),
 ('claw_fore_near',[(106,178),(143,176),(154,191),(150,214),(106,214)]),
 ('hind_near',[(159,151),(189,148),(196,167),(194,183),(183,186),(163,184)]),
 ('tail',[(188,119),(207,125),(235,153),(236,203),(222,230),(185,251),(66,251),(63,207),(66,190),(91,165),(100,171),(99,198),(107,206),(162,203),(188,193),(199,173),(179,142)]),
 ('torso',[(86,138),(113,122),(143,127),(158,143),(164,171),(162,190),(133,189),(102,182),(91,174)])
]
rear_raw += [
 ('head',[(98,57),(101,46),(132,23),(150,24),(170,42),(160,67),(142,70),(120,68),(109,80),(100,74)]),
 ('neck',[(117,58),(151,58),(166,71),(167,110),(150,125),(121,108),(116,93)]),
 ('wing_near',[(0,88),(52,49),(80,35),(105,48),(113,90),(138,111),(136,137),(123,160),(115,184),(75,182),(61,143),(40,177),(42,197),(13,196),(0,163)]),
 ('wing_far',[(150,20),(187,20),(222,43),(254,65),(254,188),(215,190),(216,159),(208,135),(185,131),(181,149),(158,143),(153,112)]),
 ('claw_fore_far',[(85,146),(107,146),(119,160),(113,177),(94,176),(86,163)]),
 ('claw_hind_near',[(100,172),(134,171),(141,185),(140,202),(111,204),(101,190)]),
 ('claw_hind_far',[(207,181),(231,179),(246,196),(241,213),(213,212)]),
 ('hind_near',[(117,141),(144,132),(155,145),(158,167),(145,184),(125,187),(114,174)]),
 ('hind_far',[(181,135),(203,134),(216,153),(220,179),(231,191),(216,201),(199,184),(184,169)]),
 ('tail',[(156,162),(186,162),(211,187),(214,220),(198,251),(68,254),(39,228),(36,196),(49,178),(78,168),(104,173),(103,187),(83,196),(87,206),(116,213),(148,211),(165,203),(168,191)]),
 ('torso',[(113,104),(148,102),(176,123),(195,139),(199,177),(182,194),(158,192),(136,180),(119,161),(108,137)])
]
rear=[(name,[(254-x,y) for x,y in points]) for name,points in rear_raw]
# Audited pixel transfer regions: only those explicit source-space selections
# move ownership. They preserve original RGB/alpha, including translucent edges.
front += [
 ('tail',[(179,115),(201,115),(200,143),(174,143)]),
 ('head',[(50,128),(58,128),(73,151),(73,157),(64,157),(52,143)]),
 ('fore_far',[(78,139),(91,128),(97,128),(98,143),(86,154),(79,152)]),
 ('fore_far',[(79,160),(90,161),(89,177),(79,179)]),
 ('claw_fore_far',[(48,190),(61,190),(61,198),(48,198)]),
 ('hind_near',[(184,163),(203,163),(202,190),(184,193)]),
 ('claw_hind_near',[(151,189),(165,189),(165,206),(151,206)]),
 ('fore_near',[(100,179),(108,179),(108,189),(100,189)])
]
rear += [
 ('wing_far',[(24,34),(35,34),(35,43),(24,43)]),
 ('hind_far',[(55,128),(71,128),(71,138),(55,138)]),
 ('wing_near',[(189,142),(198,142),(198,152),(189,152)]),
 ('claw_hind_near',[(110,183),(115,183),(115,188),(110,188)]),
 ('tail',[(85,186),(170,186),(173,215),(91,219)])
]
for facing, polygons in [('front',front),('rear',rear)]:
    overrides=[]
    if facing=='front':
        # Repair the originally concealed neck strip previously caught by the
        # far wing silhouette; remove curled-tail pixels beneath both claws.
        old=json.loads((ROOT/'segmented/front_v2/segmentation.json').read_text())
        for part in old['parts']:
            paint=Image.open(ROOT/'segmented/front_v2'/part['file'])
            for y in range(paint.height):
                for x in range(paint.width):
                    px,py=x+part['offset'][0],y+part['offset'][1]
                    if not paint.getpixel((x,y))[3]: continue
                    owner=None
                    if part['name']=='wing_far' and px>=85 and py>=99: owner='neck'
                    if part['name']=='claw_fore_near' and py>=204: owner='tail'
                    if part['name']=='claw_hind_near' and py>=199: owner='tail'
                    if owner: overrides.append({'point':[px,py],'name':owner})
    put(ROOT/f'source/{facing}_ownership.json',{'priority_polygons':polygons,'pixel_overrides':overrides})
    if cmd('segment','--source',ROOT/f'source/{facing}_registered.png','--ownership',ROOT/f'source/{facing}_ownership.json','--output',ROOT/f'segmented/{facing}_v3'): raise SystemExit(1)
