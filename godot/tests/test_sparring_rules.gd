extends SceneTree

const RULES := preload("res://scripts/progression/sparring_rules.gd")

func _initialize() -> void:
	assert(RULES.grade_for(3) == "S" and RULES.grade_for(5) == "A" and RULES.grade_for(7) == "B" and RULES.grade_for(8) == "C", "Turn thresholds should produce stable sparring grades.")
	var first := RULES.record_victory({}, 5)
	assert(first.new_best and first.grade == "A" and first.record.best_turns == 5 and first.record.attempts == 1, "The first victory should establish a personal best.")
	var slower := RULES.record_victory(first.record, 7)
	assert(not slower.new_best and slower.record.best_turns == 5 and slower.record.attempts == 2, "A slower victory should count without replacing the best.")
	var faster := RULES.record_victory(slower.record, 3)
	assert(faster.new_best and faster.record.best_grade == "S" and "3回合" in RULES.record_text(faster.record), "A faster victory should replace and describe the record.")
	assert(RULES.normalize_record({"attempts": -2, "best_turns": -1}).attempts == 0, "Damaged records should normalize safely.")
	print("SparringRules tests passed.")
	quit()
