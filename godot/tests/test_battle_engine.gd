extends SceneTree

const ENGINE := preload("res://scripts/battle/battle_engine.gd")

func _initialize() -> void:
	_test_victory_detection()
	_test_player_move_and_attack()
	_test_player_skills_and_resources()
	_test_invalid_action_preserves_resources()
	_test_complete_battle_simulation()
	_test_ranged_enemy_attack_and_cover()
	_test_brute_heavy_attack()
	_test_duelist_fast_movement()
	_test_survival_objective()
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

func _test_player_move_and_attack() -> void:
	var battle := _fixture()
	battle.active_unit = "hero"
	battle.ap = 2
	var player := _player_fixture()
	var move: Dictionary = ENGINE.player_action(battle, player, "move", Vector2i(2, 1), _seeded_rng())
	assert(bool(move.ok) and Vector2i(int(battle.player_x), int(battle.player_y)) == Vector2i(2, 1), "A valid move should update the active unit position.")
	assert(int(battle.ap) == 1, "Moving should consume one action point.")
	battle.enemies[0].x = 3
	battle.enemies[0].y = 1
	battle.enemies[0].hp = 1
	var attack: Dictionary = ENGINE.player_action(battle, player, "attack", Vector2i(3, 1), _seeded_rng())
	assert(bool(attack.ok) and int(battle.enemies[0].hp) == 0, "A normal attack should damage and clamp enemy health to zero.")
	assert(int(battle.ap) == 0, "Attacking should consume one action point.")

func _test_player_skills_and_resources() -> void:
	var battle := _fixture()
	battle.active_unit = "hero"
	battle.ap = 2
	battle.enemies[0].x = 1
	battle.enemies[0].y = 4
	battle.ally.x = 0
	battle.ally.y = 3
	var player := _player_fixture()
	var cloud: Dictionary = ENGINE.player_action(battle, player, "skill", Vector2i(1, 4), _seeded_rng())
	assert(bool(cloud.ok) and int(player.qi) == 12, "Flowing Cloud Sword should consume eight qi.")
	assert(int(player.skill_mastery.cloud) == 1 and bool(battle.skill_flash), "Using a skill should increase mastery and trigger its visual state.")

	battle = _fixture()
	battle.active_unit = "ally"
	battle.ap = 2
	battle.ally.x = 2
	battle.ally.y = 1
	battle.enemies[0].x = 4
	battle.enemies[0].y = 1
	player = _player_fixture()
	var dash: Dictionary = ENGINE.player_action(battle, player, "frost_dash", Vector2i(4, 1), _seeded_rng())
	assert(bool(dash.ok) and int(battle.ally.qi) == 9, "Frost Dash should consume six ally qi.")
	assert(Vector2i(int(battle.ally.x), int(battle.ally.y)) == Vector2i(3, 1), "Frost Dash should stop beside its target.")
	assert(int(player.skill_mastery.frost) == 1, "Frost Dash should increase its mastery.")

	battle.ap = 1
	battle.ally.qi = 10
	var guard: Dictionary = ENGINE.player_action(battle, player, "frost_guard", Vector2i.ZERO, _seeded_rng())
	assert(bool(guard.ok) and int(battle.ally.guard) == 8 and int(battle.ally.qi) == 13, "Frost Guard should grant guard and restore qi.")
	assert(int(player.skill_mastery.frost_guard) == 1, "Frost Guard should increase its mastery.")

func _test_invalid_action_preserves_resources() -> void:
	var battle := _fixture()
	battle.active_unit = "hero"
	battle.ap = 2
	var player := _player_fixture()
	player.qi = 7
	var failed: Dictionary = ENGINE.player_action(battle, player, "skill", Vector2i(4, 1), _seeded_rng())
	assert(not bool(failed.ok), "An invalid skill target or insufficient qi should fail.")
	assert(int(battle.ap) == 2 and int(player.qi) == 7 and int(player.skill_mastery.cloud) == 0, "Failed actions must not consume resources or mastery.")

