"""Dependency-free validator for the vocabulary used by anatomy.schema.json.

Unsupported schema keywords fail closed. The checked-in schema, rather than a
second handwritten list of anatomy fields, owns required and allowed keys.
"""
import math

KEYWORDS = {'$schema', 'title', 'description', 'type', 'const', 'enum', 'oneOf',
            'required', 'properties', 'additionalProperties', 'minProperties',
            'maxProperties', 'items', 'minItems', 'maxItems', 'uniqueItems',
            'minimum', 'maximum'}


class UnsupportedSchema(ValueError):
    pass


def _type(value, kind):
    return {
        'object': lambda: isinstance(value, dict),
        'array': lambda: isinstance(value, list),
        'string': lambda: isinstance(value, str),
        'null': lambda: value is None,
        'boolean': lambda: type(value) is bool,
        'number': lambda: type(value) in (int, float) and math.isfinite(value),
        'integer': lambda: type(value) in (int, float) and math.isfinite(value) and int(value) == value,
    }[kind]()


def _equal(a, b):
    if isinstance(a, bool) != isinstance(b, bool): return False
    return a == b


def validate(value, schema, path='anatomy'):
    unknown = set(schema) - KEYWORDS
    if unknown: raise UnsupportedSchema('Unsupported anatomy schema keywords: ' + ', '.join(sorted(unknown)))
    kinds = schema.get('type')
    if kinds is not None:
        kinds = [kinds] if isinstance(kinds, str) else kinds
        if not any(_type(value, kind) for kind in kinds):
            raise ValueError(path + ': expected ' + ' or '.join(kinds))
    if 'const' in schema and not _equal(value, schema['const']):
        raise ValueError(path + ': expected ' + repr(schema['const']))
    if 'enum' in schema and not any(_equal(value, allowed) for allowed in schema['enum']):
        raise ValueError(path + ': expected one of ' + repr(schema['enum']))
    if 'oneOf' in schema:
        matches = 0
        for branch in schema['oneOf']:
            try:
                validate(value, branch, path)
                matches += 1
            except UnsupportedSchema:
                raise
            except ValueError:
                pass
        if matches != 1: raise ValueError(path + ': expected exactly one schema variant')
    if isinstance(value, dict):
        properties = schema.get('properties', {})
        additional = schema.get('additionalProperties', True)
        for key, child in value.items():
            if key in properties:
                validate(child, properties[key], path + '.' + key)
            elif additional is False:
                raise ValueError(path + ': unknown key ' + repr(key))
            elif isinstance(additional, dict):
                validate(child, additional, path + '.' + key)
        for required in schema.get('required', []):
            if required not in value: raise ValueError(path + '.' + required + ': required key missing')
        for name, comparison in [('minProperties', len(value) < schema.get('minProperties', 0)),
                                 ('maxProperties', len(value) > schema.get('maxProperties', math.inf))]:
            if comparison: raise ValueError(path + ': violates ' + name)
    if isinstance(value, list):
        if len(value) < schema.get('minItems', 0) or len(value) > schema.get('maxItems', math.inf):
            raise ValueError(path + ': invalid array length')
        if schema.get('uniqueItems') and any(_equal(v, other) for i, v in enumerate(value) for other in value[:i]):
            raise ValueError(path + ': duplicate array items')
        if 'items' in schema:
            for index, child in enumerate(value): validate(child, schema['items'], '%s[%d]' % (path, index))
    if type(value) in (int, float):
        if value < schema.get('minimum', -math.inf) or value > schema.get('maximum', math.inf):
            raise ValueError(path + ': number outside schema bounds')
    return value
