extends SceneTree

const RULES := preload("res://scripts/progression/herbarium_rules.gd")

func _init() -> void:
	# 采药等级 (0.117.0) -- gather_level()/catches_to_next_level() derive
	# purely from the collection dict's total catch count, no extra save
	# field needed.
	assert(RULES.gather_level({}) == 1, "A fresh, empty herbarium should start at gather level 1.")
	assert(RULES.gather_level({"dewgrass": 2}) == 1, "2 catches (< CATCHES_PER_LEVEL) should still be level 1.")
	assert(RULES.gather_level({"dewgrass": 3}) == 2, "Exactly CATCHES_PER_LEVEL catches should cross into level 2.")
	assert(RULES.gather_level({"dewgrass": 100}) == RULES.MAX_GATHER_LEVEL, "Gather level should cap at MAX_GATHER_LEVEL no matter how many catches accumulate.")
	assert(RULES.catches_to_next_level({"dewgrass": 1}) == 2, "2 more catches should be needed to reach level 2 from 1 catch.")
	assert(RULES.catches_to_next_level({"dewgrass": 100}) == 0, "A maxed-out gather level should report 0 catches remaining.")

	# record() -- 硬门槛：未到对应等级，即使单局打出S级也绝对采不到高阶品种
	# (not just a lower probability -- LEVEL_UNLOCK filters the pool outright).
	var fresh_state := {"herbarium": {}}
	for i in range(8):
		var result: Dictionary = RULES.record(fresh_state, "S", 0)
		assert(str(result.id) == "dewgrass", "Below level 4 (needs 9 catches), even S-grade rolls must stay locked to the tier-1 specimen -- catch #%d got %s instead." % [i + 1, result.id])
	assert(RULES.gather_level(fresh_state.herbarium) == 3, "8 catches should land at level 3 (1 + 8/3), one catch short of unlocking 云纹叶 at level 4.")
	# The 9th catch is gated by the level BEFORE it lands (still 3), so it
	# stays locked to 凝露草 even though it's the catch that crosses into
	# level 4 -- the newly reached level only opens the gate for the NEXT
	# catch onward, not retroactively for the one that triggered it.
	var leveling_result: Dictionary = RULES.record(fresh_state, "S", 0)
	assert(str(leveling_result.id) == "dewgrass" and bool(leveling_result.leveled_up) and RULES.gather_level(fresh_state.herbarium) == 4, "The 9th catch should still be locked to 凝露草 but should report leveled_up as it crosses into level 4.")
	var unlocked_result: Dictionary = RULES.record(fresh_state, "S", 0)
	assert(str(unlocked_result.id) == "cloudleaf", "Once level 4 is reached, the NEXT S-grade roll should now be able to find 云纹叶 instead of only 凝露草.")

	# Once a rare specimen's tier is unlocked, undiscovered-first prioritization
	# and first-discovery cultivation rewards still work exactly as before.
	var second_state := {"herbarium": {"dewgrass": 9, "cloudleaf": 0, "sunroot": 0, "sevenstar_lotus": 0}}
	var first_cloudleaf := RULES.record(second_state, "S", 0)
	assert(str(first_cloudleaf.id) == "cloudleaf" and bool(first_cloudleaf.first_discovery) and int(first_cloudleaf.xp) == 2, "High-grade gathering should still prioritize an undiscovered eligible specimen once its tier is unlocked.")
	var repeat := RULES.record(second_state, "C", 0)
	assert(str(repeat.id) == "dewgrass" and not bool(repeat.first_discovery) and int(repeat.xp) == 0, "Duplicate specimens must not farm first-discovery rewards.")

	var low_state := {"herbarium": {}}
	assert(str(RULES.record(low_state, "C", 99).id) == "dewgrass", "Low-grade gathering should only find the common specimen.")
	assert(RULES.record(low_state, "invalid", 0).is_empty(), "Unknown grades must not mutate the collection.")
	assert(RULES.collection_text({"dewgrass": 2}).contains("凝露草×2") and RULES.collection_text({"dewgrass": 2}).contains("云纹叶×0"), "The collection summary should always name every specimen (0.90.0), not hide undiscovered ones behind ？？？.")
	print("Herbarium rule tests passed.")
	quit()
