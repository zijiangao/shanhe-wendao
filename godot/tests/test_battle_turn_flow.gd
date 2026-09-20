extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# This integration test writes autosaves. Run it in an isolated test project.
	assert(str(ProjectSettings.get_setting("application/config/name")).ends_with("-tests"), "Use an isolated test project to protect player saves.")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var state = root.get_node("GameState")
	state.new_game()
	state.data.agility = 5
	state.data.investigations = ["secret_route"]
	state.data.tutorial = {"map": true, "location": true, "battle": true, "battle_tactics": true}
	assert(state.start_blackreed_battle())
	assert(str(state.data.battle.active_unit) == "enemy:2", "The faster archer must win the opening turn.")
	var opening: Dictionary = state.data.battle.duplicate(true)
	await process_frame
	await process_frame
	assert(str(state.data.battle.active_unit) == "hero", "An enemy opening must automatically hand control back to the hero.")
	assert(int(state.data.battle.enemies[2].get("actions_taken", 0)) == 1, "The selected opening enemy must act exactly once, without being skipped.")
	assert(int(state.data.battle.action_points) == 2)
	var first_turn_titles: Array = main.find_children("*", "Label", true, false).filter(func(label: Label): return "第 1 回合" in label.text)
	assert(first_turn_titles.size() == 1, "The first playable hero turn must display round 1, not round 2.")

	# Loading a save with a pending enemy turn uses the same continuation path.
	state.data.battle = opening.duplicate(true)
	assert(root.get_node("SaveManager").save_auto())
	state.data.battle = {}
	assert(root.get_node("SaveManager").load_auto())
	main.screen = "battle"
	main._rebuild()
	await process_frame
	await process_frame
	assert(str(state.data.battle.active_unit) == "hero")
	assert(int(state.data.battle.enemies[2].get("actions_taken", 0)) == 1, "A loaded pending enemy must not lose or repeat its action.")

	main.enemy_turn_active = true
	var before: Dictionary = state.data.duplicate(true)
	var mode_before: String = main.battle_mode
	main._battle_mode_selected("brace")
	main._execute_player_action("brace")
	main._end_active_turn()
	assert(state.data == before and main.battle_mode == mode_before, "Input during enemy presentation must not mutate the battle.")
	main.enemy_turn_active = false

	# Autosaves taken immediately after spending the last AP must also resume.
	state.data.battle.action_points = 0
	state.data.battle.hero_gauge = 100
	for enemy in state.data.battle.enemies:
		enemy.gauge = 0
	var previous_turn := int(state.data.battle.turn)
	main.battle_mode = "frost_dash"
	main._rebuild()
	await process_frame
	await process_frame
	assert(int(state.data.battle.turn) == previous_turn + 1 and int(state.data.battle.action_points) == 2, "An exhausted saved player turn must advance exactly once.")
	assert(main.battle_mode == "move", "A new actor must not inherit the previous actor's exclusive skill selection.")
	print("Battle turn flow tests passed.")
	quit()
