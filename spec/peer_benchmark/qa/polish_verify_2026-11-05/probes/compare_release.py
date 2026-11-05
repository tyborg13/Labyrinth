"""Record a moving release ref without editing this fixed task checkout."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
BASE = Path(__file__).resolve().parents[1]
def git(*args): return subprocess.check_output(['git', *args])
head=git('rev-parse','HEAD').decode().strip()
release=git('rev-parse','codex/release').decode().strip()
changed=git('diff','--name-only',head,release).decode().splitlines()
manifest=json.loads((BASE/'evidence/source_manifest.json').read_text())
checks={}
for path,expected in manifest['files'].items():
    actual=hashlib.sha256(git('show',release+':'+path)).hexdigest()
    checks[path]={'same':actual==expected,'audited_sha256':expected,'release_sha256':actual}
report={'checked_at_utc':datetime.now(timezone.utc).isoformat(),'audited_head':head,'release_ref_at_check':release,'changed_files':changed,'cited_source_checks':checks,
        'scope':'Runtime observations execute the fixed audited checkout. Later release applicability is source comparison/inference, not an execution of the newer tree.'}
(BASE/'evidence/release_delta.json').write_text(json.dumps(report,indent=2)+'\n')
(BASE/'evidence/release_delta.patch').write_bytes(git('diff',head,release))
if 'scripts/cutout_render_gate.gd' in changed:
    (BASE/'evidence/latest_cutout_render_gate.gd.txt').write_bytes(git('show',release+':scripts/cutout_render_gate.gd'))
print('QA52 RELEASE COMPARISON: audited=%s release=%s changed_files=%d cited_source_matches=%d/%d' % (head[:9],release[:9],len(changed),sum(v['same'] for v in checks.values()),len(checks)))
