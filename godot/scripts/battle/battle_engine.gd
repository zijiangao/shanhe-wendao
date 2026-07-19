class_name BattleEngine
extends RefCounted

const RULES := preload("res://scripts/battle/battle_rules.gd")
const GROWTH_RULES := preload("res://scripts/progression/growth_rules.gd")

static func is_victory(battle: Dictionary) -> bool:
	if str(battle.get("objective", {}).get("type", "eliminate")) == "survive":
		var required_rounds := maxi(1, int(battle.objective.get("rounds", 1)))
		if int(battle.get("turn", 1)) > required_rounds:
			return true
	for enemy in battle.enemies:
		if int(enemy.hp) > 0:
			return false
	return true

static func objective_text(battle: Dictionary) -> String:
	var objective: Dictionary = battle.get("objective", {"type": "eliminate"})
	if str(objective.get("type", "eliminate")) == "survive":
		var required_rounds := maxi(1, int(objective.get("rounds", 1)))
		var completed_rounds := mini(required_rounds, maxi(0, int(battle.get("turn", 1)) - 1))
		return "坚持回合 %d/%d（或提前击败所有对手）" % [completed_rounds, required_rounds]
	return "击败所有敌人"

static func player_action(battle: Dictionary, player: Dictionary, action: String, target: Vector2i = Vector2i.ZERO, rng: RandomNumberGenerator = null) -> Dictionary:
	if int(battle.ap) <= 0:
		return _failure("行动点已用尽，请结束回合。")
	match action:
		"move":
			return _move(battle, target)
		"attack":
			return _attack(battle, player, target, rng)
		"skill":
			return _cloud_skill(battle, player, target, rng)
		"frost_dash":
			return _frost_dash(battle, player, target, rng)
		"frost_guard":
			return _frost_guard(battle, player)
		_:
			return _failure("未知战斗行动：%s" % action)

static func _move(battle: Dictionary, target: Vector2i) -> Dictionary:
	if not RULES.can_move_to(battle, target):
		return _failure("只能移动到两格内的空地。")
	var active_name := _active_name(battle)
	RULES.set_active_position(battle, target)
	battle.ap = int(battle.ap) - 1
	battle.result = "%s施展身法，移动到新的位置。" % active_name
	_clear_effect(battle)
	return _success(battle, 0)

