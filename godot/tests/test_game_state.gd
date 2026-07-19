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

	print("GameState tests passed.")
	quit()
