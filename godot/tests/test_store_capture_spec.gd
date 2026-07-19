extends SceneTree

const SPEC := preload("res://scripts/release/store_capture_spec.gd")

func _initialize() -> void:
	assert(SPEC.OUTPUT_SIZE == Vector2i(1920, 1080), "Steam screenshots should use the required 1920x1080 target.")
	assert(SPEC.SHOTS.size() >= 5, "The Steam store candidate set should contain at least five gameplay screenshots.")
	var ids: Dictionary = {}
	var filenames: Dictionary = {}
	for shot in SPEC.SHOTS:
		var id := str(shot.get("id", ""))
		var filename := str(shot.get("filename", ""))
		assert(not id.is_empty() and not ids.has(id), "Screenshot identifiers must be present and unique.")
		assert(filename.ends_with(".png") and not filenames.has(filename), "Screenshot filenames must be unique PNG files.")
		assert(SPEC.filename_for(id) == filename, "Every screenshot id must resolve to its stable filename.")
		ids[id] = true
		filenames[filename] = true
	for required in ["world_map", "blackreed_investigation", "blackreed_tactics", "skill_impact", "huashan_companion", "luoyang_choice"]:
		assert(ids.has(required), "The store capture set is missing %s." % required)
	print("Store capture specification tests passed.")
	quit()
