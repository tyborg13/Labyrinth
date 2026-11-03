"""Run the unchanged rr46 verifier for the two director-specified Reaver jobs."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from tests.rr46 import verify_native
verify_native.RIGS=('ashen_reaver',)
verify_native.INVENTORY=Path(__file__).with_name('depth_inventory.json')
if __name__=='__main__':raise SystemExit(verify_native.main())
