extends SceneTree

const RULES := preload("res://scripts/progression/crafting_rules.gd")

func _initialize() -> void:
	var state := _state()
	assert(RULES.can_craft(state, "healing_powder"), "Two herbs should enable a healing powder recipe.")
	assert(RULES.apply(state, "healing_powder"), "A valid medicine recipe should apply.")
	assert(int(state.materials.herbs) == 1 and int(state.consumables.healing_powder) == 1, "Medicine crafting should consume herbs and produce one combat item.")
	assert(RULES.apply(state, "temper_blade"), "Enough ore and silver should temper the weapon.")
	assert(int(state.materials.ore) == 0 and int(state.silver) == 12 and int(state.forge_level) == 1, "Tempering should consume its full cost and raise the permanent level.")
	state.materials.ore = 9
	state.silver = 50
	assert(RULES.apply(state, "temper_blade") and RULES.apply(state, "temper_blade"), "The weapon should support three total tempering levels.")
	assert(not RULES.can_craft(state, "temper_blade"), "Tempering must stop at the level cap.")
	assert(not RULES.apply(state, "invalid"), "Unknown recipes must never mutate state.")
	print("Crafting rules tests passed.")
	quit()

func _state() -> Dictionary:
	return {"materials": {"herbs": 3, "ore": 3}, "consumables": {"healing_powder": 0}, "silver": 20, "forge_level": 0}
