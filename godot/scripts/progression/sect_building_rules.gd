class_name SectBuildingRules
extends RefCounted

## 青云门门派建设 (0.167.0): four fixed buildings give small, visible
## preparation bonuses without turning the story into a waiting simulator.
## Construction is available from the start; each upgrade is a normal weekly
## action and reuses the existing silver, herbs, and ore inventory.
const MAX_LEVEL := 3
const BUILDING_IDS := ["training_ground", "library", "herb_garden", "forge"]
const BUILDINGS := {
	"training_ground": {
		"title": "演武场",
		"tag": "修炼",
		"description": "整饬木桩与剑坪，让每周修炼更有收获。",
		"effects": ["尚未整修", "修炼额外获得2点修为", "修炼额外获得4点修为", "修炼额外获得6点修为"],
		"costs": [{}, {"silver": 300, "herbs": 1, "ore": 2}, {"silver": 700, "herbs": 3, "ore": 5}, {"silver": 1500, "herbs": 6, "ore": 10}],
	},
	"library": {
		"title": "藏经阁",
		"tag": "武学",
		"description": "修补藏书与抄录秘籍，降低秘籍阁的银两门槛。",
		"effects": ["尚未整修", "秘籍阁费用减免5%", "秘籍阁费用减免10%", "秘籍阁费用减免15%"],
		"costs": [{}, {"silver": 300, "herbs": 2, "ore": 1}, {"silver": 700, "herbs": 4, "ore": 4}, {"silver": 1500, "herbs": 8, "ore": 8}],
	},
	"herb_garden": {
		"title": "药圃",
		"tag": "采集",
		"description": "开垦药圃，结束每周时稳定收回门派药材。",
		"effects": ["尚未整修", "每周结束获得1份药材", "每周结束获得2份药材", "每周结束获得3份药材"],
		"costs": [{}, {"silver": 300, "herbs": 2, "ore": 1}, {"silver": 700, "herbs": 5, "ore": 3}, {"silver": 1500, "herbs": 9, "ore": 6}],
	},
	"forge": {
		"title": "铸造坊",
		"tag": "锻造",
		"description": "添置炉具与模具，减少锻造装备的矿石消耗。",
		"effects": ["尚未整修", "锻造装备少消耗1矿石", "锻造装备少消耗2矿石", "锻造装备少消耗3矿石"],
		"costs": [{}, {"silver": 300, "herbs": 1, "ore": 2}, {"silver": 700, "herbs": 2, "ore": 6}, {"silver": 1500, "herbs": 4, "ore": 12}],
	},
}

static func normalized_sect(value: Variant) -> Dictionary:
	var result := {"buildings": {}}
	var saved: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var saved_buildings: Dictionary = saved.get("buildings", {}) if typeof(saved.get("buildings", {})) == TYPE_DICTIONARY else {}
	for id in BUILDING_IDS:
		result.buildings[id] = clampi(int(saved_buildings.get(id, 0)), 0, MAX_LEVEL)
	return result

static func level(state: Dictionary, id: String) -> int:
	if not BUILDINGS.has(id):
		return 0
	var sect: Dictionary = state.get("sect", {}) if typeof(state.get("sect", {})) == TYPE_DICTIONARY else {}
	var buildings: Dictionary = sect.get("buildings", {}) if typeof(sect.get("buildings", {})) == TYPE_DICTIONARY else {}
	return clampi(int(buildings.get(id, 0)), 0, MAX_LEVEL)

static func cost_for_next(state: Dictionary, id: String) -> Dictionary:
	if not BUILDINGS.has(id):
		return {}
	var next_level := level(state, id) + 1
	if next_level > MAX_LEVEL:
		return {}
	return Dictionary(BUILDINGS[id].costs[next_level]).duplicate(true)

static func can_upgrade(state: Dictionary, id: String, check_action: bool = true) -> bool:
	if not BUILDINGS.has(id) or level(state, id) >= MAX_LEVEL:
		return false
	if int(state.get("week", 1)) >= 104:
		return false
	if check_action and bool(state.get("acted_this_week", false)):
		return false
	var cost := cost_for_next(state, id)
	if int(state.get("silver", 0)) < int(cost.get("silver", 0)):
		return false
	var materials: Dictionary = state.get("materials", {})
	return int(materials.get("herbs", 0)) >= int(cost.get("herbs", 0)) and int(materials.get("ore", 0)) >= int(cost.get("ore", 0))

