extends SceneTree

const RULES := preload("res://scripts/progression/equipment_rules.gd")

func _init() -> void:
	var missing := {}
	RULES.add_owned(missing, "owned_weapons", "iron_sword", 1)
	assert(RULES.owned_count(missing, "owned_weapons", "iron_sword") == 1, "The first item must initialize a missing equipment category.")
	var corrupted := {"owned_armors": []}
	assert(RULES.owned_count(corrupted, "owned_armors", "hedgehog_mail") == 0)
	RULES.add_owned(corrupted, "owned_armors", "hedgehog_mail", 1)
	assert(RULES.owned_count(corrupted, "owned_armors", "hedgehog_mail") == 1)
	missing.owned_weapons.iron_sword = -3
	RULES.add_owned(missing, "owned_weapons", "iron_sword", 1)
	assert(int(missing.owned_weapons.iron_sword) == 1, "Invalid negative ownership must not swallow a newly acquired item.")
	var unchanged := missing.duplicate(true)
	RULES.add_owned(missing, "owned_weapons", "", 1)
	assert(missing == unchanged, "Empty item identifiers must not create inventory entries.")
	assert(RULES.owned_count({}, "owned_weapons", "iron_sword") == 0, "An empty state should report zero owned copies of anything.")
	var state := {"owned_weapons": {}, "equipped_weapon": "", "companion_gear": {}}
	RULES.add_owned(state, "owned_weapons", "iron_sword", 2)
	assert(RULES.owned_count(state, "owned_weapons", "iron_sword") == 2, "add_owned() should accumulate the owned count.")
	RULES.add_owned(state, "owned_weapons", "iron_sword", -1)
	assert(RULES.owned_count(state, "owned_weapons", "iron_sword") == 1, "add_owned() should also subtract, down to a positive remainder.")
	RULES.add_owned(state, "owned_weapons", "iron_sword", -1)
	assert(RULES.owned_count(state, "owned_weapons", "iron_sword") == 0 and "iron_sword" not in state.owned_weapons, "Dropping to zero should erase the key entirely, not leave a zero entry lingering.")

	# wearers()/claimed_count() -- 沈羽 (equipped_weapon) plus every companion's
	# companion_gear[id]["weapon"/"armor"] all count as "wearing" something.
	var roster_state := {"equipped_weapon": "iron_sword", "companion_gear": {"zhou_mubai": {"weapon": "iron_sword", "armor": ""}, "liu_ruyan": {"weapon": "cold_crow_blade", "armor": ""}}}
	assert(RULES.claimed_count(roster_state, "weapon", "iron_sword") == 2, "Both 沈羽 and 周慕白 wearing 铁胎剑 should count as two claims.")
	assert(RULES.claimed_count(roster_state, "weapon", "iron_sword", "hero") == 1, "Excluding 沈羽's own slot should drop the count to just 周慕白's claim.")
	assert(RULES.claimed_count(roster_state, "weapon", "cold_crow_blade") == 1, "柳如烟's separate weapon should be counted independently.")
	assert(RULES.claimed_count(roster_state, "weapon", "dragon_etched_sword") == 0, "An unworn weapon id should report zero claims.")

	# is_available_for() -- exactly enough owned copies for every current
	# wearer means no more room; excluding the wearer being re-checked lets
	# them keep their own slot without being blocked by themselves.
	var supply_state := {"owned_weapons": {"iron_sword": 1}, "equipped_weapon": "iron_sword", "companion_gear": {}}
	assert(RULES.is_available_for(supply_state, "owned_weapons", "weapon", "iron_sword", "hero"), "沈羽 re-selecting the weapon he's already wearing must always succeed.")
	assert(not RULES.is_available_for(supply_state, "owned_weapons", "weapon", "iron_sword", "zhou_mubai"), "With only one copy already worn by 沈羽, a companion should not be able to also equip it.")
	RULES.add_owned(supply_state, "owned_weapons", "iron_sword", 1)
	assert(RULES.is_available_for(supply_state, "owned_weapons", "weapon", "iron_sword", "zhou_mubai"), "A second copy should free up availability for a companion.")
	assert(RULES.is_available_for(supply_state, "owned_weapons", "weapon", "", "zhou_mubai"), "Unequipping (empty id) should always be available regardless of supply.")

	# reconcile_wearers() -- selling down to fewer copies than current wearers
	# must forcibly unequip enough people (沈羽 first, then companions) to fit.
	var reconcile_state := {"owned_weapons": {"iron_sword": 2}, "equipped_weapon": "iron_sword", "companion_gear": {"zhou_mubai": {"weapon": "iron_sword", "armor": ""}}}
	RULES.add_owned(reconcile_state, "owned_weapons", "iron_sword", -1)
	RULES.reconcile_wearers(reconcile_state, "owned_weapons", "weapon", "iron_sword")
	assert(str(reconcile_state.equipped_weapon) == "", "Dropping to one copy with two wearers should unequip 沈羽 first.")
	assert(str(reconcile_state.companion_gear.zhou_mubai.weapon) == "iron_sword", "The companion should keep the remaining copy -- only the excess wearer count gets trimmed.")

	print("Equipment rule tests passed.")
	quit()