func _test_complete_battle_simulation() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.active_unit = "hero"
	battle.ap = 2
	battle.enemies[0].x = 2
	battle.enemies[0].y = 1
	var player := _player_fixture()
	var hero_hp := 20
	var rng := _seeded_rng()
	var rounds := 0
	while not ENGINE.is_victory(battle) and hero_hp > 0 and rounds < 5:
		var action: Dictionary = ENGINE.player_action(battle, player, "attack", Vector2i(2, 1), rng)
		assert(bool(action.ok), "The simulated player attack should be legal.")
		if ENGINE.is_victory(battle):
			break
		var enemy: Dictionary = ENGINE.enemy_turn(battle, hero_hp, rng)
		hero_hp = int(enemy.hero_hp)
		rounds += 1
	assert(ENGINE.is_victory(battle) and hero_hp > 0, "A complete battle should be simulatable without any UI nodes.")

func _test_ranged_enemy_attack_and_cover() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.enemies[0].x = 5
	battle.enemies[0].y = 1
	battle.enemies[0].range = 4
	var exposed: Dictionary = ENGINE.enemy_turn(battle, 20, _seeded_rng())
	assert(int(exposed.hero_hp) < 20, "A ranged enemy should damage a visible target without moving adjacent.")

	battle = _fixture()
	battle.erase("ally")
	battle.enemies[0].x = 5
	battle.enemies[0].y = 1
	battle.enemies[0].range = 4
	battle.blocked = [[3, 1]]
	var covered: Dictionary = ENGINE.enemy_turn(battle, 20, _seeded_rng())
	assert(int(covered.hero_hp) == 20, "Cover should prevent a ranged enemy from dealing damage.")
	assert(Vector2i(int(battle.enemies[0].x), int(battle.enemies[0].y)) != Vector2i(5, 1), "A ranged enemy without line of sight should reposition.")

func _test_brute_heavy_attack() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.turn = 2
	battle.enemies[0].role = "brute"
	battle.enemies[0].x = 2
	battle.enemies[0].y = 1
	var outcome: Dictionary = ENGINE.enemy_turn(battle, 30, _seeded_rng())
	assert(int(outcome.total_hurt) >= int(battle.enemies[0].attack) + 4, "Brutes should gain bonus damage on their telegraphed heavy turn.")
	assert("重击" in str(battle.result), "Heavy attacks should be reported in the battle log.")

func _test_duelist_fast_movement() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.enemies[0].role = "duelist"
	var outcome: Dictionary = ENGINE.enemy_turn(battle, 20, _seeded_rng())
	assert(int(outcome.hero_hp) == 20, "A distant duelist should move instead of attacking.")
	assert(Vector2i(int(battle.enemies[0].x), int(battle.enemies[0].y)) == Vector2i(2, 1), "Duelists should advance up to two cells per enemy turn.")

func _test_survival_objective() -> void:
	var battle := _fixture()
	battle.objective = {"type": "survive", "rounds": 2}
	assert(not ENGINE.is_victory(battle), "A survival objective should not complete before the required rounds.")
	assert("0/2" in ENGINE.objective_text(battle), "Objective text should show initial survival progress.")
	var first: Dictionary = ENGINE.enemy_turn(battle, 100, _seeded_rng())
	assert(not bool(first.hero_defeated) and not ENGINE.is_victory(battle), "Surviving one round should not complete a two-round objective.")
	var second: Dictionary = ENGINE.enemy_turn(battle, int(first.hero_hp), _seeded_rng())
	assert(not bool(second.hero_defeated) and ENGINE.is_victory(battle), "Surviving the required number of rounds should complete the objective with enemies alive.")
	assert("2/2" in ENGINE.objective_text(battle), "Objective text should show completed survival progress.")

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
		"ally": {"name": "林清霜", "hp": 30, "guard": 0, "qi": 15, "max_qi": 15, "attack": 5, "x": 1, "y": 3},
		"enemies": [{"name": "剑客", "role": "melee", "hp": 10, "attack": 8, "range": 1, "x": 4, "y": 1}]
	}

func _player_fixture() -> Dictionary:
	return {
		"strength": 4,
		"qi": 20,
		"skill_mastery": {"cloud": 0, "frost": 0, "frost_guard": 0}
	}
