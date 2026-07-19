extends SceneTree

const RULES := preload("res://scripts/ui/navigation_rules.gd")

func _initialize() -> void:
	root.get_node("SettingsManager").ensure_controller_navigation()
	assert(str(RULES.back_action("location").target) == "map", "Back from a location should return to the world map.")
	assert(str(RULES.back_action("map").target) == "menu", "Back from the world map should return to the main menu.")
	assert(str(RULES.back_action("settings", "menu").target) == "menu", "Settings should return to the screen that opened it.")
	assert(str(RULES.back_action("credits", "menu").target) == "menu", "Credits should return to the screen that opened them.")
	assert(str(RULES.back_action("save", "location").target) == "location", "Overlay screens should remember their origin.")
	assert(not bool(RULES.back_action("battle").allowed), "Back must not abandon an active battle.")
	assert(not bool(RULES.back_action("dialogue").allowed), "Back must not skip mandatory dialogue.")
	assert(not bool(RULES.back_action("choice").allowed), "Back must not bypass a story choice.")
	assert(not bool(RULES.back_action("defeat").allowed), "Defeat results require an explicit retry or retreat choice.")
	assert(RULES.can_pause("battle") and RULES.can_pause("dialogue") and RULES.can_pause("training"), "Modal gameplay should expose the safe pause menu.")
	assert(not RULES.can_pause("settings") and RULES.blocks_header_navigation("battle"), "Overlay pages should navigate back normally while battles block header bypasses.")
	assert(not RULES.should_save_on_quit("menu", {"week": 1}), "Quitting from the startup menu must not overwrite an existing autosave with default memory state.")
	assert(RULES.should_save_on_quit("location", {"week": 2}), "Quitting an active journey should request a safety save.")
	assert(InputMap.has_action("ui_accept") and InputMap.has_action("ui_cancel"), "Godot UI confirm and cancel actions must be available for keyboard and controller navigation.")
	assert(_has_joypad_event("ui_accept") and _has_joypad_event("ui_cancel"), "UI confirm and cancel should include joypad mappings.")
	for action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		assert(_has_joypad_event(action), "%s should include a joypad direction mapping." % action)
	print("NavigationRules tests passed.")
	quit()

func _has_joypad_event(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return true
	return false
