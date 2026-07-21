class_name WuxueRules
extends RefCounted

const MAX_EQUIPPED_MOVES := 2
const MAX_LEVEL := 10
const LIGHTNESS_LEVEL_DIVISOR := 3
const TRAIN_XP_MIN := 8
const TRAIN_XP_MAX := 15

const MOVES := {
	"stone_splitting_fist": {"title": "裂石拳", "description": "内力贯拳，无视护甲。", "price": 150, "qi_cost": 5, "upgrade_base": 30, "level_damage_bonus": 1},
	"night_triple_blade": {"title": "暗夜三刀", "description": "三刀连斩，刀刀见血。", "price": 260, "qi_cost": 9, "upgrade_base": 50, "level_damage_bonus": 1},
}

const INTERNAL := {
	"purple_mist_art": {"title": "紫霞神功", "description": "内力外放，诸般攻击更进一筹。攻击 +2。", "price": 200, "damage_bonus": 2, "upgrade_base": 40, "level_damage_bonus": 1},
	"five_elements_art": {"title": "五行归元功", "description": "五行调和，疗伤更速。回春散额外恢复 +5。", "price": 200, "healing_bonus": 5, "upgrade_base": 40, "level_healing_bonus": 1},
}

const LIGHTNESS := {
	"ripple_steps": {"title": "凌波微步", "description": "身法灵动，多行一步。移动范围 +1。", "price": 150, "move_bonus": 1, "upgrade_base": 30},
	"wind_walk": {"title": "神行百变", "description": "疾行如风，进退由心。移动范围 +2。", "price": 320, "move_bonus": 2, "upgrade_base": 60},
}

static func move_level(state: Dictionary, id: String) -> int:
	return clampi(int(Dictionary(state.get("move_levels", {})).get(id, 1)), 1, MAX_LEVEL)

static func internal_level(state: Dictionary, id: String) -> int:
	return clampi(int(Dictionary(state.get("internal_levels", {})).get(id, 1)), 1, MAX_LEVEL)

static func lightness_level(state: Dictionary, id: String) -> int:
	return clampi(int(Dictionary(state.get("lightness_levels", {})).get(id, 1)), 1, MAX_LEVEL)

static func move_damage_bonus(state: Dictionary, id: String) -> int:
	if not MOVES.has(id):
		return 0
	return (move_level(state, id) - 1) * int(MOVES[id].get("level_damage_bonus", 0))

static func internal_damage_bonus(state: Dictionary) -> int:
	var id := str(state.get("equipped_internal", ""))
	if not INTERNAL.has(id):
		return 0
	var item: Dictionary = INTERNAL[id]
	var level := internal_level(state, id)
	return int(item.get("damage_bonus", 0)) + (level - 1) * int(item.get("level_damage_bonus", 0))

static func internal_healing_bonus(state: Dictionary) -> int:
	var id := str(state.get("equipped_internal", ""))
	if not INTERNAL.has(id):
		return 0
	var item: Dictionary = INTERNAL[id]
	var level := internal_level(state, id)
	return int(item.get("healing_bonus", 0)) + (level - 1) * int(item.get("level_healing_bonus", 0))

static func lightness_move_bonus(state: Dictionary) -> int:
	var id := str(state.get("equipped_lightness", ""))
	if not LIGHTNESS.has(id):
		return 0
	var level := lightness_level(state, id)
	return int(LIGHTNESS[id].get("move_bonus", 0)) + (level - 1) / LIGHTNESS_LEVEL_DIVISOR

static func upgrade_cost(catalog: Dictionary, id: String, current_level: int) -> int:
	return int(catalog[id].upgrade_base) * (current_level + 1)

## 修炼 (free but slow, spends a week in the sect) and 升级 (instant, costs
## silver at 秘籍阁) both feed the same level -- this is a deliberate second
## path to the same progression, not a duplicate system.
static func xp_needed(level: int) -> int:
	return 20 * (level + 1)

static func wuxue_xp(state: Dictionary, id: String) -> int:
	return maxi(0, int(Dictionary(state.get("wuxue_xp", {})).get(id, 0)))

static func train_move(state: Dictionary, id: String, xp_gain: int) -> Dictionary:
	if not MOVES.has(id) or id not in Array(state.get("learned_moves", [])):
		return {"ok": false}
	if move_level(state, id) >= MAX_LEVEL:
		return {"ok": false, "already_maxed": true}
	return _train(state, "move_levels", id, xp_gain, move_level(state, id))

