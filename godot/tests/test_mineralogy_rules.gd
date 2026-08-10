extends SceneTree

const RULES := preload("res://scripts/progression/mineralogy_rules.gd")

func _init() -> void:
	# 挖矿等级 (0.117.0) -- gather_level()/catches_to_next_level() derive
	# purely from the mineralogy dict's total catch count, no extra save
	# field needed.
	assert(RULES.gather_level({}) == 1, "A fresh, empty mineral ledger should start at gather level 1.")
	assert(RULES.gather_level({"ironstone": 2}) == 1, "2 catches (< CATCHES_PER_LEVEL) should still be level 1.")
	assert(RULES.gather_level({"ironstone": 3}) == 2, "Exactly CATCHES_PER_LEVEL catches should cross into level 2.")
	assert(RULES.gather_level({"ironstone": 100}) == RULES.MAX_GATHER_LEVEL, "Gather level should cap at MAX_GATHER_LEVEL no matter how many catches accumulate.")
	assert(RULES.catches_to_next_level({"ironstone": 1}) == 2, "2 more catches should be needed to reach level 2 from 1 catch.")
	assert(RULES.catches_to_next_level({"ironstone": 100}) == 0, "A maxed-out gather level should report 0 catches remaining.")

	# record() -- 硬门槛：未到对应等级，即使单局打出S级也绝对挖不到高阶矿石
	# (not just a lower probability -- LEVEL_UNLOCK filters the pool outright).
	var fresh_state := {"mineralogy": {}}
	for i in range(8):
		var result: Dictionary = RULES.record(fresh_state, "S", 0)
		assert(str(result.id) == "ironstone", "Below level 4 (needs 9 catches), even S-grade rolls must stay locked to the tier-1 mineral -- catch #%d got %s instead." % [i + 1, result.id])
	assert(RULES.gather_level(fresh_state.mineralogy) == 3, "8 catches should land at level 3 (1 + 8/3), one catch short of unlocking 流银砂 at level 4.")
	# The 9th catch is gated by the level BEFORE it lands (still 3), so it
	# stays locked to 青铁石 even though it's the catch that crosses into
	# level 4 -- the newly reached level only opens the gate for the NEXT
	# catch onward, not retroactively for the one that triggered it.
	var leveling_result: Dictionary = RULES.record(fresh_state, "S", 0)
	assert(str(leveling_result.id) == "ironstone" and bool(leveling_result.leveled_up) and RULES.gather_level(fresh_state.mineralogy) == 4, "The 9th catch should still be locked to 青铁石 but should report leveled_up as it crosses into level 4.")
	var unlocked_result: Dictionary = RULES.record(fresh_state, "S", 0)
	assert(str(unlocked_result.id) == "silver_sand", "Once level 4 is reached, the NEXT S-grade roll should now be able to find 流银砂 instead of only 青铁石.")

	# Once a rare mineral's tier is unlocked, undiscovered-first prioritization
	# and first-discovery appraisal rewards still work exactly as before.
	var second_state := {"mineralogy": {"ironstone": 9, "silver_sand": 0, "fire_copper": 0, "star_marrow": 0}}
	var first_silver_sand := RULES.record(second_state, "S", 0)
	assert(str(first_silver_sand.id) == "silver_sand" and bool(first_silver_sand.first_discovery) and int(first_silver_sand.silver) == 2, "High-grade mining should still prioritize an undiscovered eligible mineral once its tier is unlocked.")
	var repeat := RULES.record(second_state, "C", 0)
	assert(str(repeat.id) == "ironstone" and not bool(repeat.first_discovery) and int(repeat.silver) == 0, "Duplicate minerals must not farm appraisal rewards.")

	var low_state := {"mineralogy": {}}
	assert(str(RULES.record(low_state, "C", 99).id) == "ironstone", "Low-grade mining should only find the common mineral.")
	assert(RULES.record(low_state, "invalid", 0).is_empty(), "Unknown grades must not mutate the mineral ledger.")
	assert(RULES.collection_text({"ironstone": 2}).contains("青铁石×2") and RULES.collection_text({"ironstone": 2}).contains("流银砂×0"), "The mineral summary should always name every mineral (0.90.0), not hide undiscovered ones behind ？？？.")
	print("Mineralogy rule tests passed.")
	quit()
