class_name BattleEngine
extends RefCounted

const RULES := preload("res://scripts/battle/battle_rules.gd")

static func is_victory(battle: Dictionary) -> bool:
	for enemy in battle.enemies:
		if int(enemy.hp) > 0:
			return false
	return true

static func enemy_turn(battle: Dictionary, hero_hp: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var total_hurt := 0
	var ally_was_active := battle.has("ally") and int(battle.ally.hp) > 0
	for enemy in battle.enemies:
		if int(enemy.hp) <= 0:
			continue
		var target_data := select_target(battle, enemy)
		var target: Vector2i = target_data.position
		var target_is_ally: bool = target_data.is_ally
		var enemy_position := Vector2i(int(enemy.x), int(enemy.y))
		var distance := _distance(enemy_position, target)
		if distance == 1:
			var hurt := int(enemy.attack) + _roll_bonus(rng)
			if target_is_ally:
				var blocked := mini(hurt, int(battle.ally.guard))
				hurt -= blocked
				battle.ally.guard = maxi(0, int(battle.ally.guard) - blocked)
				battle.ally.hp = maxi(0, int(battle.ally.hp) - hurt)
			else:
				hero_hp = maxi(0, hero_hp - hurt)
			total_hurt += hurt
		else:
			var path := RULES.find_path(battle, enemy_position, target, true)
			if path.size() > 1:
				enemy.x = path[1].x
				enemy.y = path[1].y

	var hero_defeated := hero_hp <= 0
	var ally_defeated := ally_was_active and battle.has("ally") and int(battle.ally.hp) <= 0
	if not hero_defeated:
		battle.turn = int(battle.turn) + 1
		battle.ap = 2
		battle.active_unit = "hero"
		battle.result = _turn_result(total_hurt, ally_defeated)
		battle.effect = {"x": battle.player_x, "y": battle.player_y, "text": "-%d" % total_hurt, "type": "damage"} if total_hurt > 0 else {}
		battle.skill_flash = false
	return {
		"battle": battle,
		"hero_hp": hero_hp,
		"hero_defeated": hero_defeated,
		"ally_defeated": ally_defeated,
		"total_hurt": total_hurt
	}

static func select_target(battle: Dictionary, enemy: Dictionary) -> Dictionary:
	var enemy_position := Vector2i(int(enemy.x), int(enemy.y))
	var target := Vector2i(int(battle.player_x), int(battle.player_y))
	var target_is_ally := false
	var distance := _distance(enemy_position, target)
	if battle.has("ally") and int(battle.ally.hp) > 0:
		var ally_target := Vector2i(int(battle.ally.x), int(battle.ally.y))
		var ally_distance := _distance(enemy_position, ally_target)
		if ally_distance < distance:
			target = ally_target
			target_is_ally = true
	return {"position": target, "is_ally": target_is_ally}

static func _distance(from: Vector2i, to: Vector2i) -> int:
	return absi(from.x - to.x) + absi(from.y - to.y)

static func _roll_bonus(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, 2) if rng != null else randi_range(0, 2)

static func _turn_result(total_hurt: int, ally_defeated: bool) -> String:
	var message := "敌方行动结束。你方受到%d点伤害。" % total_hurt
	if ally_defeated:
		message += " 林清霜力竭倒地，本场战斗无法继续行动。"
	return message
