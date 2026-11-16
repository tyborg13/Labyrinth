extends RefCounted
## Proof-only before image: retain the integrated scene and omit only atk-12's
## three presentation calls. No resolver, timing constant or save is changed.
static func before(source: String) -> String:
	var lines: PackedStringArray = source.split("\n")
	var omitted: int = 0
	for index: int in range(lines.size()):
		if not lines[index].strip_edges().begins_with('await preload("res://scripts/hero_loss_playback.gd").present(self, '): continue
		lines[index] = lines[index].left(lines[index].length() - lines[index].strip_edges().length()) + "pass # atk-12 proof: before presentation repair"
		omitted += 1
	assert(omitted == 3, "atk-12 before-source contract: exactly three presentation calls")
	return "\n".join(lines)
