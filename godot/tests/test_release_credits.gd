extends SceneTree

const CREDITS_PATH := "res://data/credits.json"

func _initialize() -> void:
	assert(FileAccess.file_exists(CREDITS_PATH), "The shipping credits manifest must exist.")
	var file := FileAccess.open(CREDITS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	assert(typeof(parsed) == TYPE_DICTIONARY and int(parsed.get("version", 0)) >= 1, "Credits must be valid versioned JSON.")
	var ids: Dictionary = {}
	for section in parsed.get("sections", []):
		ids[str(section.get("id", ""))] = true
		assert(not str(section.get("title", "")).is_empty() and not section.get("lines", []).is_empty(), "Every credits section needs a visible title and content.")
	for required in ["production", "art", "audio", "technology", "thanks"]:
		assert(ids.has(required), "Credits must include the %s section." % required)
	assert(FileAccess.file_exists("res://ASSET_PROVENANCE.md"), "Release review requires an asset provenance register.")
	assert(FileAccess.file_exists("res://THIRD_PARTY_NOTICES.md"), "Release review requires third-party notices.")
	print("Release credits tests passed.")
	quit()
