"""Portable minimum clear-distance search along a bounded signed-distance ray."""
RAY_SEARCH_DEFAULTS = {'steps': 1024, 'bisection_steps': 32,
                       'numerical_epsilon_m': 1e-8, 'minimum_step_m': 1e-6}


def first_clear(distance_at, margin, bound):
    epsilon = RAY_SEARCH_DEFAULTS['numerical_epsilon_m']
    previous, length = 0., 0.
    for _ in range(RAY_SEARCH_DEFAULTS['steps']):
        distance = distance_at(length)
        if distance >= margin - epsilon:
            for _ in range(RAY_SEARCH_DEFAULTS['bisection_steps']):
                middle = (previous + length) / 2
                if distance_at(middle) >= margin - epsilon:
                    length = middle
                else:
                    previous = middle
            return length
        previous = length
        length += max(RAY_SEARCH_DEFAULTS['minimum_step_m'], margin - distance)
        if length > bound:
            break
    if distance_at(bound) >= margin - epsilon:
        length = bound
        previous = min(previous, bound)
        for _ in range(RAY_SEARCH_DEFAULTS['bisection_steps']):
            middle = (previous + length) / 2
            if distance_at(middle) >= margin - epsilon:
                length = middle
            else:
                previous = middle
        return length
    return None
