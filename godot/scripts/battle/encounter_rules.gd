class_name EncounterRules
extends RefCounted

# Fixed chapter challenges, never scaled to the player's level or current week.
# Preparation therefore makes an actual difference; existing battle saves and
# retry checkpoints retain the encounter that was originally started.
const STORY_OPPONENTS := {
	"huashan_trial": [
		{"hp": 42, "attack": 8, "speed": 8, "armor": 2},
		{"hp": 48, "attack": 9, "speed": 7, "armor": 3}
	],
	"wuku_finale": [
		{"hp": 110, "attack": 12, "speed": 9, "armor": 4},
		{"hp": 50, "attack": 9, "speed": 8, "armor": 3},
		{"hp": 35, "attack": 7, "speed": 9, "armor": 1}
	]
}

static func prepare_story(battle: Dictionary, trusted_su: bool = false) -> Dictionary:
	var id := str(battle.get("battle_id", ""))
	if not STORY_OPPONENTS.has(id):
		return battle
	var opponents: Array = STORY_OPPONENTS[id]
	for index in range(mini(opponents.size(), battle.enemies.size())):
		for stat in opponents[index]:
			battle.enemies[index][stat] = opponents[index][stat]
		battle.enemies[index].max_hp = battle.enemies[index].hp
	if id == "huashan_trial":
		battle.objective.rounds = 5
	elif trusted_su:
		# Emei's support still weakens the crossbowman, without removing the
		# ranged threat altogether.
		battle.enemies[2].hp = 25
		battle.enemies[2].max_hp = 25
	return battle

const BLACKREED_PATROL := {
	"name": "巡寨快刀",
	"role": "duelist",
	"hp": 14,
	"max_hp": 14,
	"attack": 4,
	"range": 1,
	"x": 5,
	"y": 5,
	"speed": 7,
	"gauge": 0
}

static func prepare_blackreed(battle: Dictionary, investigations: Array) -> Dictionary:
	var prepared := battle.duplicate(true)
	var advantages: PackedStringArray = []
	if "secret_route" in investigations:
		prepared.player_x = 2
		advantages.append("暗道前压")
	else:
		prepared.enemies.append(BLACKREED_PATROL.duplicate(true))
		advantages.append("巡寨快刀参战")
	if "archer" in investigations:
		for enemy in prepared.enemies:
			if str(enemy.get("role", "")) == "archer":
				enemy.exposure = 1
		advantages.append("弓手破绽1")
	if "herbs" in investigations:
		advantages.append("金疮药整备")
	prepared.preparation = {
		"secret_route": "secret_route" in investigations,
		"archer_spotted": "archer" in investigations,
		"herbs": "herbs" in investigations,
		"summary": " · ".join(advantages)
	}
	prepared.result = "战前准备：%s。优先处理高威胁敌人。" % prepared.preparation.summary
	return prepared
