extends SceneTree

const RULES := preload("res://scripts/progression/wuxue_rules.gd")

func _initialize() -> void:
	var state := _state()
	assert(int(RULES.internal_damage_bonus(state)) == 0 and int(RULES.internal_healing_bonus(state)) == 0 and int(RULES.lightness_move_bonus(state)) == 0, "An untrained hero should have zero wuxue bonuses.")

	assert(not RULES.learn_move(state, "stone_splitting_fist"), "150 silver should be unaffordable with only 100.")
	assert(int(state.silver) == 100 and state.learned_moves.is_empty(), "A failed manual purchase must not touch silver or the learned list.")

	state.silver = 1000
	assert(RULES.learn_move(state, "stone_splitting_fist"), "1000 silver should easily afford the cheaper move.")
	assert(int(state.silver) == 850 and "stone_splitting_fist" in Array(state.learned_moves) and "stone_splitting_fist" in Array(state.equipped_moves), "Learning a move with a free slot should charge its price and auto-equip it.")
	assert(not RULES.learn_move(state, "stone_splitting_fist"), "Learning an already-known move must be rejected, not double-charge.")

	assert(RULES.learn_move(state, "night_triple_blade"), "The second move should also be affordable and learnable.")
	assert(Array(state.equipped_moves).size() == RULES.MAX_EQUIPPED_MOVES, "Both moves should now be auto-equipped, filling the two-slot cap.")

	assert(RULES.unequip_move(state, "stone_splitting_fist"), "Unequipping a currently-equipped move should succeed.")
	assert(not ("stone_splitting_fist" in Array(state.equipped_moves)) and "stone_splitting_fist" in Array(state.learned_moves), "Unequipping must leave the move learned but no longer active.")
	assert(not RULES.unequip_move(state, "stone_splitting_fist"), "Unequipping a move that is already unequipped must fail.")
	assert(RULES.equip_move(state, "stone_splitting_fist"), "Re-equipping a learned move with a free slot should succeed.")
	assert(not RULES.equip_move(state, "stone_splitting_fist"), "Equipping an already-equipped move must fail.")
	assert(not RULES.equip_move(state, "wind_walk"), "Equipping a move id that belongs to a different category (lightness) must fail.")

	# Internal arts: learning auto-replaces, exactly like weapons/armor in ShopRules.
	var internal_state := _state()
	internal_state.silver = 1000
	assert(not RULES.equip_internal(internal_state, "purple_mist_art"), "Equipping an internal art that has not been learned must fail.")
	assert(RULES.learn_internal(internal_state, "purple_mist_art"), "Purple Mist Art should be learnable when affordable.")
	assert(int(RULES.internal_damage_bonus(internal_state)) == 2, "The equipped internal art should grant its damage bonus.")
	assert(str(internal_state.equipped_internal) == "purple_mist_art", "Learning an internal art should auto-equip it immediately.")
	assert(RULES.learn_internal(internal_state, "five_elements_art"), "A second internal art should be independently learnable.")
	assert(str(internal_state.equipped_internal) == "five_elements_art", "Learning a new internal art should replace the previously equipped one.")
	assert(int(RULES.internal_damage_bonus(internal_state)) == 0 and int(RULES.internal_healing_bonus(internal_state)) == 5, "Switching internal arts should switch which bonus applies.")
	assert(RULES.equip_internal(internal_state, "purple_mist_art"), "Re-equipping a previously learned internal art should succeed.")
	assert(int(RULES.internal_damage_bonus(internal_state)) == 2, "Re-equipping should restore that art's bonus.")
	assert(RULES.unequip_internal(internal_state, "purple_mist_art"), "Unequipping the active internal art should succeed.")
	assert(str(internal_state.equipped_internal) == "" and int(RULES.internal_damage_bonus(internal_state)) == 0, "Unequipping should zero out the bonus and clear the active slot.")
	assert(not RULES.unequip_internal(internal_state, "five_elements_art"), "Unequipping an art that is not currently active must fail.")

	# Lightness mirrors internal arts exactly.
	var lightness_state := _state()
	lightness_state.silver = 1000
	assert(RULES.learn_lightness(lightness_state, "ripple_steps"), "Ripple Steps should be learnable when affordable.")
	assert(int(RULES.lightness_move_bonus(lightness_state)) == 1, "The equipped lightness skill should grant its move bonus.")
	assert(RULES.learn_lightness(lightness_state, "wind_walk"), "A second lightness skill should be independently learnable.")
	assert(int(RULES.lightness_move_bonus(lightness_state)) == 2, "Learning a stronger lightness skill should replace the equipped one.")
	assert(RULES.equip_lightness(lightness_state, "ripple_steps"), "Switching back to a previously learned lightness skill should succeed.")
	assert(int(RULES.lightness_move_bonus(lightness_state)) == 1, "Switching lightness skills should switch the active bonus.")
	assert(not RULES.equip_lightness(lightness_state, "unknown_id"), "Equipping an unrecognized lightness id must fail.")

	# Leveling: moves cap at level 10, cost escalates per level, and the
	# per-level damage bonus only applies above the baseline level 1.
	var leveling_state := _state()
	leveling_state.silver = 5000
	RULES.learn_move(leveling_state, "stone_splitting_fist")
	assert(RULES.move_level(leveling_state, "stone_splitting_fist") == 1 and RULES.move_damage_bonus(leveling_state, "stone_splitting_fist") == 0, "A freshly learned move should start at level 1 with no level-up bonus yet.")
	assert(not RULES.upgrade_move(leveling_state, "night_triple_blade"), "Upgrading a move that hasn't been learned must fail.")
	var silver_before_upgrade := int(leveling_state.silver)
	assert(RULES.upgrade_move(leveling_state, "stone_splitting_fist"), "A well-funded hero should be able to upgrade a learned move.")
	assert(int(leveling_state.silver) == silver_before_upgrade - 60 and RULES.move_level(leveling_state, "stone_splitting_fist") == 2, "The first level-up should cost base(30) times the target level(2) and advance the level by one.")
	assert(RULES.move_damage_bonus(leveling_state, "stone_splitting_fist") == 1, "Level 2 should grant exactly one level's worth of bonus damage above the level-1 baseline.")
	for _i in range(8):
		assert(RULES.upgrade_move(leveling_state, "stone_splitting_fist"), "Nine total upgrades should reach the level cap from a well-funded state.")
	assert(RULES.move_level(leveling_state, "stone_splitting_fist") == RULES.MAX_LEVEL and RULES.move_damage_bonus(leveling_state, "stone_splitting_fist") == 9, "Reaching level 10 should grant nine level-ups' worth of bonus damage.")
	assert(not RULES.upgrade_move(leveling_state, "stone_splitting_fist"), "A move already at the level cap must not be upgradable further.")

	var poor_leveler := _state()
	poor_leveler.silver = 100
	RULES.learn_move(poor_leveler, "night_triple_blade")
	poor_leveler.silver = 10
	assert(not RULES.upgrade_move(poor_leveler, "night_triple_blade"), "Ten silver should be unaffordable for any move's first level-up.")
	assert(int(poor_leveler.silver) == 10 and RULES.move_level(poor_leveler, "night_triple_blade") == 1, "A failed level-up must not touch silver or the level.")

	# Internal arts and lightness skills level the same way; lightness's move
	# bonus only ticks up every three levels rather than every single one, to
	# keep the maximum move-range bonus sane on a small tactical board.
	var internal_leveling := _state()
	internal_leveling.silver = 5000
	RULES.learn_internal(internal_leveling, "purple_mist_art")
	assert(RULES.upgrade_internal(internal_leveling, "purple_mist_art"), "A learned internal art should be upgradable.")
	assert(int(RULES.internal_damage_bonus(internal_leveling)) == 3, "Purple Mist Art's damage bonus should rise from its base 2 to 3 after one level-up.")

	var lightness_leveling := _state()
	lightness_leveling.silver = 5000
	RULES.learn_lightness(lightness_leveling, "ripple_steps")
	assert(int(RULES.lightness_move_bonus(lightness_leveling)) == 1, "Ripple Steps should start at its base move bonus of 1.")
	for _i in range(3):
		assert(RULES.upgrade_lightness(lightness_leveling, "ripple_steps"), "Three affordable level-ups should succeed.")
	assert(RULES.lightness_level(lightness_leveling, "ripple_steps") == 4 and int(RULES.lightness_move_bonus(lightness_leveling)) == 2, "Every third level should add exactly one extra point of move range.")

	# A maxed-out entry's options row must read as full and stay disabled
	# rather than silently offering (and charging for) an impossible upgrade.
	var maxed_options: Array = RULES.options_manuals(leveling_state)
	var maxed_row := maxed_options.filter(func(o): return str(o[2]) == "upgrade_move_stone_splitting_fist")
	assert(maxed_row.size() == 1 and bool(maxed_row[0][3]) and "已满级" in str(maxed_row[0][0]), "A level-10 move's upgrade row should read as maxed and stay disabled.")

	# Training (修炼): a free but slow second path to the same levels as the
	# silver-based upgrade above. xp_needed(level) = 20*(level+1), so level 1
	# needs 40 xp to reach level 2.
	var training_state := _state()
	training_state.silver = 1000
	RULES.learn_move(training_state, "stone_splitting_fist")
	assert(not RULES.train_move(training_state, "night_triple_blade", 10).get("ok", false), "Training a move that hasn't been learned must fail.")
	var partial: Dictionary = RULES.train_move(training_state, "stone_splitting_fist", 15)
	assert(bool(partial.ok) and not bool(partial.leveled_up) and RULES.move_level(training_state, "stone_splitting_fist") == 1 and RULES.wuxue_xp(training_state, "stone_splitting_fist") == 15, "15 of the needed 40 xp should accumulate without leveling up yet.")
	var to_level_up: Dictionary = RULES.train_move(training_state, "stone_splitting_fist", 30)
	assert(bool(to_level_up.ok) and bool(to_level_up.leveled_up) and RULES.move_level(training_state, "stone_splitting_fist") == 2, "15+30=45 xp should cross the 40-xp threshold and advance to level 2.")
	assert(RULES.wuxue_xp(training_state, "stone_splitting_fist") == 5, "Leftover xp (45-40=5) should carry over into the new level rather than being discarded.")

	# A single huge training gain should be able to roll over multiple levels
	# in one session, not just the next one.
	var overflow_state := _state()
	overflow_state.silver = 1000
	RULES.learn_move(overflow_state, "night_triple_blade")
	var overflow: Dictionary = RULES.train_move(overflow_state, "night_triple_blade", 5000)
	assert(bool(overflow.leveled_up) and RULES.move_level(overflow_state, "night_triple_blade") == RULES.MAX_LEVEL, "An enormous xp gain should roll over every level at once, capping at level 10 rather than overshooting.")
	assert(RULES.wuxue_xp(overflow_state, "night_triple_blade") == 0, "Reaching the level cap should not leave leftover xp sitting unusable.")
	assert(not RULES.train_move(overflow_state, "night_triple_blade", 10).get("ok", false), "Training a move already at the level cap must be rejected.")

	# Internal arts and lightness skills train identically.
	var internal_training := _state()
	internal_training.silver = 1000
	RULES.learn_internal(internal_training, "purple_mist_art")
	assert(bool(RULES.train_internal(internal_training, "purple_mist_art", 40).get("leveled_up", false)) and RULES.internal_level(internal_training, "purple_mist_art") == 2, "Internal art training should level up the same way moves do.")
	var lightness_training := _state()
	lightness_training.silver = 1000
	RULES.learn_lightness(lightness_training, "ripple_steps")
	assert(bool(RULES.train_lightness(lightness_training, "ripple_steps", 40).get("leveled_up", false)) and RULES.lightness_level(lightness_training, "ripple_steps") == 2, "Lightness skill training should level up the same way moves do.")

	# The training sub-menu must show real progress and read as "已大成" once
	# a listed entry is maxed, rather than silently offering a no-op action.
	var training_options: Array = RULES.options_training(training_state)
	var stone_fist_row := training_options.filter(func(o): return str(o[2]) == "train_move_stone_splitting_fist")
	assert(stone_fist_row.size() == 1 and not bool(stone_fist_row[0][3]) and "5/60" in str(stone_fist_row[0][0]), "A mid-progress move's training row should show its current xp over the level-2 threshold (20*3=60) and stay enabled.")
	var maxed_training_options: Array = RULES.options_training(overflow_state)
	var maxed_training_row := maxed_training_options.filter(func(o): return str(o[2]) == "train_move_night_triple_blade")
	assert(maxed_training_row.size() == 1 and bool(maxed_training_row[0][3]) and "已大成" in str(maxed_training_row[0][0]), "A level-10 move's training row should read as maxed and stay disabled.")

	# 修炼's xp gain scales with 悟性 (insight), mirroring Flowing Cloud Sword's
	# existing "every 2 points of insight" convention.
	assert(RULES.insight_xp_bonus({"insight": 0}) == 0, "Zero insight should grant no training xp bonus.")
	assert(RULES.insight_xp_bonus({"insight": 4}) == 2, "The starting insight of 4 should grant a +2 training xp bonus.")
	assert(RULES.insight_xp_bonus({"insight": 7}) == 3, "Insight should round down to the nearest whole bonus point, not round up.")

	# options_manuals must reflect affordability and current learn/equip state for the choice-menu UI.
	var poor := _state()
	var poor_options: Array = RULES.options_manuals(poor)
	assert(poor_options.size() == RULES.MOVES.size() + RULES.INTERNAL.size() + RULES.LIGHTNESS.size() + 1, "Every catalog entry plus one leave row should always be listed.")
	for option in poor_options.slice(0, poor_options.size() - 1):
		assert(bool(option[3]), "Every unlearned entry should be disabled when the hero has no silver.")
	var leave_row: Array = poor_options.back()
	assert(str(leave_row[2]) == "leave" and not (leave_row.size() > 3 and bool(leave_row[3])), "Leaving the manuals shop must always stay enabled.")

	var rich := _state()
	rich.silver = 1000
	RULES.learn_move(rich, "stone_splitting_fist")
	var rich_options: Array = RULES.options_manuals(rich)
	var equipped_row := rich_options.filter(func(o): return str(o[2]) == "unequip_move_stone_splitting_fist")
	assert(equipped_row.size() == 1, "A learned-and-auto-equipped move should offer an unequip action, not a learn action.")

	print("Wuxue rules tests passed.")
	quit()

func _state() -> Dictionary:
	return {
		"silver": 100,
		"learned_moves": [], "equipped_moves": [],
		"learned_internal": [], "equipped_internal": "",
		"learned_lightness": [], "equipped_lightness": "",
	}
