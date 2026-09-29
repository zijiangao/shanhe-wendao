extends SceneTree

const SECT_BUILDING_RULES := preload("res://scripts/progression/sect_building_rules.gd")

func _initialize() -> void:
	var state = load("res://autoload/game_state.gd").new()
	root.add_child(state)
	state.new_game()
	assert(int(state.data.sect.buildings.training_ground) == 0, "New games should start with all sect buildings at level zero.")
	assert(not SECT_BUILDING_RULES.can_upgrade(state.data, "training_ground"), "The first construction tier must wait for chapter one completion.")
	state.data.quest_stage = "chapter_complete"
	state.data.materials.herbs = 20
	state.data.materials.ore = 20
	var silver_before := int(state.data.silver)
	var upgrade := state.upgrade_sect_building("training_ground")
	assert(bool(upgrade.ok) and int(state.data.sect.buildings.training_ground) == 1, "A ready building should upgrade to level one.")
	assert(bool(state.data.acted_this_week) and int(state.data.silver) == silver_before - 300, "Construction should consume one weekly action and its silver cost.")
	assert(not state.upgrade_sect_building("library").get("ok", false), "A second construction in the same week must be rejected.")
	assert(state.end_week(), "Ending the construction week should succeed.")
	state.data.materials.herbs = 20
	state.data.materials.ore = 20
	var garden := state.upgrade_sect_building("herb_garden")
	assert(bool(garden.ok), "The herb garden should share the first chapter unlock tier.")
	var herbs_before := int(state.data.materials.herbs)
	assert(state.end_week(), "Ending a week with a garden should succeed.")
	assert(int(state.data.materials.herbs) == herbs_before + 1, "A level-one herb garden should produce one herb each week.")
	var legacy := state.data.duplicate(true)
	legacy.erase("sect")
	assert(state.import_data(legacy), "A save from before sect construction should still load.")
	assert(int(state.data.sect.buildings.training_ground) == 0 and int(state.data.sect.buildings.herb_garden) == 0, "Old saves should migrate to empty sect buildings.")
	print("PASS test_sect_building_rules")
	quit()
