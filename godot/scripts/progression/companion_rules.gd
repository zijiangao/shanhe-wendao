class_name CompanionRules
extends RefCounted

const SHOP_RULES := preload("res://scripts/progression/shop_rules.gd")
const WUXUE_RULES := preload("res://scripts/progression/wuxue_rules.gd")

## 客栈招募的门下弟子 (0.109.0) -- distinct from the story companion 林清霜
## (who joins for free at a fixed quest beat and fights in 华山论剑试炼/
## 武库天门终战). Recruited disciples are a separate, silver-bought roster
## that only accompanies the hero in repeatable 青云门切磋 (qingyun_spar)
## sparring battles, never the story battles -- keeps this feature additive
## and never touches 林清霜's hardcoded quest integration.
## strength/agility/insight/constitution and skills_text/gear_text (0.111.0)
## are display-only flavor for 人物界面's roster browser -- they feed no
## growth/shopping system of their own (companions don't train or shop),
## they just let every roster member show the same panel shape (基础属性/
## 武学/装备) as 沈羽's own panel, filled with fixed catalog values instead
## of live save data.
const DISCIPLES := {
	"zhou_mubai": {"title": "周慕白", "description": "青云新晋剑客，出手稳健，长于协同守御。", "price": 300, "hp": 28, "max_qi": 14, "attack": 5, "guard": 0, "strength": 5, "agility": 4, "insight": 4, "constitution": 5, "skills_text": "霜华刺 · 突进两格攻击\n寒锋守势 · 获得护卫并回气", "gear_text": "随身青锋 · 稳健守御路数"},
	"liu_ruyan": {"title": "柳如烟", "description": "身法灵动的女弟子，擅长游走牵制。", "price": 380, "hp": 24, "max_qi": 16, "attack": 6, "guard": 0, "strength": 4, "agility": 6, "insight": 5, "constitution": 3, "skills_text": "霜华刺 · 突进两格攻击\n寒锋守势 · 获得护卫并回气", "gear_text": "软剑轻装 · 游走牵制路数"},
}

## 林清霜是免费的剧情同伴 (0.74.0起)，在华山剧情固定加入，只在华山论剑试炼/
## 武库天门终战出战 -- 这里的数值纯粹是人物界面的展示用途，不影响那两场
## 战斗里 game_state.gd 各自硬编码的 battle.ally 数值。
const STORY_COMPANIONS := {
	"lin_qingshuang": {"title": "林清霜", "description": "华山女侠，剑法凌厉，与沈羽并肩闯荡江湖。", "hp": 34, "max_qi": 15, "attack": 6, "guard": 0, "strength": 5, "agility": 6, "insight": 5, "constitution": 4, "skills_text": "霜华刺 · 突进两格攻击\n寒锋守势 · 获得护卫并回气", "gear_text": "华山佩剑 · 凌厉剑路"},
}

static func is_valid_disciple(id: String) -> bool:
	return DISCIPLES.has(id)

## 人物界面左右分栏浏览器 (0.111.0) 统一读取入口，覆盖 STORY_COMPANIONS 和
## DISCIPLES 两个目录 -- 沈羽本人不在这里，由 main.gd 单独处理（他是玩家
## 实时成长的存档数据，不是固定目录）。
static func is_valid_companion(id: String) -> bool:
	return DISCIPLES.has(id) or STORY_COMPANIONS.has(id)

static func companion_entry(id: String) -> Dictionary:
	return STORY_COMPANIONS.get(id, DISCIPLES.get(id, {}))

## 已加入门派的同伴列表 (0.111.0)，用于人物界面左侧名单 -- 林清霜(若已加入)
## 排在最前，其后是全部已招募弟子（不只是当前随行的那一个）。
static func roster(state: Dictionary) -> Array:
	var ids := []
	if "lin_qingshuang" in Array(state.get("companions", [])):
		ids.append("lin_qingshuang")
	for id in Array(state.get("companions", [])):
		if is_valid_disciple(str(id)):
			ids.append(str(id))
	return ids

