extends SceneTree

const ENGINE := preload("res://scripts/battle/battle_engine.gd")
const WUXUE_RULES := preload("res://scripts/progression/wuxue_rules.gd")

func _initialize() -> void:
	_test_victory_detection()
	_test_player_move_and_attack()
	_test_player_skills_and_resources()
	_test_healing_powder()
	_test_thunder_stone()
	_test_hero_brace_and_guard()
	_test_cultivation_damage_bonus()
	_test_specialty_damage_bonus()
	_test_specialty_mastery_perks()
	_test_armor_and_exposure_combo()
	_test_equipped_gear_bonuses()
	_test_wuxue_moves_require_learning()
	_test_wuxue_move_damage()
	_test_armor_splitting_spear()
	_test_wuxue_internal_and_lightness_bonuses()
	_test_wuxue_leveling()
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
	_test_ally_armor_mitigation()
	_test_ally_lightness_dash_range()
	_test_multi_target_feedback()
	_test_enemy_event_sequence()
	_test_hero_defeat()
	_test_turn_order_queue()
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
	battle.action_points = 2
	var player := _player_fixture()
	var move: Dictionary = ENGINE.player_action(battle, player, "move", Vector2i(2, 1), _seeded_rng())
	assert(bool(move.ok) and Vector2i(int(battle.player_x), int(battle.player_y)) == Vector2i(2, 1), "A valid move should update the active unit position.")
	assert(int(battle.action_points) == 1, "Moving should consume one action point.")
	battle.enemies[0].x = 3
	battle.enemies[0].y = 1
	battle.enemies[0].hp = 1
	var attack: Dictionary = ENGINE.player_action(battle, player, "attack", Vector2i(3, 1), _seeded_rng())
	assert(bool(attack.ok) and int(battle.enemies[0].hp) == 0, "A normal attack should damage and clamp enemy health to zero.")
	assert(int(battle.action_points) == 0, "Attacking should consume one action point.")

func _test_player_skills_and_resources() -> void:
	var battle := _fixture()
	battle.active_unit = "hero"
	battle.action_points = 2
	battle.enemies[0].x = 1
	battle.enemies[0].y = 4
	battle.ally.x = 0
	battle.ally.y = 3
	var player := _player_fixture()
	var cloud: Dictionary = ENGINE.player_action(battle, player, "skill", Vector2i(1, 4), _seeded_rng())
	assert(bool(cloud.ok) and int(player.qi) == 12, "Flowing Cloud Sword should consume eight qi.")
	assert(int(player.skill_mastery.cloud) == 1 and bool(battle.skill_flash), "Using a skill should increase mastery and trigger its visual state.")

	battle = _fixture()
	battle.active_unit = "hero"
	battle.action_points = 2
	battle.enemies[0].x = 2
	battle.enemies[0].y = 1
	battle.enemies[0].role = "brute"
	battle.enemies[0].hp = 100
	battle.enemies[0].max_hp = 100
	player = _player_fixture()
	# 专精改为等级制、100级满 (0.105.0) -- 精通门槛从6级放大到60级。
	player.bladesmanship = 60
	var blade: Dictionary = ENGINE.player_action(battle, player, "blade_skill", Vector2i(2, 1), _seeded_rng())
	assert(bool(blade.ok) and int(player.qi) == 14 and int(battle.action_points) == 1, "Mountain-Breaking Blade should consume six qi and one action point.")
	assert(int(battle.enemies[0].armor) == 0 and int(battle.enemies[0].exposure) == 2, "Trained blade technique should permanently remove two armor and expose a surviving target.")
	assert(bool(battle.skill_flash) and str(battle.skill_name) == "断 岳 刀 法", "Blade technique should expose its own presentation title.")
	battle.action_points = 2
	player.qi = 5
	var failed_blade: Dictionary = ENGINE.player_action(battle, player, "blade_skill", Vector2i(2, 1), _seeded_rng())
	assert(not bool(failed_blade.ok) and int(player.qi) == 5 and int(battle.action_points) == 2, "A failed blade technique must preserve qi and action points.")

	battle = _fixture()
	battle.active_unit = "ally"
	battle.action_points = 2
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

	# 同伴换武学 (0.113.0) -- a companion with a chosen move_id should borrow
	# that move's own title/qi cost/damage bonus for the dash, instead of
	# 霜华刺's fixed defaults.
	var custom_battle := _fixture()
	custom_battle.active_unit = "ally"
	custom_battle.action_points = 2
	custom_battle.ally.x = 2
	custom_battle.ally.y = 1
	custom_battle.ally.move_id = "stone_splitting_fist"
	custom_battle.enemies[0].x = 4
	custom_battle.enemies[0].y = 1
	var custom_player := _player_fixture()
	assert(ENGINE.ally_dash_title(custom_battle) == "裂石拳" and ENGINE.ally_dash_qi_cost(custom_battle) == 5, "ally_dash_title()/ally_dash_qi_cost() should read the companion's chosen move from WuxueRules.MOVES.")
	var custom_dash: Dictionary = ENGINE.player_action(custom_battle, custom_player, "frost_dash", Vector2i(4, 1), _seeded_rng())
	assert(bool(custom_dash.ok) and int(custom_battle.ally.qi) == 10, "The dash should spend 裂石拳's own 5-qi cost instead of 霜华刺's default 6.")
	assert(str(custom_battle.skill_name) == "裂石拳", "The dash's presentation title should match the companion's chosen move.")
	var default_battle := _fixture()
	default_battle.active_unit = "ally"
	default_battle.action_points = 2
	default_battle.ally.x = 2
	default_battle.ally.y = 1
	default_battle.enemies[0].x = 4
	default_battle.enemies[0].y = 1
	default_battle.enemies[0].hp = 100
	custom_battle.enemies[0].hp = 100
	var default_dash: Dictionary = ENGINE.player_action(default_battle, _player_fixture(), "frost_dash", Vector2i(4, 1), _seeded_rng())
	assert(int(custom_dash.damage) == int(default_dash.damage) + 1, "裂石拳's level_damage_bonus (+1) should be strictly additive on top of the default dash formula, not a full formula replacement.")

	battle.action_points = 1
	battle.ally.qi = 10
	var guard: Dictionary = ENGINE.player_action(battle, player, "frost_guard", Vector2i.ZERO, _seeded_rng())
	assert(bool(guard.ok) and int(battle.ally.guard) == 8 and int(battle.ally.qi) == 13, "Frost Guard should grant guard and restore qi.")
	assert(int(player.skill_mastery.frost_guard) == 1, "Frost Guard should increase its mastery.")
	assert(bool(battle.skill_flash) and str(battle.skill_name) == "寒 锋 守 势", "Frost Guard should expose its own presentation title.")

func _test_healing_powder() -> void:
	var battle := _fixture()
	battle.active_unit = "hero"
	battle.action_points = 2
	var player := _player_fixture()
	player.hp = 20
	player.max_hp = 45
	player.herbalism = 4
	player.consumables = {"healing_powder": 1}
	var result: Dictionary = ENGINE.player_action(battle, player, "heal")
	assert(bool(result.ok) and int(result.healed) == 14 and int(player.hp) == 34, "Herbalism should improve the healing powder's battle recovery.")
	assert(int(player.consumables.healing_powder) == 0 and int(battle.action_points) == 1, "Healing should consume one item and one action point.")
	var failed: Dictionary = ENGINE.player_action(battle, player, "heal")
	assert(not bool(failed.ok) and int(battle.action_points) == 1, "Using a missing healing powder must preserve action points.")

