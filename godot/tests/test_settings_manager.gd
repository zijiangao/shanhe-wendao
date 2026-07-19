extends SceneTree

const MANAGER_SCRIPT := preload("res://autoload/settings_manager.gd")
const TEST_PATH := "user://codex_settings_test.cfg"

func _initialize() -> void:
	_cleanup()
	assert(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0, "The project should provide separate music and sound-effect buses.")
	var manager = MANAGER_SCRIPT.new()
	var normalized: Dictionary = manager.normalize({"master_volume": 2.0, "music_volume": -1.0, "sfx_volume": 0.45, "fullscreen": 1, "screen_shake": false, "combat_flashes": false, "ui_scale": 1.22, "difficulty": "master", "unknown": true})
	assert(is_equal_approx(float(normalized.master_volume), 1.0), "Master volume should clamp to one.")
	assert(is_equal_approx(float(normalized.music_volume), 0.0), "Music volume should clamp to zero.")
	assert(is_equal_approx(float(normalized.ui_scale), 1.15), "UI scale should snap to a supported value.")
	assert(bool(normalized.fullscreen) and not normalized.has("unknown"), "Settings should normalize types and discard unknown keys.")
	assert(str(normalized.difficulty) == "master", "A supported combat difficulty should survive normalization.")
	assert(not bool(normalized.screen_shake) and not bool(normalized.combat_flashes), "Combat feedback accessibility toggles should normalize as booleans.")
	assert(str(manager.normalize({"difficulty": "impossible"}).difficulty) == "standard", "Unknown difficulty values should safely fall back to standard.")
	var repaired_bindings: Dictionary = manager.normalize({"key_bindings": {"ui_up": KEY_I, "ui_right": KEY_I, "ui_down": -1, "ui_left": KEY_J}}).key_bindings
	var unique_binding_keys: Dictionary = {}
	for value in repaired_bindings.values():
		unique_binding_keys[int(value)] = true
	assert(unique_binding_keys.size() == 4, "Corrupted duplicate key bindings should normalize to four unique controls.")

	manager.data = normalized
	assert(manager.set_key_binding("ui_up", KEY_I, false), "A supported direction should accept a keyboard rebind.")
	assert(int(manager.data.key_bindings.ui_up) == KEY_I, "The selected physical key should be stored.")
	assert(InputMap.action_get_events("ui_up").any(func(event: InputEvent): return event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_I), "A saved binding should immediately replace the active gameplay action.")
	assert(manager.set_key_binding("ui_right", KEY_I, false), "Binding an occupied key should swap rather than reject it.")
	assert(int(manager.data.key_bindings.ui_right) == KEY_I and int(manager.data.key_bindings.ui_up) == KEY_D, "Conflicting bindings should exchange their previous keys.")
	assert(not manager.set_key_binding("ui_left", KEY_ESCAPE, false) and not manager.set_key_binding("ui_left", KEY_SHIFT, false) and not manager.set_key_binding("invalid", KEY_J, false), "Reserved keys, pure modifiers, and unknown actions must be rejected.")
	assert(manager.save_settings(TEST_PATH), "Settings should save to a ConfigFile.")
	var loaded_manager = MANAGER_SCRIPT.new()
	assert(loaded_manager.load_settings(TEST_PATH), "Saved settings should load successfully.")
	assert(is_equal_approx(float(loaded_manager.data.sfx_volume), 0.45), "Saved volume values should round-trip.")
	assert(is_equal_approx(float(loaded_manager.data.ui_scale), 1.15), "Saved UI scale should round-trip.")
	assert(str(loaded_manager.data.difficulty) == "master", "Saved combat difficulty should round-trip.")
	assert(int(loaded_manager.data.key_bindings.ui_right) == KEY_I and int(loaded_manager.data.key_bindings.ui_up) == KEY_D, "Custom key bindings should round-trip through settings.cfg.")
	assert(not bool(loaded_manager.data.screen_shake) and not bool(loaded_manager.data.combat_flashes), "Combat feedback toggles should round-trip.")
	manager.reset_key_bindings(false)
	assert(manager.data.key_bindings == manager.DEFAULT_KEY_BINDINGS, "Reset should restore the complete WASD layout.")

	manager.free()
	loaded_manager.free()
	_cleanup()
	print("SettingsManager tests passed.")
	quit()

func _cleanup() -> void:
	var directory := DirAccess.open("user://")
	if directory != null and directory.file_exists(TEST_PATH.trim_prefix("user://")):
		directory.remove(TEST_PATH.trim_prefix("user://"))
