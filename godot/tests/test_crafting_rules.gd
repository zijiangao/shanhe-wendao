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
	var apprentice := _state()
	apprentice.silver = 5
	assert(not RULES.can_craft(apprentice, "temper_blade"), "An apprentice miner should still need the full eight silver for tempering.")
	var master := _state()
	master.silver = 5
	master.mining = 10
	assert(RULES.effective_cost(master, "temper_blade").silver == 5 and RULES.can_craft(master, "temper_blade"), "Mining mastery should reduce the tempering silver cost from eight to five.")
	assert("挖矿大成减免" in str(RULES.options(master)[1][1]), "The workshop choice should disclose the mastery discount before crafting.")
	assert(RULES.apply(master, "temper_blade") and int(master.silver) == 0, "The discounted cost should be charged exactly once.")
	print("Crafting rules tests passed.")
	quit()

func _state() -> Dictionary:
	return {"materials": {"herbs": 3, "ore": 3}, "consumables": {"healing_powder": 0}, "silver": 20, "forge_level": 0, "mining": 0}
