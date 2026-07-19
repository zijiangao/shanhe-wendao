class_name CraftingRules
extends RefCounted

const MAX_FORGE_LEVEL := 3
const RECIPES := {
	"healing_powder": {
		"title": "炼制 · 回春散",
		"description": "药材 2 · 战斗中消耗1行动点，恢复气血。",
		"cost": {"herbs": 2, "ore": 0, "silver": 0}
	},
	"temper_blade": {
		"title": "锻造 · 淬炼青锋",
		"description": "矿石 3 · 银两 8 · 永久提高武器伤害，最多三级。",
		"cost": {"herbs": 0, "ore": 3, "silver": 8}
	}
}

static func options(state: Dictionary) -> Array:
	var forge_level := int(state.get("forge_level", 0))
	return [
		[RECIPES.healing_powder.title, "%s 当前携带 %d 份。" % [RECIPES.healing_powder.description, int(state.get("consumables", {}).get("healing_powder", 0))], "healing_powder", not can_craft(state, "healing_powder")],
		[RECIPES.temper_blade.title, "%s 当前淬炼 %d/%d。" % [RECIPES.temper_blade.description, forge_level, MAX_FORGE_LEVEL], "temper_blade", not can_craft(state, "temper_blade")]
	]

static func can_craft(state: Dictionary, recipe_id: String) -> bool:
	if not RECIPES.has(recipe_id):
		return false
	if recipe_id == "temper_blade" and int(state.get("forge_level", 0)) >= MAX_FORGE_LEVEL:
		return false
	var materials: Dictionary = state.get("materials", {})
	var cost: Dictionary = RECIPES[recipe_id].cost
	return int(materials.get("herbs", 0)) >= int(cost.herbs) and int(materials.get("ore", 0)) >= int(cost.ore) and int(state.get("silver", 0)) >= int(cost.silver)

static func apply(state: Dictionary, recipe_id: String) -> bool:
	if not can_craft(state, recipe_id):
		return false
	var cost: Dictionary = RECIPES[recipe_id].cost
	state.materials.herbs = int(state.materials.get("herbs", 0)) - int(cost.herbs)
	state.materials.ore = int(state.materials.get("ore", 0)) - int(cost.ore)
	state.silver = int(state.get("silver", 0)) - int(cost.silver)
	if recipe_id == "healing_powder":
		state.consumables.healing_powder = int(state.consumables.get("healing_powder", 0)) + 1
	else:
		state.forge_level = int(state.get("forge_level", 0)) + 1
	return true

static func inventory_text(state: Dictionary) -> String:
	return "药材 %d · 矿石 %d · 银两 %d · 回春散 %d · 淬炼 %d/%d" % [
		int(state.get("materials", {}).get("herbs", 0)), int(state.get("materials", {}).get("ore", 0)),
		int(state.get("silver", 0)), int(state.get("consumables", {}).get("healing_powder", 0)),
		int(state.get("forge_level", 0)), MAX_FORGE_LEVEL
	]
