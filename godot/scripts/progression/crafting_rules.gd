class_name CraftingRules
extends RefCounted

const TRAINING_RULES := preload("res://scripts/progression/training_minigame_rules.gd")
const HERBARIUM_RULES := preload("res://scripts/progression/herbarium_rules.gd")
const MINERALOGY_RULES := preload("res://scripts/progression/mineralogy_rules.gd")

const MAX_FORGE_LEVEL := 3
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
	"thunder_stone": {
		"title": "打造 · 霹雳石",
		"description": "矿石 2 · 战斗中消耗1行动点，直线投掷并削减护甲。",
		"cost": {"herbs": 0, "ore": 2, "silver": 0, "specimens": {}}
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
	}
}

## Workshop-crafted weapons/armor are a deliberately separate set from 西市's
## catalog (ShopRules.WEAPONS/ARMORS) -- same equip/owned/bonus machinery,
## reused via ShopRules' fallback lookup into these RECIPES entries, but a
## distinct item list acquired with materials instead of silver.
const CRAFTABLE_WEAPONS := ["forged_iron_blade", "twin_edge_saber"]
const CRAFTABLE_ARMORS := ["rattan_guard", "layered_iron_armor"]

## 炼药坊/锻造坊 split (0.84.0): alchemy covers every herb-based "炼制" recipe,
## forge covers every ore-based "打造" recipe -- this mirrors the verb the
## recipe titles already used before the split existed, not a new taxonomy.
const ALCHEMY_RECIPES := ["healing_powder", "insight_pill", "strength_pill", "agility_pill", "constitution_pill"]
const FORGE_RECIPES := ["thunder_stone", "forged_iron_blade", "twin_edge_saber", "rattan_guard", "layered_iron_armor"]

static func options_alchemy(state: Dictionary) -> Array:
	var options := [
		[RECIPES.healing_powder.title, "%s 当前携带 %d 份。" % [RECIPES.healing_powder.description, int(state.get("consumables", {}).get("healing_powder", 0))], "healing_powder", not can_craft(state, "healing_powder")],
		[RECIPES.insight_pill.title, "%s%s 当前悟性 %d。" % [RECIPES.insight_pill.description, _specimens_note(state, RECIPES.insight_pill.cost.specimens), int(state.get("insight", 0))], "insight_pill", not can_craft(state, "insight_pill")],
		[RECIPES.strength_pill.title, "%s 当前臂力 %d。" % [RECIPES.strength_pill.description, int(state.get("strength", 0))], "strength_pill", not can_craft(state, "strength_pill")],
		[RECIPES.agility_pill.title, "%s%s 当前身法 %d。" % [RECIPES.agility_pill.description, _specimens_note(state, RECIPES.agility_pill.cost.specimens), int(state.get("agility", 0))], "agility_pill", not can_craft(state, "agility_pill")],
		[RECIPES.constitution_pill.title, "%s%s 当前根骨 %d。" % [RECIPES.constitution_pill.description, _specimens_note(state, RECIPES.constitution_pill.cost.specimens), int(state.get("constitution", 0))], "constitution_pill", not can_craft(state, "constitution_pill")],
	]
	options.append(["离开炼药坊", "不消耗材料，直接返回青云门。", "leave"])
	return options

static func options_forge(state: Dictionary) -> Array:
	var options := [
		[RECIPES.thunder_stone.title, "%s 当前携带 %d 枚。" % [RECIPES.thunder_stone.description, int(state.get("consumables", {}).get("thunder_stone", 0))], "thunder_stone", not can_craft(state, "thunder_stone")],
	]
	for id in CRAFTABLE_WEAPONS:
		options.append(_gear_row(state, id, "owned_weapons"))
	for id in CRAFTABLE_ARMORS:
		options.append(_gear_row(state, id, "owned_armors"))
	options.append(["离开锻造坊", "不消耗材料，直接返回青云门。", "leave"])
	return options

static func _gear_row(state: Dictionary, id: String, owned_key: String) -> Array:
	var item: Dictionary = RECIPES[id]
	if id in Array(state.get(owned_key, [])):
		return ["%s · 已打造" % str(item.title), "%s（已拥有，前往背包装备）" % str(item.description), id, true]
	var cost: Dictionary = effective_cost(state, id)
	var discount_note := "（挖矿大成减免）" if int(cost.ore) < int(RECIPES[id].cost.ore) else ""
	return ["%s · 矿石%d%s" % [str(item.title), int(cost.ore), discount_note], "%s%s" % [str(item.description), _specimens_note(state, cost.specimens)], id, not can_craft(state, id)]

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
	if recipe_id in CRAFTABLE_WEAPONS and recipe_id in Array(state.get("owned_weapons", [])):
		return false
	if recipe_id in CRAFTABLE_ARMORS and recipe_id in Array(state.get("owned_armors", [])):
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
		"forged_iron_blade", "twin_edge_saber":
			state.owned_weapons.append(recipe_id)
			state.equipped_weapon = recipe_id
		"rattan_guard", "layered_iron_armor":
			state.owned_armors.append(recipe_id)
			state.equipped_armor = recipe_id
	return true

## 炼药坊 only deals in herbs -- its prompt line omits ore/矿谱 entirely.
static func inventory_text_alchemy(state: Dictionary) -> String:
	return "药材 %d · 银两 %d · 回春散 %d · 臂力 %d · 身法 %d · 悟性 %d · 根骨 %d\n药谱：%s" % [
		int(state.get("materials", {}).get("herbs", 0)), int(state.get("silver", 0)),
		int(state.get("consumables", {}).get("healing_powder", 0)),
		int(state.get("strength", 0)), int(state.get("agility", 0)), int(state.get("insight", 0)), int(state.get("constitution", 0)),
		HERBARIUM_RULES.collection_text(state.get("herbarium", {}))
	]

## 锻造坊 only deals in ore -- its prompt line omits herbs/药谱 entirely.
static func inventory_text_forge(state: Dictionary) -> String:
	return "矿石 %d · 银两 %d · 霹雳石 %d · 淬炼 %d/%d\n矿谱：%s" % [
		int(state.get("materials", {}).get("ore", 0)), int(state.get("silver", 0)),
		int(state.get("consumables", {}).get("thunder_stone", 0)),
		int(state.get("forge_level", 0)), MAX_FORGE_LEVEL,
		MINERALOGY_RULES.collection_text(state.get("mineralogy", {}))
	]
