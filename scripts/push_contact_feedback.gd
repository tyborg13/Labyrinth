extends RefCounted

const FloatingText = preload("res://scripts/floating_combat_text.gd")
const SURFACE_KEY: String = "push_contact_surface"
const ICONS: Dictionary = {"fire": "surface_fire"}

var _heard: Dictionary = {}


func clear() -> void:
	_heard.clear()


func play_cues(entries: Array, play_surface: Callable) -> void:
	for entry: Dictionary in entries:
		if not entry.has(SURFACE_KEY): continue
		var id: String = FloatingText.ensure_screen_layout_id(entry)
		if _heard.has(id): continue
		_heard[id] = true
		play_surface.call(entry[SURFACE_KEY])


static func split(scene: Control, entries: Array[Dictionary], events: Array[Dictionary], after: Dictionary) -> Array[Dictionary]:
	var contacts: Dictionary = {}
	for event: Dictionary in events:
		var surface: String = str(event.get("surface", ""))
		if event.get("kind") != "surface_damage" or event.get("trigger") != "entry" or not ICONS.has(surface): continue
		if event.get("actor_kind") != "enemy" or int(event.get("health_lost", 0)) <= 0: continue
		if after.has("umbra") and not scene._umbra_information_tile_visible(after, event["tile"]): continue
		var key: String = str(event["actor_key"])
		var actor_contacts: Dictionary = contacts.get_or_add(key, {})
		actor_contacts[surface] = int(actor_contacts.get(surface, 0)) + int(event["health_lost"])
	if contacts.is_empty(): return entries

	var result: Array[Dictionary]
	for entry: Dictionary in entries:
		var actor: String = str(entry.get("reaction_actor_key", ""))
		if entry.get("reaction") != "hit" or not contacts.has(actor):
			result.append(entry)
			continue
		var total: int = absi(str(entry["text"]).to_int())
		var remaining: int = total
		var contact_entries: Array[Dictionary]
		for surface: String in contacts[actor]:
			var amount: int = mini(int(contacts[actor][surface]), remaining)
			if amount <= 0: break
			remaining -= amount
			var contact: Dictionary = _damage(entry, amount)
			scene._decorate_status_damage_float(contact, ICONS[surface])
			contact[SURFACE_KEY] = surface
			contact_entries.append(contact)
		if remaining > 0: contact_entries.push_front(_damage(entry, remaining))
		# Keep the existing combined recoil and hit-stop. Later numbers share
		# the popup timeline without starting another physical impact.
		contact_entries[0][FloatingText.IMPACT_DAMAGE_KEY] = total
		for index: int in range(1, contact_entries.size()):
			contact_entries[index][FloatingText.POPUP_ONLY_KEY] = true
			contact_entries[index].erase("reaction")
		result.append_array(contact_entries)
	return result


static func _damage(entry: Dictionary, amount: int) -> Dictionary:
	return FloatingText.damage_entry(entry["tile"], "−%d" % amount, entry["color"],
		{"reaction_actor_key": entry["reaction_actor_key"], "reaction": entry["reaction"]})
