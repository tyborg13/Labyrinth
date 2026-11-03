"""Reconstruct the director's round-2 input from tracked blobs, never proof logs."""
import io
from pathlib import Path
import subprocess
import tarfile
from rr38_case import PROJECT
from rr38_proof_case import build

BASELINE_REVISION='0fd3939eb'
CASE_PATH='experiments/cutouts/chainbound_gaoler/rr38'
ASSET_PATH='assets/units/chainbound_gaoler_cutout'


def prepare(output):
    output=Path(output).resolve()
    output.relative_to(PROJECT)  # Godot resource paths must remain in this worktree.
    archive=subprocess.check_output(['git','archive',BASELINE_REVISION,CASE_PATH,ASSET_PATH],cwd=PROJECT)
    with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
        for member in bundle.getmembers():
            target=output/member.name
            target.resolve().relative_to(output)
            if member.isdir():target.mkdir(parents=True,exist_ok=True)
            elif member.isfile():
                target.parent.mkdir(parents=True,exist_ok=True)
                target.write_bytes(bundle.extractfile(member).read())
            else:raise ValueError('Unexpected archive member: '+member.name)
    source=output/CASE_PATH
    treated=output/'treated'
    build(source,output/ASSET_PATH,treated)
    return treated
