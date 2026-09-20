class_name ShopRules
extends RefCounted

const CRAFTING_RULES := preload("res://scripts/progression/crafting_rules.gd")
const EQUIPMENT_RULES := preload("res://scripts/progression/equipment_rules.gd")
const SELL_BACK_RATE := 0.5

const WEAPONS := {
	"iron_sword": {"title": "铁胎剑", "description": "锻工粗朴，胜在压手。攻击 +1。", "price": 30, "attack_bonus": 1},
	"cold_crow_blade": {"title": "寒鸦刀", "description": "刀身泛青，出鞘带风。攻击 +2。", "price": 90, "attack_bonus": 2},
	"dragon_etched_sword": {"title": "龙纹古剑", "description": "剑脊刻有前朝龙纹，锋锐罕见。攻击 +3。", "price": 220, "attack_bonus": 3},
}

const ARMORS := {
	"hedgehog_mail": {"title": "软猬甲", "description": "轻软贴身，勉强挡刃。防御 +1。", "price": 40, "defense_bonus": 1},
	"dark_iron_armor": {"title": "玄铁护甲", "description": "玄铁打底，护身周全。防御 +2。", "price": 110, "defense_bonus": 2},
	"cold_jade_armor": {"title": "寒玉战甲", "description": "寒玉嵌甲，江湖罕见的防身重器。防御 +3。", "price": 260, "defense_bonus": 3},
}

const GOODS := {
	"herbs": {"title": "药材", "buy_price": 5, "sell_price": 2},
	"ore": {"title": "矿石", "buy_price": 6, "sell_price": 3},
	"healing_powder": {"title": "回春散", "buy_price": 15, "sell_price": 6},
	"thunder_stone": {"title": "霹雳石", "buy_price": 18, "sell_price": 7},
}

## Falls back to CraftingRules' workshop-exclusive gear (a separate catalog,
## acquired with materials instead of silver) whenever the equipped id isn't
## one of 西市's own WEAPONS/ARMORS -- equip/battle code only ever deals in a
## bare id string, so it must resolve its bonus regardless of which catalog
## (market or workshop) it actually came from.
static func weapon_attack_bonus(state: Dictionary) -> int:
	var id := str(state.get("equipped_weapon", ""))
	if WEAPONS.has(id):
		return int(WEAPONS[id].attack_bonus)
	return int(CRAFTING_RULES.RECIPES.get(id, {}).get("attack_bonus", 0))

static func armor_defense_bonus(state: Dictionary) -> int:
	var id := str(state.get("equipped_armor", ""))
	if ARMORS.has(id):
		return int(ARMORS[id].defense_bonus)
	return int(CRAFTING_RULES.RECIPES.get(id, {}).get("defense_bonus", 0))

static func weapon_sell_price(id: String) -> int:
	return int(floor(float(WEAPONS.get(id, {}).get("price", 0)) * SELL_BACK_RATE))

static func armor_sell_price(id: String) -> int:
	return int(floor(float(ARMORS.get(id, {}).get("price", 0)) * SELL_BACK_RATE))

static func options_weapons(state: Dictionary) -> Array:
	var equipped := str(state.get("equipped_weapon", ""))
	var silver := int(state.get("silver", 0))
	var options := []
	for id in WEAPONS:
		var item: Dictionary = WEAPONS[id]
		var owned_count := EQUIPMENT_RULES.owned_count(state, "owned_weapons", id)
		if owned_count > 0:
			options.append(["再买一件并装备 · %s · %d 银" % [str(item.title), int(item.price)], "当前拥有 %d 件，购买后可分别装备给沈羽与同伴。" % owned_count, "buy_%s" % id, silver < int(item.price)])
		if id == equipped:
			options.append(["卖出 · %s" % str(item.title), "%s（当前装备，拥有 %d 件，回收 %d 银）" % [str(item.description), owned_count, weapon_sell_price(id)], "sell_%s" % id, false])
		elif owned_count > 0:
			var available := EQUIPMENT_RULES.is_available_for(state, "owned_weapons", "weapon", id, "hero")
			var note := "已购入 %d 件，可随时换回。" % owned_count if available else "已购入 %d 件，但均已被同伴装备，可再购买一件。" % owned_count
			options.append(["换装 · %s" % str(item.title), "%s%s" % [str(item.description), note], "equip_%s" % id, not available])
		else:
			options.append(["购买并装备 · %s · %d 银" % [str(item.title), int(item.price)], str(item.description), "buy_%s" % id, silver < int(item.price)])
	options.append(["返回", "不消耗行动点，返回西市。", "leave"])
	return options

static func options_armor(state: Dictionary) -> Array:
	var equipped := str(state.get("equipped_armor", ""))
	var silver := int(state.get("silver", 0))
	var options := []
	for id in ARMORS:
		var item: Dictionary = ARMORS[id]
		var owned_count := EQUIPMENT_RULES.owned_count(state, "owned_armors", id)
		if owned_count > 0:
			options.append(["再买一件并装备 · %s · %d 银" % [str(item.title), int(item.price)], "当前拥有 %d 件，购买后可分别装备给沈羽与同伴。" % owned_count, "buy_%s" % id, silver < int(item.price)])
		if id == equipped:
			options.append(["卖出 · %s" % str(item.title), "%s（当前装备，拥有 %d 件，回收 %d 银）" % [str(item.description), owned_count, armor_sell_price(id)], "sell_%s" % id, false])
		elif owned_count > 0:
			var available := EQUIPMENT_RULES.is_available_for(state, "owned_armors", "armor", id, "hero")
			var note := "已购入 %d 件，可随时换回。" % owned_count if available else "已购入 %d 件，但均已被同伴装备，可再购买一件。" % owned_count
			options.append(["换装 · %s" % str(item.title), "%s%s" % [str(item.description), note], "equip_%s" % id, not available])
		else:
			options.append(["购买并装备 · %s · %d 银" % [str(item.title), int(item.price)], str(item.description), "buy_%s" % id, silver < int(item.price)])
	options.append(["返回", "不消耗行动点，返回西市。", "leave"])
	return options

