extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var state := root.get_node("GameState")
	state.new_game()
	assert(main._screen_after_load() == "map")
	state.data.quest_stage = "final_choice"
	assert(main._screen_after_load() == "final_choice", "Loading must restore the unresolved finale choice.")
	state.data.pending_reward = {"battle_id": "wuku_finale"}
	assert(main._screen_after_load() == "victory", "Unclaimed victory rewards precede the finale choice.")
	state.data.pending_reward = {}
	state.complete_game("preserve")
	assert(main._screen_after_load() == "ending", "Completed journeys must return to their ending.")
	for modal in ["victory", "final_choice"]:
		main.screen = modal
		main._switch_screen("map")
		assert(main.screen == modal, "Header navigation must not discard unresolved story choices.")
		var week: int = state.data.week
		main._end_week_requested()
		assert(int(state.data.week) == week)
	print("Progression return flow tests passed.")
	quit()
