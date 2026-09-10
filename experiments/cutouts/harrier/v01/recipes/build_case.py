"""Harrier v01 source registration and explicit semantic ownership. Run from repo root."""
import hashlib,json,subprocess,sys
from pathlib import Path
from PIL import Image
C=Path('experiments/cutouts/harrier/v01')
def write(path,data):
 path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,indent=2)+'\n')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
front=[
 ('head',[(109,96),(108,65),(122,50),(123,37),(133,37),(143,28),(153,28),(147,43),(160,42),(163,62),(145,64),(141,80),(133,91),(127,99)]),
 ('hand_r',[(68,76),(84,76),(89,82),(90,88),(84,93),(75,93),(68,87)]),
 ('spear',[(17,131),(39,104),(47,99),(70,83),(81,79),(101,66),(110,65),(113,73),(90,89),(79,98),(57,114),(41,125),(28,132)]),
 ('arm_r',[(88,91),(110,84),(119,94),(106,114),(98,119),(88,114),(76,101),(75,91)]),
 ('hand_l',[(198,132),(213,131),(218,143),(220,154),(213,166),(202,166),(204,155),(197,146),(189,150),(190,139)]),
 ('arm_l',[(162,76),(181,82),(202,91),(206,103),(210,115),(214,133),(198,140),(193,122),(188,111),(183,101),(162,91),(158,83)]),
 ('foot_r',[(106,178),(129,177),(132,188),(122,196),(112,201),(94,199),(94,188)]),
 ('foot_l',[(171,199),(192,197),(195,207),(194,228),(167,229),(167,213)]),
 ('waistcloth',[(120,115),(133,115),(159,114),(169,123),(177,126),(180,141),(190,170),(176,172),(168,155),(163,164),(154,163),(147,173),(138,171),(131,158),(123,161),(119,147),(114,142)]),
 ('leg_r',[(130,123),(140,137),(123,151),(114,161),(128,178),(131,188),(110,190),(100,169),(93,158),(94,143),(114,127)]),
 ('leg_l',[(157,125),(173,129),(173,155),(169,164),(177,177),(187,187),(193,200),(183,212),(170,207),(161,187),(154,178),(152,158),(153,140)]),
 ('torso',[(111,61),(166,61),(174,82),(164,93),(169,118),(159,132),(130,129),(126,113),(116,110),(106,101),(108,82)])
]
rear=[
 ('head',[(105,29),(140,28),(152,44),(156,59),(154,73),(142,75),(123,69),(106,63),(102,53)]),
 ('hand_r',[(183,67),(194,67),(199,75),(198,85),(185,88),(181,77)]),
 ('spear',[(145,99),(174,79),(201,63),(227,44),(249,29),(254,30),(254,48),(241,60),(219,74),(199,84),(169,102),(151,111)]),
 ('arm_r',[(147,81),(162,85),(175,102),(182,101),(183,86),(199,83),(198,97),(184,117),(176,122),(166,116),(156,103),(148,96)]),
 ('hand_l',[(56,133),(68,132),(76,136),(81,146),(77,148),(71,142),(64,145),(65,152),(73,159),(69,164),(55,163),(49,151),(50,140)]),
 ('arm_l',[(104,79),(111,89),(91,103),(82,110),(78,120),(68,138),(54,137),(57,126),(67,112),(65,103),(75,98),(91,88),(95,79)]),
 ('foot_r',[(139,189),(151,189),(159,188),(166,191),(166,201),(151,207),(136,207),(134,200)]),
 ('foot_l',[(62,215),(77,211),(91,215),(94,221),(79,229),(64,232),(57,226)]),
 ('waistcloth',[(94,122),(130,122),(143,132),(140,148),(145,164),(137,166),(132,178),(125,173),(120,188),(108,179),(108,167),(97,166),(94,160),(79,166),(76,160),(87,141),(87,130)]),
 ('leg_r',[(133,134),(146,142),(160,151),(165,161),(161,174),(154,187),(151,197),(136,201),(134,193),(141,175),(146,165),(137,160),(128,151)]),
 ('leg_l',[(99,149),(108,158),(104,171),(99,181),(85,193),(78,211),(76,221),(59,224),(57,216),(64,201),(70,188),(77,179),(84,170),(89,151)]),
 ('torso',[(108,62),(139,64),(156,79),(155,99),(147,120),(141,133),(121,136),(100,132),(95,116),(97,100),(94,84),(100,70)])
]
for f,entries in [('front',front),('rear',rear)]:
 write(C/'source'/f'{f}_ownership.json',{'priority_polygons':entries,'pixel_overrides':[],'rationale':'Explicit visible semantic owners, hand before shaft; scarf/chest remain torso; waistcloth belongs pelvis. Remaining pixels must be reviewed, never swept into a fallback owner.'})
 result=subprocess.run([sys.executable,'tools/cutout_workflow.py','segment','--source',str(C/'source'/f'{f}_registered.png'),'--ownership',str(C/'source'/f'{f}_ownership.json'),'--output',str(C/'segmented'/f)],capture_output=True,text=True)
 print(f,result.returncode)
 report=json.loads((C/'segmented'/f/'segmentation.json').read_text());print('unassigned',report['unassigned_pixels'],report['unassigned_coordinates'][:80])
write(C/'recipes'/'registration.json',{'source_size':[255,255],'front':{'source':'source/front_original.png','operation':'byte-identical copy, no redraw or registration change'},'rear':{'source':'source/rear_generated.png','source_size':[1254,1254],'operation':'uniform full-image Lanczos resize to 251x251, composite at [10,5] on 255x255; original retained','scale':0.2,'offset':[10,5]},'front_landmarks':{'skull':[126,71],'shoulder_r':[112,91],'elbow_r':[98,110],'grip':[79,86],'spear_tip':[24,124],'shoulder_l':[167,85],'elbow_l':[195,102],'wrist_l':[204,135],'hip_r':[130,131],'knee_r':[103,152],'ankle_r':[117,184],'sole_r':[109,196],'hip_l':[163,137],'knee_l':[163,171],'ankle_l':[181,203],'sole_l':[178,223]},'rear_landmarks':{'skull':[135,55],'shoulder_r':[151,88],'elbow_r':[175,113],'grip':[190,78],'spear_tip':[250,35],'shoulder_l':[101,86],'elbow_l':[76,108],'wrist_l':[60,138],'hip_r':[135,142],'knee_r':[157,160],'ankle_r':[144,196],'sole_r':[146,205],'hip_l':[101,153],'knee_l':[92,176],'ankle_l':[69,218],'sole_l':[71,229]}})
write(C/'source'/'generation_requests.json',{'tool':'built-in image_gen','reference_roles':{'front_original.png':'accepted front identity/style reference; sole edit target for hidden material'},'requests':[{'prompt':'rear_prompt.txt','output':'rear_rejected_frontlike.png','disposition':'rejected: chest/toes read as mirrored front; no runtime pixels'},{'prompt':'rear_v2_prompt.txt','output':'rear_generated.png','disposition':'selected: true back of skull, spine and heel view; requires native registration/rig inspection'},{'prompt':'hidden_prompt.txt','output':'hidden_generated.png','disposition':'selected concealed material source only; do not use as front visible repaint'}],'sha256':{p.name:digest(p) for p in (C/'source').iterdir() if p.suffix in ['.png','.txt']}})
