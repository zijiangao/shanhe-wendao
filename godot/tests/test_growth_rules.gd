extends SceneTree

const RULES := preload("res://scripts/progression/growth_rules.gd")

func _initialize() -> void:
	assert(RULES.rank_name(0) == "初窥门径" and RULES.combat_bonus(0) == 0, "New characters should begin at the first cultivation rank.")
	assert(RULES.rank_name(30) == "登堂入室" and RULES.combat_bonus(30) == 1, "Crossing a rank threshold should grant a combat bonus.")
	assert(RULES.next_rank_xp(29) == 30 and RULES.next_rank_xp(999) == -1, "Rank progress should expose the next threshold and cap cleanly.")
	var state := {"xp": 0, "strength": 4, "insight": 4, "constitution": 4, "max_hp": 45, "hp": 40}
	assert(RULES.apply_training(state, "constitution"), "A supported training focus should apply.")
	assert(int(state.constitution) == 5 and int(state.max_hp) == 48 and int(state.hp) == 43 and int(state.xp) == 12, "Constitution training should grant the complete previewed reward.")
	var unchanged := state.duplicate(true)
	assert(not RULES.apply_training(state, "invalid") and state == unchanged, "Invalid training choices must not mutate progression state.")

	# Character level (0.93.0): a separate, independent progression track
	# from 境界 above -- crossing LEVEL_XP_STEP xp grants +1 to all four
	# base attributes, not just an abstract combat bonus.
	assert(RULES.character_level(0) == 1 and RULES.character_level(RULES.LEVEL_XP_STEP - 1) == 1, "A fresh character should stay at level 1 until a full step of xp accumulates.")
	assert(RULES.character_level(RULES.LEVEL_XP_STEP) == 2, "Exactly one xp step should reach level 2.")

	var fresh := {"xp": 0, "character_level": 1, "strength": 4, "agility": 5, "insight": 4, "constitution": 4, "max_hp": 45, "hp": 45}
	assert(RULES.grant_xp(fresh, RULES.LEVEL_XP_STEP - 1) == 0, "A gain that doesn't cross the xp step should grant no level.")
	assert(int(fresh.strength) == 4 and int(fresh.agility) == 5, "No level-up means no attribute change.")
	assert(RULES.grant_xp(fresh, 1) == 1, "The xp that finally crosses the step should grant exactly one level.")
	assert(int(fresh.strength) == 5 and int(fresh.agility) == 6 and int(fresh.insight) == 5 and int(fresh.constitution) == 5, "Leveling up should grant +1 to all four base attributes at once.")
	assert(int(fresh.max_hp) == 48 and int(fresh.hp) == 48, "Leveling up should also grant constitution's usual +3 max/current hp.")
	assert(int(fresh.character_level) == 2, "The tracked level should advance to match.")

	var big_jump := {"xp": 0, "character_level": 1, "strength": 4, "agility": 5, "insight": 4, "constitution": 4, "max_hp": 45, "hp": 45}
	assert(RULES.grant_xp(big_jump, RULES.LEVEL_XP_STEP * 3) == 3, "A single large xp gain should grant every level it crosses in one call, not just one.")
	assert(int(big_jump.strength) == 7, "Three levels at once should grant +3, not +1.")

	# Saves from before this feature existed must never be retroactively
	# back-paid a pile of free attribute points for xp they already earned
	# under the old model -- they start tracking from here forward only.
	var legacy_save := {"xp": RULES.LEVEL_XP_STEP * 5, "strength": 4, "agility": 5, "insight": 4, "constitution": 4, "max_hp": 45, "hp": 45}
	assert(RULES.grant_xp(legacy_save, 1) == 0, "A save with no character_level field must not be back-paid for xp already accumulated before this feature existed.")
	assert(int(legacy_save.strength) == 4, "No retroactive attribute grant should occur on a legacy save's first xp gain.")

	print("Growth rules tests passed.")
	quit()

