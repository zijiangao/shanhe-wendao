class_name EncounterRules
extends RefCounted

const BLACKREED_PATROL := {
	"name": "巡寨快刀",
	"role": "duelist",
	"hp": 14,
	"max_hp": 14,
	"attack": 4,
	"range": 1,
	"x": 5,
	"y": 5
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
