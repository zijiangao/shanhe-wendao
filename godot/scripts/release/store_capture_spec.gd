class_name StoreCaptureSpec
extends RefCounted

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIRECTORY := "user://store_screenshots"
const RNG_SEED := 20260719
const SHOTS := [
	{"id": "world_map", "filename": "01-world-map.png"},
	{"id": "blackreed_investigation", "filename": "02-blackreed-investigation.png"},
	{"id": "blackreed_tactics", "filename": "03-blackreed-tactics.png"},
	{"id": "skill_impact", "filename": "04-skill-impact.png"},
	{"id": "huashan_companion", "filename": "05-huashan-companion.png"},
	{"id": "luoyang_choice", "filename": "06-luoyang-choice.png"},
	{"id": "wuku_finale", "filename": "07-wuku-finale.png"},
	{"id": "character_growth", "filename": "08-character-growth.png"}
]

static func filename_for(id: String) -> String:
	for shot in SHOTS:
		if str(shot.id) == id:
			return str(shot.filename)
	return ""
