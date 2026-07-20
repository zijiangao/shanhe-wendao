extends Node

const DIFFICULTY_RULES := preload("res://scripts/battle/difficulty_rules.gd")
const GROWTH_RULES := preload("res://scripts/progression/growth_rules.gd")
const ENCOUNTER_RULES := preload("res://scripts/battle/encounter_rules.gd")
const REWARD_RULES := preload("res://scripts/progression/reward_rules.gd")
const TRAINING_RULES := preload("res://scripts/progression/training_minigame_rules.gd")
const TRAINING_EVENT_RULES := preload("res://scripts/progression/training_event_rules.gd")
const SPARRING_RULES := preload("res://scripts/progression/sparring_rules.gd")
const CRAFTING_RULES := preload("res://scripts/progression/crafting_rules.gd")
const HERBARIUM_RULES := preload("res://scripts/progression/herbarium_rules.gd")
const MINERALOGY_RULES := preload("res://scripts/progression/mineralogy_rules.gd")

signal state_changed
signal battle_started
signal battle_finished(victory: bool)

const SAVE_VERSION := 10
const FINAL_WEEK := 104

var data: Dictionary = {}

func _ready() -> void:
	new_game()

func new_game() -> void:
	data = {
		"save_version": SAVE_VERSION,
		"week": 1,
		"location": "qingyun",
		"energy": 3,
		"hp": 45,
		"max_hp": 45,
		"qi": 20,
		"silver": 30,
		"renown": 0,
		"xp": 0,
		"strength": 4,
		"agility": 5,
		"insight": 4,
		"constitution": 4,
		"swordsmanship": 0,
		"bladesmanship": 0,
		"herbalism": 0,
		"mining": 0,
		"training_records": TRAINING_RULES.empty_records(),
		"sparring_record": SPARRING_RULES.empty_record(),
		"skills": ["cloud"],
		"items": ["金疮药", "青锋剑"],
		"materials": {"herbs": 0, "ore": 0},
		"herbarium": {},
		"mineralogy": {},
		"consumables": {"healing_powder": 0},
		"forge_level": 0,
		"flags": [],
		"quest_stage": "meet_master",
		"investigations": [],
		"master_relation": 0,
		"alignment": {"heroism": 0, "strategy": 0, "authority": 0},
		"luoyang_route": "",
		"palace_evidence": [],
		"palace_alert": 0,
		"faction_relations": {"qingyun": 1, "huashan": 0, "emei": 0, "shaolin": 0},
		"companions": [],
		"skill_mastery": {"cloud": 0, "frost": 0, "frost_guard": 0},
		"emei_entry": "",
		"ending": {},
		"tutorial": {"map": false, "location": false, "sparring": false, "battle": false, "battle_tactics": false, "battle_defense": false},
		"battle_retry": {},
		"pending_reward": {},
		"log": ["你拜入青云门。距离厉千秋出关还有两年。"],
		"battle": {}
	}
	state_changed.emit()

func power() -> int:
	var specialties := int(data.get("swordsmanship", 0)) + int(data.get("bladesmanship", 0)) + int(data.get("herbalism", 0)) + int(data.get("mining", 0))
	return int(data.strength + data.agility + data.insight + data.constitution + data.skills.size() * 5 + specialties / 2 + int(data.get("forge_level", 0)) * 2)

func weeks_left() -> int:
	return maxi(0, FINAL_WEEK - int(data.week))

func deadline_reached() -> bool:
	return int(data.week) >= FINAL_WEEK

func spend_week() -> bool:
	if deadline_reached() or int(data.energy) <= 0:
		return false
	data.energy -= 1
	data.week = mini(FINAL_WEEK, int(data.week) + 1)
	state_changed.emit()
	return true

func rest() -> bool:
	if deadline_reached():
		return false
	data.energy = 3
	data.hp = data.max_hp
	data.qi = 20
	data.week = mini(FINAL_WEEK, int(data.week) + 1)
	add_log("你调息一周，恢复全部气血、真气与行动点。")
	return true

func travel(destination: String) -> bool:
	if destination == data.location:
		return true
	if not spend_week():
		return false
	data.location = destination
	add_log("你动身前往%s。" % place_name(destination))
	return true