func _test_thunder_stone() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.active_unit = "hero"
	battle.action_points = 2
	battle.enemies[0].role = "brute"
	battle.enemies[0].hp = 50
	battle.enemies[0].max_hp = 50
	battle.enemies[0].x = 4
	battle.enemies[0].y = 1
	var player := _player_fixture()
	player.mining = 10
	player.consumables = {"healing_powder": 0, "thunder_stone": 1}
	var result: Dictionary = ENGINE.player_action(battle, player, "thunder_stone", Vector2i(4, 1), _seeded_rng())
	assert(bool(result.ok) and int(player.consumables.thunder_stone) == 0 and int(battle.action_points) == 1, "A valid thunder-stone throw should consume one item and action point.")
	assert(int(battle.enemies[0].armor) == 1 and int(result.damage) >= 15, "Mining mastery should power the throw while permanently removing one armor.")
	battle.action_points = 2
	var failed: Dictionary = ENGINE.player_action(battle, player, "thunder_stone", Vector2i(4, 1), _seeded_rng())
	assert(not bool(failed.ok) and int(battle.action_points) == 2, "A missing thunder stone must preserve action points.")

func _test_hero_brace_and_guard() -> void:
	var battle := _fixture()
	battle.active_unit = "hero"
	battle.action_points = 2
	battle.hero_guard = 0
	battle.enemies[0].x = 2
	battle.enemies[0].y = 1
	var player := _player_fixture()
	player.qi = 10
	player.constitution = 4
	var brace: Dictionary = ENGINE.player_action(battle, player, "brace")
	assert(bool(brace.ok) and int(battle.hero_guard) == 8 and int(player.qi) == 13 and int(battle.action_points) == 1, "Hero brace should trade one action for constitution-scaled guard and three qi.")
	var outcome: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, 20, _seeded_rng())
	assert(int(outcome.hero_hp) == 18 and int(battle.hero_guard) == 0, "Hero guard should absorb eight points from the seeded ten-damage strike before health.")
	assert(str(battle.effects[0].type) == "damage" and int(outcome.events[1].blocked) == 8, "Partially blocked hero damage should reach both board feedback and presentation events.")
	battle = _fixture()
	battle.active_unit = "ally"
	battle.action_points = 1
	assert(not bool(ENGINE.player_action(battle, player, "brace").ok) and int(battle.action_points) == 1, "An ally turn must reject hero brace without consuming action points.")

func _test_cultivation_damage_bonus() -> void:
	var low_battle := _fixture()
	low_battle.active_unit = "hero"
	low_battle.action_points = 2
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
	sword_battle.action_points = 2
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
	plain_battle.action_points = 2
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
	sword_battle.action_points = 2
	sword_battle.enemies[0].x = 1
	sword_battle.enemies[0].y = 4
	sword_battle.ally.x = 0
	sword_battle.ally.y = 3
	# 专精改为等级制、100级满 (0.105.0) -- 大成门槛从10级放大到100级(封顶)。
	var sword_master := _player_fixture()
	sword_master.swordsmanship = 100
	sword_master.qi = 6
	var sword_result: Dictionary = ENGINE.player_action(sword_battle, sword_master, "skill", Vector2i(1, 4), _seeded_rng())
	assert(bool(sword_result.ok) and int(sword_master.qi) == 0, "Sword mastery should allow Flowing Cloud Sword at its reduced six-qi cost.")

	var blade_battle := _fixture()
	blade_battle.erase("ally")
	blade_battle.active_unit = "hero"
	blade_battle.action_points = 2
	blade_battle.enemies[0].x = 2
	blade_battle.enemies[0].y = 1
	blade_battle.enemies[0].hp = 100
	var blade_master := _player_fixture()
	blade_master.bladesmanship = 100
	var blade_result: Dictionary = ENGINE.player_action(blade_battle, blade_master, "attack", Vector2i(2, 1), _seeded_rng())
	assert(bool(blade_result.ok) and int(blade_battle.enemies[0].exposure) == 2, "Blade mastery should create two exposure layers with a surviving normal attack.")

	var medicine_battle := _fixture()
	medicine_battle.active_unit = "hero"
	medicine_battle.action_points = 2
	var herbal_master := _player_fixture()
	herbal_master.herbalism = 100
	herbal_master.hp = 10
	herbal_master.max_hp = 90
	herbal_master.consumables = {"healing_powder": 1}
	var medicine_result: Dictionary = ENGINE.player_action(medicine_battle, herbal_master, "heal")
	assert(bool(medicine_result.ok) and int(medicine_result.healed) == 67, "Herbalism mastery should add five healing on top of its continuous level bonus (12 base + 100/2 level bonus + 5 mastery = 67).")
	var help_text := ENGINE.hero_action_help({"strength": 4, "xp": 0, "bladesmanship": 100, "swordsmanship": 100, "insight": 4, "skill_mastery": {"cloud": 0}, "herbalism": 100})
	assert("制造2层破绽" in help_text and "剑法" in help_text and "永久破甲2" in help_text and "恢复67气血" in help_text, "The tactical action preview should expose all active mastery values and the trained blade break.")

func _test_armor_and_exposure_combo() -> void:
	var armored := _fixture()
	armored.erase("ally")
	armored.active_unit = "hero"
	armored.action_points = 2
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
	unarmored.action_points = 2
	unarmored.enemies[0].hp = 100
	unarmored.enemies[0].max_hp = 100
	unarmored.enemies[0].x = 2
	unarmored.enemies[0].y = 1
	var unarmored_attack: Dictionary = ENGINE.player_action(unarmored, _player_fixture(), "attack", Vector2i(2, 1), _seeded_rng())
	assert(int(attack.damage) == int(unarmored_attack.damage) - 2, "Brute armor should reduce normal attack damage by two.")

	armored.action_points = 1
	armored.enemies[0].x = 1
	armored.enemies[0].y = 4
	var skill: Dictionary = ENGINE.player_action(armored, player, "skill", Vector2i(1, 4), _seeded_rng())
	var plain := armored.duplicate(true)
	plain.action_points = 1
	plain.enemies[0].hp = 100
	plain.enemies[0].exposure = 0
	var plain_skill: Dictionary = ENGINE.player_action(plain, _player_fixture(), "skill", Vector2i(1, 4), _seeded_rng())
	assert(int(skill.damage) == int(plain_skill.damage) + 4, "Flowing Cloud Sword should gain four damage per exposure stack.")
	assert(int(armored.enemies[0].exposure) == 0, "Flowing Cloud Sword should consume all exposure stacks.")

