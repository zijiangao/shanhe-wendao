class_name TutorialRules
extends RefCounted

const STEPS := ["map", "location", "battle"]

static func step_for(screen: String, state: Dictionary) -> String:
	var seen: Dictionary = state.get("tutorial", {})
	if screen == "map" and not bool(seen.get("map", false)):
		return "map"
	if screen == "location" and str(state.get("location", "")) == "qingyun" and not bool(seen.get("location", false)):
		return "location"
	if screen == "battle" and not bool(seen.get("battle", false)):
		return "battle"
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
	return {}

static func mark_seen(state: Dictionary, step: String) -> void:
	if step not in STEPS:
		return
	if typeof(state.get("tutorial", {})) != TYPE_DICTIONARY:
		state.tutorial = {}
	state.tutorial[step] = true

static func reset(state: Dictionary) -> void:
	state.tutorial = {"map": false, "location": false, "battle": false}
