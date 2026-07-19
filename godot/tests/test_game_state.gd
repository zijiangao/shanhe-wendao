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
	assert(str(state.data.battle.objective.type) == "eliminate", "Legacy battles should default to an elimination objective.")
	assert(not state.data.battle_retry.is_empty(), "An in-progress legacy battle should gain a retry checkpoint.")

	state.new_game()
	state.data.energy = 3
	assert(state.start_blackreed_battle(), "The first tactical encounter should start.")
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
	assert(state.import_data(old_save), "Saves without onboarding fields should migrate.")
	assert(typeof(state.data.tutorial) == TYPE_DICTIONARY and state.data.tutorial.has("battle"), "Migration should add tutorial progress defaults.")

	state.new_game()
	state.data.energy = 3
	state.data.companions.append("lin_qingshuang")
	state.data.flags.append("su_trust")
	assert(state.start_final_battle(), "The final tactical encounter should start from a valid story state.")
	assert(str(state.data.battle.battle_id) == "wuku_finale", "The finale must use its own stable battle identifier.")
	assert(state.data.battle.has("ally") and state.data.battle.enemies.size() == 3, "The finale should include the companion and complete enemy squad.")
	state.finish_battle(true)
	assert("武库钥印" in state.data.items and int(state.data.xp) == 60, "Final victory rewards should be granted exactly once.")
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
