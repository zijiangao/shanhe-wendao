extends SceneTree

const ENGINE := preload("res://scripts/battle/battle_engine.gd")

func _initialize() -> void:
	_test_victory_detection()
	_test_player_move_and_attack()
	_test_player_skills_and_resources()
	_test_healing_powder()
	_test_cultivation_damage_bonus()
	_test_specialty_damage_bonus()
	_test_specialty_mastery_perks()
	_test_armor_and_exposure_combo()
	_test_invalid_action_preserves_resources()
	_test_complete_battle_simulation()
	_test_ranged_enemy_attack_and_cover()
	_test_archer_aimed_shot()
	_test_brute_heavy_attack()
	_test_boss_phase_and_sweep()
	_test_duelist_fast_movement()
	_test_survival_objective()
	_test_enemy_movement_and_turn_reset()
	_test_guard_and_ally_knockout()
	_test_multi_target_feedback()
	_test_enemy_event_sequence()
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
	assert(bool(battle.skill_flash) and str(battle.skill_name) == "霜 华 刺", "Frost Dash should expose its own presentation title.")

	battle.ap = 1
	battle.ally.qi = 10
	var guard: Dictionary = ENGINE.player_action(battle, player, "frost_guard", Vector2i.ZERO, _seeded_rng())
	assert(bool(guard.ok) and int(battle.ally.guard) == 8 and int(battle.ally.qi) == 13, "Frost Guard should grant guard and restore qi.")
	assert(int(player.skill_mastery.frost_guard) == 1, "Frost Guard should increase its mastery.")
	assert(bool(battle.skill_flash) and str(battle.skill_name) == "寒 锋 守 势", "Frost Guard should expose its own presentation title.")

func _test_healing_powder() -> void:
	var battle := _fixture()
	battle.active_unit = "hero"
	battle.ap = 2
	var player := _player_fixture()
	player.hp = 20
	player.max_hp = 45
	player.herbalism = 4
	player.consumables = {"healing_powder": 1}
	var result: Dictionary = ENGINE.player_action(battle, player, "heal")
	assert(bool(result.ok) and int(result.healed) == 14 and int(player.hp) == 34, "Herbalism should improve the healing powder's battle recovery.")
	assert(int(player.consumables.healing_powder) == 0 and int(battle.ap) == 1, "Healing should consume one item and one action point.")
	var failed: Dictionary = ENGINE.player_action(battle, player, "heal")
	assert(not bool(failed.ok) and int(battle.ap) == 1, "Using a missing healing powder must preserve action points.")

func _test_cultivation_damage_bonus() -> void:
	var low_battle := _fixture()
	low_battle.active_unit = "hero"
	low_battle.ap = 2
	low_battle.enemies[0].x = 1
	low_battle.enemies[0].y = 4
	low_battle.ally.x = 0
	low_battle.ally.y = 3
	low_battle.enemies[0].hp = 100
	var high_battle: Dictionary = low_battle.duplicate(true)
	var low_player := _player_fixture()
	var high_player: Dictionary = low_player.duplicate(true)
	high_player.insight = 6
	high_player.xp = 70
	var low: Dictionary = ENGINE.player_action(low_battle, low_player, "skill", Vector2i(1, 4), _seeded_rng())
	var high: Dictionary = ENGINE.player_action(high_battle, high_player, "skill", Vector2i(1, 4), _seeded_rng())
	assert(int(high.damage) == int(low.damage) + 3, "Insight and cultivation rank bonuses should deterministically increase Flowing Cloud Sword damage.")

func _test_specialty_damage_bonus() -> void:
	var sword_battle := _fixture()
	sword_battle.active_unit = "hero"
	sword_battle.ap = 2
	sword_battle.enemies[0].x = 1
	sword_battle.enemies[0].y = 4
	sword_battle.ally.x = 0
	sword_battle.ally.y = 3
	sword_battle.enemies[0].hp = 100
	var trained := _player_fixture()
	trained.swordsmanship = 6
	var baseline := _player_fixture()
	var trained_result: Dictionary = ENGINE.player_action(sword_battle, trained, "skill", Vector2i(1, 4), _seeded_rng())
	var plain_battle: Dictionary = _fixture()
	plain_battle.active_unit = "hero"
	plain_battle.ap = 2
	plain_battle.enemies[0].x = 1
	plain_battle.enemies[0].y = 4
	plain_battle.ally.x = 0
	plain_battle.ally.y = 3
	plain_battle.enemies[0].hp = 100
	var plain_result: Dictionary = ENGINE.player_action(plain_battle, baseline, "skill", Vector2i(1, 4), _seeded_rng())
	assert(bool(trained_result.get("ok", false)) and bool(plain_result.get("ok", false)), "Specialty damage comparison requires two legal sword attacks.")
	assert(int(trained_result.damage) == int(plain_result.damage) + 3, "Swordsmanship should increase sword skill damage every two levels.")

