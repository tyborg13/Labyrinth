"""View visibility only; never deform or replace the common body/rig at capture."""


def active_in_view(obj, view):
    return obj.get('capture_view', view) == view


def view_parts(spec, view):
    common = {b['region'] for b in spec['armature']['bones']} - set(spec['base'].get('covered_regions', []))
    return common | {p['part'] for p in spec['pieces']}
