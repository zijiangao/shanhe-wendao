extends SceneTree

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
	assert(training.grade == "S" and training.score == 315 and int(state.data.swordsmanship) == 3 and int(state.data.xp) == 12, "An S-grade combo result should preserve all 315 points and grant the full specialty reward.")
	assert(training.record.new_best and training.record.best_score == 315 and training.record.best_streak == 3 and state.data.training_records.swordsmanship.attempts == 1, "Training should persist its exact score, streak, and attempt count.")
	var spent_week := int(state.data.week)
	var lower_training: Dictionary = state.complete_training("swordsmanship", 180, -1, 1)
	assert(not lower_training.record.new_best and lower_training.record.best_score == 315 and lower_training.record.attempts == 2, "A lower repeat must preserve the personal best while incrementing attempts.")
	assert(int(state.data.week) == spent_week + 1, "A recorded repeat must still spend exactly one week.")
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
	assert(int(mining_training.mineral_discovery.silver) == 2 and int(state.data.silver) == 44, "A first mineral appraisal should add its one-time silver bonus to normal mining income.")
	state.data.materials.herbs = 2
	assert(state.craft("healing_powder") and int(state.data.consumables.healing_powder) == 1, "GameState should expose medicine crafting through the saved inventory.")
	assert("crafted_healing_powder" in state.data.flags, "Medicine crafting must persist its Steam milestone.")
	state.data.materials.ore = 3
	state.data.silver = 8
	assert(state.craft("temper_blade") and "tempered_blade" in state.data.flags, "Weapon tempering must persist its Steam milestone.")
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
	assert(state.import_data(old_save), "Saves without onboarding fields should migrate.")
	assert(typeof(state.data.tutorial) == TYPE_DICTIONARY and state.data.tutorial.has("battle_tactics"), "Migration should add every current tutorial progress field.")
	assert(typeof(state.data.pending_reward) == TYPE_DICTIONARY and state.data.pending_reward.is_empty(), "Older saves should gain an empty pending reward safely.")

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
