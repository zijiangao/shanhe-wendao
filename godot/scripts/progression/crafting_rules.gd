class_name CraftingRules
extends RefCounted

const TRAINING_RULES := preload("res://scripts/progression/training_minigame_rules.gd")

const MAX_FORGE_LEVEL := 3
const RECIPES := {
	"healing_powder": {
		"title": "炼制 · 回春散",
		"description": "药材 2 · 战斗中消耗1行动点，恢复气血。",
		"cost": {"herbs": 2, "ore": 0, "silver": 0}
	},
	"thunder_stone": {
		"title": "打造 · 霹雳石",
		"description": "矿石 2 · 战斗中消耗1行动点，直线投掷并削减护甲。",
		"cost": {"herbs": 0, "ore": 2, "silver": 0}
	},
	"temper_blade": {
		"title": "锻造 · 淬炼青锋",
		"description": "矿石 3 · 银两 8 · 永久提高武器伤害，最多三级。",
		"cost": {"herbs": 0, "ore": 3, "silver": 8}
	},
	"insight_pill": {
		"title": "炼制 · 悟性丹",
		"description": "药材 3 · 银两 15 · 服下后立即提升1点悟性，可反复炼制。",
		"cost": {"herbs": 3, "ore": 0, "silver": 15}
	}
}

static func options(state: Dictionary) -> Array:
	var forge_level := int(state.get("forge_level", 0))
	var temper_cost := effective_cost(state, "temper_blade")
	return [
		[RECIPES.healing_powder.title, "%s 当前携带 %d 份。" % [RECIPES.healing_powder.description, int(state.get("consumables", {}).get("healing_powder", 0))], "healing_powder", not can_craft(state, "healing_powder")],
		[RECIPES.thunder_stone.title, "%s 当前携带 %d 枚。" % [RECIPES.thunder_stone.description, int(state.get("consumables", {}).get("thunder_stone", 0))], "thunder_stone", not can_craft(state, "thunder_stone")],
		[RECIPES.temper_blade.title, "矿石 %d · 银两 %d%s · 永久提高武器伤害。当前淬炼 %d/%d。" % [int(temper_cost.ore), int(temper_cost.silver), "（挖矿大成减免）" if int(temper_cost.silver) < int(RECIPES.temper_blade.cost.silver) else "", forge_level, MAX_FORGE_LEVEL], "temper_blade", not can_craft(state, "temper_blade")],
		[RECIPES.insight_pill.title, "%s 当前悟性 %d。" % [RECIPES.insight_pill.description, int(state.get("insight", 0))], "insight_pill", not can_craft(state, "insight_pill")],
		["离开工坊", "不消耗材料，直接返回青云门。", "leave"]
	]

static func effective_cost(state: Dictionary, recipe_id: String) -> Dictionary:
	if not RECIPES.has(recipe_id):
		return {}
	var cost: Dictionary = (RECIPES[recipe_id].cost as Dictionary).duplicate(true)
	if recipe_id == "temper_blade":
		cost.silver = maxi(0, int(cost.silver) - TRAINING_RULES.tempering_silver_discount(int(state.get("mining", 0))))
	return cost

static func can_craft(state: Dictionary, recipe_id: String) -> bool:
	if not RECIPES.has(recipe_id):
		return false
	if recipe_id == "temper_blade" and int(state.get("forge_level", 0)) >= MAX_FORGE_LEVEL:
		return false
	var materials: Dictionary = state.get("materials", {})
	var cost: Dictionary = effective_cost(state, recipe_id)
	return int(materials.get("herbs", 0)) >= int(cost.herbs) and int(materials.get("ore", 0)) >= int(cost.ore) and int(state.get("silver", 0)) >= int(cost.silver)

static func apply(state: Dictionary, recipe_id: String) -> bool:
	if not can_craft(state, recipe_id):
		return false
	var cost: Dictionary = effective_cost(state, recipe_id)
	state.materials.herbs = int(state.materials.get("herbs", 0)) - int(cost.herbs)
	state.materials.ore = int(state.materials.get("ore", 0)) - int(cost.ore)
	state.silver = int(state.get("silver", 0)) - int(cost.silver)
	if recipe_id == "healing_powder":
		state.consumables.healing_powder = int(state.consumables.get("healing_powder", 0)) + 1
	elif recipe_id == "thunder_stone":
		state.consumables.thunder_stone = int(state.consumables.get("thunder_stone", 0)) + 1
	elif recipe_id == "insight_pill":
		state.insight = int(state.get("insight", 0)) + 1
	else:
		state.forge_level = int(state.get("forge_level", 0)) + 1
	return true

static func inventory_text(state: Dictionary) -> String:
	return "药材 %d · 矿石 %d · 银两 %d · 回春散 %d · 霹雳石 %d · 淬炼 %d/%d · 悟性 %d" % [
		int(state.get("materials", {}).get("herbs", 0)), int(state.get("materials", {}).get("ore", 0)),
		int(state.get("silver", 0)), int(state.get("consumables", {}).get("healing_powder", 0)),
		int(state.get("consumables", {}).get("thunder_stone", 0)),
		int(state.get("forge_level", 0)), MAX_FORGE_LEVEL, int(state.get("insight", 0))
	]
