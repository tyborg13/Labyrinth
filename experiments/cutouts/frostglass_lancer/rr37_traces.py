"""Measured cut lines on approved paint; select existing texels, never repaint.

mq-14 explicitly records its rear pouch source-fit deviation and occluded hand.
The categorical seeds cannot describe those exposed painting edges. These
source-space ownership traces finish the cut at the actual material boundaries.
"""
import numpy as np
from PIL import Image, ImageDraw
from humanoid_cutout.ownership import apply_override
from maquette_motion.silhouette import dilate, components
from cutout_pipeline.cases import write_json

TRACES = {
 'front': [
  ('head', [(89,20),(131,20),(139,54),(149,62),(137,81),(98,82),(88,74),(85,54)]),
  ('torso', [(89,77),(130,79),(134,110),(135,117),(89,117)]),
  ('torso', [(71,60),(87,53),(94,63),(89,82),(72,81)]),
  ('torso', [(130,65),(145,64),(159,76),(159,92),(140,94),(134,88)]),
  ('pelvis', [(89,109),(130,109),(132,118),(139,125),(137,137),(124,139),(122,122),(98,122),(97,136),(84,136),(84,119)]),
  ('tabard', [(98,120),(122,120),(131,141),(137,163),(129,171),(123,157),(114,146),(107,156),(101,170),(93,177),(86,174),(88,160),(79,171),(81,151)]),
  ('arm_far', [(76,79),(88,81),(83,98),(76,104),(64,118),(58,124),(55,120),(59,108),(68,97)]),
  ('arm_near', [(140,92),(158,91),(158,107),(151,119),(143,131),(136,131),(135,124),(141,111),(140,104)]),
  ('leg_far', [(99,146),(112,145),(107,169),(107,179),(101,192),(101,216),(94,222),(84,216),(87,198),(88,183),(86,178),(85,171),(92,165)]),
  ('leg_near', [(126,148),(139,153),(142,162),(151,169),(151,179),(148,185),(155,211),(154,223),(143,226),(139,217),(138,194),(134,184),(131,179),(131,169)]),
  ('foot_far', [(83,217),(100,221),(100,230),(91,233),(75,237),(67,235),(67,228),(76,221)]),
  ('foot_near', [(142,221),(155,220),(163,234),(160,246),(146,246),(139,239)]),
  ('spear', [(24,3),(49,3),(51,75),(79,221),(77,222),(76,224),(73,224),(38,75)]),
  ('hand_far', [(51,119),(61,120),(63,134),(56,138),(48,134),(46,128)]),
  ('hand_near', [(132,128),(143,129),(144,138),(138,142),(126,141),(123,136)]),
 ],
 'rear': [
  ('head', [(95,18),(147,18),(153,61),(165,67),(149,88),(137,101),(103,100),(91,83),(97,65)]),
  ('torso', [(83,66),(96,57),(102,64),(100,84),(93,94),(82,94)]),
  ('torso', [(152,72),(164,70),(172,82),(173,95),(158,97),(151,88)]),
  # Director feedback 1: this covered domain rides the cloak, including the approved pouch texels.
  ('cape_far', [(144,108),(156,108),(161,121),(163,137),(157,142),(145,139)]),
  ('arm_near', [(83,92),(96,92),(94,105),(91,119),(85,125),(79,122),(77,108)]),
  ('arm_far', [(158,96),(171,96),(173,103),(182,102),(190,106),(190,118),(178,120),(165,118),(159,110)]),
  ('leg_near', [(85,193),(97,193),(97,211),(94,222),(81,224),(80,212)]),
  ('leg_far', [(156,188),(168,188),(168,209),(171,222),(157,226),(150,216),(151,202)]),
  ('foot_near', [(80,219),(95,219),(96,226),(90,232),(78,232)]),
  ('foot_far', [(156,220),(171,219),(174,225),(185,225),(188,231),(177,237),(168,246),(151,246),(152,232)]),
  ('spear', [(211,29),(226,29),(225,46),(206,88),(190,143),(180,155),(175,153),(190,109),(195,84),(202,51)]),
  ('hand_far', [(188,104),(199,103),(200,114),(195,119),(186,117)]),
 ]}


def apply(case, view, visible, paint):
    # Begin with only the two native cloak ownership domains. All anatomy is
    # assigned by its measured paint boundary below, so no foreign islands ride
    # a limb, boot or spear. Cloth between traces retains its native half.
    near = visible['cape_near'][..., 3] > 0
    far = visible['cape_far'][..., 3] > 0
    missing = (paint[..., 3] > 0) & ~near & ~far
    for image in visible.values(): image[:] = 0
    visible['cape_near'][near] = paint[near]
    visible['cape_far'][far | missing] = paint[far | missing]
    records = []
    for name, polygon in TRACES[view]:
        image = Image.new('1', (255,255)); ImageDraw.Draw(image).polygon(polygon, fill=1)
        # The original trace stopped at the interior colour edge. Include its
        # measured three-pixel outline fringe before later foreground cuts.
        mask = (np.asarray(image) if name == 'spear' else dilate(np.asarray(image), 3)) & (paint[..., 3] > 0)
        records.append({'piece':name,'polygon':polygon,'transfers':apply_override(visible,paint,mask,name)})
    # Disconnected painted outline fringes at the measured material edges.
    # These coordinates select existing texels; no colour or alpha is authored.
    fringes = {'front': [('spear',(24,3,51,76)), ('spear',(63,190,66,201)),
                         ('arm_far',(63,100,84,124)), ('arm_near',(135,94,137,100)),
                         ('leg_far',(103,187,107,205))],
               'rear': [('spear',(185,29,227,104)), ('head',(154,55,164,65)),
                        ('foot_far',(173,232,189,244))]}
    for owner,(x0,y0,x1,y1) in fringes[view]:
        candidate = visible['cape_far'][...,3] > 0
        domain = np.zeros_like(candidate); domain[y0:y1,x0:x1] = True
        labels,groups = components(candidate,8)
        for label,size in groups:
            fragment = labels == label
            if (fragment & domain).any() and (fragment & domain).sum() == size:
                records.append({'piece':owner,'fringe_box':[x0,y0,x1,y1],
                                'transfers':apply_override(visible,paint,fragment,owner)})
    write_json(case / f'ownership/{view}_traces.json', records)
    from rr37_surfaces import ownership
    ownership(view, visible, paint)
