class_name TrainingEventRules
extends RefCounted

const EVENTS := {
	"swordsmanship": [
		{"id": "master_insight", "title": "松风点剑", "body": "师父看出你剑路中的灵光，顺势点破一处关窍。", "effects": {"xp": 3}, "reward": "额外修为 +3"},
		{"id": "sword_backlash", "title": "剑意反噬", "body": "你强行追索一线剑意，虽有所得，腕脉也被震伤。", "effects": {"xp": 5, "hp": -4}, "reward": "额外修为 +5 · 气血 -4"}
	],
	"bladesmanship": [
		{"id": "tempering_spark", "title": "炉边试刃", "body": "斩击震落炉壁上一块精矿，正可留作下次淬炼。", "effects": {"ore": 1}, "reward": "矿石 +1"},
		{"id": "old_blade_resonance", "title": "旧刃回响", "body": "一名过路刀客认可你的刀势，留下几两试刀彩头。", "effects": {"silver": 6}, "reward": "银两 +6"}
	],
	"herbalism": [
		{"id": "rare_herb", "title": "石隙灵苗", "body": "你循着异香找到一簇罕见药苗，完整保住了根须。", "effects": {"herbs": 2}, "reward": "额外药材 +2"},
		{"id": "field_medicine", "title": "就地制药", "body": "新采的药性正盛，你当场调成一包可用于战斗的回春散。", "effects": {"healing_powder": 1}, "reward": "回春散 +1"}
	],
	"mining": [
		{"id": "rich_vein", "title": "暗藏富脉", "body": "回声之后还有一层空腔，你从中剥出两块可用精矿。", "effects": {"ore": 2}, "reward": "额外矿石 +2"},
		{"id": "risky_lode", "title": "险取银砂", "body": "你抢在碎石坠落前取出银砂，肩背也被擦伤。", "effects": {"silver": 10, "hp": -3}, "reward": "银两 +10 · 气血 -3"}
	]
}

static func chance_for_grade(grade: String) -> int:
	return int({"S": 45, "A": 35, "B": 20, "C": 10}.get(grade, 0))

static func select(discipline: String, grade: String, roll: int) -> Dictionary:
	if not EVENTS.has(discipline) or roll < 0 or roll >= 100:
		return {}
	if roll >= chance_for_grade(grade):
		return {}
	var candidates: Array = EVENTS[discipline]
	return (candidates[roll % candidates.size()] as Dictionary).duplicate(true)

static func apply(state: Dictionary, event: Dictionary) -> bool:
	if event.is_empty() or typeof(event.get("effects", {})) != TYPE_DICTIONARY:
		return false
	var effects: Dictionary = event.effects
	state.xp = maxi(0, int(state.get("xp", 0)) + int(effects.get("xp", 0)))
	state.silver = maxi(0, int(state.get("silver", 0)) + int(effects.get("silver", 0)))
	state.hp = clampi(int(state.get("hp", 1)) + int(effects.get("hp", 0)), 1, int(state.get("max_hp", 1)))
	state.materials.herbs = maxi(0, int(state.materials.get("herbs", 0)) + int(effects.get("herbs", 0)))
	state.materials.ore = maxi(0, int(state.materials.get("ore", 0)) + int(effects.get("ore", 0)))
	state.consumables.healing_powder = maxi(0, int(state.consumables.get("healing_powder", 0)) + int(effects.get("healing_powder", 0)))
	return true
