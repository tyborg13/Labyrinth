"""Independent angular clock for an optional falling held item."""
def angle_at(keys, phase, drop, evaluate):
    if phase <= drop['land']:
        return evaluate(keys, min(phase, drop['start']))
    landed = [dict(at=drop['land'], value=evaluate(keys, drop['start']), interpolation='smoothstep')]
    landed += [row for row in keys if row['at'] > drop['land']]
    return evaluate(landed, phase)