static func is_recruited(state: Dictionary, id: String) -> bool:
	return id in Array(state.get("companions", []))

static func recruit(state: Dictionary, id: String) -> bool:
	if not is_valid_disciple(id) or is_recruited(state, id) or int(state.get("silver", 0)) < int(DISCIPLES[id].price):
		return false
	state.silver = int(state.get("silver", 0)) - int(DISCIPLES[id].price)
	state.companions.append(id)
	state.active_disciple = id
	return true

## 客栈选项列表：已招募的弟子显示为可选为"随行弟子"的只读行（招募即自动
## 随行，无需额外装备步骤，跟 0.104.0 招式取消装备槽的简化思路一致）；
## 未招募的显示招募价格，银两不足则禁用。
static func options_inn(state: Dictionary) -> Array:
	var options := []
	var silver := int(state.get("silver", 0))
	for id in DISCIPLES:
		var item: Dictionary = DISCIPLES[id]
		if is_recruited(state, id):
			var active_note := "（当前随行）" if str(state.get("active_disciple", "")) == id else "（已加入门派）"
			options.append(["已招募 · %s%s" % [str(item.title), active_note], str(item.description), "none", true])
		else:
			options.append(["招募 · %s · %d 银" % [str(item.title), int(item.price)], str(item.description), "recruit_%s" % id, silver < int(item.price)])
	options.append(["返回", "不消耗行动点，返回舆图。", "leave"])
	return options

## start_qingyun_spar_battle() (game_state.gd) uses this to build a
## battle.ally-shaped dict for whichever disciple is currently active, same
## field shape as 林清霜's hardcoded ally dict in the story battles.
static func active_disciple_ally(state: Dictionary) -> Dictionary:
	var id := str(state.get("active_disciple", ""))
	if not is_recruited(state, id) or not is_valid_disciple(id):
		return {}
	var item: Dictionary = DISCIPLES[id]
	var ally := {"name": str(item.title), "hp": int(item.hp), "max_hp": int(item.hp), "qi": int(item.max_qi), "max_qi": int(item.max_qi), "attack": int(item.attack), "guard": int(item.guard), "x": 1, "y": 4}
	return apply_gear_and_move(state, id, ally)

## 同伴换装备/换武学 (0.113.0) -- 同伴与沈羽共用同一份兵器/护具池
## (owned_weapons/owned_armors)，各自独立选择装备哪一件，不新建单独的
## 购置渠道；武学则从沈羽已学的 learned_moves 里选一招，替代默认的霜华刺
## （详见 battle_engine.gd 的 _frost_dash()，未选择时行为与之前完全一致）。
static func companion_weapon(state: Dictionary, id: String) -> String:
	return str(Dictionary(state.get("companion_gear", {})).get(id, {}).get("weapon", ""))

static func companion_armor(state: Dictionary, id: String) -> String:
	return str(Dictionary(state.get("companion_gear", {})).get(id, {}).get("armor", ""))

static func companion_move(state: Dictionary, id: String) -> String:
	return str(Dictionary(state.get("companion_move", {})).get(id, ""))

## 同伴换内功/轻功 (0.114.0) -- 同样从沈羽已学的 learned_internal/
## learned_lightness 里借一门，沿用沈羽自己对那门内功/轻功的等级
## (WuxueRules.internal_level()/lightness_level())，不是同伴另起炉灶重新
##练一遍。内功加成叠进 ally.attack；轻功加成叠成 ally.lightness_bonus，
## 供 _frost_dash() 扩展突进射程使用。
static func companion_internal(state: Dictionary, id: String) -> String:
	return str(Dictionary(state.get("companion_internal", {})).get(id, ""))

static func companion_lightness(state: Dictionary, id: String) -> String:
	return str(Dictionary(state.get("companion_lightness", {})).get(id, ""))