static func train_internal(state: Dictionary, id: String, xp_gain: int) -> Dictionary:
	if not INTERNAL.has(id) or id not in Array(state.get("learned_internal", [])):
		return {"ok": false}
	if internal_level(state, id) >= MAX_LEVEL:
		return {"ok": false, "already_maxed": true}
	return _train(state, "internal_levels", id, xp_gain, internal_level(state, id))

static func train_lightness(state: Dictionary, id: String, xp_gain: int) -> Dictionary:
	if not LIGHTNESS.has(id) or id not in Array(state.get("learned_lightness", [])):
		return {"ok": false}
	if lightness_level(state, id) >= MAX_LEVEL:
		return {"ok": false, "already_maxed": true}
	return _train(state, "lightness_levels", id, xp_gain, lightness_level(state, id))

static func _train(state: Dictionary, level_key: String, id: String, xp_gain: int, level: int) -> Dictionary:
	if not state.has("wuxue_xp") or typeof(state.wuxue_xp) != TYPE_DICTIONARY:
		state.wuxue_xp = {}
	var xp := wuxue_xp(state, id) + maxi(0, xp_gain)
	var leveled_up := false
	while level < MAX_LEVEL and xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		leveled_up = true
	if not state.has(level_key) or typeof(state[level_key]) != TYPE_DICTIONARY:
		state[level_key] = {}
	state[level_key][id] = level
	state.wuxue_xp[id] = 0 if level >= MAX_LEVEL else xp
	return {"ok": true, "leveled_up": leveled_up, "new_level": level, "xp": int(state.wuxue_xp[id]), "xp_needed": xp_needed(level) if level < MAX_LEVEL else 0}

static func options_training(state: Dictionary) -> Array:
	var options := []
	for id in Array(state.get("learned_moves", [])):
		options.append(_training_row(state, str(MOVES[id].title), str(MOVES[id].description), move_level(state, id), id, "train_move_%s" % id))
	for id in Array(state.get("learned_internal", [])):
		options.append(_training_row(state, str(INTERNAL[id].title), str(INTERNAL[id].description), internal_level(state, id), id, "train_internal_%s" % id))
	for id in Array(state.get("learned_lightness", [])):
		options.append(_training_row(state, str(LIGHTNESS[id].title), str(LIGHTNESS[id].description), lightness_level(state, id), id, "train_lightness_%s" % id))
	options.append(["返回", "不消耗行动点，返回修炼选择。", "leave"])
	return options

static func _training_row(state: Dictionary, title: String, description: String, level: int, id: String, route: String) -> Array:
	if level >= MAX_LEVEL:
		return ["修炼 · %s · 已大成" % title, "%s（已修炼至第10层，无需再练）" % description, route, true]
	return ["修炼 · %s Lv.%d（%d/%d 经验）" % [title, level, wuxue_xp(state, id), xp_needed(level)], description, route, false]

static func options_manuals(state: Dictionary) -> Array:
	var options := []
	options.append_array(_move_options(state))
	options.append_array(_internal_options(state))
	options.append_array(_lightness_options(state))
	options.append(["返回", "不消耗行动点，返回西市。", "leave"])
	return options

static func _level_row(title: String, level: int, cost: int, silver: int, route: String) -> Array:
	if level >= MAX_LEVEL:
		return ["升级 · %s · 已满级" % title, "已修炼至第10层，武学大成。", route, true]
	return ["升级 · %s Lv.%d→%d · %d 银" % [title, level, level + 1, cost], "修为越高，境界提升所需银两越多。", route, silver < cost]

static func _move_options(state: Dictionary) -> Array:
	var learned: Array = state.get("learned_moves", [])
	var equipped: Array = state.get("equipped_moves", [])
	var silver := int(state.get("silver", 0))
	var options := []
	for id in MOVES:
		var item: Dictionary = MOVES[id]
		if id in equipped:
			options.append(["卸下 · %s Lv.%d" % [str(item.title), move_level(state, id)], "%s（当前装备）" % str(item.description), "unequip_move_%s" % id, false])
		elif id in learned:
			var slot_full := equipped.size() >= MAX_EQUIPPED_MOVES
			options.append(["装备 · %s Lv.%d" % [str(item.title), move_level(state, id)], "%s%s" % [str(item.description), "（招式槽位已满）" if slot_full else ""], "equip_move_%s" % id, slot_full])
		else:
			options.append(["学习 · %s · %d 银" % [str(item.title), int(item.price)], str(item.description), "learn_move_%s" % id, silver < int(item.price)])
		if id in learned:
			var level := move_level(state, id)
			options.append(_level_row(str(item.title), level, upgrade_cost(MOVES, id, level), silver, "upgrade_move_%s" % id))
	return options