static func _attack(battle: Dictionary, player: Dictionary, target: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	if not RULES.can_attack_cell(battle, target, false, int(player.qi)):
		return _failure("普通攻击只能命中相邻敌人。")
	var enemy_index := RULES.enemy_at(battle, target)
	var base_damage := int(battle.ally.attack) + 2 if str(battle.get("active_unit", "hero")) == "ally" else int(player.strength) + 3 + GROWTH_RULES.combat_bonus(int(player.get("xp", 0))) + int(player.get("bladesmanship", 0)) / 2
	var armor := RULES.enemy_armor(battle.enemies[enemy_index])
	var damage := maxi(1, base_damage + _roll_bonus(rng) - armor)
	_apply_enemy_damage(battle, enemy_index, target, damage, "damage")
	var target_survived := int(battle.enemies[enemy_index].hp) > 0
	if target_survived:
		battle.enemies[enemy_index].exposure = mini(2, RULES.enemy_exposure(battle.enemies[enemy_index]) + 1)
	battle.ap = int(battle.ap) - 1
	var armor_note := "（护甲抵消%d）" % armor if armor > 0 else ""
	var exposure_note := "，并制造1层破绽" if target_survived else ""
	battle.result = "%s对%s造成%d点伤害%s%s。" % [_active_name(battle), battle.enemies[enemy_index].name, damage, armor_note, exposure_note]
	battle.skill_flash = false
	battle.skill_name = ""
	return _success(battle, damage)

static func _cloud_skill(battle: Dictionary, player: Dictionary, target: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	if str(battle.get("active_unit", "hero")) == "ally":
		return _failure("林清霜无法施展流云剑法。")
	if not RULES.can_attack_cell(battle, target, true, int(player.qi)):
		return _failure("流云剑法需要8点真气，并只能攻击同一直线三格内的敌人。")
	var enemy_index := RULES.enemy_at(battle, target)
	var exposure := RULES.enemy_exposure(battle.enemies[enemy_index])
	var exposure_bonus := exposure * 4
	var damage := int(player.strength) + 9 + int(player.get("insight", 0) / 2) + GROWTH_RULES.combat_bonus(int(player.get("xp", 0))) + int(player.get("swordsmanship", 0)) / 2 + int(player.skill_mastery.cloud / 3) + exposure_bonus + _roll_range(rng, 0, 3)
	player.qi = int(player.qi) - 8
	player.skill_mastery.cloud = int(player.skill_mastery.cloud) + 1
	battle.enemies[enemy_index].exposure = 0
	_apply_enemy_damage(battle, enemy_index, target, damage, "skill")
	battle.ap = int(battle.ap) - 1
	var exposure_note := "，引爆%d层破绽追加%d点" % [exposure, exposure_bonus] if exposure > 0 else ""
	battle.result = "流云剑气无视护甲，对%s造成%d点伤害%s！" % [battle.enemies[enemy_index].name, damage, exposure_note]
	battle.skill_flash = true
	battle.skill_name = "流 云 剑 法"
	return _success(battle, damage)

static func _frost_dash(battle: Dictionary, player: Dictionary, target: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	if not RULES.can_frost_dash(battle, target):
		return _failure("霜华刺需要6点真气，并只能突进攻击两格内的敌人。")
	var enemy_index := RULES.enemy_at(battle, target)
	var damage := int(battle.ally.attack) + 6 + int(player.skill_mastery.frost / 3) + _roll_bonus(rng)
	battle.ally.qi = int(battle.ally.qi) - 6
	player.skill_mastery.frost = int(player.skill_mastery.frost) + 1
	_apply_enemy_damage(battle, enemy_index, target, damage, "skill")
	var path := RULES.find_path(battle, Vector2i(int(battle.ally.x), int(battle.ally.y)), target, true)
	if path.size() >= 2:
		battle.ally.x = path[path.size() - 2].x
		battle.ally.y = path[path.size() - 2].y
	battle.ap = int(battle.ap) - 1
	battle.result = "林清霜踏雪突进，以霜华刺对%s造成%d点伤害！" % [battle.enemies[enemy_index].name, damage]
	battle.skill_flash = true
	battle.skill_name = "霜 华 刺"
	return _success(battle, damage)

static func _frost_guard(battle: Dictionary, player: Dictionary) -> Dictionary:
	if str(battle.get("active_unit", "hero")) != "ally" or not battle.has("ally") or int(battle.ally.hp) <= 0:
		return _failure("需要由林清霜行动才能施展寒锋守势。")
	battle.ally.guard = 8 + int(player.skill_mastery.frost_guard / 3)
	battle.ally.qi = mini(int(battle.ally.max_qi), int(battle.ally.qi) + 3)
	player.skill_mastery.frost_guard = int(player.skill_mastery.frost_guard) + 1
	battle.ap = int(battle.ap) - 1
	battle.result = "林清霜横剑凝神，获得%d点护卫并恢复3点真气。" % battle.ally.guard
	_clear_effect(battle)
	battle.skill_flash = true
	battle.skill_name = "寒 锋 守 势"
	return _success(battle, 0)

static func enemy_turn(battle: Dictionary, hero_hp: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var total_hurt := 0
	var special_notes: PackedStringArray = []
	var ally_was_active := battle.has("ally") and int(battle.ally.hp) > 0
	var boss_transition := false
	var suppressed := false
	var effects: Array = []
	var events: Array = []
	for enemy in battle.enemies:
		if int(enemy.hp) <= 0:
			continue
		if bool(enemy.get("boss", false)) and RULES.boss_phase(enemy) == 2 and not bool(enemy.get("phase_two_started", false)):
			enemy.phase_two_started = true
			boss_transition = true
			special_notes.append("%s震碎刀鞘，进入第二阶段“断岳”" % str(enemy.name))
			events.append({"type": "technique", "actor": str(enemy.name), "text": "断 岳 · 第 二 阶 段"})
		if RULES.is_boss_sweep_turn(battle, enemy):
			events.append({"type": "technique", "actor": str(enemy.name), "text": "断 岳 刀 势"})
			var sweep_damage := int(enemy.attack) + 2 + _roll_bonus(rng)
			var sweep_hits := 0
			if RULES.in_boss_sweep_range(enemy, Vector2i(int(battle.player_x), int(battle.player_y))):
				hero_hp = maxi(0, hero_hp - sweep_damage)
				total_hurt += sweep_damage
				sweep_hits += 1
				effects.append(_damage_effect(Vector2i(int(battle.player_x), int(battle.player_y)), sweep_damage))
				events.append(_hit_event(str(enemy.name), "沈羽", Vector2i(int(battle.player_x), int(battle.player_y)), sweep_damage, 0, "heavy"))
			if battle.has("ally") and int(battle.ally.hp) > 0 and RULES.in_boss_sweep_range(enemy, Vector2i(int(battle.ally.x), int(battle.ally.y))):
				var ally_hurt := sweep_damage
				var blocked := mini(ally_hurt, int(battle.ally.guard))
				ally_hurt -= blocked
				battle.ally.guard = maxi(0, int(battle.ally.guard) - blocked)
				battle.ally.hp = maxi(0, int(battle.ally.hp) - ally_hurt)
				total_hurt += ally_hurt
				sweep_hits += 1
				effects.append(_damage_effect(Vector2i(int(battle.ally.x), int(battle.ally.y)), ally_hurt, blocked))
				events.append(_hit_event(str(enemy.name), str(battle.ally.name), Vector2i(int(battle.ally.x), int(battle.ally.y)), ally_hurt, blocked, "heavy"))
			special_notes.append("%s施展断岳刀势，命中%d人" % [str(enemy.name), sweep_hits])
			continue
		var target_data := select_target(battle, enemy)
		var target: Vector2i = target_data.position
		var target_is_ally: bool = target_data.is_ally
		var enemy_position := Vector2i(int(enemy.x), int(enemy.y))
		if RULES.can_enemy_attack(battle, enemy, target):
			var heavy_attack := RULES.is_heavy_turn(battle, enemy)
			var aimed_shot := RULES.is_aimed_shot_turn(battle, enemy)
			if aimed_shot:
				events.append({"type": "technique", "actor": str(enemy.name), "text": "穿 云 箭"})
			events.append({"type": "attack", "actor": str(enemy.name), "position": enemy_position, "text": "蓄力重击" if heavy_attack else ("穿云箭" if aimed_shot else "发动攻击")})
			var hurt := int(enemy.attack) + _roll_bonus(rng) + (4 if heavy_attack else 0) + (2 if aimed_shot else 0)
			if heavy_attack:
				special_notes.append("%s发动重击" % str(enemy.name))
			if aimed_shot:
				suppressed = true
				special_notes.append("%s施展穿云箭，压制下回合行动" % str(enemy.name))
			if target_is_ally:
				var blocked := mini(hurt, int(battle.ally.guard))
				hurt -= blocked
				battle.ally.guard = maxi(0, int(battle.ally.guard) - blocked)
				battle.ally.hp = maxi(0, int(battle.ally.hp) - hurt)
				effects.append(_damage_effect(target, hurt, blocked))
				events.append(_hit_event(str(enemy.name), str(battle.ally.name), target, hurt, blocked, "heavy" if heavy_attack else ("normal" if aimed_shot else "light")))
			else:
				hero_hp = maxi(0, hero_hp - hurt)
				effects.append(_damage_effect(target, hurt))
				events.append(_hit_event(str(enemy.name), "沈羽", target, hurt, 0, "heavy" if heavy_attack else ("normal" if aimed_shot else "light")))
			total_hurt += hurt
		else:
			var path := RULES.find_path(battle, enemy_position, target, true)
			if path.size() > 1:
				var move_index := mini(RULES.enemy_move_steps(enemy), path.size() - 2)
				if move_index >= 1:
					var destination: Vector2i = path[move_index]
					events.append({"type": "move", "actor": str(enemy.name), "from": enemy_position, "to": destination})
					enemy.x = path[move_index].x
					enemy.y = path[move_index].y

	battle.effects = effects
	battle.effect = effects.back() if not effects.is_empty() else {}
	var hero_defeated := hero_hp <= 0
	var ally_defeated := ally_was_active and battle.has("ally") and int(battle.ally.hp) <= 0
	if not hero_defeated:
		battle.turn = int(battle.turn) + 1
		battle.ap = 1 if suppressed else 2
		battle.active_unit = "hero"
		battle.result = _turn_result(total_hurt, ally_defeated, special_notes)
		battle.skill_flash = boss_transition
		battle.skill_name = "断 岳 刀 势" if boss_transition else ""
	return {
		"battle": battle,
		"hero_hp": hero_hp,
		"hero_defeated": hero_defeated,
		"ally_defeated": ally_defeated,
		"total_hurt": total_hurt,
		"boss_transition": boss_transition,
		"suppressed": suppressed,
		"events": events
	}

static func select_target(battle: Dictionary, enemy: Dictionary) -> Dictionary:
	return RULES.enemy_target(battle, enemy)

static func _distance(from: Vector2i, to: Vector2i) -> int:
	return absi(from.x - to.x) + absi(from.y - to.y)

static func _roll_bonus(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, 2) if rng != null else randi_range(0, 2)

static func _roll_range(rng: RandomNumberGenerator, minimum: int, maximum: int) -> int:
	return rng.randi_range(minimum, maximum) if rng != null else randi_range(minimum, maximum)

static func _active_name(battle: Dictionary) -> String:
	return "林清霜" if str(battle.get("active_unit", "hero")) == "ally" else "沈羽"

static func _apply_enemy_damage(battle: Dictionary, enemy_index: int, target: Vector2i, damage: int, effect_type: String) -> void:
	battle.enemies[enemy_index].hp = maxi(0, int(battle.enemies[enemy_index].hp) - damage)
	battle.effect = {"x": target.x, "y": target.y, "text": "-%d" % damage, "type": effect_type}
	battle.effects = [battle.effect]

static func _damage_effect(target: Vector2i, damage: int, blocked: int = 0) -> Dictionary:
	if damage <= 0 and blocked > 0:
		return {"x": target.x, "y": target.y, "text": "格挡", "type": "guard"}
	var text := "-%d" % damage
	if blocked > 0:
		text += "  挡%d" % blocked
	return {"x": target.x, "y": target.y, "text": text, "type": "damage"}

static func _hit_event(actor: String, target_name: String, target: Vector2i, damage: int, blocked: int = 0, impact: String = "normal") -> Dictionary:
	return {
		"type": "hit",
		"actor": actor,
		"target_name": target_name,
		"target": target,
		"damage": damage,
		"blocked": blocked,
		"impact": impact
	}

static func _clear_effect(battle: Dictionary) -> void:
	battle.effect = {}
	battle.effects = []
	battle.skill_flash = false
	battle.skill_name = ""

static func _success(battle: Dictionary, damage: int) -> Dictionary:
	return {"ok": true, "battle": battle, "damage": damage, "error": ""}

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _turn_result(total_hurt: int, ally_defeated: bool, special_notes: PackedStringArray) -> String:
	var message := "敌方行动结束。你方受到%d点伤害。" % total_hurt
	if not special_notes.is_empty():
		message += " %s。" % "；".join(special_notes)
	if ally_defeated:
		message += " 林清霜力竭倒地，本场战斗无法继续行动。"
	return message