static func _companion_gear_slot(state: Dictionary, id: String) -> Dictionary:
	if not state.has("companion_gear") or typeof(state.companion_gear) != TYPE_DICTIONARY:
		state.companion_gear = {}
	if not state.companion_gear.has(id) or typeof(state.companion_gear[id]) != TYPE_DICTIONARY:
		state.companion_gear[id] = {"weapon": "", "armor": ""}
	return state.companion_gear[id]

static func equip_companion_weapon(state: Dictionary, id: String, weapon_id: String) -> bool:
	if not is_valid_companion(id) or (weapon_id != "" and weapon_id not in Array(state.get("owned_weapons", []))):
		return false
	_companion_gear_slot(state, id).weapon = weapon_id
	return true

static func equip_companion_armor(state: Dictionary, id: String, armor_id: String) -> bool:
	if not is_valid_companion(id) or (armor_id != "" and armor_id not in Array(state.get("owned_armors", []))):
		return false
	_companion_gear_slot(state, id).armor = armor_id
	return true

static func equip_companion_move(state: Dictionary, id: String, move_id: String) -> bool:
	if not is_valid_companion(id) or (move_id != "" and move_id not in Array(state.get("learned_moves", []))):
		return false
	if not state.has("companion_move") or typeof(state.companion_move) != TYPE_DICTIONARY:
		state.companion_move = {}
	state.companion_move[id] = move_id
	return true

static func equip_companion_internal(state: Dictionary, id: String, internal_id: String) -> bool:
	if not is_valid_companion(id) or (internal_id != "" and internal_id not in Array(state.get("learned_internal", []))):
		return false
	if not state.has("companion_internal") or typeof(state.companion_internal) != TYPE_DICTIONARY:
		state.companion_internal = {}
	state.companion_internal[id] = internal_id
	return true

static func equip_companion_lightness(state: Dictionary, id: String, lightness_id: String) -> bool:
	if not is_valid_companion(id) or (lightness_id != "" and lightness_id not in Array(state.get("learned_lightness", []))):
		return false
	if not state.has("companion_lightness") or typeof(state.companion_lightness) != TYPE_DICTIONARY:
		state.companion_lightness = {}
	state.companion_lightness[id] = lightness_id
	return true

## 换装/换武学选项列表，供人物界面的同伴信息卡使用。
static func options_companion_weapons(state: Dictionary, id: String) -> Array:
	var options := []
	var current := companion_weapon(state, id)
	options.append(["赤手（不装备兵器）", "卸下兵器。", "equip_weapon_", current == ""])
	for weapon_id in Array(state.get("owned_weapons", [])):
		var item: Dictionary = SHOP_RULES.WEAPONS.get(str(weapon_id), {})
		var title := str(item.get("item_name", item.get("title", weapon_id)))
		options.append(["%s（攻击+%d）" % [title, int(item.get("attack_bonus", 0))], "为同伴换上此兵器。", "equip_weapon_%s" % weapon_id, current == str(weapon_id)])
	options.append(["返回", "不消耗行动点，返回同伴信息。", "leave"])
	return options

static func options_companion_armors(state: Dictionary, id: String) -> Array:
	var options := []
	var current := companion_armor(state, id)
	options.append(["无护具", "卸下护具。", "equip_armor_", current == ""])
	for armor_id in Array(state.get("owned_armors", [])):
		var item: Dictionary = SHOP_RULES.ARMORS.get(str(armor_id), {})
		var title := str(item.get("item_name", item.get("title", armor_id)))
		options.append(["%s（防御+%d）" % [title, int(item.get("defense_bonus", 0))], "为同伴换上此护具。", "equip_armor_%s" % armor_id, current == str(armor_id)])
	options.append(["返回", "不消耗行动点，返回同伴信息。", "leave"])
	return options