func _test_equipped_gear_bonuses() -> void:
	var bare_battle := _fixture()
	bare_battle.erase("ally")
	bare_battle.active_unit = "hero"
	bare_battle.action_points = 2
	bare_battle.enemies[0].x = 2
	bare_battle.enemies[0].y = 1
	bare_battle.enemies[0].hp = 100
	bare_battle.enemies[0].max_hp = 100
	var bare_result: Dictionary = ENGINE.player_action(bare_battle, _player_fixture(), "attack", Vector2i(2, 1), _seeded_rng())

	var armed_battle := _fixture()
	armed_battle.erase("ally")
	armed_battle.active_unit = "hero"
	armed_battle.action_points = 2
	armed_battle.enemies[0].x = 2
	armed_battle.enemies[0].y = 1
	armed_battle.enemies[0].hp = 100
	armed_battle.enemies[0].max_hp = 100
	var armed_player := _player_fixture()
	armed_player.equipped_weapon = "cold_crow_blade"
	var armed_result: Dictionary = ENGINE.player_action(armed_battle, armed_player, "attack", Vector2i(2, 1), _seeded_rng())
	assert(bool(bare_result.ok) and bool(armed_result.ok), "Both attacks must land to compare their damage.")
	assert(int(armed_result.damage) == int(bare_result.damage) + 2, "An equipped weapon should add its flat attack bonus (two, for the cold crow blade) to normal-attack damage.")

	# A weapon with no matching catalog entry (a corrupted or removed id) must
	# behave exactly like being unarmed rather than erroring out.
	var unknown_player := _player_fixture()
	unknown_player.equipped_weapon = "not_a_real_weapon"
	var unknown_battle := _fixture()
	unknown_battle.erase("ally")
	unknown_battle.active_unit = "hero"
	unknown_battle.action_points = 2
	unknown_battle.enemies[0].x = 2
	unknown_battle.enemies[0].y = 1
	unknown_battle.enemies[0].hp = 100
	unknown_battle.enemies[0].max_hp = 100
	var unknown_result: Dictionary = ENGINE.player_action(unknown_battle, unknown_player, "attack", Vector2i(2, 1), _seeded_rng())
	assert(int(unknown_result.damage) == int(bare_result.damage), "An unrecognized equipped_weapon id must contribute zero bonus, not crash or guess.")

	# Armor should reduce incoming hero damage by an exact flat amount without
	# affecting the ally, who has her own separate guard resource.
	var unarmored := _fixture()
	unarmored.active_unit = "hero"
	unarmored.action_points = 2
	unarmored.hero_guard = 0
	unarmored.enemies[0].x = 2
	unarmored.enemies[0].y = 1
	var ally_hp_before := int(unarmored.ally.hp)
	var unarmored_outcome: Dictionary = ENGINE.resolve_enemy_turn(unarmored, 0, 20, _seeded_rng())

	var armored_hero := _fixture()
	armored_hero.active_unit = "hero"
	armored_hero.action_points = 2
	armored_hero.hero_guard = 0
	armored_hero.enemies[0].x = 2
	armored_hero.enemies[0].y = 1
	var armored_outcome: Dictionary = ENGINE.resolve_enemy_turn(armored_hero, 0, 20, _seeded_rng(), 3)
	assert(int(armored_outcome.hero_hp) == int(unarmored_outcome.hero_hp) + 3, "Three points of equipped armor should reduce the same seeded strike by exactly three, a flat reduction rather than a percentage.")
	assert(int(armored_hero.ally.hp) == ally_hp_before, "Hero-only armor must never reduce damage the ally takes from an unrelated hit.")

	# Omitting the new parameter entirely (four positional args -- battle,
	# enemy_index, hero_hp, rng -- exactly as every other call site in this
	# file already does) must behave identically to explicitly passing zero
	# armor -- this is the contract that keeps every other test in this file
	# valid without modification.
	var implicit_battle := _fixture()
	implicit_battle.active_unit = "hero"
	implicit_battle.action_points = 2
	implicit_battle.hero_guard = 0
	implicit_battle.enemies[0].x = 2
	implicit_battle.enemies[0].y = 1
	var implicit_outcome: Dictionary = ENGINE.resolve_enemy_turn(implicit_battle, 0, 20, _seeded_rng())
	assert(int(implicit_outcome.hero_hp) == int(unarmored_outcome.hero_hp), "Calling resolve_enemy_turn with only four positional arguments must default armor to zero.")

func _test_wuxue_moves_require_learning() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.active_unit = "hero"
	battle.action_points = 2
	battle.enemies[0].x = 2
	battle.enemies[0].y = 1
	var unlearned := _player_fixture()
	var stone_attempt: Dictionary = ENGINE.player_action(battle, unlearned, "stone_splitting_fist", Vector2i(2, 1), _seeded_rng())
	assert(not bool(stone_attempt.ok) and int(battle.action_points) == 2, "Using an unlearned move must fail without consuming an action point.")
	var blade_attempt: Dictionary = ENGINE.player_action(battle, unlearned, "night_triple_blade", Vector2i(2, 1), _seeded_rng())
	assert(not bool(blade_attempt.ok), "Night Triple Blade should also require the move be learned first.")

	# 流云剑法/断岳刀法 became normal learnable moves (0.95.0), no longer
	# innate -- they still require the same learned gate as any other, but
	# (0.104.0) no longer need a separate equip step once learned.
	var bare := _player_fixture()
	bare.learned_moves = []
	var cloud_attempt: Dictionary = ENGINE.player_action(battle, bare, "skill", Vector2i(2, 1), _seeded_rng())
	assert(not bool(cloud_attempt.ok) and int(battle.action_points) == 2, "流云剑法 must still require the move be learned first, same as 裂石拳.")
	var blade_technique_attempt: Dictionary = ENGINE.player_action(battle, bare, "blade_skill", Vector2i(2, 1), _seeded_rng())
	assert(not bool(blade_technique_attempt.ok), "断岳刀法 must still require the move be learned first, same as 暗夜三刀.")

	# A move that was learned but never "equipped" (0.104.0 removed the
	# equip step/slot cap entirely) must still work -- this is the real
	# behavioral proof the slot limit is gone, not just a field rename.
	var never_equipped := _player_fixture()
	never_equipped.learned_moves = ["stone_splitting_fist", "night_triple_blade", "cloud_sword", "blade_technique"]
	var never_equipped_attempt: Dictionary = ENGINE.player_action(battle, never_equipped, "stone_splitting_fist", Vector2i(2, 1), _seeded_rng())
	assert(bool(never_equipped_attempt.ok), "A learned move with more than two total learned moves at once (impossible under the old two-slot cap) must still be usable.")

	var ally_battle := _fixture()
	ally_battle.active_unit = "ally"
	ally_battle.action_points = 2
	ally_battle.enemies[0].x = 1
	ally_battle.enemies[0].y = 3
	var learned_player := _player_fixture()
	learned_player.learned_moves = ["stone_splitting_fist", "night_triple_blade"]
	var ally_attempt: Dictionary = ENGINE.player_action(ally_battle, learned_player, "stone_splitting_fist", Vector2i(1, 3), _seeded_rng())
	assert(not bool(ally_attempt.ok), "林清霜 cannot use the hero's learned moves on her own turn.")

