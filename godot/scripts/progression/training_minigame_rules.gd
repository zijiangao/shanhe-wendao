class_name TrainingMinigameRules
extends RefCounted

const ROUND_COUNT := 3
const COMBO_SCORE_THRESHOLD := 85
const COMBO_BONUS_PER_STEP := 5
const MAX_COMBO_BONUS := 10
const MAX_TOTAL_SCORE := 315
const WEEKLY_FOCUS_XP_BONUS := 3
const WEEKLY_FOCUS_ORDER := ["swordsmanship", "bladesmanship", "herbalism", "mining"]
const SPECIALTY_RANKS := [
	{"level": 0, "name": "初学"},
	{"level": 3, "name": "熟手"},
	{"level": 6, "name": "精通"},
	{"level": 10, "name": "大成"}
]
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

static func weekly_focus(week: int) -> String:
	return str(WEEKLY_FOCUS_ORDER[posmod(maxi(1, week) - 1, WEEKLY_FOCUS_ORDER.size())])

static func discipline_short_name(discipline: String) -> String:
	return str(DISCIPLINES.get(discipline, {}).get("title", discipline)).split(" · ")[0]

static func specialty_rank_index(level: int) -> int:
	var result := 0
	for index in range(SPECIALTY_RANKS.size()):
		if level >= int(SPECIALTY_RANKS[index].level):
			result = index
	return result

static func specialty_rank_name(level: int) -> String:
	return str(SPECIALTY_RANKS[specialty_rank_index(maxi(0, level))].name)

static func next_specialty_level(level: int) -> int:
	var current := specialty_rank_index(maxi(0, level))
	return int(SPECIALTY_RANKS[current + 1].level) if current + 1 < SPECIALTY_RANKS.size() else -1

static func gathering_bonus(level: int) -> int:
	return maxi(0, specialty_rank_index(maxi(0, level)) - 1)

static func cloud_qi_cost(level: int) -> int:
	return 6 if maxi(0, level) >= 10 else 8

static func attack_exposure_gain(level: int) -> int:
	return 2 if maxi(0, level) >= 10 else 1

static func medicine_mastery_bonus(level: int) -> int:
	return 5 if maxi(0, level) >= 10 else 0

static func craft_ore_discount(level: int) -> int:
	return 3 if maxi(0, level) >= 10 else 0

static func perk_text(discipline: String, level: int) -> String:
	match discipline:
		"swordsmanship": return "每2级剑伤 +1；大成后流云剑法只耗6真气"
		"bladesmanship": return "每2级普攻 +1；大成后普攻制造2层破绽"
		"herbalism": return "回春散随等级增强；大成再加5治疗，采药增产 +%d" % gathering_bonus(level)
		"mining": return "采矿增产 +%d；大成后打造兵刃/护具少花3矿石" % gathering_bonus(level)
	return ""

static func empty_records() -> Dictionary:
	var records := {}
	for discipline in DISCIPLINES:
		records[discipline] = {"best_score": 0, "best_streak": 0, "attempts": 0}
	return records

static func normalize_records(value: Variant) -> Dictionary:
	var source: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var records := empty_records()
	for discipline in DISCIPLINES:
		var raw: Dictionary = source.get(discipline, {}) if typeof(source.get(discipline, {})) == TYPE_DICTIONARY else {}
		records[discipline] = {
			"best_score": clampi(int(raw.get("best_score", 0)), 0, MAX_TOTAL_SCORE),
			"best_streak": clampi(int(raw.get("best_streak", 0)), 0, ROUND_COUNT),
			"attempts": maxi(0, int(raw.get("attempts", 0)))
		}
	return records

