extends SceneTree

const RULES := preload("res://scripts/battle/battle_rules.gd")

func _initialize() -> void:
	var battle := _fixture()
	assert(RULES.enemy_at(battle, Vector2i(4, 1)) == 0, "Living enemies should occupy their cells.")
	assert(RULES.enemy_at(battle, Vector2i(4, 3)) == -1, "Defeated enemies should not occupy their cells.")
	assert(RULES.is_ally_at(battle, Vector2i(1, 2)), "A living ally should occupy its cell.")
	assert(RULES.is_blocked(battle, Vector2i(-1, 0)), "Cells outside the board should be blocked.")
	assert(RULES.is_blocked(battle, Vector2i(2, 1)), "Terrain cells should be blocked.")

	assert(RULES.can_move_to(battle, Vector2i(1, 0)), "A nearby empty cell should be reachable.")
	assert(not RULES.can_move_to(battle, Vector2i(2, 1)), "Units cannot move onto blocked terrain.")
	assert(not RULES.can_move_to(battle, Vector2i(1, 2)), "Units cannot move onto an ally.")
	assert(not RULES.can_move_to(battle, Vector2i(4, 1)), "Units cannot move onto an enemy.")

	battle.enemies[0].x = 1
	battle.enemies[0].y = 0
	assert(RULES.can_attack_cell(battle, Vector2i(1, 0), false, 0), "Normal attacks should hit adjacent enemies.")
	battle.enemies[0].x = 1
	battle.enemies[0].y = 4
	battle.ally.x = 0
	battle.ally.y = 2
	assert(RULES.can_attack_cell(battle, Vector2i(1, 4), true, 8), "Hero skills should hit aligned enemies within three cells.")
	assert(not RULES.can_attack_cell(battle, Vector2i(1, 4), true, 7), "Hero skills should enforce their qi cost.")
	battle.blocked.append([1, 2])
	assert(not RULES.can_attack_cell(battle, Vector2i(1, 4), true, 8), "Skills should not pass through blocked terrain.")
	battle.blocked.clear()
	battle.enemies[0].x = 5
	battle.enemies[0].y = 1
	battle.enemies[0].range = 4
	assert(RULES.can_enemy_attack(battle, battle.enemies[0], Vector2i(1, 1)), "A ranged enemy should attack along a clear line within range.")
	battle.blocked.append([3, 1])
	assert(not RULES.can_enemy_attack(battle, battle.enemies[0], Vector2i(1, 1)), "Terrain should block ranged enemy attacks.")
	battle.blocked.clear()

	battle.active_unit = "ally"
	battle.ally.x = 1
	battle.ally.y = 2
	battle.enemies[0].x = 3
	battle.enemies[0].y = 2
	assert(RULES.can_frost_dash(battle, Vector2i(3, 2)), "The ally dash should reach an enemy within two path steps.")
	RULES.set_active_position(battle, Vector2i(2, 2))
	assert(Vector2i(int(battle.ally.x), int(battle.ally.y)) == Vector2i(2, 2), "Moving the active ally should not move the hero.")

	battle.ally.x = 3
	battle.ally.y = 2
	battle.enemies[0].x = 4
	battle.enemies[0].y = 2
	battle.enemies[0].range = 1
	battle.enemies[0].role = "brute"
	battle.turn = 2
	var preview: String = RULES.enemy_preview(battle)
	assert("蓄力重击林清霜" in preview, "Enemy previews should identify a brute's target and heavy attack.")
	assert(RULES.enemy_move_steps({"role": "duelist"}) == 2, "Duelists should have a two-cell movement allowance.")
	var boss := {"name": "厉无咎", "role": "brute", "boss": true, "hp": 20, "max_hp": 46, "x": 3, "y": 2}
	battle.enemies = [boss]
	battle.turn = 3
	assert(RULES.boss_phase(boss) == 2 and RULES.enemy_move_steps(boss) == 2, "A half-health boss should enter phase two and move faster.")
	assert(RULES.is_boss_sweep_turn(battle, boss), "The phase-two boss should telegraph a sweep every third turn.")
	assert(RULES.in_boss_sweep_range(boss, Vector2i(1, 2)) and not RULES.in_boss_sweep_range(boss, Vector2i(0, 2)), "The boss sweep should have an exact two-cell Manhattan radius.")
	assert(RULES.is_boss_sweep_cell(battle, Vector2i(1, 2)) and not RULES.is_boss_sweep_cell(battle, Vector2i(0, 2)), "Battle cells should expose the telegraphed sweep danger zone to the UI.")
	assert("立即撤离" in RULES.enemy_preview(battle), "The boss sweep preview should clearly teach its counterplay.")

	print("BattleRules tests passed.")
	quit()

func _fixture() -> Dictionary:
	return {
		"width": 6,
		"height": 5,
		"player_x": 1,
		"player_y": 1,
		"active_unit": "hero",
		"blocked": [[2, 1]],
		"ally": {"name": "林清霜", "hp": 30, "qi": 15, "x": 1, "y": 2},
		"enemies": [
			{"name": "剑客", "role": "melee", "hp": 10, "range": 1, "x": 4, "y": 1},
			{"name": "败兵", "hp": 0, "range": 1, "x": 4, "y": 3}
		]
	}
