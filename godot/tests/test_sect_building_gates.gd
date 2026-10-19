extends SceneTree

const TRAINING := preload("res://scripts/progression/training_minigame_rules.gd")
const WUXUE := preload("res://scripts/progression/wuxue_rules.gd")
const SECT := preload("res://scripts/progression/sect_building_rules.gd")

func _state(training_ground: int = 0, library: int = 0) -> Dictionary:
	return {
		"sect": {"buildings": {"training_ground": training_ground, "library": library, "herb_garden": 0, "forge": 0}},
		"swordsmanship": 0,
		"specialty_xp": {},
		"move_levels": {},
		"internal_levels": {},
		"lightness_levels": {},
		"wuxue_xp": {},
		"learned_moves": ["cloud_sword"],
		"learned_internal": ["foundational_qi"],
		"learned_lightness": ["basic_footwork"],
		"silver": 99999,
		"week": 0,
	}

func _initialize() -> void:
	# Minimal dictionaries (unit tests, old call sites) keep the old uncapped
	# behaviour -- only real saves with a sect dictionary are gated.
	assert(TRAINING.specialty_cap({}) == TRAINING.MAX_SPECIALTY_LEVEL)
	assert(WUXUE.mastery_cap({}) == WUXUE.MAX_LEVEL)

	# 演武场 Lv.0/1/2/3 -> 专精上限 29/59/99/100。
	for pair in [[0, 29], [1, 59], [2, 99], [3, 100]]:
		assert(TRAINING.specialty_cap(_state(int(pair[0]), 0)) == int(pair[1]), "training ground cap mapping")

	# 藏经阁 Lv.0/1/2/3 -> 武学上限 4/6/8/10。
	for pair in [[0, 4], [1, 6], [2, 8], [3, 10]]:
		assert(WUXUE.mastery_cap(_state(0, int(pair[0]))) == int(pair[1]), "library cap mapping")

	# 专精：在 Lv.0 上限 29 时会停在 29，并最多保留一级经验。
	var capped := _state(0, 0)
	var capped_result: Dictionary = TRAINING.train_specialty(capped, "swordsmanship", 5000)
	assert(int(capped_result.new_level) == 29 and bool(capped_result.capped), "specialty must stop at the training-ground cap.")
	assert(int(capped.specialty_xp.swordsmanship) <= TRAINING.specialty_xp_needed(29), "capped specialty xp must not stockpile more than one level.")

	# 祖父条款：旧档已 80 级、建筑 0 级时不能被压回去。
	var legacy := _state(0, 0)
	legacy.swordsmanship = 80
	var legacy_result: Dictionary = TRAINING.train_specialty(legacy, "swordsmanship", 100)
	assert(int(legacy_result.new_level) == 80 and int(legacy.swordsmanship) == 80, "existing specialty levels must be grandfathered.")
	assert(bool(legacy_result.capped), "a grandfathered level above the cap still reports capped.")

	# 升到演武场 Lv.1 后，之前积攒的一级经验应立刻兑现。
	capped.sect.buildings.training_ground = 1
	var unlock_result: Dictionary = TRAINING.train_specialty(capped, "swordsmanship", 1)
	assert(int(unlock_result.new_level) >= 30, "upgrading the training ground must let banked xp cross rank 30.")

	# 武学：藏经阁 Lv.0 时停在 4 级，升级被禁用；升到 Lv.1 后可继续。
	var wuxue_state := _state(0, 0)
	wuxue_state.move_levels = {"cloud_sword": 4}
	var train_result: Dictionary = WUXUE.train_move(wuxue_state, "cloud_sword", 500)
	assert(int(train_result.new_level) == 4 and bool(train_result.capped), "wuxue must stop at the library cap.")
	assert(not WUXUE.upgrade_move(wuxue_state, "cloud_sword"), "a capped art cannot be upgraded with silver.")
	var manual_row: Array = WUXUE._level_row(wuxue_state, "流云剑法", 4, 100, 99999, "upgrade_move_cloud_sword")
	assert(bool(manual_row[3]) and "需藏经阁" in str(manual_row[0]), "the manuals screen must explain the library lock.")
	wuxue_state.sect.buildings.library = 1
	assert(WUXUE.upgrade_move(wuxue_state, "cloud_sword"), "upgrading the library must unlock the next level.")
	assert(int(wuxue_state.move_levels.cloud_sword) == 5)

	# 建筑卡片本身要显示解锁内容，而不是只显示数值加成。
	assert("专精可突破 30" in SECT.unlock_text("training_ground", 1))
	assert("武学上限 6" in SECT.unlock_text("library", 1))
	var options: Array = SECT.options(_state(0, 0))
	var training_row := options.filter(func(row): return str(row[2]) == "upgrade_training_ground")
	assert(training_row.size() == 1 and "专精上限 29" in str(training_row[0][1]), "the construction card must show the current unlock.")
	assert(training_row[0][1].contains("专精可突破 30"), "the construction card must preview the next unlock.")

	print("Sect building gate tests passed.")
	quit()
