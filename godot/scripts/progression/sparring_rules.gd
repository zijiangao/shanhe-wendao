class_name SparringRules
extends RefCounted

const ROTATIONS := [
	{"id": "swift_swords", "name": "快剑对练", "focus": "练习走位与护体", "result": "两名同门抱剑行礼，以连环快剑检验你的步法。", "blocked": [[3, 1], [4, 4]], "enemies": [
		{"name": "青云快剑", "role": "duelist", "hp": 14, "max_hp": 14, "attack": 3, "range": 1, "x": 6, "y": 2},
		{"name": "青云守式", "role": "melee", "hp": 18, "max_hp": 18, "attack": 4, "range": 1, "x": 6, "y": 4}
	]},
	{"id": "blade_line", "name": "破阵刀课", "focus": "练习破甲与回气", "result": "演武弟子结成刀阵，逼你在强攻间隙调整真气。", "blocked": [[3, 2], [5, 4]], "enemies": [
		{"name": "演武刀首", "role": "brute", "hp": 22, "max_hp": 22, "attack": 5, "range": 1, "x": 6, "y": 2},
		{"name": "刀阵侧锋", "role": "melee", "hp": 13, "max_hp": 13, "attack": 3, "range": 1, "x": 5, "y": 4}
	]},
	{"id": "bow_step", "name": "弓步协同", "focus": "练习威胁排序与接近远敌", "result": "弓手居后压阵，持剑弟子封住前路，考验你的进攻次序。", "blocked": [[3, 1], [4, 3], [3, 5]], "enemies": [
		{"name": "青云练弓手", "role": "archer", "hp": 12, "max_hp": 12, "attack": 3, "range": 4, "x": 6, "y": 1},
		{"name": "封步剑手", "role": "duelist", "hp": 17, "max_hp": 17, "attack": 4, "range": 1, "x": 5, "y": 4}
	]}
]

static func rotation_for(week: int) -> Dictionary:
	return Dictionary(ROTATIONS[posmod(week - 1, ROTATIONS.size())]).duplicate(true)

static func empty_record() -> Dictionary:
	return {"attempts": 0, "best_turns": 0, "best_grade": "--"}

static func grade_for(turns: int) -> String:
	if turns <= 3:
		return "S"
	if turns <= 5:
		return "A"
	if turns <= 7:
		return "B"
	return "C"

static func bonus_xp_for_grade(grade: String) -> int:
	return {"S": 4, "A": 2, "B": 1}.get(grade, 0)

static func skill_gain_for_grade(grade: String) -> int:
	return 2 if grade == "S" else 1

static func discipline_name(discipline: String) -> String:
	return "刀法" if discipline == "bladesmanship" else "剑法"

static func record_victory(record_value: Variant, turns: int) -> Dictionary:
	var record := normalize_record(record_value)
	var safe_turns := maxi(1, turns)
	var new_best: bool = int(record.best_turns) == 0 or safe_turns < int(record.best_turns)
	record.attempts = int(record.attempts) + 1
	if new_best:
		record.best_turns = safe_turns
		record.best_grade = grade_for(safe_turns)
	var grade := grade_for(safe_turns)
	return {"record": record, "grade": grade, "bonus_xp": bonus_xp_for_grade(grade), "new_best": new_best}

static func normalize_record(value: Variant) -> Dictionary:
	var record := empty_record()
	if typeof(value) != TYPE_DICTIONARY:
		return record
	var source := Dictionary(value)
	record.attempts = maxi(0, int(source.get("attempts", 0)))
	record.best_turns = maxi(0, int(source.get("best_turns", 0)))
	record.best_grade = grade_for(int(record.best_turns)) if int(record.best_turns) > 0 else "--"
	return record

static func record_text(record_value: Variant) -> String:
	var record := normalize_record(record_value)
	if int(record.attempts) == 0:
		return "尚无胜绩"
	return "最佳 %s · %d回合（胜出%d次）" % [record.best_grade, record.best_turns, record.attempts]
