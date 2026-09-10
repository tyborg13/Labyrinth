"""Reproduce a native case capture while respecting the shared GUI lease.
The explicit lease-only wait accommodates the concurrent enemy batch. Startup,
execution, saving, scene roundtrips, packing and hashes use the maintained CLI.
"""
from pathlib import Path
import argparse,subprocess,sys
ROOT=Path(__file__).resolve().parents[1];REPO=ROOT.parents[3]
parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
raise SystemExit(subprocess.call([sys.executable,str(REPO/'tools/cutout_workflow.py'),'render',str(ROOT),'--output',str(args.output),'--task-id','chainbound-gaoler-editable-cutout-and-gameplay-animation','--backend','metal','--gui-lease-timeout','1800'],cwd=REPO))
