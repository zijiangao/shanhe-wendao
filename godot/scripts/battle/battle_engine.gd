class_name BattleEngine
extends RefCounted

const RULES := preload("res://scripts/battle/battle_rules.gd")
const GROWTH_RULES := preload("res://scripts/progression/growth_rules.gd")
const TRAINING_RULES := preload("res://scripts/progression/training_minigame_rules.gd")
const BLADE_QI_COST := 6

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

static func normal_damage_range(player: Dictionary) -> Vector2i:
	var base := int(player.get("strength", 0)) + 3 + GROWTH_RULES.combat_bonus(int(player.get("xp", 0))) + int(player.get("bladesmanship", 0)) / 2 + int(player.get("forge_level", 0))
	return Vector2i(base, base + 2)

static func cloud_damage_range(player: Dictionary) -> Vector2i:
	var base := int(player.get("strength", 0)) + 9 + int(player.get("insight", 0)) / 2 + GROWTH_RULES.combat_bonus(int(player.get("xp", 0))) + int(player.get("swordsmanship", 0)) / 2 + int(player.get("forge_level", 0)) + int(player.get("skill_mastery", {}).get("cloud", 0)) / 3
	return Vector2i(base, base + 3)

static func blade_damage_range(player: Dictionary) -> Vector2i:
	var base := int(player.get("strength", 0)) + 7 + GROWTH_RULES.combat_bonus(int(player.get("xp", 0))) + int(player.get("bladesmanship", 0)) / 2 + int(player.get("forge_level", 0))
	return Vector2i(base, base + 3)

static func blade_armor_break(player: Dictionary) -> int:
	return 2 if int(player.get("bladesmanship", 0)) >= 6 else 1

static func healing_amount(player: Dictionary) -> int:
	var herbalism := int(player.get("herbalism", 0))
	return 12 + herbalism / 2 + TRAINING_RULES.medicine_mastery_bonus(herbalism)

static func hero_guard_amount(player: Dictionary) -> int:
	return 6 + int(player.get("constitution", 0)) / 2

