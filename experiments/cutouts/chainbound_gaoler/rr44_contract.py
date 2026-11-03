"""Required rr-44 opt-ins; generic rigs retain their legacy defaults."""


def errors(layout):
    from humanoid_cutout.anatomy import for_layout
    anatomy=for_layout(layout)
    result=[]
    if not layout.get('stable_source_raster'):result.append('rr49: stable source raster contract missing')
    if not layout.get('painted_reference_space'):result.append('rr44: painted reference transform policy missing')
    if not layout.get('painted_node_transforms'):result.append('rr44: complete painted-node transform policy missing')
    attachment=layout.get('held_items',{}).get('chain',{})
    from rr44_feedback2_repairs import source_layout,retired_backing_texels
    if layout.get('retired_backing_texels')!=retired_backing_texels(layout['facing']):
        result.append('rr44: missing or changed rest-owner backing retirements')
    backing=[p['z_index'] for p in layout['parts'] if p.get('hidden_material') and not p.get('joint_cap_layer')]
    if any(p['z_index']>=min(backing) for p in layout['parts'] if p.get('joint_cap_layer')):
        result.append('rr44: background joint paint covers another backing')
    approved=source_layout(layout['facing'])['held_items']['chain']
    if attachment.get('floor_end')!=approved['floor_end'] or attachment.get('floor_line_y')!=approved['floor_line_y']:
        result.append('rr44: approved death landing datum changed')
    if attachment.get('presentation_grip_part')!='hand_far':result.append('rr44: required painted-grip attachment policy missing')
    if attachment.get('cap_release_parent')!='hand_far':result.append('rr44: grip cap release parent missing')
    if attachment.get('release_provenance')!='rigid_source_rgba' or attachment.get('component_provenance')!='rigid_source_rgba':result.append('rr44: exact rigid source policy missing')
    for mesh in layout.get('joint_meshes',[]):
        base_bones=anatomy['meshes'].get(mesh.get('garment'),{}).get('bones',[])
        requires=mesh.get('rigid_painted_caps') or any(r.get('kind')=='boundary' and r['bone'] not in base_bones for r in mesh.get('painted_joint_caps',[]))
        if requires and not mesh.get('rigid_source_alignment'):
            result.append('rr44: rigid source cap alignment missing: '+mesh['name'])
    return result


def sample_errors(layout,samples):
    import numpy as np
    from humanoid_cutout.gates import matrix
    result=[];parts={p['name']:p for p in layout['parts']};replaced={m['replaces_part'] for m in layout['joint_meshes']}
    needed={n for m in layout['joint_meshes'] if m.get('rigid_source_alignment') for n in m['weights'] if n in parts and parts[n]['bone']==n and n not in replaced}
    for row in samples['samples']:
        if row['view']!=layout['facing']:continue
        families=[(row.get('cap_bones',{}),row['parts'])]
        if 'raster_bones' in row:families.append((row.get('raster_cap_bones',{}),row['raster_parts']))
        for caps,paint in families:
            if set(paint)!=set(parts) or any('z_index' not in p for p in paint.values()):
                result.append('rr44: complete actual painted-node transform/depth evidence missing')
            if set(caps)!=needed:
                result.append('rr44: missing actual cap source-bone evidence');continue
            for name in needed:
                source=name;attachment=layout.get('held_items',{}).get(name,{})
                if row['phase']>=attachment.get('presentation_release_at',{}).get(row['clip'],float('inf')):source=attachment.get('cap_release_parent',name)
                expected=matrix(paint[source]['transform']).copy()
                expected[:2,2]+=expected[:2,:2]@(np.asarray(layout['joints'][name]['position'])-parts[source]['offset'])
                if not np.allclose(matrix(caps[name]),expected,atol=.0001,rtol=0):result.append(f'rr44: cap source differs: {row["view"]}/{row["clip"]}/{row["frame"]}/{name}')
    return sorted(set(result))
