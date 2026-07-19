extends Node

signal state_changed
signal battle_started
signal battle_finished(victory: bool)

const SAVE_VERSION := 2
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
		"skills": ["cloud"],
		"items": ["金疮药", "青锋剑"],
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
		"log": ["你拜入青云门。距离厉千秋出关还有两年。"],
		"battle": {}
	}
	state_changed.emit()

func power() -> int:
	return int(data.strength + data.agility + data.insight + data.constitution + data.skills.size() * 5)

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

func train() -> bool:
	if not spend_week():
		return false
	data.strength += 1
	data.xp += 12
	add_log("一周苦修，臂力提升，修为增加。")
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
		"turn": 1,
		"result": "寨主率两名喽啰封住渡口。每回合有两个行动点。",
		"blocked": [[3, 1], [3, 2], [5, 4]],
		"enemies": [
			{"name": "黑苇寨主", "role": "brute", "hp": 34, "max_hp": 34, "attack": 7, "range": 1, "x": 6, "y": 2},
			{"name": "持刀喽啰", "role": "melee", "hp": 16, "max_hp": 16, "attack": 4, "range": 1, "x": 6, "y": 4},
			{"name": "弓手喽啰", "role": "archer", "hp": 13, "max_hp": 13, "attack": 4, "range": 4, "x": 5, "y": 0}
		]
	}
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
		"turn": 1,
		"result": "林清霜与你并肩登台。她会在每次行动后自动支援攻击。",
		"blocked": [[3, 1], [4, 4]],
		"ally": {"name": "林清霜", "hp": 30, "max_hp": 30, "qi": 15, "max_qi": 15, "attack": 5, "guard": 0, "x": 1, "y": 4},
		"enemies": [
			{"name": "华山剑侍", "role": "duelist", "hp": 22, "max_hp": 22, "attack": 5, "range": 1, "x": 6, "y": 1},
			{"name": "守擂弟子", "role": "melee", "hp": 25, "max_hp": 25, "attack": 6, "range": 1, "x": 6, "y": 4}
		]
	}
	battle_started.emit()
	state_changed.emit()
	return true

func finish_battle(victory: bool) -> void:
	var battle_id: String = str(data.battle.get("battle_id", "blackreed"))
	data.battle = {}
	if victory:
		if battle_id == "huashan_trial":
			data.xp += 30
			data.renown += 3
			data.silver += 10
			if "思过崖通行令" not in data.items:
				data.items.append("思过崖通行令")
			add_log("你与林清霜通过华山双人试炼，获准前往思过崖。")
		else:
			data.xp += 22
			data.renown += 4
			data.silver += 15
			if "玄铁令" not in data.items:
				data.items.append("玄铁令")
			if "villain_revealed" not in data.flags:
				data.flags.append("villain_revealed")
			add_log("黑苇寨主败退。你夺得玄铁令，并查明厉千秋的阴谋。")
	else:
		data.hp = ceili(float(data.max_hp) / 2.0)
		data.silver = maxi(0, int(data.silver) - 10)
		add_log("你战败后被渔民救回，损失十两银子。")
	battle_finished.emit(victory)
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
	for skill in ["cloud", "frost", "frost_guard"]:
		if not data.skill_mastery.has(skill):
			data.skill_mastery[skill] = 0
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
	for stat in ["strength", "agility", "insight", "constitution"]:
		data[stat] = maxi(1, int(data.get(stat, 1)))
	if str(data.location) not in ["qingyun", "blackreed", "luoyang", "huashan", "emei"]:
		data.location = "qingyun"

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
	for enemy in battle.enemies:
		if typeof(enemy) != TYPE_DICTIONARY or not enemy.has("hp") or not enemy.has("x") or not enemy.has("y"):
			return false
		var default_range := 4 if "弓手" in str(enemy.get("name", "")) else 1
		enemy.range = maxi(1, int(enemy.get("range", default_range)))
		var enemy_name := str(enemy.get("name", ""))
		var default_role := "archer" if "弓手" in enemy_name else ("brute" if "寨主" in enemy_name else ("duelist" if "剑侍" in enemy_name else "melee"))
		if str(enemy.get("role", "")) not in ["melee", "archer", "brute", "duelist"]:
			enemy.role = default_role
		if int(enemy.x) < 0 or int(enemy.x) >= width or int(enemy.y) < 0 or int(enemy.y) >= height:
			return false
	return true