func train(focus: String = "strength") -> bool:
	if focus not in ["strength", "insight", "constitution"]:
		return false
	if not spend_week():
		return false
	if not GROWTH_RULES.apply_training(data, focus):
		return false
	add_log({"strength": "你锻体一周，臂力与修为提升。", "insight": "你参悟一周，悟性与修为提升。", "constitution": "你筑基一周，根骨、气血与修为提升。"}[focus])
	return true

func complete_training(discipline: String, score: int, event_roll: int = -1, best_streak: int = 0) -> Dictionary:
	var safe_score := clampi(score, 0, TRAINING_RULES.MAX_TOTAL_SCORE)
	var outcome := TRAINING_RULES.outcome(discipline, safe_score)
	var focus_week := int(data.get("week", 1))
	if outcome.is_empty() or not spend_week():
		return {}
	if discipline == TRAINING_RULES.weekly_focus(focus_week):
		outcome.weekly_focus = true
		outcome.weekly_focus_bonus = TRAINING_RULES.WEEKLY_FOCUS_XP_BONUS
		outcome.xp = int(outcome.xp) + TRAINING_RULES.WEEKLY_FOCUS_XP_BONUS
	outcome.score = safe_score
	outcome.best_streak = clampi(best_streak, 0, TRAINING_RULES.ROUND_COUNT)
	outcome.record = TRAINING_RULES.record_attempt(data.training_records, discipline, safe_score, best_streak)
	var previous_level := int(data.get(discipline, 0))
	data[discipline] = previous_level + int(outcome.specialty_gain)
	var current_level := int(data[discipline])
	outcome.specialty_level = current_level
	outcome.specialty_rank = TRAINING_RULES.specialty_rank_name(current_level)
	outcome.rank_up = TRAINING_RULES.specialty_rank_index(current_level) > TRAINING_RULES.specialty_rank_index(previous_level)
	var gathering_bonus := TRAINING_RULES.gathering_bonus(current_level)
	if discipline == "herbalism":
		outcome.herbs = int(outcome.get("herbs", 0)) + gathering_bonus
	if discipline == "mining":
		outcome.ore = int(outcome.get("ore", 0)) + gathering_bonus
	data.xp += int(outcome.xp)
	data.silver += int(outcome.silver)
	data.materials.herbs = int(data.materials.herbs) + int(outcome.get("herbs", 0))
	data.materials.ore = int(data.materials.ore) + int(outcome.get("ore", 0))
	if discipline == "herbalism":
		var discovery := HERBARIUM_RULES.record(data, str(outcome.grade), event_roll if event_roll >= 0 else randi_range(0, 99))
		if not discovery.is_empty():
			outcome.herb_discovery = discovery
			data.xp += int(discovery.get("xp", 0))
	if discipline == "mining":
		var discovery := MINERALOGY_RULES.record(data, str(outcome.grade), event_roll if event_roll >= 0 else randi_range(0, 99))
		if not discovery.is_empty():
			outcome.mineral_discovery = discovery
			data.silver += int(discovery.get("silver", 0))
	if str(outcome.item) != "":
		data.items.append(str(outcome.item))
	if str(outcome.grade) == "S" and "training_s_grade" not in data.flags:
		data.flags.append("training_s_grade")
	var event := TRAINING_EVENT_RULES.select(discipline, str(outcome.grade), event_roll)
	if not event.is_empty() and TRAINING_EVENT_RULES.apply(data, event):
		outcome.event = event
		if "training_event_seen" not in data.flags:
			data.flags.append("training_event_seen")
		add_log("修炼奇遇：%s，%s。" % [str(event.title), str(event.reward)])
	add_log("专项修炼完成：%s级，%s。" % [str(outcome.grade), TRAINING_RULES.reward_text(outcome)])
	if bool(outcome.rank_up):
		add_log("%s技艺突破至%s。" % [str(TRAINING_RULES.DISCIPLINES[discipline].title).split(" · ")[0], str(outcome.specialty_rank)])
	return outcome

func craft(recipe_id: String) -> bool:
	if not CRAFTING_RULES.apply(data, recipe_id):
		return false
	var milestone := "crafted_healing_powder" if recipe_id == "healing_powder" else "tempered_blade"
	if milestone not in data.flags:
		data.flags.append(milestone)
	add_log("青云工坊完成：%s。" % str(CRAFTING_RULES.RECIPES[recipe_id].title))
	state_changed.emit()
	return true

