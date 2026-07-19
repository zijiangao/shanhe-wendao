class_name TutorialRules
extends RefCounted

const STEPS := ["map", "location", "battle", "battle_tactics"]

static func step_for(screen: String, state: Dictionary) -> String:
	var seen: Dictionary = state.get("tutorial", {})
	if screen == "map" and not bool(seen.get("map", false)):
		return "map"
	if screen == "location" and str(state.get("location", "")) == "qingyun" and not bool(seen.get("location", false)):
		return "location"
	if screen == "battle" and not bool(seen.get("battle", false)):
		return "battle"
	if screen == "battle" and not bool(seen.get("battle_tactics", false)):
		return "battle_tactics"
	return ""

static func content(step: String, objective: String) -> Dictionary:
	match step:
		"map":
			return {
				"title": "初入江湖 · 天下舆图",
				"body": "当前目标：%s\n\n选择黑苇渡即可直接启程。旅行和修炼会消耗周数，右上角可查看剩余时间。" % objective
			}
		"location":
			return {
				"title": "场景行动",
				"body": "当前目标：%s\n\n先点击带“主线”标记的正殿。演武场和藏经阁是可选准备，不会阻挡剧情。" % objective
			}
		"battle":
			return {
				"title": "战棋入门",
				"body": "每回合共有2点行动点。\n\n1. 选择“移动”后点击蓝色格位。\n2. 选择攻击或武学，再点击高亮敌人。\n3. 留意“敌方预判”，行动完后结束回合。\n\n战败后可从战斗开始处重试。"
			}
		"battle_tactics":
			return {
				"title": "看懂敌人 · 制造破绽",
				"body": "先看右侧敌方预判，再决定本回合的目标与站位。\n\n· 重装敌人拥有护甲；普攻会受减伤，但可制造最多2层破绽。\n· 流云剑法无视护甲，并引爆破绽追加伤害。\n· 标记‘疾步2’的剑客一次能移动2格，不要低估其威胁范围。\n· 弓手每逢第3回合可能施展穿云箭；命中后，下回合少1行动点。\n· 岩石能阻挡直线射击。躲入掩体，或优先解决弓手。"
			}
	return {}

static func mark_seen(state: Dictionary, step: String) -> void:
	if step not in STEPS:
		return
	if typeof(state.get("tutorial", {})) != TYPE_DICTIONARY:
		state.tutorial = {}
	state.tutorial[step] = true

static func reset(state: Dictionary) -> void:
	state.tutorial = {"map": false, "location": false, "battle": false, "battle_tactics": false}
