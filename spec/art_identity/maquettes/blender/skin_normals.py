"""Preserve the continuous CC0 skin's corner normals across ownership cuts."""

SKIN_NORMAL_DEFAULTS = {'dot_error_max': .0001}


def copy_to(source, faces, target):
    normals=[tuple(source.corner_normals[i].vector) for face in faces for i in face.loop_indices]
    target.normals_split_custom_set(normals)


def matches(source, objects):
    by_face={tuple(face.vertices):face for face in source.polygons}
    for obj in objects:
        if obj.get('piece_type')!='body':
            continue
        if not obj.data.has_custom_normals:
            return False
        for face in obj.data.polygons:
            original=by_face.get(tuple(face.vertices))
            if original is None:
                return False
            for before,after in zip(original.loop_indices,face.loop_indices):
                a=source.corner_normals[before].vector
                b=obj.data.corner_normals[after].vector
                if 1-a.dot(b)>SKIN_NORMAL_DEFAULTS['dot_error_max']:
                    return False
    return True