static func record_attempt(records: Dictionary, discipline: String, score: int, best_streak: int) -> Dictionary:
	if not is_valid_discipline(discipline):
		return {}
	var normalized := normalize_records(records)
	records.clear()
	records.merge(normalized)
	var current: Dictionary = records.get(discipline, {})
	var safe_score := clampi(score, 0, MAX_TOTAL_SCORE)
	var new_best := int(current.attempts) == 0 or safe_score > int(current.best_score)
	current.best_score = maxi(int(current.best_score), safe_score)
	current.best_streak = maxi(int(current.best_streak), clampi(best_streak, 0, ROUND_COUNT))
	current.attempts = int(current.attempts) + 1
	records[discipline] = current
	return {"new_best": new_best, "best_score": int(current.best_score), "best_grade": grade(int(current.best_score)), "best_streak": int(current.best_streak), "attempts": int(current.attempts)}

static func records_text(records: Variant) -> String:
	var normalized := normalize_records(records)
	var entries: Array[String] = []
	for entry in [["swordsmanship", "剑"], ["bladesmanship", "刀"], ["herbalism", "药"], ["mining", "矿"]]:
		var record: Dictionary = normalized[entry[0]]
		entries.append("%s %s·%d（%d次）" % [entry[1], grade(int(record.best_score)) if int(record.attempts) > 0 else "—", int(record.best_score), int(record.attempts)])
	return " · ".join(entries)

static func options(state: Dictionary = {}) -> Array:
	var result: Array = []
	var focus := weekly_focus(int(state.get("week", 1)))
	for entry in [["swordsmanship", "剑法 · 听风辨势"], ["bladesmanship", "刀法 · 破阵斩隙"], ["herbalism", "采药 · 寻香识草"], ["mining", "挖矿 · 听音寻脉"]]:
		var discipline := str(entry[0])
		var level := maxi(0, int(state.get(discipline, 0)))
		var next_level := next_specialty_level(level)
		var progress := "已达大成" if next_level < 0 else "距下境界 %d级" % (next_level - level)
		var focus_text := "【本周专精 · 额外修为 +%d】\n" % WEEKLY_FOCUS_XP_BONUS if discipline == focus else ""
		result.append([str(entry[1]), "%s%s %d级 · %s · %s\n小游戏成绩决定本周成长与收益。" % [focus_text, specialty_rank_name(level), level, progress, perk_text(discipline, level)], discipline])
	return result

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

static func challenge(discipline: String, primary: String, secondary: String = "", advanced: bool = false) -> Dictionary:
	if not is_valid_discipline(discipline) or primary not in DIRECTIONS:
		return {}
	match discipline:
		"swordsmanship":
			var follow := secondary if secondary in DIRECTIONS else opposite(primary)
			var targets := [primary, follow, opposite(follow)] if advanced else [primary, follow]
			var labels: Array[String] = []
			for target in targets:
				labels.append(str(DIRECTION_LABELS[target]))
			return {"discipline": discipline, "advanced": advanced, "targets": targets, "prompt": "剑谱：%s" % " → ".join(labels), "timing": "进阶三式剑路" if advanced else "迅速依次出招"}
		"bladesmanship":
			var blade_target := opposite(primary) if advanced else primary
			var blade_ideal := 1400 if advanced else 1000
			return {"discipline": discipline, "advanced": advanced, "targets": [blade_target], "prompt": "%s：%s" % ["识破虚招，回斩" if advanced else "蓄势斩向", DIRECTION_LABELS[blade_target]], "timing": "最佳窗口 %.2f–%.2f 秒" % [float(blade_ideal - 150) / 1000.0, float(blade_ideal + 150) / 1000.0], "ideal_ms": blade_ideal}
		"herbalism":
			var herb_targets := [opposite(primary), opposite(secondary)] if advanced and secondary in DIRECTIONS else [opposite(primary)]
			var herb_prompt := "两株叶尖朝%s、%s，依次寻根" % [DIRECTION_LABELS[primary], DIRECTION_LABELS[secondary]] if herb_targets.size() > 1 else "叶尖朝%s，药根在……" % DIRECTION_LABELS[primary]
			return {"discipline": discipline, "advanced": advanced, "targets": herb_targets, "prompt": herb_prompt, "timing": "依次选择两株的相反方向" if herb_targets.size() > 1 else "选择相反方向"}
		"mining":
			var mining_ideal := 800 if advanced else 1200
			return {"discipline": discipline, "advanced": advanced, "targets": [primary], "prompt": "%s：%s" % ["短促回声" if advanced else "矿脉回声", DIRECTION_LABELS[primary]], "timing": "共鸣点 %.2f–%.2f 秒" % [float(mining_ideal - 150) / 1000.0, float(mining_ideal + 150) / 1000.0], "ideal_ms": mining_ideal}
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

