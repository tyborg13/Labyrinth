"""Immutable pre-rr-35 sources shared by the reference and preservation gates."""
import hashlib
import subprocess
from rr35_case import PROJECT

BASE_REVISION = 'f1fae7475b2c034f85cd785f080434283c94bfee'
SOURCE_SHA256 = {
    'tools/humanoid_cutout/reach.py': 'd3d4e6a742bf650ce9862a68ac213593e50c612284e7f58deebb76cda7ac2b58',
    'spec/art_identity/registry.json': '68c1d42a005a7f14bde4d8e0ed8714c3049c9b9735a7f82bb78f6f445b6d54b6',
    'spec/assets/board_pixel_density/registry.json': 'ea869e963fbb8d8548741cad0cf90cb6c395f8608de0d42bbcf6e122c6f8483d',
    'spec/assets/board_pixel_density/outputs.json': '21830ae8d4e43ef81b92ebdb44c8671f9157194fae170ab8adf87825abdb7daf',
}


def read_source(path):
    expected = SOURCE_SHA256[path]
    source = subprocess.check_output(['git', 'show', BASE_REVISION + ':' + path], cwd=PROJECT)
    actual = hashlib.sha256(source).hexdigest()
    if actual != expected:
        raise ValueError('rr-35 baseline source hash differs: ' + BASE_REVISION + ':' + path)
    return source
