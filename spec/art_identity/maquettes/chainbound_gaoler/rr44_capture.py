"""Bridge-only bounded view or four-label capture of an immutable saved body."""
import sys
from functools import partial
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(PROJECT))
from spec.art_identity.maquettes.blender import capture_view

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:]
    mode=args.pop(0)
    options=dict(preview=True) if mode=='preview' else dict(ownership_only=True,solo_parts=mode.split(','))
    capture_view.render=partial(capture_view.render,**options)
    raise SystemExit(capture_view.main(args))
