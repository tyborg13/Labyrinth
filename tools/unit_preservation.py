"""Read preservation evidence from a unit's pinned Git history, never later units."""
import json
import subprocess


def read_bytes(project, revision, relative):
    if revision is None:
        return (project / relative).read_bytes()
    return subprocess.check_output(['git', 'show', revision + ':' + relative], cwd=project)


def read_json(project, revision, relative):
    return json.loads(read_bytes(project, revision, relative))


def changed_paths(project, baseline, end):
    """Include additions, removals and both sides of renames in this exact range."""
    output = subprocess.check_output(
        ['git', 'diff', '--no-renames', '--name-only', '-z', baseline, end, '--'],
        cwd=project)
    return [name for name in output.decode().split('\0') if name]


def tracked_paths(project, revision, prefix):
    output = subprocess.check_output(
        ['git', 'ls-tree', '-r', '--name-only', '-z', revision, '--', prefix], cwd=project)
    return [name for name in output.decode().split('\0') if name]
