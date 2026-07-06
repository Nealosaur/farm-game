class_name EventScript
extends RefCounted
## Alive Stride 2: pure parser for the event-script command DSL. Structurally
## inspired by Stardew's command-per-line event format (space-separated
## tokens, quoted strings for prose) — this is an ORIGINAL, Godot-idiomatic
## implementation, not ported code: no shared vocabulary of command names
## beyond what the contract specifies, and dispatch (see EventRunner) uses
## GDScript's own has_method/call reflection rather than any borrowed
## interpreter shape.
##
## A "script" is Array[String], one command per entry, e.g.:
##   ["speak alden \"Ah — you made it.\"", "wait 1.0", "end"]
## parse_line() turns ONE such string into {"cmd": String, "args": Array[String]}.
## Tokenizing rules:
##   - Tokens are separated by runs of whitespace.
##   - A double-quoted run ("...") is ONE token, quotes stripped, and may
##     contain internal whitespace (that's the whole point — dialog text).
##   - An unterminated quote consumes to the end of the line (documented,
##     not a crash) — malformed data should still parse to *something*
##     rather than throw, matching this file's "never crash on a bad script"
##     spirit (mirrors SaveManager's forgiving-parse convention).
##   - The command name is always args[0] lowercase-as-written (commands are
##     case-sensitive by convention; every command in the contract is
##     lowercase) — callers use it directly as `_cmd_<name>`.
##
## Kept a RefCounted/static-method utility (like NPCRegistry/DialogResolver)
## so it's independently unit-testable with zero scene-tree/autoload
## dependency.


static func parse_line(line: String) -> Dictionary:
	var tokens := _tokenize(line)
	if tokens.is_empty():
		return {"cmd": "", "args": []}
	var cmd: String = tokens[0]
	var args: Array[String] = []
	for i in range(1, tokens.size()):
		args.append(tokens[i])
	return {"cmd": cmd, "args": args}


static func _tokenize(line: String) -> Array[String]:
	var tokens: Array[String] = []
	var i := 0
	var n := line.length()
	while i < n:
		# Skip leading whitespace.
		while i < n and line[i] == " ":
			i += 1
		if i >= n:
			break
		if line[i] == "\"":
			i += 1
			var start := i
			while i < n and line[i] != "\"":
				i += 1
			tokens.append(line.substr(start, i - start))
			if i < n:
				i += 1  # skip closing quote
		else:
			var start := i
			while i < n and line[i] != " ":
				i += 1
			tokens.append(line.substr(start, i - start))
	return tokens


static func parse(script: Array) -> Array[Dictionary]:
	## Convenience: parse every line of a full script array at once, in order.
	var out: Array[Dictionary] = []
	for line: String in script:
		out.append(parse_line(line))
	return out
