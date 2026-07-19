extends SceneTree

const SPEC := preload("res://scripts/battle/battle_scene_spec.gd")

func _initialize() -> void:
	var texture_paths: Dictionary = {}
	for battle_id in ["blackreed", "huashan_trial", "wuku_finale"]:
		var scene: Dictionary = SPEC.scene_for(battle_id)
		var texture_path := str(scene.get("texture", ""))
		assert(FileAccess.file_exists(texture_path), "%s should reference a shipping battle backdrop." % battle_id)
		assert(not texture_paths.has(texture_path), "Each commercial story battle should have a visually distinct backdrop.")
		assert(not str(scene.get("title", "")).is_empty(), "Each battle scene should expose a readable atmosphere title.")
		assert(Color(str(scene.get("shade", "#000000"))).a > 0.0, "Each battle scene should define a legibility shade.")
		texture_paths[texture_path] = true
	assert(SPEC.scene_for("unknown") == SPEC.scene_for(SPEC.FALLBACK_ID), "Unknown battles should use the safe fallback scene.")
	print("Battle scene specification tests passed.")
	quit()

