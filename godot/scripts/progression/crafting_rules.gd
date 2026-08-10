class_name CraftingRules
extends RefCounted

const TRAINING_RULES := preload("res://scripts/progression/training_minigame_rules.gd")
const HERBARIUM_RULES := preload("res://scripts/progression/herbarium_rules.gd")
const MINERALOGY_RULES := preload("res://scripts/progression/mineralogy_rules.gd")
const EQUIPMENT_RULES := preload("res://scripts/progression/equipment_rules.gd")

## "specimens" (0.85.0) names specific 药谱/矿谱 collectibles a recipe needs,
## on top of the plain herbs/ore pool -- reuses the same named items 采药/挖矿
## already roll into state.herbarium/state.mineralogy, giving those specimens
## an actual crafting purpose instead of being pure flavor/collection XP.
## Most recipes have none (empty dict); a few need one named specimen, and the
## two "advanced" gear pieces need two distinct specimens at once.
const RECIPES := {
	"healing_powder": {
		"title": "炼制 · 回春散",
		"description": "药材 2 · 战斗中消耗1行动点，恢复气血。",
		"cost": {"herbs": 2, "ore": 0, "silver": 0, "specimens": {}}
	},
	"insight_pill": {
		"title": "炼制 · 悟性丹",
		"description": "药材 3 · 云纹叶 1 · 银两 15 · 服下后立即提升1点悟性，可反复炼制。",
		"cost": {"herbs": 3, "ore": 0, "silver": 15, "specimens": {"cloudleaf": 1}}
	},
	"strength_pill": {
		"title": "炼制 · 臂力丹",
		"description": "药材 3 · 银两 15 · 服下后立即提升1点臂力，可反复炼制。",
		"cost": {"herbs": 3, "ore": 0, "silver": 15, "specimens": {}}
	},
	"agility_pill": {
		"title": "炼制 · 身法丹",
		"description": "药材 3 · 云纹叶 1 · 银两 15 · 服下后立即提升1点身法，可反复炼制。",
		"cost": {"herbs": 3, "ore": 0, "silver": 15, "specimens": {"cloudleaf": 1}}
	},
	"constitution_pill": {
		"title": "炼制 · 根骨丹",
		"description": "药材 3 · 云纹叶 1 · 赤阳参 1 · 银两 15 · 服下后立即提升1点根骨（并提升最大与当前气血），可反复炼制。",
		"cost": {"herbs": 3, "ore": 0, "silver": 15, "specimens": {"cloudleaf": 1, "sunroot": 1}}
	},
	"forged_iron_blade": {
		"title": "打造 · 自铸铁刃",
		"item_name": "自铸铁刃",
		"description": "工坊自制兵刃，攻击 +2，只需材料，不同于西市的银两购置。",
		"cost": {"herbs": 0, "ore": 5, "silver": 0, "specimens": {}},
		"attack_bonus": 2
	},
	"twin_edge_saber": {
		"title": "打造 · 双刃寒锋",
		"item_name": "双刃寒锋",
		"description": "工坊自制兵刃，攻击 +3，流银砂 1，锻造要求更高。",
		"cost": {"herbs": 0, "ore": 10, "silver": 0, "specimens": {"silver_sand": 1}},
		"attack_bonus": 3
	},
	"rattan_guard": {
		"title": "打造 · 藤甲护身",
		"item_name": "藤甲护身",
		"description": "工坊自制护具，防御 +1，只需材料，不同于西市的银两购置。",
		"cost": {"herbs": 0, "ore": 5, "silver": 0, "specimens": {}},
		"defense_bonus": 1
	},
	"layered_iron_armor": {
		"title": "打造 · 叠层甲胄",
		"item_name": "叠层甲胄",
		"description": "工坊自制护具，防御 +2，流银砂 1，赤火铜 1，锻造要求更高。",
		"cost": {"herbs": 0, "ore": 8, "silver": 0, "specimens": {"silver_sand": 1, "fire_copper": 1}},
		"defense_bonus": 2
	},
	"vitality_pill": {
		"title": "炼制 · 回元丹",
		"description": "药材 5 · 七星莲 1 · 银两 40 · 服下后四维属性各+1，可反复炼制，炼药坊5级解锁。",
		"cost": {"herbs": 5, "ore": 0, "silver": 40, "specimens": {"sevenstar_lotus": 1}}
	},
	"star_marrow_blade": {
		"title": "打造 · 星陨寒锋",
		"item_name": "星陨寒锋",
		"description": "工坊自制兵刃，攻击 +5，星陨髓 1，锻造坊5级解锁，江湖顶尖神兵。",
		"cost": {"herbs": 0, "ore": 15, "silver": 0, "specimens": {"star_marrow": 1}},
		"attack_bonus": 5
	},
	"star_marrow_armor": {
		"title": "打造 · 星陨玄甲",
		"item_name": "星陨玄甲",
		"description": "工坊自制护具，防御 +4，星陨髓 1，锻造坊5级解锁，江湖顶尖玄甲。",
		"cost": {"herbs": 0, "ore": 12, "silver": 0, "specimens": {"star_marrow": 1}},
		"defense_bonus": 4
	}
}

