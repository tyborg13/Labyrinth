"""Bridge capture on a larger canvas at unchanged mq-18 physical pixel scale."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parents[5]))
from spec.art_identity.maquettes.blender import render
from spec.art_identity.maquettes.last_lamplighter.capture import main

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:]
    spec=json.loads(Path(args[0]).read_text())
    render.RENDER_DEFAULTS['size']=spec['mq20']['capture_size_px']
    raise SystemExit(main(*args))
