"""Preserve r1 source UVs while retiring continuations superseded by paint."""
from humanoid_cutout.gait_continuations import nearest_donors
from rr44_feedback2_repairs import source_layout


def rebuild(case,layout,images,authority):
    original=source_layout(layout['facing']);old={p['name']:p for p in original['parts']};parts={p['name']:p for p in layout['parts']}
    def table(recipes):
        result={}
        for name,recipe in recipes.items():
            part=parts[name]
            if part['logical_part'] in ('arm_far','hand_far','chain'):continue
            x0,y0=old[name]['offset'];x1,y1=part['offset'];targets=[]
            for x,y,_,_ in recipe['texels']:
                u,v=x+x0,y+y0
                if authority[v,u] or images[name][v,u,3]:continue
                targets.append((u-x1,v-y1))
            if not targets:continue
            rebound=nearest_donors(case,layout,part,targets)
            if 'clips' in recipe:rebound['clips']=list(recipe['clips'])
            result[name]=rebound
        return result
    layout['gait_continuations']=table(original.get('gait_continuations',{}))
    layout['clip_continuations']={clip:table(recipes) for clip,recipes in original.get('clip_continuations',{}).items()}