static func evaluate_challenge(discipline: String, correct: bool, elapsed_ms: int, previous_streak: int, challenge_data: Dictionary = {}) -> Dictionary:
	var base_score := score_challenge_variant(discipline, correct, elapsed_ms, challenge_data)
	var streak := previous_streak + 1 if base_score >= COMBO_SCORE_THRESHOLD else 0
	var combo_bonus := mini(MAX_COMBO_BONUS, maxi(0, streak - 1) * COMBO_BONUS_PER_STEP)
	return {
		"base_score": base_score,
		"combo_bonus": combo_bonus,
		"score": base_score + combo_bonus,
		"streak": streak,
		"quality": score_quality(base_score),
		"feedback": timing_feedback_variant(discipline, elapsed_ms, correct, challenge_data)
	}

static func score_challenge_variant(discipline: String, correct: bool, elapsed_ms: int, challenge_data: Dictionary) -> int:
	if not correct:
		return 0
	if not bool(challenge_data.get("advanced", false)):
		return score_challenge(discipline, correct, elapsed_ms)
	match discipline:
		"swordsmanship":
			if elapsed_ms <= 1800: return 100
			if elapsed_ms <= 2600: return 85
			if elapsed_ms <= 3600: return 70
			return 55
		"herbalism":
			if elapsed_ms <= 2600: return 100
			if elapsed_ms <= 4000: return 85
			return 70
		"bladesmanship", "mining":
			var ideal := int(challenge_data.get("ideal_ms", 1000 if discipline == "bladesmanship" else 1200))
			var delta := absi(elapsed_ms - ideal)
			if delta <= 150: return 100
			if delta <= 300: return 85
			if delta <= 550: return 70
			return 55
	return score_challenge(discipline, correct, elapsed_ms)

static func timing_feedback_variant(discipline: String, elapsed_ms: int, correct: bool, challenge_data: Dictionary) -> String:
	if not correct:
		return "失误"
	if discipline in ["bladesmanship", "mining"] and challenge_data.has("ideal_ms"):
		var ideal := int(challenge_data.ideal_ms)
		if elapsed_ms < ideal - 300: return "过早"
		if elapsed_ms > ideal + 300: return "过晚"
		return "正中时机"
	return timing_feedback(discipline, elapsed_ms, correct)

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
	if int(result.get("weekly_focus_bonus", 0)) > 0:
		parts.append("本周专精 +%d修为" % int(result.weekly_focus_bonus))
	if int(result.silver) > 0:
		parts.append("银两 +%d" % int(result.silver))
	if str(result.item) != "":
		parts.append("获得%s" % str(result.item))
	if int(result.get("herbs", 0)) > 0:
		parts.append("药材 +%d" % int(result.herbs))
	var discovery: Dictionary = result.get("herb_discovery", {})
	if not discovery.is_empty():
		parts.append("%s%s（%s）" % ["新识 " if bool(discovery.get("first_discovery", false)) else "采得 ", str(discovery.name), str(discovery.rarity)])
		if int(discovery.get("xp", 0)) > 0:
			parts.append("药谱心得 +%d" % int(discovery.xp))
	if int(result.get("ore", 0)) > 0:
		parts.append("矿石 +%d" % int(result.ore))
	var mineral: Dictionary = result.get("mineral_discovery", {})
	if not mineral.is_empty():
		parts.append("%s%s（%s）" % ["新识 " if bool(mineral.get("first_discovery", false)) else "掘得 ", str(mineral.name), str(mineral.rarity)])
		if int(mineral.get("silver", 0)) > 0:
			parts.append("鉴矿所得 +%d银两" % int(mineral.silver))
	return " · ".join(parts)