## Workshop-crafted weapons/armor are a deliberately separate set from 西市's
## catalog (ShopRules.WEAPONS/ARMORS) -- same equip/owned/bonus machinery,
## reused via ShopRules' fallback lookup into these RECIPES entries, but a
## distinct item list acquired with materials instead of silver.
const CRAFTABLE_WEAPONS := ["forged_iron_blade", "twin_edge_saber", "star_marrow_blade"]
const CRAFTABLE_ARMORS := ["rattan_guard", "layered_iron_armor", "star_marrow_armor"]

## 炼药坊/锻造坊 split (0.84.0): alchemy covers every herb-based "炼制" recipe,
## forge covers every ore-based "打造" recipe -- this mirrors the verb the
## recipe titles already used before the split existed, not a new taxonomy.
const ALCHEMY_RECIPES := ["healing_powder", "insight_pill", "strength_pill", "agility_pill", "constitution_pill", "vitality_pill"]
const FORGE_RECIPES := ["forged_iron_blade", "twin_edge_saber", "rattan_guard", "layered_iron_armor", "star_marrow_blade", "star_marrow_armor"]

## 炼药坊/锻造坊等级 (0.118.0) -- 独立于采药/挖矿的图鉴等级 (0.117.0)，是
## 工坊本身的1-10级熟练度，从"累计成功打造/炼制次数"直接推算，无需额外
## 存档字段之外的东西（只需两个简单计数器 alchemy_crafts/forge_crafts，
## GameState.new_game()/_migrate_and_validate() 里默认0，老存档天然兼容）。
## CRAFTS_PER_LEVEL=1 是刻意的：锻造坊的兵刃/护具只能各打造一次（不像采药/
## 挖矿可以无限重复），若沿用采药挖矿的 CATCHES_PER_LEVEL=3 会让锻造坊的
## 等级永远够不到后面新配方的门槛——把已有的4件兵刃/护具全部打造一遍正好
## 凑满5级，解锁星陨髓打造的顶尖神兵/玄甲，门槛与"练完现有全部配方"精确
## 对齐，不会出现"新配方永远解锁不了"的死锁。炼药坊的丹药本身可反复炼制，
## 同一套节奏用起来也很顺畅。已有的5款炼药坊配方/4款锻造坊配方门槛都设为
## 1级（不受影响，它们已经被0.117.0的采集图鉴等级间接把关过了），只有新增
## 的顶尖配方需要5级。
const MAX_CRAFT_LEVEL := 10
const CRAFTS_PER_LEVEL := 1
const RECIPE_LEVEL_REQUIREMENT := {
	"vitality_pill": 5,
	"star_marrow_blade": 5,
	"star_marrow_armor": 5,
}