func _test_wuxue_move_damage() -> void:
	var stone_battle := _fixture()
	stone_battle.erase("ally")
	stone_battle.active_unit = "hero"
	stone_battle.action_points = 2
	stone_battle.enemies[0].x = 2
	stone_battle.enemies[0].y = 1
	stone_battle.enemies[0].hp = 100
	stone_battle.enemies[0].max_hp = 100
	stone_battle.enemies[0].armor = 50
	var stone_player := _player_fixture()
	stone_player.learned_moves = ["stone_splitting_fist"]
	stone_player.qi = 20
	var stone_result: Dictionary = ENGINE.player_action(stone_battle, stone_player, "stone_splitting_fist", Vector2i(2, 1), _seeded_rng())
	var expected_stone := ENGINE.stone_fist_damage_range(stone_player)
	assert(bool(stone_result.ok) and int(stone_player.qi) == 15, "A legal Stone Splitting Fist should hit and consume five qi.")
	assert(int(stone_result.damage) >= expected_stone.x and int(stone_result.damage) <= expected_stone.y, "Stone Splitting Fist damage should land within its expected range.")
	assert(int(stone_battle.enemies[0].hp) == 100 - int(stone_result.damage), "A heavily-armored enemy should take the exact same damage as an unarmored one -- Stone Splitting Fist ignores armor entirely.")

	var low_qi_player := _player_fixture()
	low_qi_player.learned_moves = ["stone_splitting_fist"]
	low_qi_player.qi = 4
	var low_qi_battle := _fixture()
	low_qi_battle.erase("ally")
	low_qi_battle.active_unit = "hero"
	low_qi_battle.action_points = 2
	low_qi_battle.enemies[0].x = 2
	low_qi_battle.enemies[0].y = 1
	var starved_attempt: Dictionary = ENGINE.player_action(low_qi_battle, low_qi_player, "stone_splitting_fist", Vector2i(2, 1), _seeded_rng())
	assert(not bool(starved_attempt.ok) and int(low_qi_player.qi) == 4, "Four qi should be insufficient for Stone Splitting Fist's five-qi cost, and a failed use must not spend any.")

	# 流云剑法/断岳刀法 now level like any other move (0.95.0) -- guard against
	# the exact "preview formula updated, inline execution formula forgotten"
	# bug class this file already documents for other moves, by comparing a
	# same-seed-RNG plain skill hit before and after leveling cloud_sword up.
	var cloud_plain_battle := _fixture()
	cloud_plain_battle.erase("ally")
	cloud_plain_battle.active_unit = "hero"
	cloud_plain_battle.action_points = 2
	cloud_plain_battle.enemies[0].x = 1
	cloud_plain_battle.enemies[0].y = 4
	var cloud_plain_player := _player_fixture()
	var cloud_plain_result: Dictionary = ENGINE.player_action(cloud_plain_battle, cloud_plain_player, "skill", Vector2i(1, 4), _seeded_rng())
	var cloud_leveled_battle := _fixture()
	cloud_leveled_battle.erase("ally")
	cloud_leveled_battle.active_unit = "hero"
	cloud_leveled_battle.action_points = 2
	cloud_leveled_battle.enemies[0].x = 1
	cloud_leveled_battle.enemies[0].y = 4
	var cloud_leveled_player := _player_fixture()
	cloud_leveled_player.move_levels = {"cloud_sword": 2}
	var cloud_leveled_result: Dictionary = ENGINE.player_action(cloud_leveled_battle, cloud_leveled_player, "skill", Vector2i(1, 4), _seeded_rng())
	assert(int(cloud_leveled_result.damage) == int(cloud_plain_result.damage) + 1, "Leveling 流云剑法 from 1 to 2 should raise its actual inflicted damage by exactly its one-point-per-level bonus, not just the preview formula.")

	var blade_battle := _fixture()
	blade_battle.erase("ally")
	blade_battle.active_unit = "hero"
	blade_battle.action_points = 2
	blade_battle.enemies[0].x = 2
	blade_battle.enemies[0].y = 1
	blade_battle.enemies[0].hp = 200
	blade_battle.enemies[0].max_hp = 200
	blade_battle.enemies[0].armor = 0
	var blade_player := _player_fixture()
	blade_player.learned_moves = ["night_triple_blade"]
	blade_player.qi = 20
	var blade_result: Dictionary = ENGINE.player_action(blade_battle, blade_player, "night_triple_blade", Vector2i(2, 1), _seeded_rng())
	assert(bool(blade_result.ok) and int(blade_player.qi) == 11, "A legal Night Triple Blade should hit and consume nine qi.")
	var hit_range := ENGINE.night_blade_hit_range(blade_player)
	assert(int(blade_result.damage) >= hit_range.x * 3 and int(blade_result.damage) <= hit_range.y * 3, "Three unarmored hits should sum within three times the per-hit range.")

	var armored_blade_battle := _fixture()
	armored_blade_battle.erase("ally")
	armored_blade_battle.active_unit = "hero"
	armored_blade_battle.action_points = 2
	armored_blade_battle.enemies[0].x = 2
	armored_blade_battle.enemies[0].y = 1
	armored_blade_battle.enemies[0].hp = 200
	armored_blade_battle.enemies[0].max_hp = 200
	armored_blade_battle.enemies[0].armor = 2
	var armored_blade_player := _player_fixture()
	armored_blade_player.learned_moves = ["night_triple_blade"]
	armored_blade_player.qi = 20
	var armored_blade_result: Dictionary = ENGINE.player_action(armored_blade_battle, armored_blade_player, "night_triple_blade", Vector2i(2, 1), _seeded_rng())
	assert(int(armored_blade_result.damage) < int(blade_result.damage), "Unlike Stone Splitting Fist, Night Triple Blade should subtract the enemy's armor from every one of its three hits.")

## 演武场新增拳掌/枪棍 (0.106.0) -- 裂甲枪是新增的枪棍类招式：护甲减半，
## 枪棍大成(100级)后升级为完全无视护甲。同时验证 fistsmanship/staffsmanship
## 的每2级+1伤害加成，跟剑法/刀法完全同款写法。
func _test_armor_splitting_spear() -> void:
	var unlearned_battle := _fixture()
	unlearned_battle.erase("ally")
	unlearned_battle.active_unit = "hero"
	unlearned_battle.action_points = 2
	unlearned_battle.enemies[0].x = 2
	unlearned_battle.enemies[0].y = 1
	var unlearned_player := _player_fixture()
	var unlearned_attempt: Dictionary = ENGINE.player_action(unlearned_battle, unlearned_player, "armor_splitting_spear", Vector2i(2, 1), _seeded_rng())
	assert(not bool(unlearned_attempt.ok) and int(unlearned_battle.action_points) == 2, "Using an unlearned 裂甲枪 must fail without consuming an action point.")

	var half_pierce_battle := _fixture()
	half_pierce_battle.erase("ally")
	half_pierce_battle.active_unit = "hero"
	half_pierce_battle.action_points = 2
	half_pierce_battle.enemies[0].x = 2
	half_pierce_battle.enemies[0].y = 1
	half_pierce_battle.enemies[0].hp = 100
	half_pierce_battle.enemies[0].max_hp = 100
	half_pierce_battle.enemies[0].armor = 10
	var half_pierce_player := _player_fixture()
	half_pierce_player.learned_moves = ["armor_splitting_spear"]
	half_pierce_player.qi = 20
	var half_pierce_result: Dictionary = ENGINE.player_action(half_pierce_battle, half_pierce_player, "armor_splitting_spear", Vector2i(2, 1), _seeded_rng())
	var expected_spear := ENGINE.spear_damage_range(half_pierce_player)
	assert(bool(half_pierce_result.ok) and int(half_pierce_player.qi) == 14, "A legal 裂甲枪 should hit and consume six qi.")
	assert(int(half_pierce_result.damage) >= expected_spear.x - 5 and int(half_pierce_result.damage) <= expected_spear.y - 5, "裂甲枪 should only subtract half the enemy's ten armor (five), not the full amount.")

	var full_pierce_battle := _fixture()
	full_pierce_battle.erase("ally")
	full_pierce_battle.active_unit = "hero"
	full_pierce_battle.action_points = 2
	full_pierce_battle.enemies[0].x = 2
	full_pierce_battle.enemies[0].y = 1
	full_pierce_battle.enemies[0].hp = 100
	full_pierce_battle.enemies[0].max_hp = 100
	full_pierce_battle.enemies[0].armor = 10
	var full_pierce_player := _player_fixture()
	full_pierce_player.learned_moves = ["armor_splitting_spear"]
	full_pierce_player.qi = 20
	full_pierce_player.staffsmanship = 100
	var full_pierce_result: Dictionary = ENGINE.player_action(full_pierce_battle, full_pierce_player, "armor_splitting_spear", Vector2i(2, 1), _seeded_rng())
	var expected_full_spear := ENGINE.spear_damage_range(full_pierce_player)
	assert(int(full_pierce_result.damage) >= expected_full_spear.x and int(full_pierce_result.damage) <= expected_full_spear.y, "At 枪棍 level 100, 裂甲枪 should ignore the enemy's armor entirely, matching its unarmored damage range.")

	# fistsmanship/staffsmanship should add +1 damage per two levels, the
	# exact same shape as swordsmanship/bladesmanship's existing bonus.
	var fist_battle := _fixture()
	fist_battle.erase("ally")
	fist_battle.active_unit = "hero"
	fist_battle.action_points = 2
	fist_battle.enemies[0].x = 2
	fist_battle.enemies[0].y = 1
	fist_battle.enemies[0].hp = 100
	var fist_player := _player_fixture()
	fist_player.learned_moves = ["stone_splitting_fist"]
	fist_player.fistsmanship = 6
	fist_player.qi = 20
	var fist_result: Dictionary = ENGINE.player_action(fist_battle, fist_player, "stone_splitting_fist", Vector2i(2, 1), _seeded_rng())
	var baseline_fist_battle := _fixture()
	baseline_fist_battle.erase("ally")
	baseline_fist_battle.active_unit = "hero"
	baseline_fist_battle.action_points = 2
	baseline_fist_battle.enemies[0].x = 2
	baseline_fist_battle.enemies[0].y = 1
	baseline_fist_battle.enemies[0].hp = 100
	var baseline_fist_player := _player_fixture()
	baseline_fist_player.learned_moves = ["stone_splitting_fist"]
	baseline_fist_player.qi = 20
	var baseline_fist_result: Dictionary = ENGINE.player_action(baseline_fist_battle, baseline_fist_player, "stone_splitting_fist", Vector2i(2, 1), _seeded_rng())
	assert(int(fist_result.damage) == int(baseline_fist_result.damage) + 3, "拳掌 level 6 should add exactly three damage (6/2) to 裂石拳, mirroring 剑法/刀法's bonus shape.")

	# 拳掌大成 (100级)：裂石拳真气消耗从5降到3.
	var fist_master_battle := _fixture()
	fist_master_battle.erase("ally")
	fist_master_battle.active_unit = "hero"
	fist_master_battle.action_points = 2
	fist_master_battle.enemies[0].x = 2
	fist_master_battle.enemies[0].y = 1
	var fist_master_player := _player_fixture()
	fist_master_player.learned_moves = ["stone_splitting_fist"]
	fist_master_player.fistsmanship = 100
	fist_master_player.qi = 3
	var fist_master_result: Dictionary = ENGINE.player_action(fist_master_battle, fist_master_player, "stone_splitting_fist", Vector2i(2, 1), _seeded_rng())
	assert(bool(fist_master_result.ok) and int(fist_master_player.qi) == 0, "拳掌大成 should let 裂石拳 land with only three qi (a five-qi hero would otherwise be short).")

