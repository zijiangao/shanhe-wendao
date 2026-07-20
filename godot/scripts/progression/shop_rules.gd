class_name ShopRules
extends RefCounted

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

static func weapon_attack_bonus(state: Dictionary) -> int:
	var id := str(state.get("equipped_weapon", ""))
	return int(WEAPONS.get(id, {}).get("attack_bonus", 0))

static func armor_defense_bonus(state: Dictionary) -> int:
	var id := str(state.get("equipped_armor", ""))
	return int(ARMORS.get(id, {}).get("defense_bonus", 0))

static func weapon_sell_price(id: String) -> int:
	return int(floor(float(WEAPONS.get(id, {}).get("price", 0)) * SELL_BACK_RATE))

static func armor_sell_price(id: String) -> int:
	return int(floor(float(ARMORS.get(id, {}).get("price", 0)) * SELL_BACK_RATE))

static func options_weapons(state: Dictionary) -> Array:
	var owned: Array = state.get("owned_weapons", [])
	var equipped := str(state.get("equipped_weapon", ""))
	var silver := int(state.get("silver", 0))
	var options := []
	for id in WEAPONS:
		var item: Dictionary = WEAPONS[id]
		if id == equipped:
			options.append(["卖出 · %s" % str(item.title), "%s（当前装备，回收 %d 银）" % [str(item.description), weapon_sell_price(id)], "sell_%s" % id, false])
		elif id in owned:
			options.append(["换装 · %s" % str(item.title), "%s 已购入，可随时换回。" % str(item.description), "equip_%s" % id, false])
		else:
			options.append(["购买并装备 · %s · %d 银" % [str(item.title), int(item.price)], str(item.description), "buy_%s" % id, silver < int(item.price)])
	options.append(["返回", "不消耗行动点，返回西市。", "leave"])
	return options

static func options_armor(state: Dictionary) -> Array:
	var owned: Array = state.get("owned_armors", [])
	var equipped := str(state.get("equipped_armor", ""))
	var silver := int(state.get("silver", 0))
	var options := []
	for id in ARMORS:
		var item: Dictionary = ARMORS[id]
		if id == equipped:
			options.append(["卖出 · %s" % str(item.title), "%s（当前装备，回收 %d 银）" % [str(item.description), armor_sell_price(id)], "sell_%s" % id, false])
		elif id in owned:
			options.append(["换装 · %s" % str(item.title), "%s 已购入，可随时换回。" % str(item.description), "equip_%s" % id, false])
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

static func buy_weapon(state: Dictionary, id: String) -> bool:
	if not WEAPONS.has(id) or id in Array(state.get("owned_weapons", [])) or int(state.get("silver", 0)) < int(WEAPONS[id].price):
		return false
	state.silver = int(state.get("silver", 0)) - int(WEAPONS[id].price)
	state.owned_weapons.append(id)
	state.equipped_weapon = id
	return true

static func buy_armor(state: Dictionary, id: String) -> bool:
	if not ARMORS.has(id) or id in Array(state.get("owned_armors", [])) or int(state.get("silver", 0)) < int(ARMORS[id].price):
		return false
	state.silver = int(state.get("silver", 0)) - int(ARMORS[id].price)
	state.owned_armors.append(id)
	state.equipped_armor = id
	return true

static func equip_weapon(state: Dictionary, id: String) -> bool:
	if not WEAPONS.has(id) or id not in Array(state.get("owned_weapons", [])):
		return false
	state.equipped_weapon = id
	return true

static func equip_armor(state: Dictionary, id: String) -> bool:
	if not ARMORS.has(id) or id not in Array(state.get("owned_armors", [])):
		return false
	state.equipped_armor = id
	return true

static func sell_weapon(state: Dictionary, id: String) -> bool:
	if not WEAPONS.has(id) or id not in Array(state.get("owned_weapons", [])):
		return false
	state.owned_weapons.erase(id)
	state.silver = int(state.get("silver", 0)) + weapon_sell_price(id)
	if str(state.get("equipped_weapon", "")) == id:
		state.equipped_weapon = ""
	return true

static func sell_armor(state: Dictionary, id: String) -> bool:
	if not ARMORS.has(id) or id not in Array(state.get("owned_armors", [])):
		return false
	state.owned_armors.erase(id)
	state.silver = int(state.get("silver", 0)) + armor_sell_price(id)
	if str(state.get("equipped_armor", "")) == id:
		state.equipped_armor = ""
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
