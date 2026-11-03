"""Complete rr-44 error vocabulary; observations never come from native truth."""
from rr38_cpu_diagnostics import Diagnostics as BaseDiagnostics


def kinds(measurement):
    result=set(measurement['kinds'])
    clean=measurement['clean'];metrics=measurement['metrics']
    for field,kind in (('exposed_outline_pixels','outline'),('outline_outside_pixels','outline_outside'),
                       ('outside_pixels','outside'),('dark_slab_blocks','dark_slab')):
        if clean.get(field):result.add(kind)
    for field,kind in (('uncovered_foreign_texels','foreign'),('uncovered_outline_pixels','uncovered_outline'),
                       ('uncovered_outside_surface_pixels','outside_surface')):
        if metrics.get(field):result.add(kind)
    if any('released held item' in e for e in measurement['components']['errors']):result.add('released')
    return sorted(result)


class Diagnostics(BaseDiagnostics):
    def __init__(self,case,model):
        super().__init__(case,model)
        from rr44_release import RigidSourcePolicy
        self.release=RigidSourcePolicy(case,self.anatomy,self.motion,self.layout,self.release.baseline)
        if self.layout.get('painted_backing_authority')=='rr44_feedback2':
            from rr44_surface_policy import surface
            self.surface=surface(self.surface)

    def measure(self,pose,layers,maps):
        self.release.pose=pose
        result=super().measure(pose,layers,maps)
        result['kinds']=kinds(result)
        return result