func add_investigation(clue: String, message: String) -> bool:
	if clue in data.investigations:
		return false
	data.investigations.append(clue)
	add_log(message)
	return true

func start_blackreed_battle() -> bool:
	if not spend_week():
		return false
	data.qi = 20
	data.battle = {
		"battle_id": "blackreed",
		"name": "黑苇渡遭遇战",
		"width": 8,
		"height": 6,
		"player_x": 1,
		"player_y": 3,
		"ap": 2,
		"active_unit": "hero",
		"hero_guard": 0,
		"turn": 1,
		"objective": {"type": "eliminate"},
		"result": "寨主率两名喽啰封住渡口。每回合有两个行动点。",
		"blocked": [[3, 1], [3, 2], [5, 4]],
		"enemies": [
			{"name": "黑苇寨主", "role": "brute", "hp": 34, "max_hp": 34, "attack": 7, "range": 1, "x": 6, "y": 2},
			{"name": "持刀喽啰", "role": "melee", "hp": 16, "max_hp": 16, "attack": 4, "range": 1, "x": 6, "y": 4},
			{"name": "弓手喽啰", "role": "archer", "hp": 13, "max_hp": 13, "attack": 4, "range": 4, "x": 5, "y": 0}
		]
	}
	data.battle = ENCOUNTER_RULES.prepare_blackreed(data.battle, data.investigations)
	_apply_current_difficulty()
	capture_battle_checkpoint()
	battle_started.emit()
	state_changed.emit()
	return true

func start_qingyun_spar_battle(discipline: String = "swordsmanship") -> bool:
	if discipline not in ["swordsmanship", "bladesmanship"]:
		return false
	var rotation := SPARRING_RULES.rotation_for(int(data.week))
	if not spend_week():
		return false
	data.qi = 20
	data.battle = {
		"battle_id": "qingyun_spar", "rotation_id": rotation.id, "discipline": discipline, "name": "青云门 · %s" % rotation.name, "width": 8, "height": 6,
		"player_x": 1, "player_y": 3, "ap": 2, "active_unit": "hero", "hero_guard": 0, "turn": 1,
		"objective": {"type": "eliminate"},
		"result": rotation.result,
		"blocked": rotation.blocked,
		"enemies": rotation.enemies
	}
	_apply_current_difficulty()
	capture_battle_checkpoint()
	battle_started.emit()
	state_changed.emit()
	return true

func start_huashan_trial_battle() -> bool:
	if not spend_week():
		return false
	data.qi = 20
	data.battle = {
		"battle_id": "huashan_trial",
		"name": "华山论剑试炼",
		"width": 8,
		"height": 6,
		"player_x": 1,
		"player_y": 3,
		"ap": 2,
		"active_unit": "hero",
		"hero_guard": 0,
		"turn": 1,
		"objective": {"type": "survive", "rounds": 4},
		"result": "林清霜与你并肩登台。她会在每次行动后自动支援攻击。",
		"blocked": [[3, 1], [4, 4]],
		"ally": {"name": "林清霜", "hp": 30, "max_hp": 30, "qi": 15, "max_qi": 15, "attack": 5, "guard": 0, "x": 1, "y": 4},
		"enemies": [
			{"name": "华山剑侍", "role": "duelist", "hp": 22, "max_hp": 22, "attack": 5, "range": 1, "x": 6, "y": 1},
			{"name": "守擂弟子", "role": "melee", "hp": 25, "max_hp": 25, "attack": 6, "range": 1, "x": 6, "y": 4}
		]
	}
	_apply_current_difficulty()
	capture_battle_checkpoint()
	battle_started.emit()
	state_changed.emit()
	return true