static func options_goods(state: Dictionary) -> Array:
	var silver := int(state.get("silver", 0))
	var options := []
	for id in GOODS:
		var item: Dictionary = GOODS[id]
		var owned := _good_count(state, id)
		options.append(["购买 · %s · %d 银/份" % [str(item.title), int(item.buy_price)], "当前携带 %d 份。" % owned, "buy_%s" % id, silver < int(item.buy_price)])
		options.append(["出售 · %s · 回收 %d 银/份" % [str(item.title), int(item.sell_price)], "当前携带 %d 份。" % owned, "sell_%s" % id, owned <= 0])
	options.append(["返回", "不消耗行动点，返回西市。", "leave"])
	return options

## 兵器/护具数量制 (0.119.0): 已拥有也可以再次购买，多买一份就多一份能同时
## 让沈羽或同伴穿着的名额，不再是"买过就不能再买"的一次性所有权。
static func buy_weapon(state: Dictionary, id: String) -> bool:
	if not WEAPONS.has(id) or int(state.get("silver", 0)) < int(WEAPONS[id].price):
		return false
	state.silver = int(state.get("silver", 0)) - int(WEAPONS[id].price)
	EQUIPMENT_RULES.add_owned(state, "owned_weapons", id, 1)
	state.equipped_weapon = id
	return true

static func buy_armor(state: Dictionary, id: String) -> bool:
	if not ARMORS.has(id) or int(state.get("silver", 0)) < int(ARMORS[id].price):
		return false
	state.silver = int(state.get("silver", 0)) - int(ARMORS[id].price)
	EQUIPMENT_RULES.add_owned(state, "owned_armors", id, 1)
	state.equipped_armor = id
	return true

## Ownership alone is authoritative here -- owned_weapons/owned_armors can
## only ever be populated by buy_weapon()/buy_armor() (validated against
## WEAPONS/ARMORS) or CraftingRules.apply() (validated against its own
## catalog), so re-checking WEAPONS/ARMORS membership here would incorrectly
## reject a legitimately owned workshop-crafted item. 数量制 (0.119.0) 还要求
## 至少有一份"没被同伴占用"的空闲份数，否则拒绝换装。
static func equip_weapon(state: Dictionary, id: String) -> bool:
	if not EQUIPMENT_RULES.is_available_for(state, "owned_weapons", "weapon", id, "hero"):
		return false
	state.equipped_weapon = id
	return true

static func equip_armor(state: Dictionary, id: String) -> bool:
	if not EQUIPMENT_RULES.is_available_for(state, "owned_armors", "armor", id, "hero"):
		return false
	state.equipped_armor = id
	return true

static func sell_weapon(state: Dictionary, id: String) -> bool:
	if not WEAPONS.has(id) or EQUIPMENT_RULES.owned_count(state, "owned_weapons", id) <= 0:
		return false
	EQUIPMENT_RULES.add_owned(state, "owned_weapons", id, -1)
	state.silver = int(state.get("silver", 0)) + weapon_sell_price(id)
	EQUIPMENT_RULES.reconcile_wearers(state, "owned_weapons", "weapon", id)
	return true

static func sell_armor(state: Dictionary, id: String) -> bool:
	if not ARMORS.has(id) or EQUIPMENT_RULES.owned_count(state, "owned_armors", id) <= 0:
		return false
	EQUIPMENT_RULES.add_owned(state, "owned_armors", id, -1)
	state.silver = int(state.get("silver", 0)) + armor_sell_price(id)
	EQUIPMENT_RULES.reconcile_wearers(state, "owned_armors", "armor", id)
	return true

static func buy_good(state: Dictionary, id: String, quantity: int = 1) -> bool:
	if not GOODS.has(id) or quantity <= 0:
		return false
	var cost := int(GOODS[id].buy_price) * quantity
	if int(state.get("silver", 0)) < cost:
		return false
	state.silver = int(state.get("silver", 0)) - cost
	_add_good(state, id, quantity)
	return true

static func sell_good(state: Dictionary, id: String, quantity: int = 1) -> bool:
	if not GOODS.has(id) or quantity <= 0 or _good_count(state, id) < quantity:
		return false
	_add_good(state, id, -quantity)
	state.silver = int(state.get("silver", 0)) + int(GOODS[id].sell_price) * quantity
	return true

static func _good_count(state: Dictionary, id: String) -> int:
	if id in ["herbs", "ore"]:
		return int(state.get("materials", {}).get(id, 0))
	return int(state.get("consumables", {}).get(id, 0))

static func _add_good(state: Dictionary, id: String, delta: int) -> void:
	if id in ["herbs", "ore"]:
		state.materials[id] = maxi(0, int(state.materials.get(id, 0)) + delta)
	else:
		state.consumables[id] = maxi(0, int(state.consumables.get(id, 0)) + delta)
