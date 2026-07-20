class_name TutorialRules
extends RefCounted

const STEPS := ["map", "location", "sparring", "battle", "battle_tactics", "battle_defense"]

static func step_for(screen: String, state: Dictionary) -> String:
	var seen: Dictionary = state.get("tutorial", {})
	if screen == "map" and not bool(seen.get("map", false)):
		return "map"
	if screen == "location" and str(state.get("location", "")) == "qingyun" and not bool(seen.get("location", false)):
		return "location"
	var battle: Dictionary = state.get("battle", {}) if typeof(state.get("battle", {})) == TYPE_DICTIONARY else {}
	if screen == "battle" and str(battle.get("battle_id", "")) == "qingyun_spar" and not bool(seen.get("sparring", false)):
		return "sparring"
	if screen == "battle" and not bool(seen.get("battle", false)):
		return "battle"
	if screen == "battle" and not bool(seen.get("battle_tactics", false)):
		return "battle_tactics"
	if screen == "battle" and not bool(seen.get("battle_defense", false)):
		return "battle_defense"
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
		"sparring":
			return {
				"title": "青 云 演 武 · 以 战 代 练",
				"body": "演武课题每周轮换，战败不会损失银两。\n\n· 3回合内胜出为S，5回合内为A，7回合内为B，其后为C。\n· S/A/B评价会追加4/2/1点修为；C级没有表现修为。\n· 本次选择的剑法或刀法必定提升，S级提升2点，其余提升1点。\n· 最快回合与胜出次数会永久记录；可在修炼菜单查看个人最佳。"
			}
		"battle_tactics":
			return {
				"title": "看懂敌人 · 制造破绽",
				"body": "先看右侧敌方预判，再决定本回合的目标与站位。\n\n· 重装敌人拥有护甲；普攻会受减伤，但可制造最多2层破绽。\n· 流云剑法无视护甲，并引爆破绽追加伤害。\n· 标记‘疾步2’的剑客一次能移动2格，不要低估其威胁范围。\n· 弓手每逢第3回合可能施展穿云箭；命中后，下回合少1行动点。\n· 岩石能阻挡直线射击。躲入掩体，或优先解决弓手。"
			}
		"battle_defense":
			return {
				"title": "攻 守 有 度 · 运 气 护 体",
				"body": "沈羽可消耗1行动点施展“运气护体”：\n\n· 获得由根骨决定的护体值，敌人攻击会先削减护体，再伤及气血。\n· 同时恢复3点真气，可在剑法之后重新蓄气。\n· 护体不会叠加；重复施展会用新的护体值覆盖旧值。\n· 敌方预判出现蓄力重击，或首领周围格位变红时，优先撤离；来不及撤离再运气护体。\n· 右侧状态栏会持续显示当前护体，挡伤也会出现在命中反馈中。"
			}
	return {}

static func mark_seen(state: Dictionary, step: String) -> void:
	if step not in STEPS:
		return
	if typeof(state.get("tutorial", {})) != TYPE_DICTIONARY:
		state.tutorial = {}
	state.tutorial[step] = true

static func reset(state: Dictionary) -> void:
	state.tutorial = {"map": false, "location": false, "sparring": false, "battle": false, "battle_tactics": false, "battle_defense": false}