func _test_specialty_mastery_perks() -> void:
	var sword_battle := _fixture()
	sword_battle.active_unit = "hero"
	sword_battle.ap = 2
	sword_battle.enemies[0].x = 1
	sword_battle.enemies[0].y = 4
	sword_battle.ally.x = 0
	sword_battle.ally.y = 3
	var sword_master := _player_fixture()
	sword_master.swordsmanship = 10
	sword_master.qi = 6
	var sword_result: Dictionary = ENGINE.player_action(sword_battle, sword_master, "skill", Vector2i(1, 4), _seeded_rng())
	assert(bool(sword_result.ok) and int(sword_master.qi) == 0, "Sword mastery should allow Flowing Cloud Sword at its reduced six-qi cost.")

	var blade_battle := _fixture()
	blade_battle.erase("ally")
	blade_battle.active_unit = "hero"
	blade_battle.ap = 2
	blade_battle.enemies[0].x = 2
	blade_battle.enemies[0].y = 1
	blade_battle.enemies[0].hp = 100
	var blade_master := _player_fixture()
	blade_master.bladesmanship = 10
	var blade_result: Dictionary = ENGINE.player_action(blade_battle, blade_master, "attack", Vector2i(2, 1), _seeded_rng())
	assert(bool(blade_result.ok) and int(blade_battle.enemies[0].exposure) == 2, "Blade mastery should create two exposure layers with a surviving normal attack.")

	var medicine_battle := _fixture()
	medicine_battle.active_unit = "hero"
	medicine_battle.ap = 2
	var herbal_master := _player_fixture()
	herbal_master.herbalism = 10
	herbal_master.hp = 10
	herbal_master.max_hp = 45
	herbal_master.consumables = {"healing_powder": 1}
	var medicine_result: Dictionary = ENGINE.player_action(medicine_battle, herbal_master, "heal")
	assert(bool(medicine_result.ok) and int(medicine_result.healed) == 22, "Herbalism mastery should add five healing on top of its continuous level bonus.")

func _test_armor_and_exposure_combo() -> void:
	var armored := _fixture()
	armored.erase("ally")
	armored.active_unit = "hero"
	armored.ap = 2
	armored.enemies[0].role = "brute"
	armored.enemies[0].hp = 100
	armored.enemies[0].max_hp = 100
	armored.enemies[0].x = 2
	armored.enemies[0].y = 1
	var player := _player_fixture()
	var attack: Dictionary = ENGINE.player_action(armored, player, "attack", Vector2i(2, 1), _seeded_rng())
	assert(bool(attack.ok) and int(armored.enemies[0].exposure) == 1, "A normal attack should create one exposure stack on a surviving target.")

	var unarmored := _fixture()
	unarmored.erase("ally")
	unarmored.active_unit = "hero"
	unarmored.ap = 2
	unarmored.enemies[0].hp = 100
	unarmored.enemies[0].max_hp = 100
	unarmored.enemies[0].x = 2
	unarmored.enemies[0].y = 1
	var unarmored_attack: Dictionary = ENGINE.player_action(unarmored, _player_fixture(), "attack", Vector2i(2, 1), _seeded_rng())
	assert(int(attack.damage) == int(unarmored_attack.damage) - 2, "Brute armor should reduce normal attack damage by two.")

	armored.ap = 1
	armored.enemies[0].x = 1
	armored.enemies[0].y = 4
	var skill: Dictionary = ENGINE.player_action(armored, player, "skill", Vector2i(1, 4), _seeded_rng())
	var plain := armored.duplicate(true)
	plain.ap = 1
	plain.enemies[0].hp = 100
	plain.enemies[0].exposure = 0
	var plain_skill: Dictionary = ENGINE.player_action(plain, _player_fixture(), "skill", Vector2i(1, 4), _seeded_rng())
	assert(int(skill.damage) == int(plain_skill.damage) + 4, "Flowing Cloud Sword should gain four damage per exposure stack.")
	assert(int(armored.enemies[0].exposure) == 0, "Flowing Cloud Sword should consume all exposure stacks.")

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

func _test_archer_aimed_shot() -> void:
	var aimed := _fixture()
	aimed.erase("ally")
	aimed.turn = 3
	aimed.enemies[0].role = "archer"
	aimed.enemies[0].range = 4
	aimed.enemies[0].x = 5
	aimed.enemies[0].y = 1
	var aimed_outcome: Dictionary = ENGINE.enemy_turn(aimed, 30, _seeded_rng())
	assert(bool(aimed_outcome.suppressed) and int(aimed.ap) == 1, "A clear aimed shot should reduce the next shared player turn to one action point.")
	assert(Array(aimed_outcome.events).size() == 3 and str(aimed_outcome.events[0].type) == "technique", "Aimed shots should present their technique before attack and hit events.")
	assert(str(aimed_outcome.events[2].impact) == "normal", "Aimed shots should carry medium-strength impact feedback.")

	var regular := _fixture()
	regular.erase("ally")
	regular.turn = 1
	regular.enemies[0].role = "archer"
	regular.enemies[0].range = 4
	regular.enemies[0].x = 5
	regular.enemies[0].y = 1
	var regular_outcome: Dictionary = ENGINE.enemy_turn(regular, 30, _seeded_rng())
	assert(int(aimed_outcome.total_hurt) == int(regular_outcome.total_hurt) + 2, "Aimed shots should deal exactly two bonus damage with the same random roll.")

	var covered := _fixture()
	covered.erase("ally")
	covered.turn = 3
	covered.enemies[0].role = "archer"
	covered.enemies[0].range = 4
	covered.enemies[0].x = 5
	covered.enemies[0].y = 1
	covered.blocked = [[3, 1]]
	var covered_outcome: Dictionary = ENGINE.enemy_turn(covered, 30, _seeded_rng())
	assert(not bool(covered_outcome.suppressed) and int(covered.ap) == 2, "Cover should prevent an aimed shot from applying action suppression.")

