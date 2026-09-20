extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(str(ProjectSettings.get_setting("application/config/name")).ends_with("-tests"), "Use isolated saves.")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var state = root.get_node("GameState")
	state.new_game()
	state.data.agility = 100
	state.data.hp = 100
	state.data.max_hp = 100
	for step in state.data.tutorial:
		state.data.tutorial[step] = true
	assert(state.start_blackreed_battle())
	var battle: Dictionary = state.data.battle
	battle.hero_gauge = 0
	for index in range(battle.enemies.size()):
		battle.enemies[index].gauge = 0
		if index != 0:
			battle.enemies[index].hp = 0
	battle.enemies[0].gauge = 100
	battle.enemies[0].x = int(battle.player_x) + 1
	battle.enemies[0].y = battle.player_y
	assert(root.get_node("SaveManager").save_auto())
	var saved_before := FileAccess.get_file_as_string("user://autosave.json")
	var paused = load("res://tests/fixtures/paused_enemy_view.gd").new()
	root.add_child(paused)
	main.active_battle_view = paused
	main._end_active_turn()
	assert(paused.waiting and main.enemy_turn_active, "The test must stop inside an actual enemy animation.")
	main._safe_quit()
	main._safe_quit()
	assert(main.quit_after_battle_turn, "Window close must queue until combat settlement is complete.")
	assert(FileAccess.get_file_as_string("user://autosave.json") == saved_before, "An in-flight animation must not overwrite the last consistent save.")
	paused.release_animation.emit()
	assert(not main.enemy_turn_active and not main.quit_after_battle_turn)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://autosave.json"))
	assert(int(saved.hp) < 100 and int(saved.hp) == int(state.data.hp), "The final quit save must include the enemy's damage.")
	assert(str(saved.battle.active_unit) == "hero" and int(saved.battle.action_points) == 2, "Reloading must not replay the enemy attack that already resolved.")
	paused.queue_free()
	print("Battle quit flow tests passed.")
	quit()
