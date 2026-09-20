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
	print("Companion save validation tests passed.")
	quit()
