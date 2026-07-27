extends SceneTree

const RULES := preload("res://scripts/progression/crafting_rules.gd")

func _initialize() -> void:
	var state := _state()
	assert(RULES.can_craft(state, "healing_powder"), "Two herbs should enable a healing powder recipe.")
	assert(RULES.apply(state, "healing_powder"), "A valid medicine recipe should apply.")
	assert(int(state.materials.herbs) == 1 and int(state.consumables.healing_powder) == 1, "Medicine crafting should consume herbs and produce one combat item.")
	assert(not RULES.can_craft(state, "thunder_stone"), "霹雳石 is no longer a craftable recipe (0.88.0) -- it's still buyable at 西市's 杂货铺, just not forged here.")
	assert(not RULES.apply(state, "invalid"), "Unknown recipes must never mutate state.")

	var broke := {"materials": {"herbs": 0, "ore": 0}, "consumables": {"healing_powder": 0, "thunder_stone": 0}, "silver": 0, "mining": 0, "strength": 0, "agility": 0, "insight": 0, "constitution": 0, "owned_weapons": [], "owned_armors": [], "herbarium": {}, "mineralogy": {}}
	var broke_alchemy: Array = RULES.options_alchemy(broke)
	assert(broke_alchemy.size() == 6, "A fresh recruit with no materials should still see a sixth way out of the alchemy building.")
	for option in broke_alchemy.slice(0, 5):
		assert(bool(option[3]), "Every real alchemy recipe should be disabled when nothing is affordable.")
	var alchemy_leave_option: Array = broke_alchemy[5]
	assert(str(alchemy_leave_option[2]) == "leave", "The escape option must be the fixed 'leave' id, not a recipe.")
	assert(alchemy_leave_option.size() <= 3 or not bool(alchemy_leave_option[3]), "Leaving the alchemy building must never be disabled, even with zero materials.")

	var broke_forge: Array = RULES.options_forge(broke)
	assert(broke_forge.size() == 5, "A fresh recruit with no materials should still see a fifth way out of the forge, now that 霹雳石 is gone.")
	for option in broke_forge.slice(0, 4):
		assert(bool(option[3]), "Every real forge recipe should be disabled when nothing is affordable.")
	var forge_leave_option: Array = broke_forge[4]
	assert(str(forge_leave_option[2]) == "leave", "The escape option must be the fixed 'leave' id, not a recipe.")
	assert(forge_leave_option.size() <= 3 or not bool(forge_leave_option[3]), "Leaving the forge must never be disabled, even with zero materials.")

	# 悟性丹 (insight pill): there is no level cap -- it can be crafted
	# repeatedly for as long as the player can afford it, mirroring how
	# attribute training itself has no ceiling. It also requires one named
	# 云纹叶 specimen from the 药谱 collection (0.85.0), not just generic herbs.
	var scholar := _state()
	scholar.materials.herbs = 3
	scholar.silver = 15
	scholar.insight = 4
	assert(not RULES.can_craft(scholar, "insight_pill"), "Herbs and silver alone should not afford an insight pill without a 云纹叶 specimen.")
	scholar.herbarium = {"cloudleaf": 2}
	assert(RULES.can_craft(scholar, "insight_pill"), "Three herbs, fifteen silver, and a 云纹叶 specimen should afford an insight pill.")
	assert(RULES.apply(scholar, "insight_pill"), "A well-stocked hero should be able to craft an insight pill.")
	assert(int(scholar.materials.herbs) == 0 and int(scholar.silver) == 0 and int(scholar.insight) == 5 and int(scholar.herbarium.cloudleaf) == 1, "Crafting an insight pill should consume its full cost -- including one 云纹叶 -- and immediately raise insight by one.")
	assert(not RULES.can_craft(scholar, "insight_pill"), "Crafting again immediately should be blocked by lack of materials, not a level cap.")
	scholar.materials.herbs = 3
	scholar.silver = 15
	assert(RULES.apply(scholar, "insight_pill") and int(scholar.insight) == 6 and int(scholar.herbarium.cloudleaf) == 0, "Insight pills should be repeatable without limit, unlike weapon tempering, as long as 云纹叶 keeps being restocked.")

	# 臂力丹/身法丹/根骨丹 mirror 悟性丹 exactly, except 臂力丹 needs no named
	# specimen, 身法丹 needs one, and 根骨丹 needs two distinct specimens at
	# once (also grants the same +3 max/current hp that attribute-training
	# constitution already does, since 根骨 has always meant "more health,"
	# not just a bare number).
	var brawler := _state()
	brawler.materials.herbs = 3
	brawler.silver = 15
	assert(RULES.apply(brawler, "strength_pill") and int(brawler.strength) == 5, "A strength pill should raise strength by exactly one -- it needs no named specimen.")

	var acrobat := _state()
	acrobat.materials.herbs = 3
	acrobat.silver = 15
	assert(not RULES.can_craft(acrobat, "agility_pill"), "An agility pill should be blocked without its 云纹叶 specimen, even with full herbs and silver.")
	acrobat.herbarium = {"cloudleaf": 1}
	assert(RULES.apply(acrobat, "agility_pill") and int(acrobat.agility) == 6, "An agility pill should raise agility by exactly one -- the first way to ever raise it, since no training option covers it.")

	var vitalist := _state()
	vitalist.materials.herbs = 3
	vitalist.silver = 15
	vitalist.herbarium = {"cloudleaf": 1}
	assert(not RULES.can_craft(vitalist, "constitution_pill"), "A constitution pill needs BOTH 云纹叶 and 赤阳参 -- one alone should not be enough.")
	vitalist.herbarium = {"cloudleaf": 1, "sunroot": 1}
	var hp_before := int(vitalist.hp)
	var max_hp_before := int(vitalist.max_hp)
	assert(RULES.apply(vitalist, "constitution_pill") and int(vitalist.constitution) == 5, "A constitution pill should raise constitution by exactly one once both named specimens are present.")
	assert(int(vitalist.max_hp) == max_hp_before + 3 and int(vitalist.hp) == hp_before + 3, "A constitution pill should also grant +3 max and current hp, matching attribute-training constitution's existing effect.")
	assert(int(vitalist.herbarium.cloudleaf) == 0 and int(vitalist.herbarium.sunroot) == 0, "Both named specimens should be fully consumed, not just one of the two.")

	# Workshop-crafted weapons/armor: a separate, materials-only set from
	# 西市's silver-priced catalog. Replaces the old 淬炼青锋 tempering recipe.
	# 锻造坊 recipes are ore-only now (0.86.0) -- herbs alone should never
	# afford any of them, matching 炼药坊's herb-only recipes on the other side.
	var smith := _state()
	smith.materials = {"herbs": 5, "ore": 0}
	smith.silver = 0
	assert(not RULES.can_craft(smith, "forged_iron_blade"), "Herbs alone should not afford an ore-only forge recipe.")
	smith.materials = {"herbs": 0, "ore": 5}
	assert(RULES.can_craft(smith, "forged_iron_blade"), "Five ore should exactly afford the cheaper workshop weapon, with zero silver or named specimens required.")
	assert(RULES.apply(smith, "forged_iron_blade"), "A well-stocked smith should be able to forge the weapon.")
	assert(int(smith.materials.ore) == 0 and "forged_iron_blade" in Array(smith.owned_weapons) and str(smith.equipped_weapon) == "forged_iron_blade", "Forging a workshop weapon should consume its full ore cost, own it, and equip it immediately -- no silver ever changes hands.")
	assert(not RULES.can_craft(smith, "forged_iron_blade"), "An already-forged weapon must not be craftable again.")

	var armorer := _state()
	armorer.materials = {"herbs": 5, "ore": 0}
	assert(not RULES.can_craft(armorer, "rattan_guard"), "Herbs alone should not afford 藤甲护身 now that it is an ore-only forge recipe.")
	armorer.materials = {"herbs": 0, "ore": 5}
	assert(RULES.apply(armorer, "rattan_guard"), "Five ore should afford the cheaper workshop armor.")
	assert(int(armorer.materials.ore) == 0 and "rattan_guard" in Array(armorer.owned_armors) and str(armorer.equipped_armor) == "rattan_guard", "Forging workshop armor should consume its full ore cost, own it, and equip it immediately.")

	# Mining mastery discounts the ORE cost of workshop gear now, replacing
	# the old silver discount on 淬炼青锋. 双刃寒锋 is ore-only (0.86.0) and
	# additionally needs a named 流银砂 specimen from the 矿谱 collection (0.85.0).
	var master_smith := _state()
	master_smith.materials = {"herbs": 0, "ore": 7}
	master_smith.mining = 10
	assert(RULES.effective_cost(master_smith, "twin_edge_saber").ore == 7, "Mining mastery should reduce the pricier saber's ore cost from ten to seven.")
	assert(not RULES.can_craft(master_smith, "twin_edge_saber"), "Even with the ore discount, the saber should still be blocked without a 流银砂 specimen.")
	master_smith.mineralogy = {"silver_sand": 1}
	assert("挖矿大成减免" in str(RULES.options_forge(master_smith).filter(func(o): return str(o[2]) == "twin_edge_saber")[0][0]), "The forge choice should disclose the mastery discount before crafting.")
	assert(RULES.apply(master_smith, "twin_edge_saber") and int(master_smith.materials.ore) == 0 and int(master_smith.mineralogy.silver_sand) == 0, "The discounted ore cost and the named specimen should both be charged exactly once.")

	print("Crafting rules tests passed.")
	quit()

func _state() -> Dictionary:
	return {"materials": {"herbs": 3, "ore": 5}, "consumables": {"healing_powder": 0, "thunder_stone": 0}, "silver": 20, "mining": 0, "strength": 4, "agility": 5, "insight": 4, "constitution": 4, "hp": 45, "max_hp": 45, "owned_weapons": [], "equipped_weapon": "", "owned_armors": [], "equipped_armor": "", "herbarium": {}, "mineralogy": {}}
