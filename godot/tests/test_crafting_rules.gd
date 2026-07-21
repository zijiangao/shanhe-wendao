extends SceneTree

const RULES := preload("res://scripts/progression/crafting_rules.gd")

func _initialize() -> void:
	var state := _state()
	assert(RULES.can_craft(state, "healing_powder"), "Two herbs should enable a healing powder recipe.")
	assert(RULES.apply(state, "healing_powder"), "A valid medicine recipe should apply.")
	assert(int(state.materials.herbs) == 1 and int(state.consumables.healing_powder) == 1, "Medicine crafting should consume herbs and produce one combat item.")
	assert(RULES.apply(state, "thunder_stone"), "Two ore should produce one throwable thunder stone.")
	assert(int(state.materials.ore) == 3 and int(state.consumables.thunder_stone) == 1, "Thunder-stone crafting should consume exactly two ore.")
	assert(RULES.apply(state, "temper_blade"), "Enough ore and silver should temper the weapon.")
	assert(int(state.materials.ore) == 0 and int(state.silver) == 12 and int(state.forge_level) == 1, "Tempering should consume its full cost and raise the permanent level.")
	state.materials.ore = 9
	state.silver = 50
	assert(RULES.apply(state, "temper_blade") and RULES.apply(state, "temper_blade"), "The weapon should support three total tempering levels.")
	assert(not RULES.can_craft(state, "temper_blade"), "Tempering must stop at the level cap.")
	assert(not RULES.apply(state, "invalid"), "Unknown recipes must never mutate state.")
	var apprentice := _state()
	apprentice.silver = 5
	assert(not RULES.can_craft(apprentice, "temper_blade"), "An apprentice miner should still need the full eight silver for tempering.")
	var master := _state()
	master.silver = 5
	master.mining = 10
	assert(RULES.effective_cost(master, "temper_blade").silver == 5 and RULES.can_craft(master, "temper_blade"), "Mining mastery should reduce the tempering silver cost from eight to five.")
	assert("挖矿大成减免" in str(RULES.options(master)[2][1]), "The workshop choice should disclose the mastery discount before crafting.")
	assert(RULES.apply(master, "temper_blade") and int(master.silver) == 0, "The discounted cost should be charged exactly once.")
	var broke := {"materials": {"herbs": 0, "ore": 0}, "consumables": {"healing_powder": 0, "thunder_stone": 0}, "silver": 0, "forge_level": 0, "mining": 0, "strength": 0, "agility": 0, "insight": 0, "constitution": 0}
	var broke_options: Array = RULES.options(broke)
	assert(broke_options.size() == 8, "A fresh recruit with no materials should still see an eighth way out of the workshop.")
	for option in broke_options.slice(0, 7):
		assert(bool(option[3]), "Every real recipe should be disabled when nothing is affordable.")
	var leave_option: Array = broke_options[7]
	assert(str(leave_option[2]) == "leave", "The escape option must be the fixed 'leave' id, not a recipe.")
	assert(leave_option.size() <= 3 or not bool(leave_option[3]), "Leaving the workshop must never be disabled, even with zero materials.")

	# 悟性丹 (insight pill): unlike tempering, there is no level cap -- it can
	# be crafted repeatedly for as long as the player can afford it, mirroring
	# how attribute training itself has no ceiling.
	var scholar := _state()
	scholar.materials.herbs = 3
	scholar.silver = 15
	scholar.insight = 4
	assert(RULES.can_craft(scholar, "insight_pill"), "Three herbs and fifteen silver should afford an insight pill.")
	assert(RULES.apply(scholar, "insight_pill"), "A well-stocked hero should be able to craft an insight pill.")
	assert(int(scholar.materials.herbs) == 0 and int(scholar.silver) == 0 and int(scholar.insight) == 5, "Crafting an insight pill should consume its full cost and immediately raise insight by one.")
	assert(not RULES.can_craft(scholar, "insight_pill"), "Crafting again immediately should be blocked by lack of materials, not a level cap.")
	scholar.materials.herbs = 3
	scholar.silver = 15
	assert(RULES.apply(scholar, "insight_pill") and int(scholar.insight) == 6, "Insight pills should be repeatable without limit, unlike weapon tempering.")

	# 臂力丹/身法丹/根骨丹 mirror 悟性丹 exactly, except 根骨丹 also grants the
	# same +3 max/current hp that attribute-training constitution already
	# does, since 根骨 has always meant "more health," not just a bare number.
	var brawler := _state()
	brawler.materials.herbs = 3
	brawler.silver = 15
	assert(RULES.apply(brawler, "strength_pill") and int(brawler.strength) == 5, "A strength pill should raise strength by exactly one.")

	var acrobat := _state()
	acrobat.materials.herbs = 3
	acrobat.silver = 15
	assert(RULES.apply(acrobat, "agility_pill") and int(acrobat.agility) == 6, "An agility pill should raise agility by exactly one -- the first way to ever raise it, since no training option covers it.")

	var vitalist := _state()
	vitalist.materials.herbs = 3
	vitalist.silver = 15
	var hp_before := int(vitalist.hp)
	var max_hp_before := int(vitalist.max_hp)
	assert(RULES.apply(vitalist, "constitution_pill") and int(vitalist.constitution) == 5, "A constitution pill should raise constitution by exactly one.")
	assert(int(vitalist.max_hp) == max_hp_before + 3 and int(vitalist.hp) == hp_before + 3, "A constitution pill should also grant +3 max and current hp, matching attribute-training constitution's existing effect.")
	print("Crafting rules tests passed.")
	quit()

func _state() -> Dictionary:
	return {"materials": {"herbs": 3, "ore": 5}, "consumables": {"healing_powder": 0, "thunder_stone": 0}, "silver": 20, "forge_level": 0, "mining": 0, "strength": 4, "agility": 5, "insight": 4, "constitution": 4, "hp": 45, "max_hp": 45}
