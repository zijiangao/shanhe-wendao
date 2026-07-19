extends SceneTree

const RULES := preload("res://scripts/progression/growth_rules.gd")

func _initialize() -> void:
	assert(RULES.rank_name(0) == "初窥门径" and RULES.combat_bonus(0) == 0, "New characters should begin at the first cultivation rank.")
	assert(RULES.rank_name(30) == "登堂入室" and RULES.combat_bonus(30) == 1, "Crossing a rank threshold should grant a combat bonus.")
	assert(RULES.next_rank_xp(29) == 30 and RULES.next_rank_xp(999) == -1, "Rank progress should expose the next threshold and cap cleanly.")
	var state := {"xp": 0, "strength": 4, "insight": 4, "constitution": 4, "max_hp": 45, "hp": 40}
	assert(RULES.apply_training(state, "constitution"), "A supported training focus should apply.")
	assert(int(state.constitution) == 5 and int(state.max_hp) == 48 and int(state.hp) == 43 and int(state.xp) == 12, "Constitution training should grant the complete previewed reward.")
	var unchanged := state.duplicate(true)
	assert(not RULES.apply_training(state, "invalid") and state == unchanged, "Invalid training choices must not mutate progression state.")
	print("Growth rules tests passed.")
	quit()