static func _craft_count_key(workshop: String) -> String:
	return "alchemy_crafts" if workshop == "alchemy" else "forge_crafts"

static func craft_level(state: Dictionary, workshop: String) -> int:
	var crafts := int(state.get(_craft_count_key(workshop), 0))
	return mini(MAX_CRAFT_LEVEL, 1 + crafts / CRAFTS_PER_LEVEL)

static func crafts_to_next_level(state: Dictionary, workshop: String) -> int:
	var level := craft_level(state, workshop)
	if level >= MAX_CRAFT_LEVEL:
		return 0
	var crafts := int(state.get(_craft_count_key(workshop), 0))
	return level * CRAFTS_PER_LEVEL - crafts

static func workshop_for(recipe_id: String) -> String:
	return "alchemy" if recipe_id in ALCHEMY_RECIPES else "forge"

static func recipe_level_requirement(recipe_id: String) -> int:
	return int(RECIPE_LEVEL_REQUIREMENT.get(recipe_id, 1))

static func options_alchemy(state: Dictionary) -> Array:
	var options := [
		[RECIPES.healing_powder.title, "%s 当前携带 %d 份。" % [RECIPES.healing_powder.description, int(state.get("consumables", {}).get("healing_powder", 0))], "healing_powder", not can_craft(state, "healing_powder")],
		[RECIPES.insight_pill.title, "%s%s 当前悟性 %d。" % [RECIPES.insight_pill.description, _specimens_note(state, RECIPES.insight_pill.cost.specimens), int(state.get("insight", 0))], "insight_pill", not can_craft(state, "insight_pill")],
		[RECIPES.strength_pill.title, "%s 当前臂力 %d。" % [RECIPES.strength_pill.description, int(state.get("strength", 0))], "strength_pill", not can_craft(state, "strength_pill")],
		[RECIPES.agility_pill.title, "%s%s 当前身法 %d。" % [RECIPES.agility_pill.description, _specimens_note(state, RECIPES.agility_pill.cost.specimens), int(state.get("agility", 0))], "agility_pill", not can_craft(state, "agility_pill")],
		[RECIPES.constitution_pill.title, "%s%s 当前根骨 %d。" % [RECIPES.constitution_pill.description, _specimens_note(state, RECIPES.constitution_pill.cost.specimens), int(state.get("constitution", 0))], "constitution_pill", not can_craft(state, "constitution_pill")],
		[RECIPES.vitality_pill.title, "%s%s%s" % [RECIPES.vitality_pill.description, _specimens_note(state, RECIPES.vitality_pill.cost.specimens), _level_note(state, "vitality_pill")], "vitality_pill", not can_craft(state, "vitality_pill")],
	]
	options.append(["离开炼药坊", "不消耗材料，直接返回青云门。", "leave"])
	return options

static func options_forge(state: Dictionary) -> Array:
	var options := []
	for id in CRAFTABLE_WEAPONS:
		options.append(_gear_row(state, id, "owned_weapons"))
	for id in CRAFTABLE_ARMORS:
		options.append(_gear_row(state, id, "owned_armors"))
	options.append(["离开锻造坊", "不消耗材料，直接返回青云门。", "leave"])
	return options

## 兵器/护具数量制 (0.119.0): 打造不再是"打过一次就永久锁死"，同一件可以
## 反复打造多份（凑够材料即可），每份多打一份就多一个人能同时装备它。
static func _gear_row(state: Dictionary, id: String, owned_key: String) -> Array:
	var item: Dictionary = RECIPES[id]
	var owned_count := EQUIPMENT_RULES.owned_count(state, owned_key, id)
	var owned_note := "（已拥有 %d 件）" % owned_count if owned_count > 0 else ""
	var cost: Dictionary = effective_cost(state, id)
	var discount_note := "（挖矿大成减免）" if int(cost.ore) < int(RECIPES[id].cost.ore) else ""
	return ["%s · 矿石%d%s%s" % [str(item.title), int(cost.ore), discount_note, owned_note], "%s%s%s" % [str(item.description), _specimens_note(state, cost.specimens), _level_note(state, id)], id, not can_craft(state, id)]