func start_final_battle() -> bool:
	if not spend_week():
		return false
	data.qi = 20
	data.hp = data.max_hp
	var trusted_su: bool = "su_trust" in data.flags
	data.battle = {
		"battle_id": "wuku_finale",
		"name": "武库天门决战",
		"width": 8,
		"height": 6,
		"player_x": 1,
		"player_y": 3,
		"ap": 2,
		"active_unit": "hero",
		"hero_guard": 0,
		"turn": 1,
		"objective": {"type": "eliminate"},
		"result": "厉无咎率玄甲亲卫守住武库天门。林清霜并肩出剑，苏晚晴则在阵外截断援兵。" if trusted_su else "厉无咎率玄甲亲卫守住武库天门。林清霜与你并肩迎敌。",
		"blocked": [[3, 1], [3, 4], [5, 2]],
		"ally": {"name": "林清霜", "hp": 34, "max_hp": 34, "qi": 15, "max_qi": 15, "attack": 6, "guard": 0, "x": 1, "y": 4},
		"enemies": [
			{"name": "厉无咎", "role": "brute", "boss": true, "hp": 46, "max_hp": 46, "attack": 8, "range": 1, "x": 6, "y": 2},
			{"name": "玄甲亲卫", "role": "melee", "hp": 22, "max_hp": 22, "attack": 6, "range": 1, "x": 6, "y": 4},
			{"name": "武库弩手", "role": "archer", "hp": 12 if trusted_su else 17, "max_hp": 12 if trusted_su else 17, "attack": 5, "range": 4, "x": 5, "y": 0}
		]
	}
	_apply_current_difficulty()
	capture_battle_checkpoint()
	battle_started.emit()
	state_changed.emit()
	return true

func finish_battle(victory: bool) -> void:
	var battle_id: String = str(data.battle.get("battle_id", "blackreed"))
	var battle_difficulty: String = str(data.battle.get("difficulty", "standard"))
	var battle_turns: int = int(data.battle.get("turn", 1))
	var spar_discipline: String = str(data.battle.get("discipline", "swordsmanship"))
	data.battle = {}
	if victory:
		data.battle_retry = {}
		var base_reward := REWARD_RULES.base_for(battle_id)
		data.xp += int(base_reward.xp)
		data.renown += int(base_reward.renown)
		data.silver += int(base_reward.silver)
		data.pending_reward = {"battle_id": battle_id, "turns": battle_turns}
		if battle_id == "qingyun_spar":
			var spar_result := SPARRING_RULES.record_victory(data.get("sparring_record", {}), battle_turns)
			data.sparring_record = spar_result.record
			data.xp += int(spar_result.bonus_xp)
			var skill_gain := SPARRING_RULES.skill_gain_for_grade(str(spar_result.grade))
			data[spar_discipline] = int(data.get(spar_discipline, 0)) + skill_gain
			data.pending_reward.grade = spar_result.grade
			data.pending_reward.performance_xp = spar_result.bonus_xp
			data.pending_reward.discipline = spar_discipline
			data.pending_reward.skill_gain = skill_gain
			data.pending_reward.new_best = spar_result.new_best
			if str(spar_result.grade) == "S" and "spar_s_grade" not in data.flags:
				data.flags.append("spar_s_grade")
		if battle_id == "wuku_finale":
			if "武库钥印" not in data.items:
				data.items.append("武库钥印")
			add_log("你与同伴击败厉无咎，武库的命运将由你决定。")
		elif battle_id == "huashan_trial":
			if "思过崖通行令" not in data.items:
				data.items.append("思过崖通行令")
			add_log("你与林清霜通过华山双人试炼，获准前往思过崖。")
		elif battle_id == "qingyun_spar":
			add_log("你在青云演武场胜出，与同门复盘了攻守得失。")
		else:
			if "玄铁令" not in data.items:
				data.items.append("玄铁令")
			if "villain_revealed" not in data.flags:
				data.flags.append("villain_revealed")
			add_log("黑苇寨主败退。你夺得玄铁令，并查明厉千秋的阴谋。")
	elif battle_id == "qingyun_spar":
		data.hp = data.max_hp
		add_log("你在切磋中落败，同门扶你下场休整；未损失银两。")
	else:
		var recovery: Dictionary = DIFFICULTY_RULES.defeat_recovery(battle_difficulty, int(data.max_hp), int(data.silver))
		data.hp = recovery.hp
		data.silver = recovery.silver
		add_log("你战败后被江湖同道救回，%s。" % ("没有损失银两" if int(recovery.loss) == 0 else "损失%d两银子" % int(recovery.loss)))
	battle_finished.emit(victory)
	state_changed.emit()

func claim_pending_reward(choice_id: String) -> bool:
	if typeof(data.get("pending_reward", {})) != TYPE_DICTIONARY or data.pending_reward.is_empty():
		return false
	var battle_id := str(data.pending_reward.get("battle_id", ""))
	if not REWARD_RULES.apply_choice(data, battle_id, choice_id):
		return false
	var choice := REWARD_RULES.choice_for(battle_id, choice_id)
	data.pending_reward = {}
	add_log("战后取舍：%s。" % str(choice.get("title", choice_id)))
	return true

