"""Enumerate logical native filenames for legacy glob-based review tools."""
from pathlib import Path
import json


def frame_paths(folder, pattern='*.png'):
    folder = Path(folder).absolute()
    for parent in (folder, *folder.parents):
        index = parent / 'native_storage.json'
        if index.is_file():
            return sorted(parent / logical for logical in json.loads(index.read_bytes())['files']
                          if (parent / logical).parent == folder and Path(logical).match(pattern))
    return sorted(folder.glob(pattern))
