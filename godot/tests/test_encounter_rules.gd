extends SceneTree

const RULES := preload("res://scripts/battle/encounter_rules.gd")

func _initialize() -> void:
	_test_fully_prepared_route()
	_test_missing_secret_route_adds_patrol()
	_test_partial_preparation_is_explicit()
	print("EncounterRules tests passed.")
	quit()

func _test_fully_prepared_route() -> void:
	var battle := RULES.prepare_blackreed(_fixture(), ["secret_route", "archer", "herbs"])
	assert(int(battle.player_x) == 2, "The secret route should advance the hero's starting cell.")
	assert(battle.enemies.size() == 3, "The secret route should bypass the roaming duelist.")
	assert(int(battle.enemies[2].exposure) == 1, "Studying arrow marks should expose the archer.")
	assert(bool(battle.preparation.herbs), "Herb preparation should be recorded for presentation and saves.")
	assert("暗道前压" in str(battle.result) and "弓手破绽1" in str(battle.result), "Battle briefing should explain earned advantages.")

func _test_missing_secret_route_adds_patrol() -> void:
	var battle := RULES.prepare_blackreed(_fixture(), ["archer", "herbs"])
	assert(battle.enemies.size() == 4, "Skipping the secret route should add the roaming patrol.")
	var patrol: Dictionary = battle.enemies.back()
	assert(str(patrol.name) == "巡寨快刀" and str(patrol.role) == "duelist", "The reinforcement should use the fast duelist role.")
	assert(int(patrol.x) < int(battle.width) and int(patrol.y) < int(battle.height), "The patrol must spawn inside the board.")

func _test_partial_preparation_is_explicit() -> void:
	var battle := RULES.prepare_blackreed(_fixture(), ["secret_route", "herbs"])
	assert(not bool(battle.preparation.archer_spotted), "Unfound archer intelligence must remain explicit.")
	assert(not battle.enemies[2].has("exposure"), "The archer should not receive free exposure without its clue.")
	assert("金疮药整备" in str(battle.preparation.summary), "Optional supplies should appear in the preparation summary.")

func _fixture() -> Dictionary:
	return {
		"battle_id": "blackreed",
		"width": 8,
		"height": 6,
		"player_x": 1,
		"player_y": 3,
		"blocked": [[3, 1]],
		"enemies": [
			{"name": "黑苇寨主", "role": "brute", "hp": 34, "max_hp": 34, "attack": 7, "x": 6, "y": 2},
			{"name": "持刀喽啰", "role": "melee", "hp": 16, "max_hp": 16, "attack": 4, "x": 6, "y": 4},
			{"name": "弓手喽啰", "role": "archer", "hp": 13, "max_hp": 13, "attack": 4, "x": 5, "y": 0}
		]
	}