func _apply_current_difficulty() -> void:
	var manager: Node = get_tree().root.get_node_or_null("SettingsManager") if is_inside_tree() else null
	var level: String = str(manager.data.get("difficulty", "standard")) if manager != null else "standard"
	data.battle = DIFFICULTY_RULES.apply_to_battle(data.battle, level)

func complete_game(legacy: String) -> void:
	var titles: Dictionary = {"destroy": "山河同心", "seal": "持令守序", "preserve": "问道藏锋"}
	var route: String = str({"destroy": "heroism", "seal": "authority", "preserve": "strategy"}.get(legacy, "heroism"))
	var support: int = int(data.alignment.get(route, 0)) * 2 + int(data.master_relation)
	support += int(data.faction_relations.get("huashan", 0)) + int(data.faction_relations.get("emei", 0))
	support += 2 if "su_trust" in data.flags else 0
	support += 2 if "lin_qingshuang" in data.companions else 0
	var rank: String = "传说" if support >= 10 and weeks_left() >= 20 else ("圆满" if support >= 6 else "余波未平")
	var base_story: String = str({
		"destroy": "你击碎武库机关，将兵谱公之于众。各派不再争夺一把钥匙，而是共同守住百姓身后的山河。",
		"seal": "你以玄铁令重立盟约，将武库交由各派共守。江湖从此多了一条规矩：力量必须接受众人的监督。",
		"preserve": "你封存杀伐之术，只带走医理与机关篇。武库没有成为王座，却化作救人济世的一盏暗灯。"
	}.get(legacy, "武库尘埃落定，新的江湖由此开始。"))
	var companion_story: String = "林清霜与你并肩走出天门，苏晚晴也兑现承诺，三派从此互通音讯。" if "su_trust" in data.flags else "林清霜与你并肩走出天门，但峨眉对武库的余波仍保持警惕。"
	data.ending = {"id": legacy, "title": titles.get(legacy, "山河问道"), "rank": rank, "story": base_story + "\n\n" + companion_story, "week": int(data.week), "support": support}
	data.quest_stage = "game_complete"
	if "game_complete" not in data.flags:
		data.flags.append("game_complete")
	add_log("终章完成：%s（%s）。" % [data.ending.title, rank])

func capture_battle_checkpoint() -> void:
	if data.battle.is_empty():
		return
	data.battle_retry = {
		"battle": data.battle.duplicate(true),
		"hp": int(data.hp),
		"qi": int(data.qi),
		"silver": int(data.silver),
		"week": int(data.week),
		"energy": int(data.energy),
		"skill_mastery": data.skill_mastery.duplicate(true),
		"log": data.log.duplicate(true)
	}

func retry_last_battle() -> bool:
	if typeof(data.get("battle_retry", {})) != TYPE_DICTIONARY or data.battle_retry.is_empty():
		return false
	var checkpoint: Dictionary = data.battle_retry
	if not checkpoint.has("battle") or not _valid_battle(checkpoint.battle):
		data.battle_retry = {}
		return false
	data.hp = clampi(int(checkpoint.get("hp", data.max_hp)), 1, int(data.max_hp))
	data.qi = clampi(int(checkpoint.get("qi", 20)), 0, 20)
	data.silver = maxi(0, int(checkpoint.get("silver", data.silver)))
	data.week = clampi(int(checkpoint.get("week", data.week)), 1, FINAL_WEEK)
	data.energy = clampi(int(checkpoint.get("energy", data.energy)), 0, 3)
	if typeof(checkpoint.get("skill_mastery", {})) == TYPE_DICTIONARY:
		data.skill_mastery = checkpoint.skill_mastery.duplicate(true)
	if typeof(checkpoint.get("log", [])) == TYPE_ARRAY:
		data.log = checkpoint.log.duplicate(true)
	data.battle = checkpoint.battle.duplicate(true)
	battle_started.emit()
	state_changed.emit()
	return true

func abandon_battle_retry() -> void:
	data.battle_retry = {}
	state_changed.emit()

func add_log(message: String) -> void:
	data.log.push_front(message)
	if data.log.size() > 6:
		data.log.resize(6)
	state_changed.emit()

