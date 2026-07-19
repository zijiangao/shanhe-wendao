extends SceneTree

const ENGINE := preload("res://scripts/battle/battle_engine.gd")

func _initialize() -> void:
	_test_victory_detection()
	_test_enemy_movement_and_turn_reset()
	_test_guard_and_ally_knockout()
	_test_hero_defeat()
	print("BattleEngine tests passed.")
	quit()

func _test_victory_detection() -> void:
	var battle := _fixture()
	assert(not ENGINE.is_victory(battle), "A living enemy should prevent victory.")
	battle.enemies[0].hp = 0
	assert(ENGINE.is_victory(battle), "Defeating every enemy should produce victory.")

func _test_enemy_movement_and_turn_reset() -> void:
	var battle := _fixture()
	var outcome: Dictionary = ENGINE.enemy_turn(battle, 20, _seeded_rng())
	assert(int(outcome.hero_hp) == 20, "A distant enemy should move instead of damaging the hero.")
	assert(Vector2i(int(battle.enemies[0].x), int(battle.enemies[0].y)) == Vector2i(3, 1), "Enemies should advance one path step toward their target.")
	assert(int(battle.turn) == 2 and int(battle.ap) == 2 and str(battle.active_unit) == "hero", "A completed enemy turn should reset the player turn.")

func _test_guard_and_ally_knockout() -> void:
	var battle := _fixture()
	battle.ally = {"name": "林清霜", "hp": 1, "guard": 4, "x": 3, "y": 1}
	var outcome: Dictionary = ENGINE.enemy_turn(battle, 20, _seeded_rng())
	assert(bool(outcome.ally_defeated), "An ally reduced to zero health should be reported as knocked out.")
	assert(int(battle.ally.hp) == 0 and int(battle.ally.guard) == 0, "Guard should absorb damage before ally health and both should be clamped.")
	assert("倒地" in str(battle.result), "The combat log should clearly communicate an ally knockout.")
	assert(str(battle.active_unit) == "hero", "Control should return to the hero after an ally knockout.")

func _test_hero_defeat() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.enemies[0].x = 2
	battle.enemies[0].y = 1
	var outcome: Dictionary = ENGINE.enemy_turn(battle, 1, _seeded_rng())
	assert(bool(outcome.hero_defeated) and int(outcome.hero_hp) == 0, "Hero health should clamp to zero and report defeat.")
	assert(int(battle.turn) == 1, "A defeated hero should not begin another player turn.")

func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260719
	return rng

func _fixture() -> Dictionary:
	return {
		"width": 6,
		"height": 5,
		"player_x": 1,
		"player_y": 1,
		"active_unit": "ally",
		"ap": 0,
		"turn": 1,
		"blocked": [],
		"result": "",
		"ally": {"name": "林清霜", "hp": 30, "guard": 0, "x": 1, "y": 3},
		"enemies": [{"name": "剑客", "hp": 10, "attack": 8, "x": 4, "y": 1}]
	}
