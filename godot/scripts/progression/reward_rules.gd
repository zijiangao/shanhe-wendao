class_name RewardRules
extends RefCounted

const BASE_REWARDS := {
	"qingyun_spar": {"title": "同 门 切 磋", "story": "晨光落在演武场上。胜负点到即止，你与同门互相指出了招式中的破绽。", "xp": 4, "silver": 2, "renown": 0, "item": "无", "next_screen": "location"},
	"blackreed": {"title": "大 捷", "story": "黑苇寨众溃散，渡口重归平静。你从寨主身上搜出一枚玄铁令，厉千秋的阴谋终于露出端倪。", "xp": 22, "silver": 15, "renown": 4, "item": "玄铁令", "next_screen": "map"},
	"huashan_trial": {"title": "剑 会 胜 出", "story": "你与林清霜剑路相合，通过华山双人试炼。守台长老准许你们前往思过崖查看残图。", "xp": 30, "silver": 10, "renown": 3, "item": "思过崖通行令", "next_screen": "map"},
	"wuku_finale": {"title": "天 门 已 定", "story": "厉无咎的刀落在石阶上。武库机关仍在轰鸣，而决定它命运的人已经变成了你。", "xp": 60, "silver": 30, "renown": 8, "item": "武库钥印", "next_screen": "final_choice"}
}

const CHOICES := {
	"qingyun_spar": [
		{"id": "review", "title": "复盘剑路", "description": "修为 +4", "effects": {"xp": 4}},
		{"id": "stipend", "title": "领取演武津贴", "description": "银两 +6 · 真气回满", "effects": {"silver": 6, "restore_qi": true}},
		{"id": "fellowship", "title": "与同门交流", "description": "声望 +1 · 青云关系 +1", "effects": {"renown": 1, "faction": {"qingyun": 1}}}
	],
	"blackreed": [
		{"id": "temper", "title": "参悟寨主刀势", "description": "修为 +8 · 流云熟练度 +1", "effects": {"xp": 8, "mastery": {"cloud": 1}}},
		{"id": "supplies", "title": "收整渡口货箱", "description": "银两 +15 · 真气回满", "effects": {"silver": 15, "restore_qi": true}},
		{"id": "mercy", "title": "救济受困商旅", "description": "声望 +3 · 侠义 +1", "effects": {"renown": 3, "alignment": {"heroism": 1}}}
	],
	"huashan_trial": [
		{"id": "temper", "title": "复盘双剑合击", "description": "修为 +12 · 霜华刺熟练度 +1", "effects": {"xp": 12, "mastery": {"frost": 1}}},
		{"id": "supplies", "title": "领取剑会彩头", "description": "银两 +18 · 真气回满", "effects": {"silver": 18, "restore_qi": true}},
		{"id": "fellowship", "title": "与华山弟子论剑", "description": "声望 +2 · 华山关系 +2", "effects": {"renown": 2, "faction": {"huashan": 2}}}
	],
	"wuku_finale": [
		{"id": "temper", "title": "参悟断岳刀痕", "description": "修为 +20 · 流云熟练度 +2", "effects": {"xp": 20, "mastery": {"cloud": 2}}},
		{"id": "supplies", "title": "收缴武库军资", "description": "银两 +25 · 真气回满", "effects": {"silver": 25, "restore_qi": true}},
		{"id": "witness", "title": "请群侠共同见证", "description": "声望 +4 · 侠义 +1", "effects": {"renown": 4, "alignment": {"heroism": 1}}}
	]
}

static func base_for(battle_id: String) -> Dictionary:
	return Dictionary(BASE_REWARDS.get(battle_id, BASE_REWARDS.blackreed)).duplicate(true)

static func choices_for(battle_id: String) -> Array:
	return Array(CHOICES.get(battle_id, CHOICES.blackreed)).duplicate(true)

static func choice_for(battle_id: String, choice_id: String) -> Dictionary:
	for choice in choices_for(battle_id):
		if str(choice.get("id", "")) == choice_id:
			return choice
	return {}

static func apply_choice(state: Dictionary, battle_id: String, choice_id: String) -> bool:
	var choice := choice_for(battle_id, choice_id)
	if choice.is_empty():
		return false
	var effects: Dictionary = choice.get("effects", {})
	state.xp = int(state.get("xp", 0)) + int(effects.get("xp", 0))
	state.silver = int(state.get("silver", 0)) + int(effects.get("silver", 0))
	state.renown = int(state.get("renown", 0)) + int(effects.get("renown", 0))
	if bool(effects.get("restore_qi", false)):
		state.qi = 20
	for skill in Dictionary(effects.get("mastery", {})):
		state.skill_mastery[skill] = int(state.skill_mastery.get(skill, 0)) + int(effects.mastery[skill])
	for route in Dictionary(effects.get("alignment", {})):
		state.alignment[route] = int(state.alignment.get(route, 0)) + int(effects.alignment[route])
	for faction in Dictionary(effects.get("faction", {})):
		state.faction_relations[faction] = int(state.faction_relations.get(faction, 0)) + int(effects.faction[faction])
	return true
