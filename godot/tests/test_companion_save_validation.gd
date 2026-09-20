extends SceneTree

const EQUIPMENT := preload("res://scripts/progression/equipment_rules.gd")

func _initialize() -> void:
	var state = load("res://autoload/game_state.gd").new()
	root.add_child(state)
	state.new_game()
	var saved: Dictionary = state.data.duplicate(true)
	saved.companions = ["zhou_mubai", "liu_ruyan"]
	saved.owned_weapons = {"iron_sword": 1}
	saved.owned_armors = {"hedgehog_mail": 1}
	saved.equipped_weapon = "iron_sword"
	saved.companion_gear = {"nobody": {"weapon": "iron_sword"}, "zhou_mubai": "broken", "liu_ruyan": {"weapon": "unknown", "armor": "hedgehog_mail"}}
	assert(state.import_data(saved))
	assert(not state.data.companion_gear.has("nobody") and not state.data.companion_gear.has("zhou_mubai"), "Invalid nested equipment and unjoined owners must be discarded.")
	assert(str(state.data.companion_gear.liu_ruyan.weapon) == "" and str(state.data.companion_gear.liu_ruyan.armor) == "hedgehog_mail", "Valid owned gear must survive recovery while unknown gear is cleared.")
	saved.companion_gear = {"zhou_mubai": {"weapon": "iron_sword"}, "liu_ruyan": {"weapon": "iron_sword"}}
	assert(state.import_data(saved))
	assert(EQUIPMENT.claimed_count(state.data, "weapon", "iron_sword") == 1, "Loading must enforce the actual number of owned equipment copies.")
	var recovered: Dictionary = state.data.duplicate(true)
	assert(state.import_data(recovered) and state.data.companion_gear == recovered.companion_gear, "Repeated loads must not progressively remove valid equipment.")
	saved.learned_moves = ["cloud_sword"]
	saved.learned_internal = ["purple_mist_art"]
	saved.learned_lightness = ["ripple_steps"]
	saved.companion_move = {"zhou_mubai": "cloud_sword", "liu_ruyan": "blade_technique", "nobody": "cloud_sword"}
	saved.companion_internal = {"zhou_mubai": "purple_mist_art", "liu_ruyan": "missing"}
	saved.companion_lightness = {"zhou_mubai": "ripple_steps", "liu_ruyan": "missing"}
	saved.companion_tasks = {"zhou_mubai": "train", "liu_ruyan": "missing", "nobody": "earn"}
	assert(state.import_data(saved))
	assert(state.data.companion_move == {"zhou_mubai": "cloud_sword"})
	assert(state.data.companion_internal == {"zhou_mubai": "purple_mist_art"})
	assert(state.data.companion_lightness == {"zhou_mubai": "ripple_steps"})
	assert(state.data.companion_tasks == {"zhou_mubai": "train"}, "Only joined companions with valid tasks may retain assignments.")
	saved.equipped_internal = ""
	saved.equipped_lightness = ""
	assert(state.import_data(saved))
	assert(state.data.equipped_internal == "" and state.data.equipped_lightness == "", "Explicit unequip choices must survive loading.")
	var original_power: int = state.power()
	saved.learned_moves.append("cloud_sword")
	saved.learned_internal.append("purple_mist_art")
	saved.learned_lightness.append("ripple_steps")
	assert(state.import_data(saved))
	assert(state.data.learned_moves == ["cloud_sword"])
	assert(state.data.learned_internal.count("purple_mist_art") == 1 and state.data.learned_lightness.count("ripple_steps") == 1)
	assert(state.power() == original_power, "Duplicate learned skills must not inflate combat power.")
	print("Companion save validation tests passed.")
	quit()
