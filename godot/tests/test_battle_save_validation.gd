extends SceneTree

const ENGINE := preload("res://scripts/battle/battle_engine.gd")

func _initialize() -> void:
	var state = load("res://autoload/game_state.gd").new()
	root.add_child(state)
	state.new_game()
	assert(state.start_blackreed_battle())
	var original: Dictionary = state.data.battle.duplicate(true)
	for actor in ["enemy:-1", "enemy:999", "enemy:oops", "enemy:0:1", "stranger", "ally"]:
		var invalid := original.duplicate(true)
		invalid.active_unit = actor
		assert(not state._valid_battle(invalid), "Invalid or missing actors must be rejected before the battle screen reads them.")
	var dead_enemy := original.duplicate(true)
	dead_enemy.active_unit = "enemy:0"
	dead_enemy.enemies[0].hp = 0
	assert(not state._valid_battle(dead_enemy))
	var enemy_turn := original.duplicate(true)
	enemy_turn.active_unit = "enemy:0"
	enemy_turn.action_points = 99
	assert(state._valid_battle(enemy_turn) and int(enemy_turn.action_points) == 0)
	var hero_turn := original.duplicate(true)
	hero_turn.erase("active_unit")
	hero_turn.action_points = 99
	assert(state._valid_battle(hero_turn) and str(hero_turn.active_unit) == "hero" and int(hero_turn.action_points) == 2, "Legacy hero saves should normalize without losing the battle.")
	for ally in [{}, {"hp": 0, "x": 1, "y": 2}]:
		var defeated := original.duplicate(true)
		defeated.active_unit = "ally"
		defeated.action_points = 2
		defeated.ally = ally
		var before := defeated.duplicate(true)
		var result := ENGINE.player_action(defeated, state.data, "move", Vector2i(0, 0))
		assert(not result.ok and defeated == before, "An absent or defeated companion must never spend an action or move.")
	print("Battle save validation tests passed.")
	quit()