static func hero_action_help(player: Dictionary) -> String:
	var normal := normal_damage_range(player)
	var cloud := cloud_damage_range(player)
	var blade := blade_damage_range(player)
	var exposure := TRAINING_RULES.attack_exposure_gain(int(player.get("bladesmanship", 0)))
	var qi_cost := TRAINING_RULES.cloud_qi_cost(int(player.get("swordsmanship", 0)))
	return "普攻 %d–%d（护甲前）· 命中制造%d层破绽\n剑法 %d–%d（无视护甲）· 引爆破绽 · %d真气\n刀法 %d–%d（相邻）· 永久破甲%d · %d真气\n护体%d并回3气 · 回春散恢复%d气血" % [normal.x, normal.y, exposure, cloud.x, cloud.y, qi_cost, blade.x, blade.y, blade_armor_break(player), BLADE_QI_COST, hero_guard_amount(player), healing_amount(player)]

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
		"blade_skill":
			return _blade_skill(battle, player, target, rng)
		"frost_dash":
			return _frost_dash(battle, player, target, rng)
		"frost_guard":
			return _frost_guard(battle, player)
		"heal":
			return _use_healing_powder(battle, player)
		"thunder_stone":
			return _use_thunder_stone(battle, player, target, rng)
		"brace":
			return _hero_brace(battle, player)
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
	var base_damage := int(battle.ally.attack) + 2 if str(battle.get("active_unit", "hero")) == "ally" else int(player.strength) + 3 + GROWTH_RULES.combat_bonus(int(player.get("xp", 0))) + int(player.get("bladesmanship", 0)) / 2 + int(player.get("forge_level", 0))
	var armor := RULES.enemy_armor(battle.enemies[enemy_index])
	var damage := maxi(1, base_damage + _roll_bonus(rng) - armor)
	_apply_enemy_damage(battle, enemy_index, target, damage, "damage")
	var target_survived := int(battle.enemies[enemy_index].hp) > 0
	if target_survived:
		battle.enemies[enemy_index].exposure = mini(2, RULES.enemy_exposure(battle.enemies[enemy_index]) + TRAINING_RULES.attack_exposure_gain(int(player.get("bladesmanship", 0))))
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
	var qi_cost := TRAINING_RULES.cloud_qi_cost(int(player.get("swordsmanship", 0)))
	if not RULES.can_attack_cell(battle, target, true, int(player.qi), qi_cost):
		return _failure("流云剑法需要%d点真气，并只能攻击同一直线三格内的敌人。" % qi_cost)
	var enemy_index := RULES.enemy_at(battle, target)
	var exposure := RULES.enemy_exposure(battle.enemies[enemy_index])
	var exposure_bonus := exposure * 4
	var damage := int(player.strength) + 9 + int(player.get("insight", 0) / 2) + GROWTH_RULES.combat_bonus(int(player.get("xp", 0))) + int(player.get("swordsmanship", 0)) / 2 + int(player.get("forge_level", 0)) + int(player.skill_mastery.cloud / 3) + exposure_bonus + _roll_range(rng, 0, 3)
	player.qi = int(player.qi) - qi_cost
	player.skill_mastery.cloud = int(player.skill_mastery.cloud) + 1
	battle.enemies[enemy_index].exposure = 0
	_apply_enemy_damage(battle, enemy_index, target, damage, "skill")
	battle.ap = int(battle.ap) - 1
	var exposure_note := "，引爆%d层破绽追加%d点" % [exposure, exposure_bonus] if exposure > 0 else ""
	battle.result = "流云剑气无视护甲，对%s造成%d点伤害%s！" % [battle.enemies[enemy_index].name, damage, exposure_note]
	battle.skill_flash = true
	battle.skill_name = "流 云 剑 法"
	return _success(battle, damage)