func _test_brute_heavy_attack() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.turn = 2
	battle.enemies[0].role = "brute"
	battle.enemies[0].x = 2
	battle.enemies[0].y = 1
	var outcome: Dictionary = ENGINE.enemy_turn(battle, 30, _seeded_rng())
	assert(int(outcome.total_hurt) >= int(battle.enemies[0].attack) + 4, "Brutes should gain bonus damage on their telegraphed heavy turn.")
	assert(str(outcome.events.back().impact) == "heavy", "Brute heavy attacks should request high-strength impact feedback.")
	assert("重击" in str(battle.result), "Heavy attacks should be reported in the battle log.")

func _test_boss_phase_and_sweep() -> void:
	var battle := _fixture()
	battle.turn = 3
	battle.player_x = 1
	battle.player_y = 1
	battle.ally.x = 2
	battle.ally.y = 2
	battle.enemies[0] = {"name": "厉无咎", "role": "brute", "boss": true, "hp": 20, "max_hp": 46, "attack": 8, "range": 1, "x": 2, "y": 1}
	var outcome: Dictionary = ENGINE.enemy_turn(battle, 40, _seeded_rng())
	assert(bool(outcome.boss_transition), "Crossing half health should emit exactly one boss phase transition.")
	assert(int(outcome.hero_hp) < 40 and int(battle.ally.hp) < 30, "The telegraphed sweep should hit every party member within two cells.")
	assert("第二阶段" in str(battle.result) and "断岳刀势" in str(battle.result), "The battle log should announce both transition and signature attack.")
	assert(Array(outcome.events).any(func(event: Dictionary): return str(event.get("type", "")) == "hit" and str(event.get("impact", "")) == "heavy"), "Boss sweeps should mark every damage event as a heavy impact.")
	battle.turn = 4
	var second: Dictionary = ENGINE.enemy_turn(battle, int(outcome.hero_hp), _seeded_rng())
	assert(not bool(second.boss_transition), "The boss phase transition must not repeat on later turns.")

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

func _test_multi_target_feedback() -> void:
	var battle := _fixture()
	battle.turn = 3
	battle.player_x = 1
	battle.player_y = 1
	battle.ally.x = 2
	battle.ally.y = 2
	battle.ally.guard = 99
	battle.enemies[0] = {"name": "厉无咎", "role": "brute", "boss": true, "phase_two_started": true, "hp": 20, "max_hp": 46, "attack": 8, "range": 1, "x": 2, "y": 1}
	ENGINE.enemy_turn(battle, 40, _seeded_rng())
	assert(Array(battle.effects).size() == 2, "A sweeping attack should retain separate feedback for every target hit.")
	assert(Vector2i(int(battle.effects[0].x), int(battle.effects[0].y)) == Vector2i(1, 1), "Hero damage feedback should appear on the hero cell.")
	assert(Vector2i(int(battle.effects[1].x), int(battle.effects[1].y)) == Vector2i(2, 2), "Ally feedback should appear on the ally cell instead of being merged onto the hero.")
	assert(str(battle.effects[1].type) == "guard", "A fully blocked hit should be communicated as a guard result.")

func _test_enemy_event_sequence() -> void:
	var battle := _fixture()
	battle.erase("ally")
	var movement: Dictionary = ENGINE.enemy_turn(battle, 20, _seeded_rng())
	assert(Array(movement.events).size() == 1 and str(movement.events[0].type) == "move", "A distant enemy should emit one movement presentation event.")
	assert(Vector2i(movement.events[0].from) == Vector2i(4, 1) and Vector2i(movement.events[0].to) == Vector2i(3, 1), "Movement events should retain their exact origin and destination.")

	battle = _fixture()
	battle.erase("ally")
	battle.enemies[0].x = 2
	battle.enemies[0].y = 1
	var attack: Dictionary = ENGINE.enemy_turn(battle, 20, _seeded_rng())
	assert(Array(attack.events).size() == 2, "A direct enemy strike should emit an attack cue followed by its hit result.")
	assert(str(attack.events[0].type) == "attack" and str(attack.events[1].type) == "hit", "Enemy presentation events must preserve attack-before-impact ordering.")
	assert(Vector2i(attack.events[1].target) == Vector2i(1, 1), "The hit event should identify the actual target cell.")
	assert(str(attack.events[1].impact) == "light", "Regular enemy strikes should use light impact feedback.")

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
		"insight": 4,
		"xp": 0,
		"qi": 20,
		"skill_mastery": {"cloud": 0, "frost": 0, "frost_guard": 0}
	}