func _test_wuxue_internal_and_lightness_bonuses() -> void:
	var plain_battle := _fixture()
	plain_battle.erase("ally")
	plain_battle.active_unit = "hero"
	plain_battle.action_points = 2
	plain_battle.enemies[0].x = 2
	plain_battle.enemies[0].y = 1
	plain_battle.enemies[0].hp = 100
	var plain_player := _player_fixture()
	var plain_result: Dictionary = ENGINE.player_action(plain_battle, plain_player, "attack", Vector2i(2, 1), _seeded_rng())

	var trained_battle := _fixture()
	trained_battle.erase("ally")
	trained_battle.active_unit = "hero"
	trained_battle.action_points = 2
	trained_battle.enemies[0].x = 2
	trained_battle.enemies[0].y = 1
	trained_battle.enemies[0].hp = 100
	var trained_player := _player_fixture()
	trained_player.equipped_internal = "purple_mist_art"
	var trained_result: Dictionary = ENGINE.player_action(trained_battle, trained_player, "attack", Vector2i(2, 1), _seeded_rng())
	assert(bool(plain_result.ok) and bool(trained_result.ok), "Both attacks must land to compare their damage.")
	assert(int(trained_result.damage) == int(plain_result.damage) + 2, "The equipped Purple Mist Art should add its flat two-point damage bonus to a normal attack.")

	var healer := _player_fixture()
	healer.equipped_internal = "five_elements_art"
	assert(ENGINE.healing_amount(healer) == ENGINE.healing_amount(_player_fixture()) + 5, "Five Elements Art should add its five-point healing bonus.")

	# 轻功 extends the hero's own move range by exactly its bonus, without
	# touching the two-argument can_move_to() call every other test in this
	# file already relies on.
	var far_battle := _fixture()
	far_battle.erase("ally")
	far_battle.active_unit = "hero"
	far_battle.action_points = 2
	far_battle.player_x = 0
	far_battle.player_y = 0
	var grounded_player := _player_fixture()
	var grounded_move: Dictionary = ENGINE.player_action(far_battle, grounded_player, "move", Vector2i(3, 0), _seeded_rng())
	assert(not bool(grounded_move.ok), "Four steps away should be out of reach without any lightness skill.")

	var winged_battle := _fixture()
	winged_battle.erase("ally")
	winged_battle.active_unit = "hero"
	winged_battle.action_points = 2
	winged_battle.player_x = 0
	winged_battle.player_y = 0
	var winged_player := _player_fixture()
	winged_player.equipped_lightness = "ripple_steps"
	var winged_move: Dictionary = ENGINE.player_action(winged_battle, winged_player, "move", Vector2i(3, 0), _seeded_rng())
	assert(bool(winged_move.ok) and Vector2i(int(winged_battle.player_x), int(winged_battle.player_y)) == Vector2i(3, 0), "Ripple Steps' +1 move bonus should reach the same cell that was out of range unequipped.")

	var ally_far_battle := _fixture()
	ally_far_battle.active_unit = "ally"
	ally_far_battle.action_points = 2
	ally_far_battle.ally.x = 0
	ally_far_battle.ally.y = 0
	var ally_winged_player := _player_fixture()
	ally_winged_player.equipped_lightness = "wind_walk"
	var ally_move: Dictionary = ENGINE.player_action(ally_far_battle, ally_winged_player, "move", Vector2i(3, 0), _seeded_rng())
	assert(not bool(ally_move.ok), "The hero's own lightness skill must never extend 林清霜's movement range on her turn.")

