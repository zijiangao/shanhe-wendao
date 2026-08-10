class_name EquipmentRules
extends RefCounted

## 兵器/护具数量制 (0.119.0) -- owned_weapons/owned_armors 从"不重复id列表"
## 改为"id -> 拥有数量"字典，允许西市重复购买/锻造坊重复打造同一件装备多份。
## 数量决定了能同时装备的人数上限：拥有几份，就最多几人（沈羽或同伴）能
## 同时穿着同一件装备，第 N+1 个人想装备时必须先有人卸下，或再买/打造一份
## ——这直接取代了0.113.0"同一件装备可以多人同时装备，不排他"的设计（当时
## 装备是不限量的单纯"是否拥有"布尔值，谈不上排他）。
##
## 这个文件是数量与"谁在穿"归属的单一权威：shop_rules.gd（购买/出售/沈羽
## 装备）与 crafting_rules.gd（打造）都通过这里增减数量；companion_rules.gd
## （同伴装备）与 shop_rules.gd（沈羽装备）都通过这里校验"是否还有空闲的
## 一份"。刻意拆成独立文件，因为 shop_rules.gd 已经 preload 了
## crafting_rules.gd，两者互相 preload 会形成循环依赖，而这个文件本身零依赖，
## 三者都可以安全 preload 它。

static func owned_count(state: Dictionary, field: String, id: String) -> int:
	if id == "":
		return 0
	return int(Dictionary(state.get(field, {})).get(id, 0))

static func add_owned(state: Dictionary, field: String, id: String, delta: int) -> void:
	if typeof(state.get(field, {})) != TYPE_DICTIONARY:
		state[field] = {}
	var next_count := int(state[field].get(id, 0)) + delta
	if next_count <= 0:
		state[field].erase(id)
	else:
		state[field][id] = next_count

## 谁正穿着 id -- {"hero": weapon_id/armor_id, companion_id: weapon_id/armor_id, ...}。
## slot 是 "weapon" 或 "armor"，对应 state.equipped_weapon/equipped_armor 与
## 每位同伴 companion_gear[id]["weapon"/"armor"]。
static func wearers(state: Dictionary, slot: String) -> Dictionary:
	var result := {"hero": str(state.get("equipped_%s" % slot, ""))}
	var gear: Dictionary = state.get("companion_gear", {})
	for companion_id in gear:
		result[str(companion_id)] = str(Dictionary(gear[companion_id]).get(slot, ""))
	return result

## exclude_wearer 让"这个人自己已经穿着它"不计入占用，允许原地重选同一件
## 而不会被自己的旧记录误判为"已被占满"。
static func claimed_count(state: Dictionary, slot: String, id: String, exclude_wearer: String = "") -> int:
	if id == "":
		return 0
	var count := 0
	var current_wearers := wearers(state, slot)
	for wearer_id in current_wearers:
		if wearer_id == exclude_wearer:
			continue
		if str(current_wearers[wearer_id]) == id:
			count += 1
	return count

static func is_available_for(state: Dictionary, field: String, slot: String, id: String, wearer: String) -> bool:
	if id == "":
		return true
	return owned_count(state, field, id) > claimed_count(state, slot, id, wearer)

## 出售/材料回收导致拥有数量降到低于当前穿着人数时，从沈羽开始、其次按
## companion_gear 字典的遍历顺序依次卸下，直到"穿着人数"不超过"拥有数量"
## 为止 -- 保证卖出装备后不会出现"没人真正拥有却还穿在身上"的状态。
static func reconcile_wearers(state: Dictionary, field: String, slot: String, id: String) -> void:
	if id == "":
		return
	var owned := owned_count(state, field, id)
	while claimed_count(state, slot, id) > owned:
		if str(state.get("equipped_%s" % slot, "")) == id:
			state["equipped_%s" % slot] = ""
			continue
		var gear: Dictionary = state.get("companion_gear", {})
		var unequipped_one := false
		for companion_id in gear:
			if str(Dictionary(gear[companion_id]).get(slot, "")) == id:
				gear[companion_id][slot] = ""
				unequipped_one = true
				break
		if not unequipped_one:
			break
