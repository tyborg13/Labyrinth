"""Resolve case-owned leg roles; no figure identities or motion tuning."""


def roles_for(anatomy, view):
    roles = anatomy.get('leg_roles', {}).get(view, {})
    if roles and (set(roles) != {'stride', 'trailing'} or set(roles.values()) != {'near', 'far'}):
        raise ValueError('leg_roles.' + view + ': stride and trailing must name distinct near/far legs')
    return roles


def resolve_bone(name, anatomy, view):
    if name in ('foot_stride', 'foot_trailing'):
        role = name.removeprefix('foot_')
        roles = roles_for(anatomy, view)
        if role not in roles: raise ValueError('TODO_DESIGN_' + view + '_' + name)
        return 'foot_' + roles[role]
    return name
