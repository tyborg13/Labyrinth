"""Bridge entry; inherit mq-20 renderer and unchanged physical registration."""
import sys
import importlib
from pathlib import Path
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parents[5]))
from spec.art_identity.maquettes.blender import render
base=importlib.import_module('spec.art_identity.maquettes.last_lamplighter.capture')

if __name__=='__main__':
    render.RENDER_DEFAULTS['size']=1088
    args=sys.argv[sys.argv.index('--')+1:];mode=args[-1];standard=base.render
    def bounded(spec,objects,output,**kwargs):
        if mode.startswith('pass:'):
            kind=mode.split(':',1)[1];kwargs.update(preview=True,ownership_only=False,solo_parts=None,
                image_modes=('silhouette' if kind=='facing' else kind,),capture_facing=kind=='facing')
        else:kwargs.update(capture_facing=False,solos_only=True)
        return standard(spec,objects,output,**kwargs)
    base.render=bounded
    raise SystemExit(base.main(*args))
