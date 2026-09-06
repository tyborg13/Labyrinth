"""Keep a native source set stable across capture and edit export."""
from contextlib import contextmanager
import fcntl
from pathlib import Path


@contextmanager
def source_lock(directory: Path):
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / ".capture-export.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError(f"Another capture/export is using this native source set: {directory}") from error
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)
