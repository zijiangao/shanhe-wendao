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
	assert(hero_options.slice(0, RULES.TASKS.size()).all(func(o): return bool(o[3])), "A pending assignment must block all competing tasks.")
	var spent_state := _hero_state()
	spent_state.acted_this_week = true
	assert(RULES.options_hero(spent_state).slice(0, RULES.TASKS.size()).all(func(o): return bool(o[3])), "A completed weekly action must disable assignment controls.")
	assert(RULES.options_hero(_hero_state()).slice(0, RULES.TASKS.size()).all(func(o): return not bool(o[3])), "A fresh week must enable all assignments.")
	assert(hero_options.size() == RULES.TASKS.size() + 1, "Every task plus one leave row should always be listed.")
	var train_row := hero_options.filter(func(o): return str(o[2]) == "assign_hero_train")
	assert(train_row.size() == 1 and bool(train_row[0][3]) and "已分派" in str(train_row[0][0]), "The currently-assigned task's row should be marked and disabled.")

	var companion_options_state := _hero_state()
	companion_options_state.companion_tasks = {"zhou_mubai": "gather"}
	var companion_stats := {"name": "周慕白", "level": 1, "strength": 5, "agility": 4, "insight": 4, "constitution": 5, "attack": 5}
	var companion_options: Array = RULES.options_companion(companion_options_state, "zhou_mubai", companion_stats)
	var gather_row := companion_options.filter(func(o): return str(o[2]) == "assign_companion_gather")
	assert(gather_row.size() == 1 and bool(gather_row[0][3]) and "当前职守" in str(gather_row[0][0]), "The companion's currently-assigned post should be marked as ongoing.")
	assert("总管" in str(gather_row[0][0]) and "药材" in str(gather_row[0][1]), "Companion options should use the 门派职守 titles and forecast text, not the old task labels.")
	var none_row := companion_options.filter(func(o): return str(o[0]) == "不任职守")
	assert(none_row.size() == 1 and not bool(none_row[0][3]), "The 'no post' row should stay enabled so the player can always cancel an assignment.")

	# 门派职守 (0.175.0) -- the post bonus only applies when the caller passes
	# a companion stat snapshot, so old call sites keep their exact old numbers.
	var post_earn_state := _hero_state()
	post_earn_state.companion_tasks = {"zhou_mubai": "earn"}
	var post_earn: Dictionary = RULES.resolve_companion(post_earn_state, "zhou_mubai", 5, 3, companion_stats)
	assert(int(post_earn.silver) == 18, "The base 赚钱 payout must stay 10 + attack + roll.")
	assert(int(post_earn.post_bonus.silver) == 5, "掌柜 should add 26% of the base payout at insight 4 (18 -> 5).")
	assert(int(post_earn_state.silver) == 100 + 18 + 5, "The post bonus must be credited to the same silver pool.")

	var post_gather_state := _hero_state()
	post_gather_state.companion_tasks = {"zhou_mubai": "gather"}
	var post_gather: Dictionary = RULES.resolve_companion(post_gather_state, "zhou_mubai", 5, 5, companion_stats)
	assert(int(post_gather_state.materials.herbs) == 3 and int(post_gather_state.materials.ore) == 3, "总管 should add +1 herb/+1 ore on top of the base 2/2 at roll 5.")

	var post_train_state := _hero_state()
	post_train_state.companion_tasks = {"zhou_mubai": "train"}
	var post_train: Dictionary = RULES.resolve_companion(post_train_state, "zhou_mubai", 5, 0, companion_stats)
	assert(int(post_train_state.xp) == 1, "传功长老 should grant 沈羽 +1 xp/week at insight 4.")
	assert(int(post_train.xp_gained) == RULES.COMPANION_TRAIN_XP, "The companion still receives their own 修炼 xp.")

	var envoy_state := _hero_state()
	envoy_state.companion_tasks = {"zhou_mubai": "envoy"}
	var envoy_result: Dictionary = RULES.resolve_companion(envoy_state, "zhou_mubai", 5, 0, companion_stats)
	assert(int(envoy_result.renown) == 1 and int(envoy_state.renown) == 1, "知客 at level 1 grants the base 1 renown, no extra yet.")
	var veteran_stats := companion_stats.duplicate(true)
	veteran_stats.level = 30
	var veteran_result: Dictionary = RULES.resolve_companion(envoy_state, "zhou_mubai", 5, 0, veteran_stats)
	assert(int(veteran_result.post_bonus.renown) == 1 and int(envoy_state.renown) == 3, "知客 at level 30 adds one extra renown on top of the base.")

	var hero_envoy_state := _hero_state()
	hero_envoy_state.weekly_task_hero = "envoy"
	var hero_envoy: Dictionary = RULES.resolve_hero(hero_envoy_state, 6)
	assert(int(hero_envoy.renown) == 2 and int(hero_envoy_state.renown) == 2, "沈羽's 游历 task should grant 1 + roll/6 renown.")

	var damaged := _hero_state()
	damaged.companion_growth = {"zhou_mubai": {"xp": -20, "level": 99, "strength": -4, "constitution": []}}
	assert(RULES.companion_level(damaged, "zhou_mubai") == 1)
	assert(RULES.companion_xp(damaged, "zhou_mubai") == 0)
	assert(RULES.companion_attack_growth(damaged, "zhou_mubai") == 0 and RULES.companion_hp_growth(damaged, "zhou_mubai") == 0)
	assert(RULES.grant_companion_xp(damaged, "zhou_mubai", 25) == 1)
	assert(RULES.companion_level(damaged, "zhou_mubai") == 2 and RULES.companion_attack_growth(damaged, "zhou_mubai") == 1)
	assert(RULES.grant_companion_xp(damaged, "zhou_mubai", 1) == 0, "Recovered growth must not repeatedly pay level rewards.")
	print("Weekly task rules tests passed.")
	quit()

func _hero_state() -> Dictionary:
	return {"silver": 100, "strength": 4, "insight": 4, "constitution": 4, "week": 1, "xp": 0, "materials": {"herbs": 0, "ore": 0}, "weekly_task_hero": "", "companion_tasks": {}, "companion_growth": {}}
