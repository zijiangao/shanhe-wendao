extends Node

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const UI_SCALES := [0.9, 1.0, 1.15, 1.3]
const DIFFICULTIES := ["story", "standard", "master"]
const REBINDABLE_ACTIONS := ["ui_up", "ui_right", "ui_down", "ui_left"]
const DEFAULT_KEY_BINDINGS := {"ui_up": KEY_W, "ui_right": KEY_D, "ui_down": KEY_S, "ui_left": KEY_A}
const ARROW_KEYS := {"ui_up": KEY_UP, "ui_right": KEY_RIGHT, "ui_down": KEY_DOWN, "ui_left": KEY_LEFT}
const JOYPAD_DIRECTIONS := {"ui_up": 11, "ui_down": 12, "ui_left": 13, "ui_right": 14}
const RESERVED_BINDING_KEYS := [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]

var data: Dictionary = {}

func _ready() -> void:
	ensure_controller_navigation()
	load_settings()
	apply_settings()

func defaults() -> Dictionary:
	return {
		"master_volume": 0.8,
		"music_volume": 0.7,
		"sfx_volume": 0.8,
		"fullscreen": false,
		"screen_shake": true,
		"combat_flashes": true,
		"ui_scale": 1.0,
		"difficulty": "standard",
		"key_bindings": DEFAULT_KEY_BINDINGS.duplicate(true)
	}

func load_settings(path: String = SETTINGS_PATH) -> bool:
	var values := defaults()
	var config := ConfigFile.new()
	var loaded := config.load(path) == OK
	if loaded:
		for key in values:
			values[key] = config.get_value("settings", key, values[key])
	data = normalize(values)
	return loaded

func save_settings(path: String = SETTINGS_PATH) -> bool:
	data = normalize(data)
	var config := ConfigFile.new()
	for key in data:
		config.set_value("settings", key, data[key])
	return config.save(path) == OK

func update_setting(key: String, value: Variant, apply: bool = true, save: bool = true) -> void:
	if not defaults().has(key):
		return
	data[key] = value
	data = normalize(data)
	if apply:
		apply_settings()
	if save:
		save_settings()
	settings_changed.emit()

func normalize(values: Dictionary) -> Dictionary:
	var result := defaults()
	for key in result:
		if values.has(key):
			result[key] = values[key]
	result.master_volume = clampf(float(result.master_volume), 0.0, 1.0)
	result.music_volume = clampf(float(result.music_volume), 0.0, 1.0)
	result.sfx_volume = clampf(float(result.sfx_volume), 0.0, 1.0)
	result.fullscreen = bool(result.fullscreen)
	result.screen_shake = bool(result.screen_shake)
	result.combat_flashes = bool(result.combat_flashes)
	var requested_scale := clampf(float(result.ui_scale), 0.9, 1.3)
	var closest_scale: float = UI_SCALES[0]
	for scale in UI_SCALES:
		if absf(float(scale) - requested_scale) < absf(closest_scale - requested_scale):
			closest_scale = float(scale)
	result.ui_scale = closest_scale
	var requested_difficulty := str(result.difficulty)
	result.difficulty = requested_difficulty if requested_difficulty in DIFFICULTIES else "standard"
	var requested_bindings = result.get("key_bindings", {})
	var bindings: Dictionary = DEFAULT_KEY_BINDINGS.duplicate(true)
	if typeof(requested_bindings) == TYPE_DICTIONARY:
		var used: Dictionary = {}
		for action in REBINDABLE_ACTIONS:
			var keycode := int(requested_bindings.get(action, DEFAULT_KEY_BINDINGS[action]))
			if keycode <= 0 or keycode in RESERVED_BINDING_KEYS or keycode in used:
				for fallback_action in REBINDABLE_ACTIONS:
					var candidate := int(DEFAULT_KEY_BINDINGS[fallback_action])
					if candidate not in used:
						keycode = candidate
						break
			bindings[action] = keycode
			used[keycode] = true
	result.key_bindings = bindings
	return result

func apply_settings() -> void:
	_apply_bus_volume("Master", float(data.get("master_volume", 0.8)))
	_apply_bus_volume("Music", float(data.get("music_volume", 0.7)))
	_apply_bus_volume("SFX", float(data.get("sfx_volume", 0.8)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(data.get("fullscreen", false)) else DisplayServer.WINDOW_MODE_WINDOWED)
	get_tree().root.content_scale_factor = float(data.get("ui_scale", 1.0))
	apply_key_bindings()

func set_key_binding(action: String, keycode: int, save: bool = true) -> bool:
	if action not in REBINDABLE_ACTIONS or keycode <= 0 or keycode in RESERVED_BINDING_KEYS:
		return false
	var bindings: Dictionary = data.get("key_bindings", DEFAULT_KEY_BINDINGS.duplicate(true)).duplicate(true)
	var previous := int(bindings.get(action, DEFAULT_KEY_BINDINGS[action]))
	for other_action in REBINDABLE_ACTIONS:
		if other_action != action and int(bindings.get(other_action, 0)) == keycode:
			bindings[other_action] = previous
	bindings[action] = keycode
	data.key_bindings = bindings
	data = normalize(data)
	apply_key_bindings()
	if save:
		save_settings()
	settings_changed.emit()
	return true

func reset_key_bindings(save: bool = true) -> void:
	data.key_bindings = DEFAULT_KEY_BINDINGS.duplicate(true)
	apply_key_bindings()
	if save:
		save_settings()
	settings_changed.emit()

func key_label(action: String) -> String:
	return OS.get_keycode_string(int(data.get("key_bindings", DEFAULT_KEY_BINDINGS).get(action, DEFAULT_KEY_BINDINGS.get(action, 0))))

func apply_key_bindings() -> void:
	var bindings: Dictionary = data.get("key_bindings", DEFAULT_KEY_BINDINGS)
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var arrow := InputEventKey.new()
		arrow.keycode = int(ARROW_KEYS[action])
		InputMap.action_add_event(action, arrow)
		var custom := InputEventKey.new()
		custom.physical_keycode = int(bindings.get(action, DEFAULT_KEY_BINDINGS[action]))
		InputMap.action_add_event(action, custom)
		_add_joypad_button(action, int(JOYPAD_DIRECTIONS[action]))

func _apply_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, linear_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(0.001, linear_volume)))

func ensure_controller_navigation() -> void:
	_add_joypad_button("ui_accept", 0)
	_add_joypad_button("ui_cancel", 1)
	_add_joypad_button("ui_up", 11)
	_add_joypad_button("ui_down", 12)
	_add_joypad_button("ui_left", 13)
	_add_joypad_button("ui_right", 14)

func _add_joypad_button(action: StringName, button_index: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and (existing as InputEventJoypadButton).button_index == button_index:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action, event)