func place_name(id: String) -> String:
	return {"qingyun": "青云门", "blackreed": "黑苇渡", "luoyang": "洛阳城", "huashan": "华山", "emei": "峨眉山"}.get(id, id)

func import_data(value: Dictionary) -> bool:
	if int(value.get("save_version", 1)) > SAVE_VERSION:
		push_warning("Save file was created by a newer game version.")
		return false
	new_game()
	for key in value:
		if data.has(key):
			data[key] = value[key]
	_migrate_and_validate()
	data.save_version = SAVE_VERSION
	state_changed.emit()
	return true

func _migrate_and_validate() -> void:
	# 新字段由 new_game() 提供默认值；这里修复旧版本类型及已淘汰的战斗结构。
	if typeof(data.flags) != TYPE_ARRAY:
		data.flags = []
	if typeof(data.items) != TYPE_ARRAY:
		data.items = []
	if typeof(data.materials) != TYPE_DICTIONARY:
		data.materials = {"herbs": 0, "ore": 0}
	if typeof(data.get("herbarium", {})) != TYPE_DICTIONARY:
		data.herbarium = {}
	if typeof(data.get("mineralogy", {})) != TYPE_DICTIONARY:
		data.mineralogy = {}
	data.training_records = TRAINING_RULES.normalize_records(data.get("training_records", {}))
	data.sparring_record = SPARRING_RULES.normalize_record(data.get("sparring_record", {}))
	if typeof(data.consumables) != TYPE_DICTIONARY:
		data.consumables = {"healing_powder": 0}
	# Convert 0.27/0.28 herb items into the dedicated material inventory.
	var migrated_items: Array = []
	for item in data.items:
		if str(item) == "上品药材":
			data.materials.herbs = int(data.materials.get("herbs", 0)) + 2
		elif str(item) == "寻常药材":
			data.materials.herbs = int(data.materials.get("herbs", 0)) + 1
		else:
			migrated_items.append(item)
	data.items = migrated_items
	if typeof(data.investigations) != TYPE_ARRAY:
		data.investigations = []
	if typeof(data.palace_evidence) != TYPE_ARRAY:
		data.palace_evidence = []
	if typeof(data.alignment) != TYPE_DICTIONARY:
		data.alignment = {"heroism": 0, "strategy": 0, "authority": 0}
	for route in ["heroism", "strategy", "authority"]:
		if not data.alignment.has(route):
			data.alignment[route] = 0
	if typeof(data.faction_relations) != TYPE_DICTIONARY:
		data.faction_relations = {"qingyun": 1, "huashan": 0, "emei": 0, "shaolin": 0}
	if typeof(data.companions) != TYPE_ARRAY:
		data.companions = []
	if typeof(data.skills) != TYPE_ARRAY:
		data.skills = ["cloud"]
	if typeof(data.log) != TYPE_ARRAY:
		data.log = []
	else:
		var normalized_log: Array[String] = []
		for entry in data.log.slice(0, 6):
			normalized_log.append(str(entry))
		data.log = normalized_log
	if typeof(data.skill_mastery) != TYPE_DICTIONARY:
		data.skill_mastery = {"cloud": 0, "frost": 0, "frost_guard": 0}
	if typeof(data.ending) != TYPE_DICTIONARY:
		data.ending = {}
	for skill in ["cloud", "frost", "frost_guard"]:
		if not data.skill_mastery.has(skill):
			data.skill_mastery[skill] = 0
	if typeof(data.tutorial) != TYPE_DICTIONARY:
		data.tutorial = {"map": false, "location": false, "sparring": false, "battle": false, "battle_tactics": false, "battle_defense": false}
	for step in ["map", "location", "sparring", "battle", "battle_tactics", "battle_defense"]:
		data.tutorial[step] = bool(data.tutorial.get(step, false))
	if typeof(data.battle_retry) != TYPE_DICTIONARY:
		data.battle_retry = {}
	elif not data.battle_retry.is_empty():
		if not data.battle_retry.has("battle") or not _valid_battle(data.battle_retry.battle):
			data.battle_retry = {}
	if typeof(data.pending_reward) != TYPE_DICTIONARY:
		data.pending_reward = {}
	elif not data.pending_reward.is_empty() and str(data.pending_reward.get("battle_id", "")) not in ["blackreed", "qingyun_spar", "huashan_trial", "wuku_finale"]:
		data.pending_reward = {}
	if not _valid_battle(data.battle):
		data.battle = {}
	data.week = clampi(int(data.week), 1, FINAL_WEEK)
	data.energy = clampi(int(data.energy), 0, 3)
	data.max_hp = maxi(1, int(data.max_hp))
	data.hp = clampi(int(data.hp), 1, int(data.max_hp))
	data.qi = clampi(int(data.qi), 0, 20)
	data.silver = maxi(0, int(data.silver))
	data.renown = maxi(0, int(data.renown))
	data.xp = maxi(0, int(data.xp))
	data.materials.herbs = maxi(0, int(data.materials.get("herbs", 0)))
	data.materials.ore = maxi(0, int(data.materials.get("ore", 0)))
	var normalized_herbarium := {}
	for specimen_id in HERBARIUM_RULES.SPECIMENS:
		var count := maxi(0, int(data.herbarium.get(specimen_id, 0)))
		if count > 0:
			normalized_herbarium[specimen_id] = count
	data.herbarium = normalized_herbarium
	var normalized_mineralogy := {}
	for specimen_id in MINERALOGY_RULES.SPECIMENS:
		var count := maxi(0, int(data.mineralogy.get(specimen_id, 0)))
		if count > 0:
			normalized_mineralogy[specimen_id] = count
	data.mineralogy = normalized_mineralogy
	data.consumables.healing_powder = maxi(0, int(data.consumables.get("healing_powder", 0)))
	data.forge_level = clampi(int(data.get("forge_level", 0)), 0, CRAFTING_RULES.MAX_FORGE_LEVEL)
	for stat in ["strength", "agility", "insight", "constitution"]:
		data[stat] = maxi(1, int(data.get(stat, 1)))
	for specialty in ["swordsmanship", "bladesmanship", "herbalism", "mining"]:
		data[specialty] = maxi(0, int(data.get(specialty, 0)))
	if str(data.location) not in ["qingyun", "blackreed", "luoyang", "huashan", "emei"]:
		data.location = "qingyun"
	if not data.battle.is_empty() and data.battle_retry.is_empty():
		capture_battle_checkpoint()