## Human-readable reason for the disabled state. The pavilion is reachable
## after the week's action has already been spent, so "材料不足" must not be
## used for every locked card -- that made fully stocked players think
## construction was permanently impossible.
static func upgrade_block_reason(state: Dictionary, id: String) -> String:
	if not BUILDINGS.has(id):
		return "无法升级"
	if level(state, id) >= MAX_LEVEL:
		return "已达最高等级"
	if int(state.get("week", 1)) >= 104:
		return "两年期限已到"
	if bool(state.get("acted_this_week", false)):
		return "本周已行动，结束本周后可升级"
	var cost := cost_for_next(state, id)
	if int(state.get("silver", 0)) < int(cost.get("silver", 0)):
		return "银两不足（%d/%d）" % [int(state.get("silver", 0)), int(cost.get("silver", 0))]
	var materials: Dictionary = state.get("materials", {})
	if int(materials.get("herbs", 0)) < int(cost.get("herbs", 0)):
		return "药材不足（%d/%d）" % [int(materials.get("herbs", 0)), int(cost.get("herbs", 0))]
	if int(materials.get("ore", 0)) < int(cost.get("ore", 0)):
		return "矿石不足（%d/%d）" % [int(materials.get("ore", 0)), int(cost.get("ore", 0))]
	return ""

static func upgrade(state: Dictionary, id: String) -> Dictionary:
	if not can_upgrade(state, id, false):
		return {"ok": false}
	var cost := cost_for_next(state, id)
	var next_level := level(state, id) + 1
	state.silver = int(state.get("silver", 0)) - int(cost.get("silver", 0))
	state.materials.herbs = int(state.materials.get("herbs", 0)) - int(cost.get("herbs", 0))
	state.materials.ore = int(state.materials.get("ore", 0)) - int(cost.get("ore", 0))
	state.sect.buildings[id] = next_level
	return {"ok": true, "id": id, "level": next_level, "cost": cost}

static func effect_text(state: Dictionary, id: String) -> String:
	if not BUILDINGS.has(id):
		return ""
	return str(BUILDINGS[id].effects[level(state, id)])

static func next_effect_text(state: Dictionary, id: String) -> String:
	var next_level := level(state, id) + 1
	if not BUILDINGS.has(id) or next_level > MAX_LEVEL:
		return "已达最高等级"
	return str(BUILDINGS[id].effects[next_level])

static func cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "已达最高等级"
	var parts: Array[String] = []
	if int(cost.get("silver", 0)) > 0:
		parts.append("银两 %d" % int(cost.silver))
	if int(cost.get("herbs", 0)) > 0:
		parts.append("药材 %d" % int(cost.herbs))
	if int(cost.get("ore", 0)) > 0:
		parts.append("矿石 %d" % int(cost.ore))
	return "、".join(parts)

static func training_xp_bonus(state: Dictionary) -> int:
	return level(state, "training_ground") * 2

static func herb_weekly_bonus(state: Dictionary) -> int:
	return level(state, "herb_garden")

static func library_discount(state: Dictionary, base_cost: int) -> int:
	return mini(base_cost, int(floor(float(base_cost) * level(state, "library") * 0.05)))

static func forge_ore_discount(state: Dictionary) -> int:
	return level(state, "forge")

static func options(state: Dictionary) -> Array:
	var result := []
	for id in BUILDING_IDS:
		var entry: Dictionary = BUILDINGS[id]
		var current := level(state, id)
		var cost := cost_for_next(state, id)
		var locked := current >= MAX_LEVEL or not can_upgrade(state, id)
		var status := "当前 Lv.%d · %s" % [current, effect_text(state, id)]
		if current < MAX_LEVEL:
			status += "\n下级：%s · 需要%s" % [next_effect_text(state, id), cost_text(cost)]
		var blocked := upgrade_block_reason(state, id)
		if blocked != "":
			status += "\n%s" % blocked
		result.append(["%s · Lv.%d" % [str(entry.title), current], "%s\n%s" % [str(entry.description), status], "upgrade_%s" % id, locked])
	result.append(["离开营造图", "不消耗行动点，返回青云门。", "leave"])
	return result
