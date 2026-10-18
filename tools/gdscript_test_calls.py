"""String-aware, conservative call reader for the test registration audit.

This reads dispatch expressions, not arbitrary GDScript execution. Strings stay
atomic: their values are used only as literal load/deferred-call arguments.
Function bodies own their local aliases; nested alias lookup uses class scope.

Known limits (director decision, qa-08 review fecdbf24e; none occur in tests/):
- a lambda body counts as reachable from its enclosing function even if the lambda is never invoked;
- StringName/NodePath literals (&"x", ^"x") are not read as load/deferred-call arguments, and GDScript's \\UXXXXXX
  escapes are not decoded, so such calls report as orphaned. Use plain string literals in test dispatch.
"""
from __future__ import annotations

import ast
import re
from typing import NamedTuple


TOKEN = re.compile(
    r'''(?P<comment>\#[^\n]*)|(?P<string>"""(?:\\[\s\S]|(?!""")[\s\S])*"""|'''
    r"'''(?:\\[\s\S]|(?!''')[\s\S])*'''|"
    r'''"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*')|'''
    r'(?P<name>[A-Za-z_]\w*)|(?P<space>\s+)|(?P<symbol>.)'
)


class Token(NamedTuple):
    kind: str
    value: str
    line: int
    column: int


class Script(NamedTuple):
    methods: dict[str, list[Token]]
    class_tokens: list[Token]
    parent: str


class Calls(NamedTuple):
    inline: list[tuple[str, str]]
    aliases: list[tuple[str, str]]
    local: list[str]
    deferred: list[str]
    children: list[str]


def tokenize(text: str) -> list[Token]:
    tokens = []
    line, column = 1, 0
    for match in TOKEN.finditer(text):
        kind, value = match.lastgroup, match[0]
        if kind not in ("space", "comment"):
            decoded = value
            if kind == "string":
                try:
                    decoded = ast.literal_eval(value)
                except (ValueError, SyntaxError):
                    # An unfamiliar escape remains data, never source code.
                    width = 3 if value[:3] in ('"""', "'''") else 1
                    decoded = value[width:-width]
            tokens.append(Token(kind, decoded, line, column))
        if "\n" in value:
            line += value.count("\n")
            column = len(value.rsplit("\n", 1)[1])
        else:
            column += len(value)
    return tokens


def script(text: str) -> Script:
    tokens = tokenize(text)
    methods, class_tokens = {}, []
    index = 0
    while index < len(tokens):
        token = tokens[index]
        start = index
        if token.value == "static" and token.column == 0:
            index += 1
            token = tokens[index] if index < len(tokens) else token
        if token.kind == "name" and token.value == "func" and tokens[start].column == 0:
            name = tokens[index + 1].value
            end = index + 2
            while end < len(tokens) and not (tokens[end].column == 0 and tokens[end].line > token.line):
                end += 1
            methods[name] = tokens[index + 2:end]
            index = end
        else:
            class_tokens.extend(tokens[start:index + 1])
            index += 1
    parent = ""
    for index, token in enumerate(class_tokens[:-1]):
        if token.value == "extends" and token.column == 0 and class_tokens[index + 1].kind == "string":
            parent = class_tokens[index + 1].value
    return Script(methods, class_tokens, parent)


def aliases(tokens: list[Token]) -> dict[str, str]:
    result = {}
    for index, token in enumerate(tokens[:-1]):
        if token.kind != "name" or token.value not in ("const", "var"):
            continue
        name = tokens[index + 1]
        if name.kind != "name":
            continue
        offset = index + 2
        # Untyped '=', typed ': Variant =', and inferred ':=' share the same
        # assignment token. Stop at the declaration's physical line boundary.
        while offset < len(tokens) and tokens[offset].line == token.line and tokens[offset].value not in ("=", ";"):
            offset += 1
        tail = tokens[offset:offset + 5]
        if (len(tail) == 5 and [t.value for t in tail[:3]] in
                (["=", "load", "("], ["=", "preload", "("]) and
                tail[3].kind == "string" and tail[3].value.endswith(".gd") and tail[4].value == ")"):
            result[name.value] = tail[3].value
    return result


def calls(tokens: list[Token]) -> Calls:
    inline, receivers, local, deferred, children = [], [], [], [], []
    for index, token in enumerate(tokens):
        if token.kind != "name":
            continue
        tail = tokens[index:index + 8]
        values = [t.value for t in tail]
        if (len(tail) >= 7 and token.value in ("load", "preload") and values[1] == "(" and
                tail[2].kind == "string" and tail[2].value.endswith(".gd") and values[3:5] == [")", "."] and
                tail[5].kind == "name" and values[6] == "("):
            inline.append((tail[2].value, tail[5].value))
        if index and tokens[index - 1].value == ".":
            continue
        chain, offset = [token.value], index + 1
        while (offset + 1 < len(tokens) and tokens[offset].value == "." and tokens[offset + 1].kind == "name"):
            chain.append(tokens[offset + 1].value)
            offset += 2
        if offset >= len(tokens) or tokens[offset].value != "(":
            continue
        arguments = tokens[offset + 1:offset + 4]
        if len(chain) > 1:
            receivers.append((".".join(chain[:-1]), chain[-1]))
            if len(chain) == 2 and chain[-1] == "call_deferred":
                deferred.append(chain[0])
        else:
            local.append(chain[0])
        if chain[-1] in ("call_deferred", "_run_child") and arguments and arguments[0].kind == "string":
            (children if chain[-1] == "_run_child" else deferred).append(arguments[0].value)
        if (chain == ["Callable"] and len(arguments) >= 3 and
                [t.value for t in arguments[:2]] == ["self", ","] and arguments[2].kind == "string"):
            deferred.append(arguments[2].value)
    return Calls(inline, receivers, local, deferred, children)


def suite_names(tokens: list[Token]) -> list[str]:
    """Legacy helper's literal SUITES array, excluding quoted source examples."""
    for index, token in enumerate(tokens):
        if token.kind == "name" and token.value == "SUITES":
            remaining = tokens[index + 1:]
            opening = next((i for i, t in enumerate(remaining) if t.value == "="), len(remaining)) + 1
            remaining = remaining[opening:]
            if remaining and remaining[0].value == "[":
                end = next((i for i, t in enumerate(remaining) if t.value == "]"), len(remaining))
                return [t.value for t in remaining[1:end] if t.kind == "string"]
    return []
