extends SceneTree

const SECT_BUILDING_RULES := preload("res://scripts/progression/sect_building_rules.gd")

func _initialize() -> void:
	var state = load("res://autoload/game_state.gd").new()
	root.add_child(state)
	state.new_game()
	assert(int(state.data.sect.buildings.training_ground) == 0, "New games should start with all sect buildings at level zero.")
	assert(not SECT_BUILDING_RULES.can_upgrade(state.data, "training_ground"), "New games still need construction materials.")
	state.data.materials.herbs = 20
	state.data.materials.ore = 20
	assert(str(state.data.quest_stage) == "explore" and SECT_BUILDING_RULES.can_upgrade(state.data, "training_ground"), "Construction must be available before starting any story quest.")
	for option in SECT_BUILDING_RULES.options(state.data):
		assert("剧情推进" not in str(option[1]) and "第一章" not in str(option[1]), "Construction help must describe costs without chapter prerequisites.")
	var silver_before := int(state.data.silver)
	var upgrade: Dictionary = state.upgrade_sect_building("training_ground")
	assert(bool(upgrade.ok) and int(state.data.sect.buildings.training_ground) == 1, "A ready building should upgrade to level one before meeting the master.")
	assert(bool(state.data.acted_this_week) and int(state.data.silver) == silver_before - 300, "Construction should consume one weekly action and its silver cost.")
	assert(int(state.data.materials.herbs) == 19 and int(state.data.materials.ore) == 18, "Construction should consume its herb and ore costs.")
	assert(SECT_BUILDING_RULES.upgrade_block_reason(state.data, "library") == "本周已行动，结束本周后可升级", "A stocked but already-acted player must be told to end the week, not that materials are missing.")
	assert(not state.upgrade_sect_building("library").get("ok", false), "A second construction in the same week must be rejected.")
	assert(state.end_week(), "Ending the construction week should succeed.")
	assert(SECT_BUILDING_RULES.upgrade_block_reason(state.data, "library") == "", "After ending the week with enough resources, the next construction must have no blocking reason.")
	state.data.materials.herbs = 20
	state.data.materials.ore = 20
	var garden: Dictionary = state.upgrade_sect_building("herb_garden")
	assert(bool(garden.ok), "The herb garden should also be available before starting any story quest.")
	var herbs_before := int(state.data.materials.herbs)
	assert(state.end_week(), "Ending a week with a garden should succeed.")
	assert(int(state.data.materials.herbs) == herbs_before + 1, "A level-one herb garden should produce one herb each week.")
	var legacy: Dictionary = state.data.duplicate(true)
	legacy.erase("sect")
	assert(state.import_data(legacy), "A save from before sect construction should still load.")
	assert(int(state.data.sect.buildings.training_ground) == 0 and int(state.data.sect.buildings.herb_garden) == 0, "Old saves should migrate to empty sect buildings.")
	for id in SECT_BUILDING_RULES.BUILDING_IDS:
		state.new_game()
		state.data.materials.herbs = 100
		state.data.materials.ore = 100
		for next_level in range(1, SECT_BUILDING_RULES.MAX_LEVEL + 1):
			var cost: Dictionary = SECT_BUILDING_RULES.cost_for_next(state.data, id)
			assert(not cost.has("stage"), "Construction costs must not contain a story prerequisite.")
			assert(SECT_BUILDING_RULES.can_upgrade(state.data, id), "Every construction tier must be available with sufficient resources before starting the story.")
			var before: Dictionary = state.data.duplicate(true)
			var result: Dictionary = state.upgrade_sect_building(id)
			assert(bool(result.get("ok", false)) and SECT_BUILDING_RULES.level(state.data, id) == next_level, "Every building should reach levels one through three without quest progress.")
			assert(str(state.data.quest_stage) == "explore", "Construction must not start or advance story quests.")
			assert(int(state.data.silver) == int(before.silver) - int(cost.silver), "Each tier should deduct its silver cost.")
			assert(int(state.data.materials.herbs) == int(before.materials.herbs) - int(cost.herbs), "Each tier should deduct its herb cost.")
			assert(int(state.data.materials.ore) == int(before.materials.ore) - int(cost.ore), "Each tier should deduct its ore cost.")
			assert(state.end_week(), "Ending each construction week should succeed.")
		var maximum: Dictionary = state.data.duplicate(true)
		assert(not state.upgrade_sect_building(id).get("ok", false) and state.data == maximum, "Buildings at the maximum level must reject further upgrades without consuming resources or actions.")
	for resource in ["silver", "herbs", "ore"]:
		state.new_game()
		state.data.materials.herbs = 100
		state.data.materials.ore = 100
		var cost: Dictionary = SECT_BUILDING_RULES.cost_for_next(state.data, "training_ground")
		if resource == "silver":
			state.data.silver = int(cost.silver) - 1
		else:
			state.data.materials[resource] = int(cost[resource]) - 1
		var insufficient: Dictionary = state.data.duplicate(true)
		assert(not state.upgrade_sect_building("training_ground").get("ok", false) and state.data == insufficient, "Each missing resource must block construction without consuming other resources or the weekly action.")
	state.new_game()
	state.data.materials.herbs = 100
	state.data.materials.ore = 100
	state.data.week = state.FINAL_WEEK
	var deadline: Dictionary = state.data.duplicate(true)
	assert(not state.upgrade_sect_building("training_ground").get("ok", false) and state.data == deadline, "The two-year deadline must still reject construction without changing state.")
	assert(not SECT_BUILDING_RULES.can_upgrade(state.data, "unknown_building"), "Unknown buildings must still be rejected.")
	state.new_game()
	state.data.acted_this_week = false
	state.data.silver = 0
	state.data.materials = {"herbs": 100, "ore": 100}
	assert(SECT_BUILDING_RULES.upgrade_block_reason(state.data, "training_ground").begins_with("银两不足"), "A silver shortfall must be named explicitly.")
	state.data.silver = 1000
	state.data.materials = {"herbs": 0, "ore": 100}
	assert(SECT_BUILDING_RULES.upgrade_block_reason(state.data, "training_ground").begins_with("药材不足"), "A herb shortfall must be named explicitly.")
	state.data.materials = {"herbs": 100, "ore": 0}
	assert(SECT_BUILDING_RULES.upgrade_block_reason(state.data, "training_ground").begins_with("矿石不足"), "An ore shortfall must be named explicitly.")
	state.data.materials = {"herbs": 100, "ore": 100}
	state.data.week = state.FINAL_WEEK
	assert(SECT_BUILDING_RULES.upgrade_block_reason(state.data, "training_ground") == "两年期限已到", "The deadline must have its own reason.")
	state.data.week = 1
	state.data.sect.buildings.training_ground = SECT_BUILDING_RULES.MAX_LEVEL
	assert(SECT_BUILDING_RULES.upgrade_block_reason(state.data, "training_ground") == "已达最高等级", "A maxed building must report its cap, not a resource shortage.")
	print("PASS test_sect_building_rules")
	quit()
