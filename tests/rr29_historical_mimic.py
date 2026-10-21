"""Read superseded production assertions at each unit's immutable endpoint.

The assertions themselves remain in their original tests. These read-only
snapshots prevent rr-29's new production painting from changing their inputs.
"""
from contextlib import contextmanager
from io import BytesIO
from pathlib import Path
import subprocess
import tarfile
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
UNIT_ENDS = {'rr20':'901d327897650870b05f9208e2d028df8ad6efdf',
             'rr26':'b36624291', 'rr28':'94911ca47'}


def production_bytes(unit, path):
    return subprocess.check_output(['git','show',UNIT_ENDS[unit]+':'+str(path.relative_to(PROJECT))],cwd=PROJECT)


@contextmanager
def snapshot(unit, prefixes):
    archive = subprocess.check_output(['git','archive',UNIT_ENDS[unit],'--',*prefixes],cwd=PROJECT)
    with tempfile.TemporaryDirectory(prefix='rr29-historical-') as folder:
        root=Path(folder).resolve()
        with tarfile.open(fileobj=BytesIO(archive)) as files:
            for member in files:
                if member.isfile():
                    target=root/member.name;target.parent.mkdir(parents=True,exist_ok=True)
                    target.write_bytes(files.extractfile(member).read())
        yield root
