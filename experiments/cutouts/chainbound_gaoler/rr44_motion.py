"""Retain the approved death budget; new clamps require native calibration."""
from cutout_pipeline.cases import read_json
from rr44_case import BASE

FLOORS = {'move.arm_swing.near.upper_deg': 10, 'move.arm_swing.far.upper_deg': 7,
          'press.hand_near.lift_px': 14, 'reel.hand_far.lift_px': 4,
          'reel.hand_far.forward_px': 5, 'pin.hand_far.lift_px': 2,
          'pin.hand_far.forward_px': 3, 'guard.hand_far.lift_px': 4}


def apply(data):
    before = read_json(BASE/'compiled_motion.json')
    changes = []
    for view in data['view_tracks']:
        for track in data['view_tracks'][view]['death']:
            if track['source']=='hand_far.lift_px': continue
            old = next(t for t in before['view_tracks'][view]['death'] if t['source']==track['source'])
            if old != track:
                if track['source']!='coat_near_tip.lift_px':
                    raise ValueError('Unapproved death choreography change: '+track['source'])
                changes.append(dict(view=view,clip='death',source=track['source'],director_peak=4,peak=2.5,
                                    reason='retained rr-42 measured budget; owner approved death unchanged'))
                track.update(old)
    return data, changes
