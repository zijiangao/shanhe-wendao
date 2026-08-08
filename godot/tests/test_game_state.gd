extends SceneTree

const SHOP_RULES := preload("res://scripts/progression/shop_rules.gd")
const WUXUE_RULES := preload("res://scripts/progression/wuxue_rules.gd")
const TRAINING_RULES := preload("res://scripts/progression/training_minigame_rules.gd")
const COMPANION_RULES := preload("res://scripts/progression/companion_rules.gd")

func _initialize() -> void:
	var state = load("res://autoload/game_state.gd").new()
	root.add_child(state)
	state.new_game()

	# The hero may take exactly one action per week -- spend_action() marks it
	# taken but does NOT itself advance the week; only the explicit end_week()
	# (the "结束本周" button) does that. This replaces the old energy pool.
	state.data.week = state.FINAL_WEEK - 1
	state.data.acted_this_week = false
	assert(state.spend_action(), "The final available week should still be actionable.")
	assert(not state.spend_action(), "A second action in the same week must be rejected.")
	assert(state.data.week == state.FINAL_WEEK - 1, "spend_action() alone must not advance the week.")
	assert(state.end_week(), "Ending the final available week should succeed.")
	assert(state.data.week == state.FINAL_WEEK and not bool(state.data.acted_this_week), "Ending the week should advance it and clear the acted flag.")
	assert(state.deadline_reached(), "The deadline should be reported at FINAL_WEEK.")
	assert(not state.spend_action(), "Actions must not be takeable beyond the deadline.")
	assert(not state.end_week(), "The week must not advance beyond the deadline.")

	# 调息 (rest) was removed entirely (0.101.0) -- ending the week now
	# automatically restores hp/qi to full instead, no dedicated action needed.
	state.new_game()
	state.data.week = 12
	state.data.hp = 1
	state.data.qi = 0
	assert(state.end_week(), "Ending the week should succeed.")
	assert(state.data.week == 13 and not bool(state.data.acted_this_week), "Ending the week should advance it by exactly one and clear the acted flag.")
	assert(int(state.data.hp) == int(state.data.max_hp) and int(state.data.qi) == 20, "Ending the week should automatically restore hp/qi to full.")

	# Traveling between cities is free (0.94.0) -- it never spends the
	# week's action, unlike training/gathering/crafting/battles, and stays
	# available even after the hero has already acted this week.
	state.new_game()
	state.data.acted_this_week = true
	assert(state.travel("luoyang"), "Traveling should succeed even after the week's action is already spent.")
	assert(str(state.data.location) == "luoyang" and bool(state.data.acted_this_week), "Travel must not clear or otherwise touch the acted flag.")
	assert(state.travel("qingyun"), "A second trip in the same week must also succeed -- travel has no per-week limit.")
	assert(str(state.data.location) == "qingyun", "Travel should freely move between locations any number of times per week.")
	state.data.week = state.FINAL_WEEK
	assert(not state.travel("luoyang"), "Travel must still be blocked once the two-year deadline is reached, same as every other action.")

	var future_save: Dictionary = state.data.duplicate(true)
	future_save.save_version = state.SAVE_VERSION + 1
	assert(not state.import_data(future_save), "Saves from newer versions must be rejected.")
	state.new_game()
	# 专精改为等级制、100级满 (0.105.0) -- an S-grade result grants 3 xp
	# toward the current level, not a direct +3 to the level itself. A fresh
	# level-0 swordsmanship needs 2 xp (TrainingMinigameRules.specialty_xp_needed(0)),
	# so 3 xp levels it up to 1 with 1 leftover xp.
	var training: Dictionary = state.complete_training("swordsmanship", 315, -1, 3)
	assert(training.grade == "S" and training.score == 315 and int(state.data.swordsmanship) == 1 and int(state.data.xp) == 15, "An S-grade combo result on its weekly focus should preserve all 315 points, grant the focus bonus, and level swordsmanship up via its xp curve.")
	assert(bool(training.weekly_focus) and int(training.weekly_focus_bonus) == 3, "The matching weekly discipline should expose its bonus in the result card.")
	assert(training.record.new_best and training.record.best_score == 315 and training.record.best_streak == 3 and state.data.training_records.swordsmanship.attempts == 1, "Training should persist its exact score, streak, and attempt count.")
	assert(state.end_week(), "Ending the week should free up next week's action for a repeat attempt.")
	var spent_week := int(state.data.week)
	var lower_training: Dictionary = state.complete_training("swordsmanship", 180, -1, 1)
	assert(not lower_training.record.new_best and lower_training.record.best_score == 315 and lower_training.record.attempts == 2, "A lower repeat must preserve the personal best while incrementing attempts.")
	assert(int(state.data.week) == spent_week and bool(state.data.acted_this_week), "A recorded repeat must still use up its own week's action without advancing the week by itself.")
	assert(not bool(lower_training.get("weekly_focus", false)), "The weekly focus should rotate after time advances instead of rewarding every repeat.")
	# 专精改为等级制、100级满 (0.105.0) -- 熟手/精通/大成门槛等比放大到30/60/100.
	# Seed the level just below a rank threshold with just enough leftover xp
	# that one S-grade training (3 xp) exactly crosses it, so the rank_up
	# still triggers deterministically in a single complete_training() call.
	state.new_game()
	state.data.herbalism = 59
	state.data.specialty_xp.herbalism = TRAINING_RULES.specialty_xp_needed(59) - 3
	var mastery_herbs: Dictionary = state.complete_training("herbalism", 300, 99, 3)
	assert(mastery_herbs.rank_up and mastery_herbs.specialty_rank == "精通" and int(state.data.herbalism) == 60, "Crossing level sixty should announce herbalism mastery.")
	assert(int(mastery_herbs.herbs) == 4 and int(state.data.materials.herbs) == 4, "Master herbalism should add one material to the normal score reward.")
	state.new_game()
	state.data.mining = 99
	state.data.specialty_xp.mining = TRAINING_RULES.specialty_xp_needed(99) - 3
	var mastery_mining: Dictionary = state.complete_training("mining", 300, 99, 3)
	assert(mastery_mining.rank_up and mastery_mining.specialty_rank == "大成" and int(state.data.mining) == 100, "Crossing level one hundred should announce mining mastery.")
	assert(int(mastery_mining.ore) == 5 and int(state.data.materials.ore) == 5, "Great mining mastery should add two materials to the normal score reward.")
	state.new_game()
	var event_training: Dictionary = state.complete_training("herbalism", 300, 0)
	assert(str(event_training.get("event", {}).get("id", "")) == "rare_herb", "A deterministic high-grade roll should attach its training encounter to the result.")
	assert(int(state.data.materials.herbs) == 5, "The normal three-herb reward and two bonus herbs must be committed together.")
	assert(int(state.data.herbarium.get("dewgrass", 0)) == 1 and str(event_training.herb_discovery.name) == "凝露草", "Herbalism training should persist its score-eligible field-guide discovery.")
	assert(bool(event_training.herb_discovery.first_discovery) and int(event_training.herb_discovery.xp) == 2 and int(state.data.xp) == 14, "A first specimen should grant cultivation exactly once alongside training rewards.")
	assert("training_s_grade" in state.data.flags and "training_event_seen" in state.data.flags, "Training milestones must persist for Steam achievement restoration.")
	assert(int(state.data.week) == 1 and bool(state.data.acted_this_week), "Training should use up this week's one action without advancing the week by itself.")
	assert(state.complete_training("mining", 300, 0).is_empty(), "A second training session in the same week must be rejected.")
	assert(state.end_week() and int(state.data.week) == 2 and not bool(state.data.acted_this_week), "Explicitly ending the week should advance it and free up next week's action.")
	state.new_game()
	var mining_training: Dictionary = state.complete_training("mining", 300, 0)
	assert(int(state.data.materials.ore) == 5 and int(state.data.mineralogy.get("ironstone", 0)) == 1, "Mining should commit normal ore, encounter ore, and a score-eligible mineral discovery together.")
	assert(str(mining_training.mineral_discovery.name) == "青铁石" and bool(mining_training.mineral_discovery.first_discovery), "The mining result should expose its newly recorded mineral.")
	assert(int(mining_training.mineral_discovery.silver) == 2 and int(state.data.silver) == 10014, "A first mineral appraisal should add its one-time silver bonus to normal mining income.")
	# Crafting now spends the week's one action too (0.92.0), same as
	# mining just did above -- each craft() below needs its own end_week().
	state.end_week()
	state.data.materials.herbs = 2
	assert(state.craft("healing_powder") and int(state.data.consumables.healing_powder) == 1, "GameState should expose medicine crafting through the saved inventory.")
	assert("crafted_healing_powder" in state.data.flags, "Medicine crafting must persist its Steam milestone.")
	assert(not state.craft("healing_powder"), "A second craft in the same week must be rejected even with enough materials left.")
	state.end_week()
	state.data.materials.ore = 7
	assert(state.craft("forged_iron_blade") and "tempered_blade" in state.data.flags, "Crafting a workshop weapon must persist the same Steam milestone tempering used to.")
	assert(not state.craft("thunder_stone"), "霹雳石 is no longer a craftable workshop recipe (0.88.0).")
	assert(SHOP_RULES.buy_good(state.data, "thunder_stone") and int(state.data.consumables.thunder_stone) == 1, "霹雳石 should still be purchasable at 西市's 杂货铺, just not forged.")
	var legacy_material_save: Dictionary = state.data.duplicate(true)
	legacy_material_save.save_version = 6
	legacy_material_save.erase("materials")
	legacy_material_save.erase("consumables")
	legacy_material_save.erase("herbarium")
	legacy_material_save.erase("mineralogy")
	legacy_material_save.erase("training_records")
	legacy_material_save.items.append("上品药材")
	assert(state.import_data(legacy_material_save), "Version five saves should migrate into the crafting inventory.")
	assert(int(state.data.materials.herbs) == 2 and "上品药材" not in state.data.items, "Legacy herb items should become two material units without polluting story items.")
	assert(typeof(state.data.herbarium) == TYPE_DICTIONARY and state.data.herbarium.is_empty(), "Version-six saves should gain an empty herbarium.")
	assert(typeof(state.data.mineralogy) == TYPE_DICTIONARY and state.data.mineralogy.is_empty(), "Older saves should gain an empty mineral ledger.")
	# 演武场新增拳掌/枪棍 (0.106.0) -- training_records 现在覆盖六项专精。
	assert(state.data.training_records.size() == 6 and state.data.training_records.swordsmanship.attempts == 0, "Older saves should gain normalized empty training records.")

	var damaged_save := {"save_version": 1, "week": -20, "acted_this_week": "not a bool", "max_hp": 0, "hp": -5, "location": "nowhere", "log": "invalid", "battle": {"width": 8}}
	assert(state.import_data(damaged_save), "Older saves should be migrated.")
	assert(state.data.week == 1 and state.data.acted_this_week == false, "Numeric save values should be clamped and a malformed acted_this_week should default safely to false.")
	assert(state.data.max_hp == 1 and state.data.hp == 1, "Health values should be normalized safely.")
	assert(state.data.location == "qingyun" and state.data.log.is_empty(), "Invalid location and log data should be repaired.")
	assert(state.data.battle.is_empty(), "Incomplete battle data should be discarded.")

	# 专精改为等级制、100级满 (0.105.0) -- a save whose specialty value somehow
	# exceeded the new cap (from before the cap existed) must be clamped down
	# on migration, and a malformed specialty_xp field must be repaired.
	var overleveled_save: Dictionary = state.data.duplicate(true)
	overleveled_save.swordsmanship = 500
	overleveled_save.specialty_xp = "not even a dictionary"
	assert(state.import_data(overleveled_save), "A save with an out-of-range specialty level must still load.")
	assert(int(state.data.swordsmanship) == TRAINING_RULES.MAX_SPECIALTY_LEVEL, "A specialty level beyond the new 100-level cap must be clamped down on migration.")
	assert(typeof(state.data.specialty_xp) == TYPE_DICTIONARY and int(state.data.specialty_xp.get("swordsmanship", -1)) == 0, "A malformed specialty_xp field must be repaired to a clean dictionary rather than crashing.")

	# 演武场新增拳掌/枪棍 (0.106.0) -- a save from before these fields existed
	# must migrate to level 0, not crash on a missing key.
	var pre_fist_staff_save: Dictionary = state.data.duplicate(true)
	pre_fist_staff_save.erase("fistsmanship")
	pre_fist_staff_save.erase("staffsmanship")
	assert(state.import_data(pre_fist_staff_save), "A save from before 拳掌/枪棍 existed must still load.")
	assert(int(state.data.fistsmanship) == 0 and int(state.data.staffsmanship) == 0, "Missing fistsmanship/staffsmanship fields must default to level 0 on migration.")

	# 客栈招募的随行弟子 (0.109.0) -- a stale active_disciple pointing at a
	# disciple no longer (or never) on the roster must be cleared, not left
	# dangling.
	var stale_disciple_save: Dictionary = state.data.duplicate(true)
	stale_disciple_save.companions = []
	stale_disciple_save.active_disciple = "zhou_mubai"
	assert(state.import_data(stale_disciple_save), "A save with a stale active_disciple must still load.")
	assert(str(state.data.active_disciple) == "", "An active_disciple not present in companions must be cleared on migration.")

	var legacy_battle_save: Dictionary = state.data.duplicate(true)
	legacy_battle_save.battle = {"width": 4, "height": 3, "player_x": 0, "player_y": 1, "ap": 2, "turn": 1, "blocked": [], "enemies": [{"name": "弓手喽啰", "hp": 10, "x": 3, "y": 1}]}
	assert(state.import_data(legacy_battle_save), "A structurally valid legacy battle should migrate.")
	assert(int(state.data.battle.enemies[0].range) == 4, "Legacy archer saves should recover their ranged attack distance.")
	assert(str(state.data.battle.enemies[0].role) == "archer", "Legacy archer saves should recover their tactical role.")
	assert(int(state.data.battle.enemies[0].exposure) == 0, "Legacy battles should initialize the exposure status safely.")
	assert(str(state.data.battle.objective.type) == "eliminate", "Legacy battles should default to an elimination objective.")
	assert(not state.data.battle_retry.is_empty(), "An in-progress legacy battle should gain a retry checkpoint.")

	state.new_game()
	var spar_stage := str(state.data.quest_stage)
	assert(state.start_qingyun_spar_battle(), "Qingyun sparring should be available as repeatable training.")
	assert(str(state.data.battle.battle_id) == "qingyun_spar" and state.data.battle.enemies.size() == 2, "Sparring should use its short two-opponent encounter.")
	assert(int(state.data.week) == 1 and bool(state.data.acted_this_week), "Sparring should use up this week's one action without advancing the week by itself.")
	assert(not state.data.battle.has("ally"), "A hero with no recruited disciple should spar solo, matching the pre-0.109.0 default.")
	state.finish_battle(true)
	assert(str(state.data.quest_stage) == spar_stage and "玄铁令" not in state.data.items and "villain_revealed" not in state.data.flags, "Optional sparring must not advance or contaminate the main story.")
	assert(str(state.data.pending_reward.battle_id) == "qingyun_spar" and int(state.data.xp) == 8, "An S-grade spar should combine its light base reward with the performance bonus.")
	assert(str(state.data.pending_reward.grade) == "S" and int(state.data.pending_reward.performance_xp) == 4 and state.data.pending_reward.new_best and int(state.data.sparring_record.best_turns) == 1, "A sparring victory should persist its grade, bonus, and first personal best.")
	# 专精改为等级制、100级满 (0.105.0) -- an S-grade spar grants 2 xp
	# (SparringRules.skill_gain_for_grade), which exactly meets a fresh
	# level-0 swordsmanship's 2-xp threshold and levels it up to 1.
	assert(str(state.data.pending_reward.discipline) == "swordsmanship" and int(state.data.swordsmanship) == 1, "The default S-grade sword spar should grant enough xp to level swordsmanship up once.")
	assert("spar_s_grade" in state.data.flags, "An S-grade spar should persist its Steam achievement milestone.")
	assert(state.claim_pending_reward("fellowship") and int(state.data.faction_relations.qingyun) == 2, "Sparring should add the selected reward to the starting Qingyun relationship.")

	# 客栈招募的随行弟子 (0.109.0) -- only ever accompanies 切磋, never the
	# story battles 林清霜 fights in, so start_huashan_trial_battle()/
	# start_final_battle() are deliberately not covered here for recruited
	# disciples, but 同伴换装备/换武学 (0.113.0) DOES also apply to 林清霜
	# in those two battles, covered separately below.
	state.new_game()
	state.data.silver = 1000
	assert(COMPANION_RULES.recruit(state.data, "zhou_mubai"), "A well-funded fresh save should be able to recruit at 客栈.")
	assert(state.start_qingyun_spar_battle(), "Sparring should still start normally once a disciple is recruited.")
	assert(str(state.data.battle.ally.name) == "周慕白", "A recruited disciple should accompany the hero into 切磋 as the battle ally.")

	# 同伴换装备/换武学 (0.113.0) -- gear/move chosen for 林清霜 must carry
	# into her hardcoded ally dict in the two story battles she fights in.
	state.new_game()
	state.data.owned_weapons = ["cold_crow_blade"]
	state.data.learned_moves = ["blade_technique"]
	assert(COMPANION_RULES.equip_companion_weapon(state.data, "lin_qingshuang", "cold_crow_blade"), "The hero should be able to gear up 林清霜 before the 华山 trial.")
	assert(COMPANION_RULES.equip_companion_move(state.data, "lin_qingshuang", "blade_technique"), "The hero should be able to pick 林清霜's dash move before the 华山 trial.")
	assert(state.start_huashan_trial_battle(), "The 华山 trial should still start normally with 林清霜 geared up.")
	assert(str(state.data.battle.ally.move_id) == "blade_technique", "林清霜's ally dict in the 华山 trial should carry her chosen move id.")
	assert(int(state.data.battle.ally.attack) == 7, "林清霜's base 5 attack plus 冷鸦刀's +2 bonus should total 7 in the 华山 trial.")

	state.new_game()
	state.data.investigations = ["archer", "herbs"]
	assert(state.start_blackreed_battle(), "The first tactical encounter should start.")
	assert(state.data.battle.enemies.size() == 4 and str(state.data.battle.enemies.back().role) == "duelist", "Encounter preparation should be applied before GameState captures the battle.")
	assert(int(state.data.battle.enemies[2].exposure) == 1, "Archer intelligence should carry into the live encounter.")
	state.data.battle.player_x = 2
	state.capture_battle_checkpoint()
	var checkpoint_week := int(state.data.week)
	var checkpoint_acted := bool(state.data.acted_this_week)
	var checkpoint_silver := int(state.data.silver)
	var checkpoint_log: Array = state.data.log.duplicate(true)
	state.data.skill_mastery.cloud = 99
	state.data.hp = 1
	state.finish_battle(false)
	assert(state.data.battle.is_empty(), "A defeat should leave the active battle.")
	assert(state.retry_last_battle(), "A defeated battle should be retryable from its checkpoint.")
	assert(int(state.data.battle.player_x) == 2, "Retry should restore the finalized encounter setup.")
	assert(int(state.data.week) == checkpoint_week and bool(state.data.acted_this_week) == checkpoint_acted, "Retry must not spend another week or a second action.")
	assert(int(state.data.silver) == checkpoint_silver, "Retry should restore pre-defeat currency.")
	assert(int(state.data.skill_mastery.cloud) == 0, "Retry must not allow mastery farming through deliberate defeats.")
	assert(state.data.log == checkpoint_log, "Retry should remove the abandoned defeat entry from the journal.")
	state.abandon_battle_retry()
	assert(state.data.battle_retry.is_empty(), "Accepting defeat should discard the retry checkpoint.")

	var old_save: Dictionary = state.data.duplicate(true)
	old_save.erase("tutorial")
	old_save.erase("battle_retry")
	old_save.erase("pending_reward")
	old_save.erase("sparring_record")
	assert(state.import_data(old_save), "Saves without onboarding fields should migrate.")
	assert(typeof(state.data.tutorial) == TYPE_DICTIONARY and state.data.tutorial.has("sparring") and state.data.tutorial.has("battle_tactics") and state.data.tutorial.has("battle_arts") and state.data.tutorial.has("battle_defense"), "Migration should add every current tutorial progress field.")
	assert(typeof(state.data.pending_reward) == TYPE_DICTIONARY and state.data.pending_reward.is_empty(), "Older saves should gain an empty pending reward safely.")
	assert(typeof(state.data.sparring_record) == TYPE_DICTIONARY and int(state.data.sparring_record.attempts) == 0, "Older saves should gain an empty sparring record safely.")

	var pre_shop_save: Dictionary = state.data.duplicate(true)
	pre_shop_save.erase("equipped_weapon")
	pre_shop_save.erase("equipped_armor")
	pre_shop_save.erase("owned_weapons")
	pre_shop_save.erase("owned_armors")
	assert(state.import_data(pre_shop_save), "Saves from before the shop system should still migrate.")
	assert(str(state.data.equipped_weapon) == "" and str(state.data.equipped_armor) == "", "A save with no equipment fields should default to bare-handed and unarmored.")
	assert(state.data.owned_weapons.is_empty() and state.data.owned_armors.is_empty(), "A save with no equipment fields should default to empty inventories.")

	var corrupted_equipment_save: Dictionary = state.data.duplicate(true)
	corrupted_equipment_save.owned_weapons = ["iron_sword", "a_deleted_weapon_id"]
	corrupted_equipment_save.equipped_weapon = "a_deleted_weapon_id"
	corrupted_equipment_save.owned_armors = "not even an array"
	corrupted_equipment_save.equipped_armor = "hedgehog_mail"
	assert(state.import_data(corrupted_equipment_save), "A save with stale or malformed equipment data must still load.")
	assert(state.data.owned_weapons == ["iron_sword"], "An unrecognized weapon id must be dropped from the owned list on migration.")
	assert(str(state.data.equipped_weapon) == "", "Equipping a weapon id that failed to migrate must fall back to bare-handed rather than crash or keep a dangling reference.")
	assert(typeof(state.data.owned_armors) == TYPE_ARRAY and state.data.owned_armors.is_empty(), "A non-array owned_armors field must be repaired to an empty list.")
	assert(str(state.data.equipped_armor) == "", "An armor id that is not actually owned (post-repair) must be cleared rather than trusted.")

	state.new_game()
	state.data.silver = 1000
	var power_before := int(state.power())
	assert(SHOP_RULES.buy_weapon(state.data, "dragon_etched_sword") and SHOP_RULES.buy_armor(state.data, "cold_jade_armor"), "A well-funded fresh save should be able to gear up at the shop.")
	assert(int(state.power()) == power_before + 6, "Equipping the top-tier sword (+3 attack) and armor (+3 defense) should raise reported combat power by exactly six.")

	var pre_wuxue_save: Dictionary = state.data.duplicate(true)
	pre_wuxue_save.erase("learned_moves")
	pre_wuxue_save.erase("learned_internal")
	pre_wuxue_save.erase("equipped_internal")
	pre_wuxue_save.erase("learned_lightness")
	pre_wuxue_save.erase("equipped_lightness")
	assert(state.import_data(pre_wuxue_save), "Saves from before the wuxue system should still migrate.")
	assert(state.data.learned_moves.is_empty(), "A save with no wuxue fields should default to no moves learned.")
	assert(str(state.data.equipped_internal) == "foundational_qi" and str(state.data.equipped_lightness) == "basic_footwork", "A save with no wuxue fields should retroactively gain and equip the baseline 基础内功/基础身法 (0.94.0), since every hero always secretly knew these.")

	var corrupted_wuxue_save: Dictionary = state.data.duplicate(true)
	corrupted_wuxue_save.learned_moves = ["stone_splitting_fist", "night_triple_blade", "a_deleted_move_id"]
	corrupted_wuxue_save.learned_internal = "not even an array"
	corrupted_wuxue_save.equipped_internal = "purple_mist_art"
	corrupted_wuxue_save.learned_lightness = ["ripple_steps"]
	corrupted_wuxue_save.equipped_lightness = "wind_walk"
	assert(state.import_data(corrupted_wuxue_save), "A save with stale or malformed wuxue data must still load.")
	assert(state.data.learned_moves == ["stone_splitting_fist", "night_triple_blade"], "An unrecognized move id must be dropped from the learned list on migration; no slot cap applies (0.104.0) so both real moves survive.")
	assert(typeof(state.data.learned_internal) == TYPE_ARRAY and state.data.learned_internal == ["foundational_qi"], "A non-array learned_internal field must be repaired to just the baseline 基础内功 (0.94.0), not left empty.")
	assert(str(state.data.equipped_internal) == "foundational_qi", "An internal art that is not actually learned (post-repair) must be cleared, then fall back to the baseline 基础内功 rather than staying blank.")
	assert(str(state.data.equipped_lightness) == "basic_footwork", "A lightness skill that was never learned must be cleared, then fall back to the baseline 基础身法 rather than staying blank.")

	var pre_leveling_save: Dictionary = state.data.duplicate(true)
	pre_leveling_save.erase("move_levels")
	pre_leveling_save.erase("internal_levels")
	pre_leveling_save.erase("lightness_levels")
	assert(state.import_data(pre_leveling_save), "Saves from before wuxue leveling existed must still migrate.")
	assert(state.data.move_levels.is_empty() and state.data.internal_levels.is_empty() and state.data.lightness_levels.is_empty(), "A save with no leveling fields should default to every learned manual sitting at the unleveled baseline.")

	var corrupted_leveling_save: Dictionary = state.data.duplicate(true)
	corrupted_leveling_save.move_levels = {"stone_splitting_fist": 999, "a_deleted_move_id": 5}
	corrupted_leveling_save.internal_levels = "not even a dictionary"
	corrupted_leveling_save.lightness_levels = {"ripple_steps": -3}
	assert(state.import_data(corrupted_leveling_save), "A save with out-of-range, orphaned, or malformed leveling data must still load.")
	assert(int(state.data.move_levels.get("stone_splitting_fist", 1)) == WUXUE_RULES.MAX_LEVEL, "An absurdly high level must be clamped down to the level cap, not trusted outright.")
	assert(not state.data.move_levels.has("a_deleted_move_id"), "A level entry for a move that isn't (or is no longer) actually learned must be dropped.")
	assert(typeof(state.data.internal_levels) == TYPE_DICTIONARY and state.data.internal_levels.is_empty(), "A non-dictionary internal_levels field must be repaired to an empty dictionary.")
	assert(int(state.data.lightness_levels.get("ripple_steps", 1)) == 1, "A negative level must be clamped up to the level-1 floor, not trusted outright.")

	var pre_training_save: Dictionary = state.data.duplicate(true)
	pre_training_save.erase("wuxue_xp")
	assert(state.import_data(pre_training_save), "Saves from before wuxue training (修炼) existed must still migrate.")
	assert(state.data.wuxue_xp.is_empty(), "A save with no wuxue_xp field should default to no accumulated training progress.")

	var corrupted_training_save: Dictionary = state.data.duplicate(true)
	corrupted_training_save.wuxue_xp = {"stone_splitting_fist": -5, "a_deleted_move_id": 20}
	assert(state.import_data(corrupted_training_save), "A save with negative or orphaned training xp must still load.")
	assert(int(state.data.wuxue_xp.get("stone_splitting_fist", 0)) == 0, "Negative training xp must be clamped up to zero, not trusted outright.")
	assert(not state.data.wuxue_xp.has("a_deleted_move_id"), "Training xp for a move that isn't (or is no longer) actually learned must be dropped.")

	state.new_game()
	state.data.silver = 1000
	var wuxue_power_before := int(state.power())
	assert(WUXUE_RULES.learn_move(state.data, "stone_splitting_fist") and WUXUE_RULES.learn_internal(state.data, "purple_mist_art") and WUXUE_RULES.learn_lightness(state.data, "ripple_steps"), "A well-funded fresh save should be able to learn one manual of each kind.")
	# Purple Mist Art (damage_bonus 2) replaces the baseline 基础内功
	# (damage_bonus 1, equipped by default since 0.94.0), so its net delta
	# is only +1 here, not its full +2 -- baseline lightness (基础身法)
	# grants no move bonus at all, so Ripple Steps' delta is unaffected.
	assert(int(state.power()) == wuxue_power_before + 6, "One equipped move (+3), Purple Mist Art's net damage delta over the baseline internal art (+1), and Ripple Steps' move bonus doubled (+2) should raise power by exactly six.")

	var power_before_leveling := int(state.power())
	assert(WUXUE_RULES.upgrade_move(state.data, "stone_splitting_fist"), "A well-funded hero should be able to level up a learned, equipped move.")
	assert(int(state.power()) == power_before_leveling + 1, "Leveling an equipped move from 1 to 2 should raise power by its one-point-per-level damage bonus.")

	# 修炼 (training): free but spends this week's one action, unlike the
	# instant silver-based upgrade above -- both feed the same underlying
	# level. The hero may take exactly one action per week now (no energy
	# pool); ending the week is a separate, explicit step (end_week()).
	state.new_game()
	state.data.silver = 1000
	assert(not state.can_train_wuxue("move", "stone_splitting_fist"), "A move that hasn't been learned yet must not be trainable.")
	assert(WUXUE_RULES.learn_move(state.data, "stone_splitting_fist"), "Learning the move should succeed with enough silver.")
	var week_before_training := int(state.data.week)
	var insight_bonus := int(WUXUE_RULES.insight_xp_bonus(state.data))
	var train_result: Dictionary = state.train_wuxue("move", "stone_splitting_fist", 15)
	assert(bool(train_result.ok) and not bool(train_result.leveled_up), "A modest, explicit xp roll should train successfully without leveling up yet.")
	assert(int(state.data.week) == week_before_training and bool(state.data.acted_this_week), "Training a wuxue skill should use up this week's one action without advancing the week by itself.")
	assert(WUXUE_RULES.wuxue_xp(state.data, "stone_splitting_fist") == 15 + insight_bonus, "The recorded xp should be the explicit roll plus the hero's insight-based training bonus, not the raw roll alone.")

	assert(not bool(state.train_wuxue("move", "stone_splitting_fist", 15).get("ok", false)), "A second action in the same week must be rejected, mirroring every other training action.")
	assert(WUXUE_RULES.wuxue_xp(state.data, "stone_splitting_fist") == 15 + insight_bonus, "A training attempt blocked because the week's action is already spent must not grant additional xp.")

	assert(state.end_week(), "Ending the week should free up next week's action.")
	assert(not bool(state.train_wuxue("move", "night_triple_blade", 15).get("ok", false)), "Training a move that was never learned must be rejected before any action is spent.")
	assert(not bool(state.data.acted_this_week), "Rejecting an invalid training target must not waste the week's action on nothing.")

	state.new_game()
	state.data.companions.append("lin_qingshuang")
	state.data.flags.append("su_trust")
	assert(state.start_final_battle(), "The final tactical encounter should start from a valid story state.")
	assert(str(state.data.battle.battle_id) == "wuku_finale", "The finale must use its own stable battle identifier.")
	assert(state.data.battle.has("ally") and state.data.battle.enemies.size() == 3, "The finale should include the companion and complete enemy squad.")
	state.finish_battle(true)
	assert("武库钥印" in state.data.items and int(state.data.xp) == 60, "Final victory rewards should be granted exactly once.")
	assert(str(state.data.pending_reward.battle_id) == "wuku_finale", "Victory should persist an unresolved reward choice.")
	assert(state.claim_pending_reward("temper"), "A pending reward should be claimable once.")
	assert(int(state.data.xp) == 80 and int(state.data.skill_mastery.cloud) == 2, "The selected reward should apply on top of base rewards.")
	assert(state.data.pending_reward.is_empty() and not state.claim_pending_reward("supplies"), "Claiming must clear the pending reward and prevent duplicate grants.")
	state.data.alignment.strategy = 2
	state.data.master_relation = 2
	state.data.faction_relations.huashan = 3
	state.data.faction_relations.emei = 3
	state.complete_game("preserve")
	assert(str(state.data.quest_stage) == "game_complete", "Resolving a legacy must mark the main story complete.")
	assert(str(state.data.ending.id) == "preserve" and str(state.data.ending.title) == "问道藏锋", "The chosen legacy should produce the matching ending.")
	assert(str(state.data.ending.rank) == "传说", "Strong relationships and timely completion should earn the top ending rank.")

	print("GameState tests passed.")
	quit()