static func _internal_options(state: Dictionary) -> Array:
	var learned: Array = state.get("learned_internal", [])
	var equipped := str(state.get("equipped_internal", ""))
	var silver := int(state.get("silver", 0))
	var options := []
	for id in INTERNAL:
		var item: Dictionary = INTERNAL[id]
		if id == equipped:
			options.append(["卸下 · %s Lv.%d" % [str(item.title), internal_level(state, id)], "%s（当前修炼）" % str(item.description), "unequip_internal_%s" % id, false])
		elif id in learned:
			options.append(["修炼 · %s Lv.%d" % [str(item.title), internal_level(state, id)], str(item.description), "equip_internal_%s" % id, false])
		else:
			options.append(["学习 · %s · %d 银" % [str(item.title), int(item.price)], str(item.description), "learn_internal_%s" % id, silver < int(item.price)])
		if id in learned:
			var level := internal_level(state, id)
			options.append(_level_row(str(item.title), level, upgrade_cost(INTERNAL, id, level), silver, "upgrade_internal_%s" % id))
	return options

static func _lightness_options(state: Dictionary) -> Array:
	var learned: Array = state.get("learned_lightness", [])
	var equipped := str(state.get("equipped_lightness", ""))
	var silver := int(state.get("silver", 0))
	var options := []
	for id in LIGHTNESS:
		var item: Dictionary = LIGHTNESS[id]
		if id == equipped:
			options.append(["卸下 · %s Lv.%d" % [str(item.title), lightness_level(state, id)], "%s（当前修炼）" % str(item.description), "unequip_lightness_%s" % id, false])
		elif id in learned:
			options.append(["修炼 · %s Lv.%d" % [str(item.title), lightness_level(state, id)], str(item.description), "equip_lightness_%s" % id, false])
		else:
			options.append(["学习 · %s · %d 银" % [str(item.title), int(item.price)], str(item.description), "learn_lightness_%s" % id, silver < int(item.price)])
		if id in learned:
			var level := lightness_level(state, id)
			options.append(_level_row(str(item.title), level, upgrade_cost(LIGHTNESS, id, level), silver, "upgrade_lightness_%s" % id))
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

static func upgrade_move(state: Dictionary, id: String) -> bool:
	if not MOVES.has(id) or id not in Array(state.get("learned_moves", [])):
		return false
	var level := move_level(state, id)
	if level >= MAX_LEVEL:
		return false
	var cost := upgrade_cost(MOVES, id, level)
	if int(state.get("silver", 0)) < cost:
		return false
	state.silver = int(state.get("silver", 0)) - cost
	if not state.has("move_levels") or typeof(state.move_levels) != TYPE_DICTIONARY:
		state.move_levels = {}
	state.move_levels[id] = level + 1
	return true

static func upgrade_internal(state: Dictionary, id: String) -> bool:
	if not INTERNAL.has(id) or id not in Array(state.get("learned_internal", [])):
		return false
	var level := internal_level(state, id)
	if level >= MAX_LEVEL:
		return false
	var cost := upgrade_cost(INTERNAL, id, level)
	if int(state.get("silver", 0)) < cost:
		return false
	state.silver = int(state.get("silver", 0)) - cost
	if not state.has("internal_levels") or typeof(state.internal_levels) != TYPE_DICTIONARY:
		state.internal_levels = {}
	state.internal_levels[id] = level + 1
	return true

static func upgrade_lightness(state: Dictionary, id: String) -> bool:
	if not LIGHTNESS.has(id) or id not in Array(state.get("learned_lightness", [])):
		return false
	var level := lightness_level(state, id)
	if level >= MAX_LEVEL:
		return false
	var cost := upgrade_cost(LIGHTNESS, id, level)
	if int(state.get("silver", 0)) < cost:
		return false
	state.silver = int(state.get("silver", 0)) - cost
	if not state.has("lightness_levels") or typeof(state.lightness_levels) != TYPE_DICTIONARY:
		state.lightness_levels = {}
	state.lightness_levels[id] = level + 1
	return true
