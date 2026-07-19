class_name DifficultyRules
extends RefCounted

const LEVELS := ["story", "standard", "master"]

static func normalize(value: Variant) -> String:
	var level := str(value)
	return level if level in LEVELS else "standard"

static func display_name(level: String) -> String:
	return {"story": "休闲", "standard": "标准", "master": "宗师"}.get(normalize(level), "标准")

static func description(level: String) -> String:
	return {
		"story": "偏重剧情体验：敌人气血 -20%、伤害 -25%，战败不损失银两。",
		"standard": "推荐的完整体验：采用设计基准数值与标准战败惩罚。",
		"master": "面向战棋老手：敌人气血 +20%、伤害 +20%，战败惩罚更重。"
	}.get(normalize(level), "")

static func apply_to_battle(battle: Dictionary, requested_level: Variant) -> Dictionary:
	var level := normalize(requested_level)
	var hp_scale: float = float({"story": 0.8, "standard": 1.0, "master": 1.2}[level])
	var attack_scale: float = float({"story": 0.75, "standard": 1.0, "master": 1.2}[level])
	battle.difficulty = level
	for enemy in battle.get("enemies", []):
		var scaled_hp := maxi(1, roundi(float(enemy.get("max_hp", enemy.get("hp", 1))) * hp_scale))
		enemy.max_hp = scaled_hp
		enemy.hp = scaled_hp
		enemy.attack = maxi(1, roundi(float(enemy.get("attack", 1)) * attack_scale))
	return battle

static func defeat_recovery(level: String, max_hp: int, silver: int) -> Dictionary:
	match normalize(level):
		"story": return {"hp": maxi(1, ceili(max_hp * 0.75)), "silver": silver, "loss": 0}
		"master":
			var loss := mini(15, silver)
			return {"hp": maxi(1, ceili(max_hp / 3.0)), "silver": silver - loss, "loss": loss}
		_:
			var loss := mini(10, silver)
			return {"hp": maxi(1, ceili(max_hp / 2.0)), "silver": silver - loss, "loss": loss}
