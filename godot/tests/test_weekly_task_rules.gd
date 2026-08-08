extends SceneTree

const RULES := preload("res://scripts/progression/weekly_task_rules.gd")
const GROWTH_RULES := preload("res://scripts/progression/growth_rules.gd")

func _initialize() -> void:
	# resolve_hero() -- 赚钱
	var earn_state := _hero_state()
	earn_state.weekly_task_hero = "earn"
	var earn_result: Dictionary = RULES.resolve_hero(earn_state, 5)
	assert(str(earn_result.task) == "earn" and int(earn_result.silver) == 15 + 4 + 4 / 2 + 5, "赚钱 should charge a deterministic formula from strength/insight plus the injected roll.")
	assert(int(earn_state.silver) == 100 + int(earn_result.silver), "赚钱 should actually credit the computed silver to the save.")
	assert(str(earn_state.weekly_task_hero) == "", "Resolving should clear weekly_task_hero back to empty -- it's one-shot, not persistent.")

	# resolve_hero() -- 修炼 (delegates to GrowthRules.apply_training with a
	# week-rotating focus, mirroring the previously-unused GameState.train()).
	var train_state := _hero_state()
	train_state.weekly_task_hero = "train"
	train_state.week = 0
	var strength_before := int(train_state.strength)
	var xp_before := int(train_state.xp)
	var train_result: Dictionary = RULES.resolve_hero(train_state)
	assert(str(train_result.task) == "train" and str(train_result.focus) == "strength" and int(train_state.strength) == strength_before + 1 and int(train_state.xp) == xp_before + 12, "修炼 should apply the same +1 attribute and +12 xp that GrowthRules.apply_training() already grants elsewhere, using week 0's rotation slot (strength).")

	# resolve_hero() -- 采集
	var gather_state := _hero_state()
	gather_state.weekly_task_hero = "gather"
	var gather_result: Dictionary = RULES.resolve_hero(gather_state, 12)
	assert(int(gather_result.herbs) > 0 and int(gather_result.ore) > 0, "采集 should always yield at least some herbs and ore.")
	assert(int(gather_state.materials.herbs) == int(gather_result.herbs) and int(gather_state.materials.ore) == int(gather_result.ore), "采集 should actually credit the yield to the save's material pool.")

	# resolve_hero() -- no task assigned should be a safe no-op.
	var idle_state := _hero_state()
	assert(RULES.resolve_hero(idle_state).is_empty(), "A hero with no assigned task should resolve to nothing.")

	# resolve_companion() -- 赚钱/采集 mirror the hero's shape but scale off
	# the companion's own attack instead of 沈羽's strength/insight.
	var companion_state := _hero_state()
	companion_state.companion_tasks = {"zhou_mubai": "earn"}
	var companion_earn: Dictionary = RULES.resolve_companion(companion_state, "zhou_mubai", 5, 3)
	assert(int(companion_earn.silver) == 10 + 5 + 3, "Companion 赚钱 should scale off the companion's own attack stat, not 沈羽's.")
	assert(int(companion_state.silver) == 100 + int(companion_earn.silver), "Companion 赚钱 should credit silver to the same shared pool as the hero's.")

	# resolve_companion() -- 修炼 grants the companion's FIRST-EVER independent
	# leveling track (0.116.0), sharing GrowthRules' xp-per-level formula:
	# every COMPANION_TRAIN_XP grant nudges xp forward, and crossing a level
	# boundary bumps all four attributes (and hence attack/hp growth) by 1.
	var growth_state := _hero_state()
	growth_state.companion_tasks = {"zhou_mubai": "train"}
	var levels_needed := ceili(float(GROWTH_RULES.LEVEL_XP_STEP) / float(RULES.COMPANION_TRAIN_XP))
	for i in range(levels_needed):
		RULES.resolve_companion(growth_state, "zhou_mubai", 5)
	assert(RULES.companion_level(growth_state, "zhou_mubai") == 2, "Enough 修炼 grants should cross the first level boundary, mirroring GrowthRules.character_level().")
	assert(RULES.companion_attack_growth(growth_state, "zhou_mubai") == 1 and RULES.companion_hp_growth(growth_state, "zhou_mubai") == 3, "A level gained should add +1 to attack growth (from strength) and +3 to hp growth (from constitution), same shape as GrowthRules.grant_xp().")
	var repeat_result: Dictionary = RULES.resolve_companion(growth_state, "zhou_mubai", 5)
	assert(int(repeat_result.xp_gained) == RULES.COMPANION_TRAIN_XP, "修炼 should keep granting the same xp amount indefinitely -- no cap, unlike the old attack_bonus mechanic it replaced.")

	# options_hero()/options_companion() must reflect current assignment for the choice-menu UI.
	var options_state := _hero_state()
	options_state.weekly_task_hero = "train"
	var hero_options: Array = RULES.options_hero(options_state)
	assert(hero_options.size() == RULES.TASKS.size() + 1, "Every task plus one leave row should always be listed.")
	var train_row := hero_options.filter(func(o): return str(o[2]) == "assign_hero_train")
	assert(train_row.size() == 1 and bool(train_row[0][3]) and "已分派" in str(train_row[0][0]), "The currently-assigned task's row should be marked and disabled.")

	var companion_options_state := _hero_state()
	companion_options_state.companion_tasks = {"zhou_mubai": "gather"}
	var companion_options: Array = RULES.options_companion(companion_options_state, "zhou_mubai")
	var gather_row := companion_options.filter(func(o): return str(o[2]) == "assign_companion_gather")
	assert(gather_row.size() == 1 and bool(gather_row[0][3]) and "持续进行中" in str(gather_row[0][0]), "The companion's currently-assigned task should be marked as ongoing.")
	var none_row := companion_options.filter(func(o): return str(o[0]) == "不分派任务")
	assert(none_row.size() == 1 and not bool(none_row[0][3]), "The 'no task' row should stay enabled so the player can always cancel an assignment.")

	print("Weekly task rules tests passed.")
	quit()

func _hero_state() -> Dictionary:
	return {"silver": 100, "strength": 4, "insight": 4, "constitution": 4, "week": 1, "xp": 0, "materials": {"herbs": 0, "ore": 0}, "weekly_task_hero": "", "companion_tasks": {}, "companion_growth": {}}
