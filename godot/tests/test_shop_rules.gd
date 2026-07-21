extends SceneTree

const RULES := preload("res://scripts/progression/shop_rules.gd")

func _initialize() -> void:
	var state := _state()
	assert(int(RULES.weapon_attack_bonus(state)) == 0 and int(RULES.armor_defense_bonus(state)) == 0, "An unequipped hero should have zero gear bonuses.")

	assert(not RULES.buy_weapon(state, "cold_crow_blade"), "Ninety silver should be unaffordable with only fifty.")
	assert(state.silver == 50 and state.owned_weapons.is_empty(), "A failed purchase must not touch silver or inventory.")
	assert(RULES.buy_weapon(state, "iron_sword"), "Thirty silver should afford the cheapest sword.")
	assert(int(state.silver) == 20 and "iron_sword" in Array(state.owned_weapons) and str(state.equipped_weapon) == "iron_sword", "Buying a weapon should charge its price, own it, and equip it immediately.")
	assert(int(RULES.weapon_attack_bonus(state)) == 1, "The equipped iron sword should grant its one-point attack bonus.")
	assert(not RULES.buy_weapon(state, "iron_sword"), "Buying an already-owned weapon must be rejected, not double-charge.")

	state.silver = 300
	assert(RULES.buy_weapon(state, "dragon_etched_sword"), "A second weapon purchase should succeed once affordable.")
	assert(str(state.equipped_weapon) == "dragon_etched_sword" and "iron_sword" in Array(state.owned_weapons), "Buying a new weapon should equip it while keeping the old one owned.")
	assert(RULES.equip_weapon(state, "iron_sword"), "Switching back to a previously owned weapon should succeed.")
	assert(str(state.equipped_weapon) == "iron_sword", "Equipping should update which weapon is active.")
	assert(not RULES.equip_weapon(state, "cold_crow_blade"), "Equipping a never-purchased weapon must fail.")

	var silver_before_sell := int(state.silver)
	assert(RULES.sell_weapon(state, "iron_sword"), "Selling the currently equipped weapon should succeed.")
	assert(int(state.silver) == silver_before_sell + 15 and str(state.equipped_weapon) == "", "Selling the equipped weapon should refund half its price and leave the hero bare-handed.")
	assert("iron_sword" not in Array(state.owned_weapons), "A sold weapon must leave the owned list.")
	assert(not RULES.sell_weapon(state, "iron_sword"), "Selling a weapon that is no longer owned must fail.")
	assert(str(state.equipped_weapon) == "" and "dragon_etched_sword" in Array(state.owned_weapons), "Selling the unequipped iron sword must not disturb the still-equipped dragon sword.")

	# Workshop-crafted gear (a separate CraftingRules.RECIPES catalog, acquired
	# with materials instead of silver) shares the exact same owned/equipped
	# fields and must resolve its bonus and equip like any market weapon,
	# even though its id was never in ShopRules.WEAPONS at all.
	var smith := _state()
	smith.owned_weapons.append("forged_iron_blade")
	smith.equipped_weapon = "forged_iron_blade"
	assert(int(RULES.weapon_attack_bonus(smith)) == 2, "A crafted weapon's attack bonus should resolve via the CraftingRules fallback lookup.")
	smith.owned_weapons.append("iron_sword")
	assert(RULES.equip_weapon(smith, "iron_sword"), "Switching away from a crafted weapon to an owned market weapon should still work.")
	assert(RULES.equip_weapon(smith, "forged_iron_blade"), "Switching back to an owned crafted weapon must succeed even though it is absent from ShopRules.WEAPONS.")
	assert(not RULES.equip_weapon(smith, "twin_edge_saber"), "Equipping a crafted weapon id that was never actually owned must still fail.")
	var market_weapon_options: Array = RULES.options_weapons(smith)
	assert(market_weapon_options.filter(func(o): return str(o[2]).ends_with("forged_iron_blade")).is_empty(), "A crafted weapon must never appear in 西市's own buy/sell list -- it was never sold there.")

	# Armor mirrors the weapon flow exactly.
	var armored := _state()
	armored.silver = 500
	assert(RULES.buy_armor(armored, "dark_iron_armor"), "A well-funded hero should afford mid-tier armor.")
	assert(int(RULES.armor_defense_bonus(armored)) == 2, "Equipped armor should grant its defense bonus.")
	assert(RULES.buy_armor(armored, "cold_jade_armor"), "Buying better armor should be independently affordable.")
	assert(str(armored.equipped_armor) == "cold_jade_armor", "The newest armor purchase should become equipped.")
	var armor_silver_before := int(armored.silver)
	assert(RULES.sell_armor(armored, "cold_jade_armor"), "Selling equipped armor should succeed.")
	assert(int(armored.silver) == armor_silver_before + 130 and str(armored.equipped_armor) == "", "Selling equipped armor should refund half price and leave the hero unarmored.")
	assert(str(armored.get("equipped_armor", "")) != "dark_iron_armor", "Selling the equipped cold jade armor must not silently re-equip the older armor.")

	# Goods: two-way trade against the existing materials/consumables inventory.
	var goods := _state()
	assert(RULES.buy_good(goods, "herbs", 3), "Buying three herbs should succeed with enough silver.")
	assert(int(goods.materials.herbs) == 3 and int(goods.silver) == 35, "Buying three herbs at five silver each should charge fifteen.")
	assert(not RULES.sell_good(goods, "herbs", 5), "Selling more herbs than owned must fail.")
	assert(RULES.sell_good(goods, "herbs", 2), "Selling two of the three owned herbs should succeed.")
	assert(int(goods.materials.herbs) == 1 and int(goods.silver) == 39, "Selling two herbs at two silver each should refund four.")
	assert(RULES.buy_good(goods, "healing_powder", 1), "Healing powder should be directly purchasable from the shop.")
	assert(int(goods.consumables.healing_powder) == 1, "A bought healing powder should land in consumables, not materials.")
	assert(not RULES.buy_good(goods, "thunder_stone", 100), "An absurd bulk purchase should fail outright rather than partially charge.")

	# options_* must reflect affordability and current equip state for the choice-menu UI.
	var poor := {"silver": 0, "owned_weapons": [], "equipped_weapon": "", "owned_armors": [], "equipped_armor": "", "materials": {"herbs": 0, "ore": 0}, "consumables": {"healing_powder": 0, "thunder_stone": 0}}
	var weapon_options: Array = RULES.options_weapons(poor)
	assert(weapon_options.size() == RULES.WEAPONS.size() + 1, "Every weapon plus a leave option should always be listed.")
	for option in weapon_options.slice(0, RULES.WEAPONS.size()):
		assert(bool(option[3]), "Every weapon should be disabled when the hero has no silver.")
	var leave_row: Array = weapon_options.back()
	assert(str(leave_row[2]) == "leave" and not bool(leave_row.size() > 3 and leave_row[3]), "Leaving the weapon shop must always stay enabled.")

	var geared := _state()
	geared.silver = 1000
	RULES.buy_weapon(geared, "cold_crow_blade")
	var geared_options: Array = RULES.options_weapons(geared)
	var equipped_row := geared_options.filter(func(o): return str(o[2]) == "sell_cold_crow_blade")
	assert(equipped_row.size() == 1, "The currently equipped weapon should offer a sell action, not a buy action.")
	var goods_options: Array = RULES.options_goods(_state())
	assert(goods_options.size() == RULES.GOODS.size() * 2 + 1, "Goods should list a buy and sell row per item plus one leave row.")

	print("Shop rules tests passed.")
	quit()

func _state() -> Dictionary:
	return {
		"silver": 50,
		"owned_weapons": [], "equipped_weapon": "",
		"owned_armors": [], "equipped_armor": "",
		"materials": {"herbs": 0, "ore": 0},
		"consumables": {"healing_powder": 0, "thunder_stone": 0},
	}