func _test_wuxue_leveling() -> void:
	# A freshly equipped move (level 1) should deal the same damage as before
	# leveling existed -- the level-up bonus must be strictly additive on top
	# of the level-1 baseline, never a retroactive change to unleveled play.
	var level1_battle := _fixture()
	level1_battle.erase("ally")
	level1_battle.active_unit = "hero"
	level1_battle.action_points = 2
	level1_battle.enemies[0].x = 2
	level1_battle.enemies[0].y = 1
	level1_battle.enemies[0].hp = 100
	level1_battle.enemies[0].armor = 50
	var level1_player := _player_fixture()
	level1_player.learned_moves = ["stone_splitting_fist"]
	level1_player.qi = 20
	var level1_result: Dictionary = ENGINE.player_action(level1_battle, level1_player, "stone_splitting_fist", Vector2i(2, 1), _seeded_rng())
	assert(bool(level1_result.ok), "A level-1 Stone Splitting Fist should still land normally.")

	var level10_battle := _fixture()
	level10_battle.erase("ally")
	level10_battle.active_unit = "hero"
	level10_battle.action_points = 2
	level10_battle.enemies[0].x = 2
	level10_battle.enemies[0].y = 1
	level10_battle.enemies[0].hp = 100
	level10_battle.enemies[0].armor = 50
	var level10_player := _player_fixture()
	level10_player.learned_moves = ["stone_splitting_fist"]
	level10_player.qi = 20
	level10_player.move_levels = {"stone_splitting_fist": WUXUE_RULES.MAX_LEVEL}
	var level10_result: Dictionary = ENGINE.player_action(level10_battle, level10_player, "stone_splitting_fist", Vector2i(2, 1), _seeded_rng())
	assert(bool(level10_result.ok) and int(level10_result.damage) == int(level1_result.damage) + 9, "A maxed-out (level 10) Stone Splitting Fist should deal exactly nine more damage than the level-1 baseline, one point per level above 1, still ignoring armor.")

	# Internal art leveling should compound with its base bonus, and stack
	# with the un-leveled weapon/forge bonuses exactly like the base case did.
	var plain_battle := _fixture()
	plain_battle.erase("ally")
	plain_battle.active_unit = "hero"
	plain_battle.action_points = 2
	plain_battle.enemies[0].x = 2
	plain_battle.enemies[0].y = 1
	plain_battle.enemies[0].hp = 100
	var plain_player := _player_fixture()
	var plain_result: Dictionary = ENGINE.player_action(plain_battle, plain_player, "attack", Vector2i(2, 1), _seeded_rng())

	var leveled_internal_battle := _fixture()
	leveled_internal_battle.erase("ally")
	leveled_internal_battle.active_unit = "hero"
	leveled_internal_battle.action_points = 2
	leveled_internal_battle.enemies[0].x = 2
	leveled_internal_battle.enemies[0].y = 1
	leveled_internal_battle.enemies[0].hp = 100
	var leveled_internal_player := _player_fixture()
	leveled_internal_player.equipped_internal = "purple_mist_art"
	leveled_internal_player.internal_levels = {"purple_mist_art": 5}
	var leveled_internal_result: Dictionary = ENGINE.player_action(leveled_internal_battle, leveled_internal_player, "attack", Vector2i(2, 1), _seeded_rng())
	assert(int(leveled_internal_result.damage) == int(plain_result.damage) + 2 + 4, "Level 5 Purple Mist Art should add its base +2 plus four more levels' worth of bonus (one per level above 1) to a normal attack.")

	# Lightness leveling ticks its move-range bonus once every three levels;
	# level 4 must add exactly one extra tile over the un-leveled base.
	var grounded_lightness_battle := _fixture()
	grounded_lightness_battle.erase("ally")
	grounded_lightness_battle.active_unit = "hero"
	grounded_lightness_battle.action_points = 2
	grounded_lightness_battle.player_x = 0
	grounded_lightness_battle.player_y = 0
	var base_lightness_player := _player_fixture()
	base_lightness_player.equipped_lightness = "ripple_steps"
	var base_lightness_move: Dictionary = ENGINE.player_action(grounded_lightness_battle, base_lightness_player, "move", Vector2i(4, 0), _seeded_rng())
	assert(not bool(base_lightness_move.ok), "Five steps away should be out of reach for an un-leveled Ripple Steps (base +1 range).")

	var leveled_lightness_battle := _fixture()
	leveled_lightness_battle.erase("ally")
	leveled_lightness_battle.active_unit = "hero"
	leveled_lightness_battle.action_points = 2
	leveled_lightness_battle.player_x = 0
	leveled_lightness_battle.player_y = 0
	var leveled_lightness_player := _player_fixture()
	leveled_lightness_player.equipped_lightness = "ripple_steps"
	leveled_lightness_player.lightness_levels = {"ripple_steps": 4}
	var leveled_lightness_move: Dictionary = ENGINE.player_action(leveled_lightness_battle, leveled_lightness_player, "move", Vector2i(4, 0), _seeded_rng())
	assert(bool(leveled_lightness_move.ok), "Level 4 Ripple Steps' extra range tick should reach the same cell that was out of range at level 1.")

func _test_invalid_action_preserves_resources() -> void:
	var battle := _fixture()
	battle.active_unit = "hero"
	battle.action_points = 2
	var player := _player_fixture()
	player.qi = 7
	var failed: Dictionary = ENGINE.player_action(battle, player, "skill", Vector2i(4, 1), _seeded_rng())
	assert(not bool(failed.ok), "An invalid skill target or insufficient qi should fail.")
	assert(int(battle.action_points) == 2 and int(player.qi) == 7 and int(player.skill_mastery.cloud) == 0, "Failed actions must not consume resources or mastery.")

func _test_complete_battle_simulation() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.active_unit = "hero"
	battle.action_points = 2
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
		var enemy: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, hero_hp, rng)
		hero_hp = int(enemy.hero_hp)
		rounds += 1
	assert(ENGINE.is_victory(battle) and hero_hp > 0, "A complete battle should be simulatable without any UI nodes.")

func _test_ranged_enemy_attack_and_cover() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.enemies[0].x = 5
	battle.enemies[0].y = 1
	battle.enemies[0].range = 4
	var exposed: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, 20, _seeded_rng())
	assert(int(exposed.hero_hp) < 20, "A ranged enemy should damage a visible target without moving adjacent.")

	battle = _fixture()
	battle.erase("ally")
	battle.enemies[0].x = 5
	battle.enemies[0].y = 1
	battle.enemies[0].range = 4
	battle.blocked = [[3, 1]]
	var covered: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, 20, _seeded_rng())
	assert(int(covered.hero_hp) == 20, "Cover should prevent a ranged enemy from dealing damage.")
	assert(Vector2i(int(battle.enemies[0].x), int(battle.enemies[0].y)) != Vector2i(5, 1), "A ranged enemy without line of sight should reposition.")

## 行动条改版：节奏判断从"共享回合数取模"改成"这个敌人自己的行动次数
## 取模"，用 actions_taken 直接播种，而不再靠 battle.turn。压制效果也从
## "下回合行动点降到1"改成直接扣被命中一方自己的行动条。
func _test_archer_aimed_shot() -> void:
	var aimed := _fixture()
	aimed.erase("ally")
	aimed.enemies[0].role = "archer"
	aimed.enemies[0].range = 4
	aimed.enemies[0].x = 5
	aimed.enemies[0].y = 1
	aimed.enemies[0].actions_taken = 2
	aimed.hero_gauge = 40
	var aimed_outcome: Dictionary = ENGINE.resolve_enemy_turn(aimed, 0, 30, _seeded_rng())
	assert(int(aimed.enemies[0].actions_taken) == 3, "The aimed-shot call should be the archer's third action.")
	assert(int(aimed.hero_gauge) == 0, "A clear aimed shot should cut the target's action gauge by half the threshold, clamped at zero here since it started below fifty.")
	assert(Array(aimed_outcome.events).size() == 3 and str(aimed_outcome.events[0].type) == "technique", "Aimed shots should present their technique before attack and hit events.")
	assert(str(aimed_outcome.events[2].impact) == "normal", "Aimed shots should carry medium-strength impact feedback.")

	var regular := _fixture()
	regular.erase("ally")
	regular.enemies[0].role = "archer"
	regular.enemies[0].range = 4
	regular.enemies[0].x = 5
	regular.enemies[0].y = 1
	regular.enemies[0].actions_taken = 0
	var regular_outcome: Dictionary = ENGINE.resolve_enemy_turn(regular, 0, 30, _seeded_rng())
	assert(int(aimed_outcome.total_hurt) == int(regular_outcome.total_hurt) + 2, "Aimed shots should deal exactly two bonus damage with the same random roll.")

	var covered := _fixture()
	covered.erase("ally")
	covered.enemies[0].role = "archer"
	covered.enemies[0].range = 4
	covered.enemies[0].x = 5
	covered.enemies[0].y = 1
	covered.enemies[0].actions_taken = 2
	covered.hero_gauge = 80
	covered.blocked = [[3, 1]]
	ENGINE.resolve_enemy_turn(covered, 0, 30, _seeded_rng())
	assert(int(covered.hero_gauge) == 80, "Cover should prevent an aimed shot from applying any gauge penalty at all -- the shot never lands.")

func _test_brute_heavy_attack() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.enemies[0].role = "brute"
	battle.enemies[0].x = 2
	battle.enemies[0].y = 1
	battle.enemies[0].actions_taken = 1
	var outcome: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, 30, _seeded_rng())
	assert(int(battle.enemies[0].actions_taken) == 2, "The heavy-attack call should be the brute's second action.")
	assert(int(outcome.total_hurt) >= int(battle.enemies[0].attack) + 4, "Brutes should gain bonus damage on their telegraphed heavy turn.")
	assert(str(outcome.events.back().impact) == "heavy", "Brute heavy attacks should request high-strength impact feedback.")
	assert("重击" in str(battle.result), "Heavy attacks should be reported in the battle log.")