static func options_companion_moves(state: Dictionary, id: String) -> Array:
	var options := []
	var current := companion_move(state, id)
	options.append(["霜华刺（默认）", "沈羽同伴的默认突进技，不占用沈羽的招式。", "equip_move_", current == ""])
	for move_id in Array(state.get("learned_moves", [])):
		var item: Dictionary = WUXUE_RULES.MOVES.get(str(move_id), {})
		if item.is_empty():
			continue
		options.append(["%s · %s" % [str(item.title), str(item.description)], "让同伴在突进攻击时改用此招式的招式名与真气消耗。", "equip_move_%s" % move_id, current == str(move_id)])
	options.append(["返回", "不消耗行动点，返回同伴信息。", "leave"])
	return options

static func options_companion_internals(state: Dictionary, id: String) -> Array:
	var options := []
	var current := companion_internal(state, id)
	options.append(["不修炼内功", "卸下内功。", "equip_internal_", current == ""])
	for internal_id in Array(state.get("learned_internal", [])):
		var item: Dictionary = WUXUE_RULES.INTERNAL.get(str(internal_id), {})
		if item.is_empty():
			continue
		options.append(["%s Lv.%d · %s" % [str(item.title), WUXUE_RULES.internal_level(state, str(internal_id)), str(item.description)], "让同伴借用此内功（沿用沈羽已修炼的等级）。", "equip_internal_%s" % internal_id, current == str(internal_id)])
	options.append(["返回", "不消耗行动点，返回同伴信息。", "leave"])
	return options

static func options_companion_lightness(state: Dictionary, id: String) -> Array:
	var options := []
	var current := companion_lightness(state, id)
	options.append(["不修炼轻功", "卸下轻功。", "equip_lightness_", current == ""])
	for lightness_id in Array(state.get("learned_lightness", [])):
		var item: Dictionary = WUXUE_RULES.LIGHTNESS.get(str(lightness_id), {})
		if item.is_empty():
			continue
		options.append(["%s Lv.%d · %s" % [str(item.title), WUXUE_RULES.lightness_level(state, str(lightness_id)), str(item.description)], "让同伴借用此轻功，扩大突进射程（沿用沈羽已修炼的等级）。", "equip_lightness_%s" % lightness_id, current == str(lightness_id)])
	options.append(["返回", "不消耗行动点，返回同伴信息。", "leave"])
	return options

static func companion_internal_damage_bonus(state: Dictionary, internal_id: String) -> int:
	if not WUXUE_RULES.INTERNAL.has(internal_id):
		return 0
	var item: Dictionary = WUXUE_RULES.INTERNAL[internal_id]
	var level := WUXUE_RULES.internal_level(state, internal_id)
	return int(item.get("damage_bonus", 0)) + (level - 1) * int(item.get("level_damage_bonus", 0))

static func companion_lightness_move_bonus(state: Dictionary, lightness_id: String) -> int:
	if not WUXUE_RULES.LIGHTNESS.has(lightness_id):
		return 0
	var level := WUXUE_RULES.lightness_level(state, lightness_id)
	return int(WUXUE_RULES.LIGHTNESS[lightness_id].get("move_bonus", 0)) + (level - 1) / WUXUE_RULES.LIGHTNESS_LEVEL_DIVISOR

## 把换装/换武学的加成叠加到基础 ally 字典上 -- 林清霜（game_state.gd 里
## 两处硬编码的基础数值）和客栈弟子（active_disciple_ally() 的基础数值）
## 都调用这个函数叠加，保持两者换装/换武学效果一致。
static func apply_gear_and_move(state: Dictionary, id: String, base_ally: Dictionary) -> Dictionary:
	var ally := base_ally.duplicate(true)
	var weapon_bonus := SHOP_RULES.weapon_attack_bonus({"equipped_weapon": companion_weapon(state, id)})
	var armor_bonus := SHOP_RULES.armor_defense_bonus({"equipped_armor": companion_armor(state, id)})
	var internal_bonus := companion_internal_damage_bonus(state, companion_internal(state, id))
	ally.attack = int(ally.get("attack", 0)) + weapon_bonus + internal_bonus
	ally.armor = armor_bonus
	ally.move_id = companion_move(state, id)
	ally.lightness_bonus = companion_lightness_move_bonus(state, companion_lightness(state, id))
	return ally
