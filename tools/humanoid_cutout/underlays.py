"""Make hidden-layer priority explicit without changing native scene order."""


def native_order(layout):
    """The loader adds bones first, their sprites second, then root meshes.

    A descendant's sprite therefore precedes its ancestor's sprite at tied
    depth. The layout part array alone is not the native draw order.
    """
    meshes = {mesh['name'] for mesh in layout['joint_meshes']}
    result = []

    def visit(bone):
        for name, joint in layout['joints'].items():
            if joint['parent'] == bone:
                visit(name)
        result.extend(part['name'] for part in layout['parts']
                      if part['bone'] == bone and part['name'] not in meshes)

    for name, joint in layout['joints'].items():
        if joint['parent'] is None:
            visit(name)
    result.extend(mesh['name'] for mesh in layout['joint_meshes'])
    return result


def distinct_depths(layout):
    """Retain native priority, below all visible paint, with no tied depths."""
    parts = {part['name']: part for part in layout['parts']}
    hidden = [name for name in native_order(layout) if parts[name].get('hidden_material')]
    first = min(part['z_index'] for part in parts.values() if not part.get('hidden_material')) - len(hidden)
    depths = {name: first + index for index, name in enumerate(hidden)}
    for part in layout['parts'] + layout['joint_meshes']:
        if part['name'] in depths:
            part['z_index'] = depths[part['name']]