func _test_boss_phase_and_sweep() -> void:
	var battle := _fixture()
	battle.player_x = 1
	battle.player_y = 1
	battle.ally.x = 2
	battle.ally.y = 2
	battle.enemies[0] = {"name": "厉无咎", "role": "brute", "boss": true, "hp": 20, "max_hp": 46, "attack": 8, "range": 1, "x": 2, "y": 1, "speed": 8, "gauge": 0}
	var transition_outcome: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, 40, _seeded_rng())
	assert(bool(transition_outcome.boss_transition), "Crossing half health should emit exactly one boss phase transition.")
	assert("第二阶段" in str(battle.result), "The battle log should announce the phase transition.")
	assert(int(battle.enemies[0].actions_taken) == 1, "Entering phase 2 should restart the per-enemy action counter from 1, not continue accumulating the phase-1 count.")
	var second_outcome: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, int(transition_outcome.hero_hp), _seeded_rng())
	assert(not bool(second_outcome.boss_transition), "The boss phase transition must not repeat on later turns.")

	# 直接把行动次数拨到2（自增后变3），验证"每3次自己的行动扫荡一次"确实
	# 生效，不用真的把 resolve_enemy_turn() 连续调用三次。
	var sweep_battle := _fixture()
	sweep_battle.player_x = 1
	sweep_battle.player_y = 1
	sweep_battle.ally.x = 2
	sweep_battle.ally.y = 2
	sweep_battle.enemies[0] = {"name": "厉无咎", "role": "brute", "boss": true, "phase_two_started": true, "actions_taken": 2, "hp": 20, "max_hp": 46, "attack": 8, "range": 1, "x": 2, "y": 1, "speed": 8, "gauge": 0}
	var sweep_outcome: Dictionary = ENGINE.resolve_enemy_turn(sweep_battle, 0, 40, _seeded_rng())
	assert(int(sweep_battle.enemies[0].actions_taken) == 3, "The sweep-triggering call should be the boss's third action since entering phase 2.")
	assert(int(sweep_outcome.hero_hp) < 40 and int(sweep_battle.ally.hp) < 30, "The telegraphed sweep should hit every party member within two cells.")
	assert("断岳刀势" in str(sweep_battle.result), "The battle log should announce the signature sweep attack.")
	assert(Array(sweep_outcome.events).any(func(event: Dictionary): return str(event.get("type", "")) == "hit" and str(event.get("impact", "")) == "heavy"), "Boss sweeps should mark every damage event as a heavy impact.")

func _test_duelist_fast_movement() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.enemies[0].role = "duelist"
	var outcome: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, 20, _seeded_rng())
	assert(int(outcome.hero_hp) == 20, "A distant duelist should move instead of attacking.")
	assert(Vector2i(int(battle.enemies[0].x), int(battle.enemies[0].y)) == Vector2i(2, 1), "Duelists should advance up to two cells per enemy turn.")

## 行动条改版：battle.turn 现在表示"行动条轮回到沈羽的次数"，不再是共享
## 回合数——is_victory()/objective_text() 都是纯函数，直接摆弄 turn 数值
## 就能测试，不需要真的走一遍 advance_turn()/resolve_enemy_turn()。
func _test_survival_objective() -> void:
	var battle := _fixture()
	battle.objective = {"type": "survive", "rounds": 2}
	battle.turn = 0
	assert(not ENGINE.is_victory(battle), "A survival objective should not complete before the required rounds.")
	assert("0/2" in ENGINE.objective_text(battle), "Objective text should show initial survival progress.")
	battle.turn = 2
	assert(not ENGINE.is_victory(battle), "Reaching exactly the required hero-turn count should not yet trigger victory -- one more hero turn must start.")
	assert("2/2" in ENGINE.objective_text(battle), "Objective text should show completed survival progress once the required count is reached.")
	battle.turn = 3
	assert(ENGINE.is_victory(battle), "One hero turn beyond the requirement should complete the survival objective with enemies alive.")

## 行动条改版：resolve_enemy_turn() 本身不再重置沈羽的回合状态（那是
## advance_turn() 的职责）。这里的fixture身法全部相等，_living_units() 的
## 固定构建顺序 hero > ally > enemy:0 决定了平局的仲裁结果。
func _test_enemy_movement_and_turn_reset() -> void:
	var battle := _fixture()
	var outcome: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, 20, _seeded_rng())
	assert(int(outcome.hero_hp) == 20, "A distant enemy should move instead of damaging the hero.")
	assert(Vector2i(int(battle.enemies[0].x), int(battle.enemies[0].y)) == Vector2i(3, 1), "Enemies should advance one path step toward their target.")
	var winner := ENGINE.advance_turn(battle)
	assert(winner == "hero" and int(battle.action_points) == 2 and int(battle.turn) == 2, "With every unit's gauge untouched by resolve_enemy_turn(), advance_turn() should tie-break to the hero, refill their action points, and count this as their next turn.")

func _test_guard_and_ally_knockout() -> void:
	var battle := _fixture()
	battle.ally = {"name": "林清霜", "hp": 1, "guard": 4, "x": 3, "y": 1, "speed": 8, "gauge": 0}
	var outcome: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, 20, _seeded_rng())
	assert(bool(outcome.ally_defeated), "An ally reduced to zero health should be reported as knocked out.")
	assert(int(battle.ally.hp) == 0 and int(battle.ally.guard) == 0, "Guard should absorb damage before ally health and both should be clamped.")
	assert("倒地" in str(battle.result), "The combat log should clearly communicate an ally knockout.")
	var winner := ENGINE.advance_turn(battle)
	assert(winner == "hero", "With the ally knocked out (excluded from the living-units queue) and every remaining gauge untouched, control should reach the hero next.")

## 同伴换装备 (0.113.0) -- battle.ally.armor (来自 CompanionRules.
## apply_gear_and_move() 的护具加成) 应当跟沈羽自己的护甲一样，在敌方命中
## 时先行减免，再扣护卫。
func _test_ally_armor_mitigation() -> void:
	var unarmored_battle := _fixture()
	unarmored_battle.ally = {"name": "周慕白", "hp": 30, "max_hp": 30, "guard": 0, "armor": 0, "x": 3, "y": 1}
	var unarmored_outcome: Dictionary = ENGINE.resolve_enemy_turn(unarmored_battle, 0, 20, _seeded_rng())
	var armored_battle := _fixture()
	armored_battle.ally = {"name": "周慕白", "hp": 30, "max_hp": 30, "guard": 0, "armor": 3, "x": 3, "y": 1}
	var armored_outcome: Dictionary = ENGINE.resolve_enemy_turn(armored_battle, 0, 20, _seeded_rng())
	assert(int(armored_battle.ally.hp) == int(unarmored_battle.ally.hp) + 3, "Three points of ally armor should reduce the same seeded strike by exactly three, matching the hero's own armor-mitigation shape.")

## 同伴换轻功 (0.114.0) -- battle.ally.lightness_bonus should extend the
## dash's max range beyond the default two cells, same shape as the hero's
## own lightness bonus extending can_move_to()'s range.
func _test_ally_lightness_dash_range() -> void:
	var grounded_battle := _fixture()
	grounded_battle.active_unit = "ally"
	grounded_battle.action_points = 2
	grounded_battle.ally.x = 0
	grounded_battle.ally.y = 0
	grounded_battle.enemies[0].x = 3
	grounded_battle.enemies[0].y = 0
	var grounded_attempt: Dictionary = ENGINE.player_action(grounded_battle, _player_fixture(), "frost_dash", Vector2i(3, 0), _seeded_rng())
	assert(not bool(grounded_attempt.ok), "Three cells away should be out of reach for an un-boosted dash (max range two).")

	var winged_battle := _fixture()
	winged_battle.active_unit = "ally"
	winged_battle.action_points = 2
	winged_battle.ally.x = 0
	winged_battle.ally.y = 0
	winged_battle.ally.lightness_bonus = 1
	winged_battle.enemies[0].x = 3
	winged_battle.enemies[0].y = 0
	var winged_attempt: Dictionary = ENGINE.player_action(winged_battle, _player_fixture(), "frost_dash", Vector2i(3, 0), _seeded_rng())
	assert(bool(winged_attempt.ok), "A +1 lightness bonus should reach the same cell that was out of range without it.")

