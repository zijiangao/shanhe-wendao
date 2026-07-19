class_name TrainingMinigameRules
extends RefCounted

const ROUND_COUNT := 3
const DIRECTIONS := ["up", "right", "down", "left"]
const DIRECTION_LABELS := {"up": "上", "right": "右", "down": "下", "left": "左"}
const DISCIPLINES := {
	"swordsmanship": {
		"title": "剑法 · 听风辨势",
		"description": "看清剑势，在三次变招中迅速选出正确方位。",
		"accent": Color("#7ba9a1")
	},
	"bladesmanship": {
		"title": "刀法 · 破阵斩隙",
		"description": "抓住刀阵空隙，以果断反应完成三次斩击。",
		"accent": Color("#b56750")
	},
	"herbalism": {
		"title": "采药 · 寻香识草",
		"description": "依山风与叶脉判断药草方位，辨错会影响收成。",
		"accent": Color("#6f9c5b")
	},
	"mining": {
		"title": "挖矿 · 听音寻脉",
		"description": "循矿石回声找到矿脉薄弱处，越快落锤收获越多。",
		"accent": Color("#a1845e")
	}
}

static func is_valid_discipline(id: String) -> bool:
	return DISCIPLINES.has(id)

static func options() -> Array:
	return [
		["剑法 · 听风辨势", "提升剑法；影响流云剑法的威力。", "swordsmanship"],
		["刀法 · 破阵斩隙", "提升刀法；为后续刀系武学打下根基。", "bladesmanship"],
		["采药 · 寻香识草", "提升采药，并按成绩获得药材。", "herbalism"],
		["挖矿 · 听音寻脉", "提升挖矿，并按成绩获得银两。", "mining"]
	]

static func score_round(correct: bool, elapsed_ms: int) -> int:
	if not correct:
		return 0
	if elapsed_ms <= 650:
		return 100
	if elapsed_ms <= 1100:
		return 85
	if elapsed_ms <= 1700:
		return 70
	return 55

static func grade(total_score: int) -> String:
	if total_score >= 270:
		return "S"
	if total_score >= 225:
		return "A"
	if total_score >= 165:
		return "B"
	return "C"

static func outcome(discipline: String, total_score: int) -> Dictionary:
	if not is_valid_discipline(discipline):
		return {}
	var result_grade := grade(total_score)
	var tier: int = int({"S": 3, "A": 2, "B": 1, "C": 1}[result_grade])
	var xp: int = int({"S": 12, "A": 9, "B": 6, "C": 3}[result_grade])
	var result := {
		"discipline": discipline,
		"grade": result_grade,
		"specialty_gain": tier,
		"xp": xp,
		"silver": 0,
		"item": ""
	}
	if discipline == "herbalism":
		result.item = "上品药材" if result_grade in ["S", "A"] else "寻常药材"
	if discipline == "mining":
		result.silver = {"S": 12, "A": 8, "B": 5, "C": 2}[result_grade]
	return result

static func reward_text(result: Dictionary) -> String:
	if result.is_empty():
		return ""
	var title := str(DISCIPLINES[str(result.discipline)].title).split(" · ")[0]
	var parts: Array[String] = ["%s +%d" % [title, int(result.specialty_gain)], "修为 +%d" % int(result.xp)]
	if int(result.silver) > 0:
		parts.append("银两 +%d" % int(result.silver))
	if str(result.item) != "":
		parts.append("获得%s" % str(result.item))
	return " · ".join(parts)
