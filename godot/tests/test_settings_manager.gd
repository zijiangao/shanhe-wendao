extends SceneTree

const MANAGER_SCRIPT := preload("res://autoload/settings_manager.gd")
const TEST_PATH := "user://codex_settings_test.cfg"

func _initialize() -> void:
	_cleanup()
	assert(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0, "The project should provide separate music and sound-effect buses.")
	var manager = MANAGER_SCRIPT.new()
	var normalized: Dictionary = manager.normalize({"master_volume": 2.0, "music_volume": -1.0, "sfx_volume": 0.45, "fullscreen": 1, "ui_scale": 1.22, "difficulty": "master", "unknown": true})
	assert(is_equal_approx(float(normalized.master_volume), 1.0), "Master volume should clamp to one.")
	assert(is_equal_approx(float(normalized.music_volume), 0.0), "Music volume should clamp to zero.")
	assert(is_equal_approx(float(normalized.ui_scale), 1.15), "UI scale should snap to a supported value.")
	assert(bool(normalized.fullscreen) and not normalized.has("unknown"), "Settings should normalize types and discard unknown keys.")
	assert(str(normalized.difficulty) == "master", "A supported combat difficulty should survive normalization.")
	assert(str(manager.normalize({"difficulty": "impossible"}).difficulty) == "standard", "Unknown difficulty values should safely fall back to standard.")

	manager.data = normalized
	assert(manager.save_settings(TEST_PATH), "Settings should save to a ConfigFile.")
	var loaded_manager = MANAGER_SCRIPT.new()
	assert(loaded_manager.load_settings(TEST_PATH), "Saved settings should load successfully.")
	assert(is_equal_approx(float(loaded_manager.data.sfx_volume), 0.45), "Saved volume values should round-trip.")
	assert(is_equal_approx(float(loaded_manager.data.ui_scale), 1.15), "Saved UI scale should round-trip.")
	assert(str(loaded_manager.data.difficulty) == "master", "Saved combat difficulty should round-trip.")

	manager.free()
	loaded_manager.free()
	_cleanup()
	print("SettingsManager tests passed.")
	quit()

func _cleanup() -> void:
	var directory := DirAccess.open("user://")
	if directory != null and directory.file_exists(TEST_PATH.trim_prefix("user://")):
		directory.remove(TEST_PATH.trim_prefix("user://"))
