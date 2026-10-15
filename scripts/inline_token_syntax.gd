extends RefCounted

# Shared by rendering, glossary extraction, and Python/GDScript coverage.
# Token contents are printable ASCII only. U+0020 is the only allowed space:
# keys cannot have edge spaces, and an explicit form must contain a nonspace.
# The ASCII lookahead applies to both fields; do not use engine-specific
# whitespace classes or trimming APIs here or in Python's matching validator.
const TOKEN_PATTERN: String = "@(icon|term|kw)\\((?=[ -~]*\\))([^()| ](?:[^()|]*[^()| ])?)(?:\\|([^()|]*[^()| ][^()|]*))?\\)"
# Detect invalid separators too: controls and every non-ASCII character between
# a token kind and '(' must fail validation instead of escaping the scan.
const TOKEN_START_PATTERN: String = "@(icon|term|kw)[^!-~]*\\("

static func tokens(markup: String) -> Array[RegExMatch]:
	var pattern := RegEx.new()
	pattern.compile(TOKEN_PATTERN)
	return pattern.search_all(markup)

static func malformed_tokens(markup: String) -> Array[String]:
	var complete: Dictionary = {}
	for token: RegExMatch in tokens(markup):
		complete[token.get_start()] = true
	var starts := RegEx.new()
	starts.compile(TOKEN_START_PATTERN)
	var malformed: Array[String]
	for start: RegExMatch in starts.search_all(markup):
		if not complete.has(start.get_start()):
			malformed.append(markup.substr(start.get_start()))
	return malformed