func _valid_battle(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var battle: Dictionary = value
	if battle.is_empty():
		return true
	for key in ["width", "height", "player_x", "player_y", "ap", "turn", "enemies", "blocked"]:
		if not battle.has(key):
			return false
	var width := int(battle.width)
	var height := int(battle.height)
	if width < 1 or height < 1 or typeof(battle.enemies) != TYPE_ARRAY or typeof(battle.blocked) != TYPE_ARRAY:
		return false
	if int(battle.player_x) < 0 or int(battle.player_x) >= width or int(battle.player_y) < 0 or int(battle.player_y) >= height:
		return false
	if typeof(battle.get("objective", {})) != TYPE_DICTIONARY:
		battle.objective = {"type": "eliminate"}
	var objective_type := str(battle.get("objective", {}).get("type", "eliminate"))
	if objective_type not in ["eliminate", "survive"]:
		battle.objective = {"type": "eliminate"}
	elif objective_type == "survive":
		battle.objective.rounds = maxi(1, int(battle.objective.get("rounds", 1)))
	else:
		battle.objective = {"type": "eliminate"}
	for enemy in battle.enemies:
		if typeof(enemy) != TYPE_DICTIONARY or not enemy.has("hp") or not enemy.has("x") or not enemy.has("y"):
			return false
		var default_range := 4 if "弓手" in str(enemy.get("name", "")) else 1
		enemy.range = maxi(1, int(enemy.get("range", default_range)))
		var enemy_name := str(enemy.get("name", ""))
		var default_role := "archer" if "弓手" in enemy_name else ("brute" if "寨主" in enemy_name else ("duelist" if "剑侍" in enemy_name else "melee"))
		if str(enemy.get("role", "")) not in ["melee", "archer", "brute", "duelist"]:
			enemy.role = default_role
		enemy.exposure = clampi(int(enemy.get("exposure", 0)), 0, 2)
		if enemy.has("armor"):
			enemy.armor = maxi(0, int(enemy.armor))
		if int(enemy.x) < 0 or int(enemy.x) >= width or int(enemy.y) < 0 or int(enemy.y) >= height:
			return false
	return true