## 炼药坊/锻造坊等级 (0.118.0) 门槛提示，跟 _specimens_note() 同款风格——
## 只有真正被 RECIPE_LEVEL_REQUIREMENT 卡住的配方才会显示，已解锁的配方
## （包括全部原有的5款丹药/4款兵刃护具）不显示任何等级文字。
static func _level_note(state: Dictionary, recipe_id: String) -> String:
	var required := recipe_level_requirement(recipe_id)
	if required <= 1:
		return ""
	var workshop := workshop_for(recipe_id)
	var level := craft_level(state, workshop)
	if level >= required:
		return ""
	var workshop_name := "炼药坊" if workshop == "alchemy" else "锻造坊"
	return " 【尚需%s %d级，当前 %d 级】" % [workshop_name, required, level]

## Names each still-missing specimen with how many the player currently owns
## vs. how many the recipe needs, e.g. " 【尚缺：云纹叶 0/1】" -- empty string
## when the recipe needs no named specimen or the player already has enough.
static func _specimens_note(state: Dictionary, specimens: Dictionary) -> String:
	var missing: Array[String] = []
	for id in specimens:
		var need := int(specimens[id])
		var have := _specimen_count(state, id)
		if have < need:
			missing.append("%s %d/%d" % [_specimen_name(id), have, need])
	return " 【尚缺：%s】" % "、".join(missing) if not missing.is_empty() else ""

static func _collection_field(specimen_id: String) -> String:
	return "herbarium" if HERBARIUM_RULES.SPECIMENS.has(specimen_id) else "mineralogy"

static func _specimen_count(state: Dictionary, specimen_id: String) -> int:
	return int(state.get(_collection_field(specimen_id), {}).get(specimen_id, 0))

static func _specimen_name(specimen_id: String) -> String:
	var field := _collection_field(specimen_id)
	var catalog: Dictionary = HERBARIUM_RULES.SPECIMENS if field == "herbarium" else MINERALOGY_RULES.SPECIMENS
	return str(catalog.get(specimen_id, {}).get("name", specimen_id))

static func _has_specimens(state: Dictionary, specimens: Dictionary) -> bool:
	for id in specimens:
		if _specimen_count(state, id) < int(specimens[id]):
			return false
	return true

static func effective_cost(state: Dictionary, recipe_id: String) -> Dictionary:
	if not RECIPES.has(recipe_id):
		return {}
	var cost: Dictionary = (RECIPES[recipe_id].cost as Dictionary).duplicate(true)
	if recipe_id in CRAFTABLE_WEAPONS or recipe_id in CRAFTABLE_ARMORS:
		cost.ore = maxi(0, int(cost.ore) - TRAINING_RULES.craft_ore_discount(int(state.get("mining", 0))))
	return cost

static func can_craft(state: Dictionary, recipe_id: String) -> bool:
	if not RECIPES.has(recipe_id):
		return false
	if craft_level(state, workshop_for(recipe_id)) < recipe_level_requirement(recipe_id):
		return false
	var materials: Dictionary = state.get("materials", {})
	var cost: Dictionary = effective_cost(state, recipe_id)
	return int(materials.get("herbs", 0)) >= int(cost.herbs) and int(materials.get("ore", 0)) >= int(cost.ore) and int(state.get("silver", 0)) >= int(cost.silver) and _has_specimens(state, cost.specimens)

