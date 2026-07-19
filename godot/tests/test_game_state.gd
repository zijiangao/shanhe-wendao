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

	print("GameState tests passed.")
	quit()
