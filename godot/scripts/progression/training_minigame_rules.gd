class_name TrainingMinigameRules
extends RefCounted

const ROUND_COUNT := 3
const COMBO_SCORE_THRESHOLD := 85
const COMBO_BONUS_PER_STEP := 5
const MAX_COMBO_BONUS := 10
const DIRECTIONS := ["up", "right", "down", "left"]
const DIRECTION_LABELS := {"up": "上", "right": "右", "down": "下", "left": "左"}
const DISCIPLINES := {
	"swordsmanship": {
		"title": "剑法 · 听风辨势",
		"description": "记住两式剑路，依次完成三组连招。",
		"mechanic": "连招",
		"accent": Color("#7ba9a1")
	},
	"bladesmanship": {
		"title": "刀法 · 破阵斩隙",
		"description": "不要抢刀；蓄势约一秒，在金色窗口内斩击。",
		"mechanic": "蓄势",
		"accent": Color("#b56750")
	},
	"herbalism": {
		"title": "采药 · 寻香识草",
		"description": "叶尖指向迷障，药根藏在相反方向。",
		"mechanic": "辨识",
		"accent": Color("#6f9c5b")
	},
	"mining": {
		"title": "挖矿 · 听音寻脉",
		"description": "听回声抓住约一点二秒的共鸣点，再向矿脉落锤。",
		"mechanic": "节奏",
		"accent": Color("#a1845e")
	}
}

static func is_valid_discipline(id: String) -> bool:
	return DISCIPLINES.has(id)

static func options() -> Array:
	return [
		["剑法 · 听风辨势", "提升剑法；影响流云剑法的威力。", "swordsmanship"],
		["刀法 · 破阵斩隙", "提升刀法；每两级增加普通攻击伤害。", "bladesmanship"],
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

static func opposite(direction: String) -> String:
	return {"up": "down", "right": "left", "down": "up", "left": "right"}.get(direction, "")

static func challenge(discipline: String, primary: String, secondary: String = "") -> Dictionary:
	if not is_valid_discipline(discipline) or primary not in DIRECTIONS:
		return {}
	match discipline:
		"swordsmanship":
			var follow := secondary if secondary in DIRECTIONS else opposite(primary)
			return {"targets": [primary, follow], "prompt": "剑谱：%s → %s" % [DIRECTION_LABELS[primary], DIRECTION_LABELS[follow]], "timing": "迅速依次出招"}
		"bladesmanship":
			return {"targets": [primary], "prompt": "蓄势斩向：%s" % DIRECTION_LABELS[primary], "timing": "最佳窗口 0.85–1.15 秒"}
		"herbalism":
			return {"targets": [opposite(primary)], "prompt": "叶尖朝%s，药根在……" % DIRECTION_LABELS[primary], "timing": "选择相反方向"}
		"mining":
			return {"targets": [primary], "prompt": "矿脉回声：%s" % DIRECTION_LABELS[primary], "timing": "共鸣点 1.05–1.35 秒"}
	return {}

static func score_challenge(discipline: String, correct: bool, elapsed_ms: int) -> int:
	if not correct:
		return 0
	match discipline:
		"swordsmanship":
			if elapsed_ms <= 1200: return 100
			if elapsed_ms <= 1800: return 85
			if elapsed_ms <= 2600: return 70
			return 55
		"bladesmanship":
			var blade_delta := absi(elapsed_ms - 1000)
			if blade_delta <= 150: return 100
			if blade_delta <= 300: return 85
			if blade_delta <= 550: return 70
			return 55
		"herbalism":
			if elapsed_ms <= 1800: return 100
			if elapsed_ms <= 3000: return 85
			return 70
		"mining":
			var mining_delta := absi(elapsed_ms - 1200)
			if mining_delta <= 150: return 100
			if mining_delta <= 350: return 85
			if mining_delta <= 650: return 70
			return 55
	return score_round(correct, elapsed_ms)

static func evaluate_challenge(discipline: String, correct: bool, elapsed_ms: int, previous_streak: int) -> Dictionary:
	var base_score := score_challenge(discipline, correct, elapsed_ms)
	var streak := previous_streak + 1 if base_score >= COMBO_SCORE_THRESHOLD else 0
	var combo_bonus := mini(MAX_COMBO_BONUS, maxi(0, streak - 1) * COMBO_BONUS_PER_STEP)
	return {
		"base_score": base_score,
		"combo_bonus": combo_bonus,
		"score": base_score + combo_bonus,
		"streak": streak,
		"quality": score_quality(base_score),
		"feedback": timing_feedback(discipline, elapsed_ms, correct)
	}

static func score_quality(base_score: int) -> String:
	if base_score >= 100:
		return "perfect"
	if base_score >= COMBO_SCORE_THRESHOLD:
		return "great"
	if base_score > 0:
		return "ok"
	return "miss"

static func timing_feedback(discipline: String, elapsed_ms: int, correct: bool) -> String:
	if not correct:
		return "失误"
	if discipline in ["bladesmanship", "mining"]:
		var ideal := 1000 if discipline == "bladesmanship" else 1200
		if elapsed_ms < ideal - 300: return "过早"
		if elapsed_ms > ideal + 300: return "过晚"
		return "正中时机"
	return "连贯" if discipline == "swordsmanship" else "辨识正确"

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
		"item": "",
		"herbs": 0,
		"ore": 0
	}
	if discipline == "herbalism":
		result.herbs = {"S": 3, "A": 2, "B": 1, "C": 1}[result_grade]
	if discipline == "mining":
		result.silver = {"S": 12, "A": 8, "B": 5, "C": 2}[result_grade]
		result.ore = {"S": 3, "A": 2, "B": 1, "C": 1}[result_grade]
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
	if int(result.get("herbs", 0)) > 0:
		parts.append("药材 +%d" % int(result.herbs))
	if int(result.get("ore", 0)) > 0:
		parts.append("矿石 +%d" % int(result.ore))
	return " · ".join(parts)