static func apply(state: Dictionary, recipe_id: String) -> bool:
	if not can_craft(state, recipe_id):
		return false
	var cost: Dictionary = effective_cost(state, recipe_id)
	state.materials.herbs = int(state.materials.get("herbs", 0)) - int(cost.herbs)
	state.materials.ore = int(state.materials.get("ore", 0)) - int(cost.ore)
	state.silver = int(state.get("silver", 0)) - int(cost.silver)
	var specimens: Dictionary = cost.specimens
	for id in specimens:
		var field := _collection_field(id)
		if typeof(state.get(field, {})) != TYPE_DICTIONARY:
			state[field] = {}
		state[field][id] = int(state[field].get(id, 0)) - int(specimens[id])
	match recipe_id:
		"healing_powder":
			state.consumables.healing_powder = int(state.consumables.get("healing_powder", 0)) + 1
		"thunder_stone":
			state.consumables.thunder_stone = int(state.consumables.get("thunder_stone", 0)) + 1
		"insight_pill":
			state.insight = int(state.get("insight", 0)) + 1
		"strength_pill":
			state.strength = int(state.get("strength", 0)) + 1
		"agility_pill":
			state.agility = int(state.get("agility", 0)) + 1
		"constitution_pill":
			state.constitution = int(state.get("constitution", 0)) + 1
			state.max_hp = int(state.get("max_hp", 0)) + 3
			state.hp = mini(int(state.max_hp), int(state.get("hp", 0)) + 3)
		"vitality_pill":
			state.strength = int(state.get("strength", 0)) + 1
			state.agility = int(state.get("agility", 0)) + 1
			state.insight = int(state.get("insight", 0)) + 1
			state.constitution = int(state.get("constitution", 0)) + 1
			state.max_hp = int(state.get("max_hp", 0)) + 3
			state.hp = mini(int(state.max_hp), int(state.get("hp", 0)) + 3)
		"forged_iron_blade", "twin_edge_saber", "star_marrow_blade":
			EQUIPMENT_RULES.add_owned(state, "owned_weapons", recipe_id, 1)
			state.equipped_weapon = recipe_id
		"rattan_guard", "layered_iron_armor", "star_marrow_armor":
			EQUIPMENT_RULES.add_owned(state, "owned_armors", recipe_id, 1)
			state.equipped_armor = recipe_id
	var craft_key := _craft_count_key(workshop_for(recipe_id))
	state[craft_key] = int(state.get(craft_key, 0)) + 1
	return true

## 炼药坊 only deals in herbs -- its prompt line omits ore entirely. Generic
## 药材 and the named 药谱 specimens are both just backpack materials to the
## player, so they're shown together on one "材料" line (0.89.0), not split
## into a separate count and a separate collection line.
static func inventory_text_alchemy(state: Dictionary) -> String:
	return "炼药坊等级 Lv.%d/%d（累计炼制次数，越高解锁越高阶丹药）\n材料：药材 %d · %s\n银两 %d · 回春散 %d · 臂力 %d · 身法 %d · 悟性 %d · 根骨 %d" % [
		craft_level(state, "alchemy"), MAX_CRAFT_LEVEL,
		int(state.get("materials", {}).get("herbs", 0)), HERBARIUM_RULES.collection_text(state.get("herbarium", {})),
		int(state.get("silver", 0)), int(state.get("consumables", {}).get("healing_powder", 0)),
		int(state.get("strength", 0)), int(state.get("agility", 0)), int(state.get("insight", 0)), int(state.get("constitution", 0))
	]

## 锻造坊 only deals in ore -- its prompt line omits herbs entirely. Generic
## 矿石 and the named 矿谱 specimens are both just backpack materials to the
## player, so they're shown together on one "材料" line (0.89.0), not split
## into a separate count and a separate collection line. No longer mentions
## 霹雳石 (recipe removed) or 淬炼 (legacy forge_level stat, unrelated to any
## current recipe) -- 0.88.0.
static func inventory_text_forge(state: Dictionary) -> String:
	return "锻造坊等级 Lv.%d/%d（累计打造次数，越高解锁越高阶兵刃护具）\n材料：矿石 %d · %s\n银两 %d" % [
		craft_level(state, "forge"), MAX_CRAFT_LEVEL,
		int(state.get("materials", {}).get("ore", 0)), MINERALOGY_RULES.collection_text(state.get("mineralogy", {})),
		int(state.get("silver", 0))
	]
