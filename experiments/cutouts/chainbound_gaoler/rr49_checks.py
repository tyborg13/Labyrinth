"""Current-frame native-equivalent contracts missing from the rr-44 CPU sweep."""
import numpy as np
from humanoid_cutout.cpu_pose import sprite_transform
from humanoid_cutout.gates import idle_pixel_errors, idle_group_offset
from humanoid_cutout.stable_paint import geometry_errors
from rr49_calibration import group


class Checks:
    def __init__(self,model,anatomy):
        self.model,self.anatomy=model,anatomy
        self.rest=None

    def measure(self,pose,layers):
        errors=geometry_errors(self.model.layout,pose)
        mismatches={}
        if pose['clip']=='idle':
            if self.rest is None:
                layout=self.model.layout
                rest=dict(view=pose['view'],clip='rest',phase=0,kind='presented',bones={n:dict(global_=[1,0,0,1,*p['position']]) for n,p in layout['joints'].items()},parts={})
                for bone in rest['bones'].values():bone['global']=bone.pop('global_')
                for part in layout['parts']:
                    t=sprite_transform(layout,rest,part)
                    rest['parts'][part['name']]=dict(transform=[t[0,0],t[1,0],t[0,1],t[1,1],*t[:2,2]],z_index=part['z_index'])
                self.rest=self.model.layers(rest)[0]
            for name,names in self.model.layout['idle_groups'].items():
                offset=idle_group_offset(self.model.layout,pose['bones'],name,self.anatomy)
                count=idle_pixel_errors(group(self.rest,names),group(layers,names),offset)
                mismatches[name]=count
                if count:errors.append(f'idle pixel mismatch: {name}: {count}')
        return dict(errors=errors,idle_group_mismatches=mismatches)