func _test_multi_target_feedback() -> void:
	var battle := _fixture()
	battle.player_x = 1
	battle.player_y = 1
	battle.ally.x = 2
	battle.ally.y = 2
	battle.ally.guard = 99
	battle.enemies[0] = {"name": "厉无咎", "role": "brute", "boss": true, "phase_two_started": true, "actions_taken": 2, "hp": 20, "max_hp": 46, "attack": 8, "range": 1, "x": 2, "y": 1, "speed": 8, "gauge": 0}
	ENGINE.resolve_enemy_turn(battle, 0, 40, _seeded_rng())
	assert(Array(battle.effects).size() == 2, "A sweeping attack should retain separate feedback for every target hit.")
	assert(Vector2i(int(battle.effects[0].x), int(battle.effects[0].y)) == Vector2i(1, 1), "Hero damage feedback should appear on the hero cell.")
	assert(Vector2i(int(battle.effects[1].x), int(battle.effects[1].y)) == Vector2i(2, 2), "Ally feedback should appear on the ally cell instead of being merged onto the hero.")
	assert(str(battle.effects[1].type) == "guard", "A fully blocked hit should be communicated as a guard result.")

func _test_enemy_event_sequence() -> void:
	var battle := _fixture()
	battle.erase("ally")
	var movement: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, 20, _seeded_rng())
	assert(Array(movement.events).size() == 1 and str(movement.events[0].type) == "move", "A distant enemy should emit one movement presentation event.")
	assert(Vector2i(movement.events[0].from) == Vector2i(4, 1) and Vector2i(movement.events[0].to) == Vector2i(3, 1), "Movement events should retain their exact origin and destination.")

	battle = _fixture()
	battle.erase("ally")
	battle.enemies[0].x = 2
	battle.enemies[0].y = 1
	var attack: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, 20, _seeded_rng())
	assert(Array(attack.events).size() == 2, "A direct enemy strike should emit an attack cue followed by its hit result.")
	assert(str(attack.events[0].type) == "attack" and str(attack.events[1].type) == "hit", "Enemy presentation events must preserve attack-before-impact ordering.")
	assert(Vector2i(attack.events[1].target) == Vector2i(1, 1), "The hit event should identify the actual target cell.")
	assert(str(attack.events[1].impact) == "light", "Regular enemy strikes should use light impact feedback.")

func _test_hero_defeat() -> void:
	var battle := _fixture()
	battle.erase("ally")
	battle.enemies[0].x = 2
	battle.enemies[0].y = 1
	var outcome: Dictionary = ENGINE.resolve_enemy_turn(battle, 0, 1, _seeded_rng())
	assert(bool(outcome.hero_defeated) and int(outcome.hero_hp) == 0, "Hero health should clamp to zero and report defeat.")
	assert(int(battle.turn) == 1, "resolve_enemy_turn() itself never touches battle.turn -- that's advance_turn()'s job, and the real caller (main.gd) stops calling it once the hero is defeated.")

## 行动条改版新增：直接验证身法驱动的出手顺序、同gauge时的固定优先级、
## 命中阈值后精确扣减而非清零、以及 preview_queue() 是不会误改真正battle
## 的纯函数。
func _test_turn_order_queue() -> void:
	var battle := _fixture()
	battle.hero_speed = 10
	battle.hero_gauge = 0
	battle.ally.speed = 5
	battle.ally.gauge = 0
	battle.enemies[0].speed = 20
	battle.enemies[0].gauge = 0
	battle.action_points = 2
	var first_winner := ENGINE.advance_turn(battle)
	assert(int(battle.action_points) == 0, "An enemy turn must not retain player action points.")
	var blocked_player := _player_fixture()
	battle.action_points = 2
	var battle_before := battle.duplicate(true)
	var player_before := blocked_player.duplicate(true)
	var blocked_action := ENGINE.player_action(battle, blocked_player, "attack", Vector2i(4, 1))
	assert(not bool(blocked_action.ok), "Player input must be rejected during an enemy turn, even with stale action points.")
	assert(battle == battle_before and blocked_player == player_before, "Rejected out-of-turn input must preserve all battle and player state.")
	assert(first_winner == "enemy:0", "The fastest unit (speed 20) should reach the action threshold first and act before anyone else.")
	assert(int(battle.enemies[0].gauge) == 0, "Acting should decrement the winner's gauge by exactly the threshold (100), and 20*5=100 leaves a clean zero remainder.")
	assert(int(battle.hero_gauge) == 50 and int(battle.ally.gauge) == 25, "Every other unit's gauge should have advanced by their own speed times the same number of ticks the winner needed.")

	# 完全同gauge时，_living_units() 的固定构建顺序 hero > ally > enemy:0
	# 决定谁赢——不依赖任何随机数，保证可复现。
	var tie_battle := _fixture()
	tie_battle.hero_speed = 10
	tie_battle.hero_gauge = 0
	tie_battle.ally.speed = 10
	tie_battle.ally.gauge = 0
	tie_battle.enemies[0].speed = 10
	tie_battle.enemies[0].gauge = 0
	assert(ENGINE.advance_turn(tie_battle) == "hero", "A perfect three-way speed tie should always resolve to the hero first, matching the fixed hero > ally > enemy priority.")

	# preview_queue() 是纯函数：连续调用两次（中间没有真正行动）必须返回
	# 完全一致的结果，且真正的battle字段一个字节都不该被改动。
	var preview_battle := _fixture()
	preview_battle.hero_speed = 7
	preview_battle.hero_gauge = 30
	preview_battle.ally.speed = 9
	preview_battle.ally.gauge = 10
	preview_battle.enemies[0].speed = 6
	preview_battle.enemies[0].gauge = 0
	var snapshot_before: Dictionary = preview_battle.duplicate(true)
	var first_preview: Array = ENGINE.preview_queue(preview_battle, 4)
	var second_preview: Array = ENGINE.preview_queue(preview_battle, 4)
	assert(first_preview == second_preview, "Two consecutive preview_queue() calls with no real turn taken between them must return identical results.")
	assert(first_preview.size() == 4, "preview_queue() should return exactly as many entries as requested while units remain alive.")
	assert(str(snapshot_before.hero_gauge) == str(preview_battle.hero_gauge) and str(snapshot_before.ally.gauge) == str(preview_battle.ally.gauge) and str(snapshot_before.enemies[0].gauge) == str(preview_battle.enemies[0].gauge), "preview_queue() must never mutate the real battle dict's gauge fields.")

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
		"hero_guard": 0,
		"action_points": 0,
		"hero_speed": 8,
		"hero_gauge": 0,
		"turn": 1,
		"blocked": [],
		"result": "",
		"ally": {"name": "林清霜", "hp": 30, "guard": 0, "qi": 15, "max_qi": 15, "attack": 5, "x": 1, "y": 3, "speed": 8, "gauge": 0},
		"enemies": [{"name": "剑客", "role": "melee", "hp": 10, "attack": 8, "range": 1, "x": 4, "y": 1, "speed": 8, "gauge": 0}]
	}

func _player_fixture() -> Dictionary:
	return {
		"strength": 4,
		"insight": 4,
		"xp": 0,
		"qi": 20,
		"skill_mastery": {"cloud": 0, "frost": 0, "frost_guard": 0},
		# 流云剑法/断岳刀法 became normal learnable moves (0.95.0), usable
		# without an equip step (0.104.0) -- most of this file's tests are
		# about damage formulas, not the learned gate itself, so the shared
		# fixture learns both by default. Tests specifically covering the
		# learned-move gate override this array.
		"learned_moves": ["cloud_sword", "blade_technique"]
	}
