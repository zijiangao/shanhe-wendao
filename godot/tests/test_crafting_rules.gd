extends SceneTree

const RULES := preload("res://scripts/progression/crafting_rules.gd")

func _initialize() -> void:
	var state := _state()
	assert(RULES.can_craft(state, "healing_powder"), "Two herbs should enable a healing powder recipe.")
	assert(RULES.apply(state, "healing_powder"), "A valid medicine recipe should apply.")
	assert(int(state.materials.herbs) == 1 and int(state.consumables.healing_powder) == 1, "Medicine crafting should consume herbs and produce one combat item.")
	assert(RULES.apply(state, "thunder_stone"), "Two ore should produce one throwable thunder stone.")
	assert(int(state.materials.ore) == 3 and int(state.consumables.thunder_stone) == 1, "Thunder-stone crafting should consume exactly two ore.")
	assert(not RULES.apply(state, "invalid"), "Unknown recipes must never mutate state.")

	var broke := {"materials": {"herbs": 0, "ore": 0}, "consumables": {"healing_powder": 0, "thunder_stone": 0}, "silver": 0, "forge_level": 0, "mining": 0, "strength": 0, "agility": 0, "insight": 0, "constitution": 0, "owned_weapons": [], "owned_armors": []}
	var broke_options: Array = RULES.options(broke)
	assert(broke_options.size() == 11, "A fresh recruit with no materials should still see an eleventh way out of the workshop.")
	for option in broke_options.slice(0, 10):
		assert(bool(option[3]), "Every real recipe should be disabled when nothing is affordable.")
	var leave_option: Array = broke_options[10]
	assert(str(leave_option[2]) == "leave", "The escape option must be the fixed 'leave' id, not a recipe.")
	assert(leave_option.size() <= 3 or not bool(leave_option[3]), "Leaving the workshop must never be disabled, even with zero materials.")

	# 悟性丹 (insight pill): there is no level cap -- it can be crafted
	# repeatedly for as long as the player can afford it, mirroring how
	# attribute training itself has no ceiling.
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

	# Workshop-crafted weapons/armor: a separate, materials-only set from
	# 西市's silver-priced catalog. Replaces the old 淬炼青锋 tempering recipe.
	var smith := _state()
	smith.materials = {"herbs": 0, "ore": 5}
	smith.silver = 0
	assert(not RULES.can_craft(smith, "rattan_guard"), "Five ore alone should not afford an armor recipe that needs herbs.")
	assert(RULES.can_craft(smith, "forged_iron_blade"), "Five ore should exactly afford the cheaper workshop weapon, with zero silver required.")
	assert(RULES.apply(smith, "forged_iron_blade"), "A well-stocked smith should be able to forge the weapon.")
	assert(int(smith.materials.ore) == 0 and "forged_iron_blade" in Array(smith.owned_weapons) and str(smith.equipped_weapon) == "forged_iron_blade", "Forging a workshop weapon should consume its full ore cost, own it, and equip it immediately -- no silver ever changes hands.")
	assert(not RULES.can_craft(smith, "forged_iron_blade"), "An already-forged weapon must not be craftable again.")

	var armorer := _state()
	armorer.materials = {"herbs": 5, "ore": 0}
	assert(RULES.apply(armorer, "rattan_guard"), "Five herbs should afford the cheaper workshop armor.")
	assert(int(armorer.materials.herbs) == 0 and "rattan_guard" in Array(armorer.owned_armors) and str(armorer.equipped_armor) == "rattan_guard", "Forging workshop armor should consume its full herb cost, own it, and equip it immediately.")

	# Mining mastery discounts the ORE cost of workshop gear now, replacing
	# the old silver discount on 淬炼青锋.
	var master_smith := _state()
	master_smith.materials = {"herbs": 2, "ore": 5}
	master_smith.mining = 10
	assert(RULES.effective_cost(master_smith, "twin_edge_saber").ore == 5, "Mining mastery should reduce the pricier saber's ore cost from eight to five.")
	assert("挖矿大成减免" in str(RULES.options(master_smith).filter(func(o): return str(o[2]) == "twin_edge_saber")[0][0]), "The workshop choice should disclose the mastery discount before crafting.")
	assert(RULES.apply(master_smith, "twin_edge_saber") and int(master_smith.materials.ore) == 0, "The discounted ore cost should be charged exactly once.")

	print("Crafting rules tests passed.")
	quit()

func _state() -> Dictionary:
	return {"materials": {"herbs": 3, "ore": 5}, "consumables": {"healing_powder": 0, "thunder_stone": 0}, "silver": 20, "forge_level": 0, "mining": 0, "strength": 4, "agility": 5, "insight": 4, "constitution": 4, "hp": 45, "max_hp": 45, "owned_weapons": [], "equipped_weapon": "", "owned_armors": [], "equipped_armor": ""}
