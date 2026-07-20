class_name SparringRules
extends RefCounted

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

static func record_victory(record_value: Variant, turns: int) -> Dictionary:
	var record := normalize_record(record_value)
	var safe_turns := maxi(1, turns)
	var new_best: bool = int(record.best_turns) == 0 or safe_turns < int(record.best_turns)
	record.attempts = int(record.attempts) + 1
	if new_best:
		record.best_turns = safe_turns
		record.best_grade = grade_for(safe_turns)
	return {"record": record, "grade": grade_for(safe_turns), "new_best": new_best}

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
