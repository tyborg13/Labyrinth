"""Project native curve control data, including both Bezier handles."""


def project_spline(spline, taper, project):
    points = spline.bezier_points if spline.type == 'BEZIER' else spline.points
    if len(points) != len(taper):
        raise ValueError('Curve taper does not cover its control points')
    for point, radius in zip(points, taper):
        if spline.type == 'BEZIER':
            coords = [tuple(point.co), tuple(point.handle_left), tuple(point.handle_right)]
            # AUTO handles would overwrite the explicitly projected coordinates.
            point.handle_left_type = point.handle_right_type = 'FREE'
            point.co, point.handle_left, point.handle_right = [project(co, radius) for co in coords]
        else:
            point.co = (*project(point.co[:3], radius), point.co[3])
