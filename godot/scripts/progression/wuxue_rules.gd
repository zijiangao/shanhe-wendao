class_name WuxueRules
extends RefCounted

const MAX_EQUIPPED_MOVES := 2

const MOVES := {
	"stone_splitting_fist": {"title": "裂石拳", "description": "内力贯拳，无视护甲。", "price": 150, "qi_cost": 5},
	"night_triple_blade": {"title": "暗夜三刀", "description": "三刀连斩，刀刀见血。", "price": 260, "qi_cost": 9},
}

const INTERNAL := {
	"purple_mist_art": {"title": "紫霞神功", "description": "内力外放，诸般攻击更进一筹。攻击 +2。", "price": 200, "damage_bonus": 2},
	"five_elements_art": {"title": "五行归元功", "description": "五行调和，疗伤更速。回春散额外恢复 +5。", "price": 200, "healing_bonus": 5},
}

const LIGHTNESS := {
	"ripple_steps": {"title": "凌波微步", "description": "身法灵动，多行一步。移动范围 +1。", "price": 150, "move_bonus": 1},
	"wind_walk": {"title": "神行百变", "description": "疾行如风，进退由心。移动范围 +2。", "price": 320, "move_bonus": 2},
}

static func internal_damage_bonus(state: Dictionary) -> int:
	var id := str(state.get("equipped_internal", ""))
	return int(INTERNAL.get(id, {}).get("damage_bonus", 0))

static func internal_healing_bonus(state: Dictionary) -> int:
	var id := str(state.get("equipped_internal", ""))
	return int(INTERNAL.get(id, {}).get("healing_bonus", 0))

static func lightness_move_bonus(state: Dictionary) -> int:
	var id := str(state.get("equipped_lightness", ""))
	return int(LIGHTNESS.get(id, {}).get("move_bonus", 0))

static func options_manuals(state: Dictionary) -> Array:
	var options := []
	options.append_array(_move_options(state))
	options.append_array(_internal_options(state))
	options.append_array(_lightness_options(state))
	options.append(["返回", "不消耗行动点，返回西市。", "leave"])
	return options

static func _move_options(state: Dictionary) -> Array:
	var learned: Array = state.get("learned_moves", [])
	var equipped: Array = state.get("equipped_moves", [])
	var silver := int(state.get("silver", 0))
	var options := []
	for id in MOVES:
		var item: Dictionary = MOVES[id]
		if id in equipped:
			options.append(["卸下 · %s" % str(item.title), "%s（当前装备）" % str(item.description), "unequip_move_%s" % id, false])
		elif id in learned:
			var slot_full := equipped.size() >= MAX_EQUIPPED_MOVES
			options.append(["装备 · %s" % str(item.title), "%s%s" % [str(item.description), "（招式槽位已满）" if slot_full else ""], "equip_move_%s" % id, slot_full])
		else:
			options.append(["学习 · %s · %d 银" % [str(item.title), int(item.price)], str(item.description), "learn_move_%s" % id, silver < int(item.price)])
	return options

static func _internal_options(state: Dictionary) -> Array:
	var learned: Array = state.get("learned_internal", [])
	var equipped := str(state.get("equipped_internal", ""))
	var silver := int(state.get("silver", 0))
	var options := []
	for id in INTERNAL:
		var item: Dictionary = INTERNAL[id]
		if id == equipped:
			options.append(["卸下 · %s" % str(item.title), "%s（当前修炼）" % str(item.description), "unequip_internal_%s" % id, false])
		elif id in learned:
			options.append(["修炼 · %s" % str(item.title), str(item.description), "equip_internal_%s" % id, false])
		else:
			options.append(["学习 · %s · %d 银" % [str(item.title), int(item.price)], str(item.description), "learn_internal_%s" % id, silver < int(item.price)])
	return options

static func _lightness_options(state: Dictionary) -> Array:
	var learned: Array = state.get("learned_lightness", [])
	var equipped := str(state.get("equipped_lightness", ""))
	var silver := int(state.get("silver", 0))
	var options := []
	for id in LIGHTNESS:
		var item: Dictionary = LIGHTNESS[id]
		if id == equipped:
			options.append(["卸下 · %s" % str(item.title), "%s（当前修炼）" % str(item.description), "unequip_lightness_%s" % id, false])
		elif id in learned:
			options.append(["修炼 · %s" % str(item.title), str(item.description), "equip_lightness_%s" % id, false])
		else:
			options.append(["学习 · %s · %d 银" % [str(item.title), int(item.price)], str(item.description), "learn_lightness_%s" % id, silver < int(item.price)])
	return options

static func learn_move(state: Dictionary, id: String) -> bool:
	if not MOVES.has(id) or id in Array(state.get("learned_moves", [])) or int(state.get("silver", 0)) < int(MOVES[id].price):
		return false
	state.silver = int(state.get("silver", 0)) - int(MOVES[id].price)
	state.learned_moves.append(id)
	if Array(state.equipped_moves).size() < MAX_EQUIPPED_MOVES:
		state.equipped_moves.append(id)
	return true

static func learn_internal(state: Dictionary, id: String) -> bool:
	if not INTERNAL.has(id) or id in Array(state.get("learned_internal", [])) or int(state.get("silver", 0)) < int(INTERNAL[id].price):
		return false
	state.silver = int(state.get("silver", 0)) - int(INTERNAL[id].price)
	state.learned_internal.append(id)
	state.equipped_internal = id
	return true

static func learn_lightness(state: Dictionary, id: String) -> bool:
	if not LIGHTNESS.has(id) or id in Array(state.get("learned_lightness", [])) or int(state.get("silver", 0)) < int(LIGHTNESS[id].price):
		return false
	state.silver = int(state.get("silver", 0)) - int(LIGHTNESS[id].price)
	state.learned_lightness.append(id)
	state.equipped_lightness = id
	return true

static func equip_move(state: Dictionary, id: String) -> bool:
	if not MOVES.has(id) or id not in Array(state.get("learned_moves", [])) or id in Array(state.get("equipped_moves", [])):
		return false
	if Array(state.equipped_moves).size() >= MAX_EQUIPPED_MOVES:
		return false
	state.equipped_moves.append(id)
	return true

static func unequip_move(state: Dictionary, id: String) -> bool:
	if id not in Array(state.get("equipped_moves", [])):
		return false
	state.equipped_moves.erase(id)
	return true

static func equip_internal(state: Dictionary, id: String) -> bool:
	if not INTERNAL.has(id) or id not in Array(state.get("learned_internal", [])):
		return false
	state.equipped_internal = id
	return true

static func unequip_internal(state: Dictionary, id: String) -> bool:
	if str(state.get("equipped_internal", "")) != id:
		return false
	state.equipped_internal = ""
	return true

static func equip_lightness(state: Dictionary, id: String) -> bool:
	if not LIGHTNESS.has(id) or id not in Array(state.get("learned_lightness", [])):
		return false
	state.equipped_lightness = id
	return true

static func unequip_lightness(state: Dictionary, id: String) -> bool:
	if str(state.get("equipped_lightness", "")) != id:
		return false
	state.equipped_lightness = ""
	return true
