extends SceneTree

const SHOP_RULES := preload("res://scripts/progression/shop_rules.gd")
const WUXUE_RULES := preload("res://scripts/progression/wuxue_rules.gd")

func _initialize() -> void:
	var state = load("res://autoload/game_state.gd").new()
	root.add_child(state)
	state.new_game()

	state.data.week = state.FINAL_WEEK - 1
	state.data.energy = 1
	assert(state.spend_week(), "The final available week should be spendable.")
	assert(state.data.week == state.FINAL_WEEK, "Spending the final week should reach the deadline.")
	assert(state.deadline_reached(), "The deadline should be reported at FINAL_WEEK.")
	assert(not state.spend_week(), "Actions must not spend time beyond the deadline.")
	assert(not state.rest(), "Rest must not restore energy beyond the deadline.")

	state.data.week = 12
	state.data.energy = 0
	assert(not state.spend_week(), "An action requires energy before the deadline.")
	assert(state.rest(), "Rest should work before the deadline.")
	assert(state.data.week == 13 and state.data.energy == 3, "Rest should advance one week and restore energy.")

	state.data.week = state.FINAL_WEEK - 1
	state.data.energy = 1
	assert(state.spend_week(), "A special story action should be able to spend the final week.")
	assert(not state.spend_week(), "A special story action must not bypass the deadline.")

	var future_save: Dictionary = state.data.duplicate(true)
	future_save.save_version = state.SAVE_VERSION + 1
	assert(not state.import_data(future_save), "Saves from newer versions must be rejected.")
	state.new_game()
	var training: Dictionary = state.complete_training("swordsmanship", 315, -1, 3)
	assert(training.grade == "S" and training.score == 315 and int(state.data.swordsmanship) == 3 and int(state.data.xp) == 15, "An S-grade combo result on its weekly focus should preserve all 315 points and grant the focus bonus.")
	assert(bool(training.weekly_focus) and int(training.weekly_focus_bonus) == 3, "The matching weekly discipline should expose its bonus in the result card.")
	assert(training.record.new_best and training.record.best_score == 315 and training.record.best_streak == 3 and state.data.training_records.swordsmanship.attempts == 1, "Training should persist its exact score, streak, and attempt count.")
	var spent_week := int(state.data.week)
	var lower_training: Dictionary = state.complete_training("swordsmanship", 180, -1, 1)
	assert(not lower_training.record.new_best and lower_training.record.best_score == 315 and lower_training.record.attempts == 2, "A lower repeat must preserve the personal best while incrementing attempts.")
	assert(int(state.data.week) == spent_week + 1, "A recorded repeat must still spend exactly one week.")
	assert(not bool(lower_training.get("weekly_focus", false)), "The weekly focus should rotate after time advances instead of rewarding every repeat.")
	state.new_game()
	state.data.herbalism = 5
	var mastery_herbs: Dictionary = state.complete_training("herbalism", 300, 99, 3)
	assert(mastery_herbs.rank_up and mastery_herbs.specialty_rank == "精通" and int(state.data.herbalism) == 8, "Crossing level six should announce herbalism mastery.")
	assert(int(mastery_herbs.herbs) == 4 and int(state.data.materials.herbs) == 4, "Master herbalism should add one material to the normal score reward.")
	state.new_game()
	state.data.mining = 8
	var mastery_mining: Dictionary = state.complete_training("mining", 300, 99, 3)
	assert(mastery_mining.rank_up and mastery_mining.specialty_rank == "大成" and int(state.data.mining) == 11, "Crossing level ten should announce mining mastery.")
	assert(int(mastery_mining.ore) == 5 and int(state.data.materials.ore) == 5, "Great mining mastery should add two materials to the normal score reward.")
	state.new_game()
	var event_training: Dictionary = state.complete_training("herbalism", 300, 0)
	assert(str(event_training.get("event", {}).get("id", "")) == "rare_herb", "A deterministic high-grade roll should attach its training encounter to the result.")
	assert(int(state.data.materials.herbs) == 5, "The normal three-herb reward and two bonus herbs must be committed together.")
	assert(int(state.data.herbarium.get("dewgrass", 0)) == 1 and str(event_training.herb_discovery.name) == "凝露草", "Herbalism training should persist its score-eligible field-guide discovery.")
	assert(bool(event_training.herb_discovery.first_discovery) and int(event_training.herb_discovery.xp) == 2 and int(state.data.xp) == 14, "A first specimen should grant cultivation exactly once alongside training rewards.")
	assert("training_s_grade" in state.data.flags and "training_event_seen" in state.data.flags, "Training milestones must persist for Steam achievement restoration.")
	assert(int(state.data.week) == 2 and int(state.data.energy) == 2, "Training should spend exactly one week and one energy.")
	state.new_game()
	var mining_training: Dictionary = state.complete_training("mining", 300, 0)
	assert(int(state.data.materials.ore) == 5 and int(state.data.mineralogy.get("ironstone", 0)) == 1, "Mining should commit normal ore, encounter ore, and a score-eligible mineral discovery together.")
	assert(str(mining_training.mineral_discovery.name) == "青铁石" and bool(mining_training.mineral_discovery.first_discovery), "The mining result should expose its newly recorded mineral.")
	assert(int(mining_training.mineral_discovery.silver) == 2 and int(state.data.silver) == 10014, "A first mineral appraisal should add its one-time silver bonus to normal mining income.")
	state.data.materials.herbs = 2
	assert(state.craft("healing_powder") and int(state.data.consumables.healing_powder) == 1, "GameState should expose medicine crafting through the saved inventory.")
	assert("crafted_healing_powder" in state.data.flags, "Medicine crafting must persist its Steam milestone.")
	state.data.materials.ore = 5
	state.data.silver = 8
	assert(state.craft("temper_blade") and "tempered_blade" in state.data.flags, "Weapon tempering must persist its Steam milestone.")
	assert(state.craft("thunder_stone") and int(state.data.consumables.thunder_stone) == 1 and "crafted_thunder_stone" in state.data.flags, "GameState should craft and persist the mining combat item milestone.")
	var legacy_material_save: Dictionary = state.data.duplicate(true)
	legacy_material_save.save_version = 6
	legacy_material_save.erase("materials")
	legacy_material_save.erase("consumables")
	legacy_material_save.erase("forge_level")
	legacy_material_save.erase("herbarium")
	legacy_material_save.erase("mineralogy")
	legacy_material_save.erase("training_records")
	legacy_material_save.items.append("上品药材")
	assert(state.import_data(legacy_material_save), "Version five saves should migrate into the crafting inventory.")
	assert(int(state.data.materials.herbs) == 2 and "上品药材" not in state.data.items, "Legacy herb items should become two material units without polluting story items.")
	assert(typeof(state.data.herbarium) == TYPE_DICTIONARY and state.data.herbarium.is_empty(), "Version-six saves should gain an empty herbarium.")
	assert(typeof(state.data.mineralogy) == TYPE_DICTIONARY and state.data.mineralogy.is_empty(), "Older saves should gain an empty mineral ledger.")
	assert(state.data.training_records.size() == 4 and state.data.training_records.swordsmanship.attempts == 0, "Older saves should gain normalized empty training records.")

	var damaged_save := {"save_version": 1, "week": -20, "energy": 99, "max_hp": 0, "hp": -5, "location": "nowhere", "log": "invalid", "battle": {"width": 8}}
	assert(state.import_data(damaged_save), "Older saves should be migrated.")
	assert(state.data.week == 1 and state.data.energy == 3, "Numeric save values should be clamped.")
	assert(state.data.max_hp == 1 and state.data.hp == 1, "Health values should be normalized safely.")
	assert(state.data.location == "qingyun" and state.data.log.is_empty(), "Invalid location and log data should be repaired.")
	assert(state.data.battle.is_empty(), "Incomplete battle data should be discarded.")

	var legacy_battle_save: Dictionary = state.data.duplicate(true)
	legacy_battle_save.battle = {"width": 4, "height": 3, "player_x": 0, "player_y": 1, "ap": 2, "turn": 1, "blocked": [], "enemies": [{"name": "弓手喽啰", "hp": 10, "x": 3, "y": 1}]}
	assert(state.import_data(legacy_battle_save), "A structurally valid legacy battle should migrate.")
	assert(int(state.data.battle.enemies[0].range) == 4, "Legacy archer saves should recover their ranged attack distance.")
	assert(str(state.data.battle.enemies[0].role) == "archer", "Legacy archer saves should recover their tactical role.")
	assert(int(state.data.battle.enemies[0].exposure) == 0, "Legacy battles should initialize the exposure status safely.")
	assert(str(state.data.battle.objective.type) == "eliminate", "Legacy battles should default to an elimination objective.")
	assert(not state.data.battle_retry.is_empty(), "An in-progress legacy battle should gain a retry checkpoint.")

	state.new_game()
	state.data.energy = 3
	var spar_stage := str(state.data.quest_stage)
	assert(state.start_qingyun_spar_battle(), "Qingyun sparring should be available as repeatable training.")
	assert(str(state.data.battle.battle_id) == "qingyun_spar" and state.data.battle.enemies.size() == 2, "Sparring should use its short two-opponent encounter.")
	assert(int(state.data.week) == 2 and int(state.data.energy) == 2, "Sparring should spend exactly one week and energy.")
	state.finish_battle(true)
	assert(str(state.data.quest_stage) == spar_stage and "玄铁令" not in state.data.items and "villain_revealed" not in state.data.flags, "Optional sparring must not advance or contaminate the main story.")
	assert(str(state.data.pending_reward.battle_id) == "qingyun_spar" and int(state.data.xp) == 8, "An S-grade spar should combine its light base reward with the performance bonus.")
	assert(str(state.data.pending_reward.grade) == "S" and int(state.data.pending_reward.performance_xp) == 4 and state.data.pending_reward.new_best and int(state.data.sparring_record.best_turns) == 1, "A sparring victory should persist its grade, bonus, and first personal best.")
	assert(str(state.data.pending_reward.discipline) == "swordsmanship" and int(state.data.swordsmanship) == 2, "The default S-grade sword spar should improve swordsmanship twice.")
	assert("spar_s_grade" in state.data.flags, "An S-grade spar should persist its Steam achievement milestone.")
	assert(state.claim_pending_reward("fellowship") and int(state.data.faction_relations.qingyun) == 2, "Sparring should add the selected reward to the starting Qingyun relationship.")

	state.new_game()
	state.data.energy = 3
	state.data.investigations = ["archer", "herbs"]
	assert(state.start_blackreed_battle(), "The first tactical encounter should start.")
	assert(state.data.battle.enemies.size() == 4 and str(state.data.battle.enemies.back().role) == "duelist", "Encounter preparation should be applied before GameState captures the battle.")
	assert(int(state.data.battle.enemies[2].exposure) == 1, "Archer intelligence should carry into the live encounter.")
	state.data.battle.player_x = 2
	state.capture_battle_checkpoint()
	var checkpoint_week := int(state.data.week)
	var checkpoint_energy := int(state.data.energy)
	var checkpoint_silver := int(state.data.silver)
	var checkpoint_log: Array = state.data.log.duplicate(true)
	state.data.skill_mastery.cloud = 99
	state.data.hp = 1
	state.finish_battle(false)
	assert(state.data.battle.is_empty(), "A defeat should leave the active battle.")
	assert(state.retry_last_battle(), "A defeated battle should be retryable from its checkpoint.")
	assert(int(state.data.battle.player_x) == 2, "Retry should restore the finalized encounter setup.")
	assert(int(state.data.week) == checkpoint_week and int(state.data.energy) == checkpoint_energy, "Retry must not spend another week or energy point.")
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
	pre_wuxue_save.erase("equipped_moves")
	pre_wuxue_save.erase("learned_internal")
	pre_wuxue_save.erase("equipped_internal")
	pre_wuxue_save.erase("learned_lightness")
	pre_wuxue_save.erase("equipped_lightness")
	assert(state.import_data(pre_wuxue_save), "Saves from before the wuxue system should still migrate.")
	assert(state.data.learned_moves.is_empty() and state.data.equipped_moves.is_empty(), "A save with no wuxue fields should default to no moves learned or equipped.")
	assert(str(state.data.equipped_internal) == "" and str(state.data.equipped_lightness) == "", "A save with no wuxue fields should default to no internal art or lightness skill equipped.")

	var corrupted_wuxue_save: Dictionary = state.data.duplicate(true)
	corrupted_wuxue_save.learned_moves = ["stone_splitting_fist", "a_deleted_move_id"]
	corrupted_wuxue_save.equipped_moves = ["stone_splitting_fist", "night_triple_blade", "a_deleted_move_id"]
	corrupted_wuxue_save.learned_internal = "not even an array"
	corrupted_wuxue_save.equipped_internal = "purple_mist_art"
	corrupted_wuxue_save.learned_lightness = ["ripple_steps"]
	corrupted_wuxue_save.equipped_lightness = "wind_walk"
	assert(state.import_data(corrupted_wuxue_save), "A save with stale or malformed wuxue data must still load.")
	assert(state.data.learned_moves == ["stone_splitting_fist"], "An unrecognized move id must be dropped from the learned list on migration.")
	assert(state.data.equipped_moves == ["stone_splitting_fist"], "equipped_moves must drop any id that is not (or no longer) actually learned.")
	assert(typeof(state.data.learned_internal) == TYPE_ARRAY and state.data.learned_internal.is_empty(), "A non-array learned_internal field must be repaired to an empty list.")
	assert(str(state.data.equipped_internal) == "", "An internal art that is not actually learned (post-repair) must be cleared rather than trusted.")
	assert(str(state.data.equipped_lightness) == "", "A lightness skill that was never learned must be cleared, even if it names a real catalog id.")

	var oversized_moves_save: Dictionary = state.data.duplicate(true)
	oversized_moves_save.learned_moves = ["stone_splitting_fist", "night_triple_blade"]
	oversized_moves_save.equipped_moves = ["stone_splitting_fist", "night_triple_blade", "stone_splitting_fist"]
	assert(state.import_data(oversized_moves_save), "A save whose equipped_moves list somehow grew past the slot cap must still load.")
	assert(Array(state.data.equipped_moves).size() == WUXUE_RULES.MAX_EQUIPPED_MOVES, "equipped_moves must be clamped to the two-slot cap on migration, however it got oversized.")

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

	state.new_game()
	state.data.silver = 1000
	var wuxue_power_before := int(state.power())
	assert(WUXUE_RULES.learn_move(state.data, "stone_splitting_fist") and WUXUE_RULES.learn_internal(state.data, "purple_mist_art") and WUXUE_RULES.learn_lightness(state.data, "ripple_steps"), "A well-funded fresh save should be able to learn one manual of each kind.")
	assert(int(state.power()) == wuxue_power_before + 7, "One equipped move (+3), Purple Mist Art's damage bonus (+2), and Ripple Steps' move bonus doubled (+2) should raise power by exactly seven.")

	var power_before_leveling := int(state.power())
	assert(WUXUE_RULES.upgrade_move(state.data, "stone_splitting_fist"), "A well-funded hero should be able to level up a learned, equipped move.")
	assert(int(state.power()) == power_before_leveling + 1, "Leveling an equipped move from 1 to 2 should raise power by its one-point-per-level damage bonus.")

	state.new_game()
	state.data.energy = 3
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