static func _blade_skill(battle: Dictionary, player: Dictionary, target: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	if str(battle.get("active_unit", "hero")) == "ally":
		return _failure("林清霜无法施展断岳刀法。")
	if int(player.get("qi", 0)) < BLADE_QI_COST or not RULES.can_attack_cell(battle, target, false, int(player.get("qi", 0))):
		return _failure("断岳刀法需要%d点真气，并只能攻击相邻敌人。" % BLADE_QI_COST)
	var enemy_index := RULES.enemy_at(battle, target)
	var old_armor := RULES.enemy_armor(battle.enemies[enemy_index])
	var armor_break := mini(old_armor, blade_armor_break(player))
	var remaining_armor := maxi(0, old_armor - armor_break)
	var damage_range := blade_damage_range(player)
	var damage := maxi(1, damage_range.x + _roll_range(rng, 0, damage_range.y - damage_range.x) - remaining_armor)
	player.qi = int(player.qi) - BLADE_QI_COST
	battle.enemies[enemy_index].armor = remaining_armor
	_apply_enemy_damage(battle, enemy_index, target, damage, "skill")
	if int(battle.enemies[enemy_index].hp) > 0:
		battle.enemies[enemy_index].exposure = 2
	battle.ap = int(battle.ap) - 1
	battle.result = "断岳刀势劈中%s，造成%d点伤害，永久削去%d点护甲并制造2层破绽！" % [battle.enemies[enemy_index].name, damage, armor_break]
	battle.skill_flash = true
	battle.skill_name = "断 岳 刀 法"
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

static func _use_healing_powder(battle: Dictionary, player: Dictionary) -> Dictionary:
	if str(battle.get("active_unit", "hero")) != "hero":
		return _failure("回春散只能由沈羽使用。")
	if int(player.get("hp", 0)) >= int(player.get("max_hp", 1)):
		return _failure("当前气血已满，无需服药。")
	var consumables: Dictionary = player.get("consumables", {})
	if int(consumables.get("healing_powder", 0)) <= 0:
		return _failure("行囊中没有回春散。")
	var healing := healing_amount(player)
	var before := int(player.hp)
	player.hp = mini(int(player.max_hp), before + healing)
	player.consumables.healing_powder = int(player.consumables.healing_powder) - 1
	battle.ap = int(battle.ap) - 1
	battle.result = "沈羽服下回春散，恢复%d点气血。" % (int(player.hp) - before)
	_clear_effect(battle)
	return {"ok": true, "battle": battle, "damage": 0, "healed": int(player.hp) - before, "error": ""}

static func _use_thunder_stone(battle: Dictionary, player: Dictionary, target: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	if str(battle.get("active_unit", "hero")) != "hero":
		return _failure("霹雳石只能由沈羽使用。")
	var consumables: Dictionary = player.get("consumables", {})
	if int(consumables.get("thunder_stone", 0)) <= 0:
		return _failure("行囊中没有霹雳石。")
	if not RULES.can_attack_cell(battle, target, true, 1, 0):
		return _failure("霹雳石只能投向同一直线三格内的敌人。")
	var enemy_index := RULES.enemy_at(battle, target)
	var old_armor := RULES.enemy_armor(battle.enemies[enemy_index])
	var damage := 8 + int(player.get("mining", 0)) / 2 + TRAINING_RULES.gathering_bonus(int(player.get("mining", 0))) + _roll_range(rng, 0, 2)
	player.consumables.thunder_stone = int(player.consumables.thunder_stone) - 1
	battle.enemies[enemy_index].armor = maxi(0, old_armor - 1)
	_apply_enemy_damage(battle, enemy_index, target, damage, "skill")
	battle.ap = int(battle.ap) - 1
	battle.result = "霹雳石命中%s，造成%d点伤害并削去1点护甲！" % [battle.enemies[enemy_index].name, damage]
	battle.skill_flash = true
	battle.skill_name = "霹 雳 石"
	return _success(battle, damage)

static func _hero_brace(battle: Dictionary, player: Dictionary) -> Dictionary:
	if str(battle.get("active_unit", "hero")) != "hero":
		return _failure("运气护体只能由沈羽施展。")
	var guard := hero_guard_amount(player)
	battle.hero_guard = guard
	var restored := mini(20, int(player.get("qi", 0)) + 3) - int(player.get("qi", 0))
	player.qi = int(player.get("qi", 0)) + restored
	battle.ap = int(battle.ap) - 1
	battle.result = "沈羽运气护体，获得%d点护体并恢复%d点真气。" % [guard, restored]
	_clear_effect(battle)
	battle.skill_flash = true
	battle.skill_name = "运 气 护 体"
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
				var hero_blocked := mini(sweep_damage, maxi(0, int(battle.get("hero_guard", 0))))
				var hero_hurt := sweep_damage - hero_blocked
				battle.hero_guard = maxi(0, int(battle.get("hero_guard", 0)) - hero_blocked)
				hero_hp = maxi(0, hero_hp - hero_hurt)
				total_hurt += hero_hurt
				sweep_hits += 1
				effects.append(_damage_effect(Vector2i(int(battle.player_x), int(battle.player_y)), hero_hurt, hero_blocked))
				events.append(_hit_event(str(enemy.name), "沈羽", Vector2i(int(battle.player_x), int(battle.player_y)), hero_hurt, hero_blocked, "heavy"))
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
				var hero_blocked := mini(hurt, maxi(0, int(battle.get("hero_guard", 0))))
				hurt -= hero_blocked
				battle.hero_guard = maxi(0, int(battle.get("hero_guard", 0)) - hero_blocked)
				hero_hp = maxi(0, hero_hp - hurt)
				effects.append(_damage_effect(target, hurt, hero_blocked))
				events.append(_hit_event(str(enemy.name), "沈羽", target, hurt, hero_blocked, "heavy" if heavy_attack else ("normal" if aimed_shot else "light")))
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
