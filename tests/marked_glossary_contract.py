"""mrk-01's approved supersession of four historical glossary identities.

Read-only test expectations: original director copy and goldens stay protected.
"""

# mrk-01 supersedes only these four protected keyword identities. Keep the
# director's staged copy and golden files intact; all other rows stay exact.
MARKED_RETIRED = {"lob", "icefall", "burrow", "erupt"}
MARKED_DEFINITION = "These tiles take the hit on this enemy's next turn."
MARKED_METADATA = {
    "id": "marked", "name": "Marked", "icon": "marked",
    "aliases": ["icefall", "Icefall", "icefall_mark", "icefall_land", "lob",
                "Lob Slag", "lob_slag", "lob_mark", "lob_land", "slag_lands",
                "burrow", "Burrow", "erupt", "Erupt"],
}


def marked_metadata_supersession(metadata):
    result = []
    inserted = False
    for entry in metadata:
        if entry["id"] in MARKED_RETIRED:
            if not inserted:
                result.append(MARKED_METADATA)
                inserted = True
        else:
            result.append(entry)
    return result


def marked_glossary_supersession(entries):
    result = {key: entry for key, entry in entries.items() if key not in MARKED_RETIRED}
    result["marked"] = dict(MARKED_METADATA, definition=MARKED_DEFINITION)
    return result
