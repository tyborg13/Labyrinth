extends RefCounted

# Shared by rendering, glossary extraction, and Python/GDScript coverage.
# Keys may contain punctuation or spaces: glossary lookup decides validity.
const TOKEN_PATTERN: String = "@(icon|term|kw)\\(([^()|\\r\\n]+)(?:\\|([^()|\\r\\n]+))?\\)"
const TOKEN_START_PATTERN: String = "@(icon|term|kw)\\s*\\("

static func tokens(markup: String) -> Array[RegExMatch]:
	var pattern := RegEx.new()
	pattern.compile(TOKEN_PATTERN)
	return pattern.search_all(markup)

static func malformed_tokens(markup: String) -> Array[String]:
	var complete: Dictionary = {}
	for token: RegExMatch in tokens(markup):
		var key: String = token.get_string(2)
		var form: String = token.get_string(3)
		if key.strip_edges().is_empty() or key != key.strip_edges(): continue
		if token.get_start(3) >= 0 and form.strip_edges().is_empty(): continue
		complete[token.get_start()] = true
	var starts := RegEx.new()
	starts.compile(TOKEN_START_PATTERN)
	var malformed: Array[String]
	for start: RegExMatch in starts.search_all(markup):
		if not complete.has(start.get_start()):
			malformed.append(markup.substr(start.get_start()))
	return malformed
