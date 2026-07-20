extends SceneTree

const RULES := preload("res://scripts/progression/sparring_rules.gd")

func _initialize() -> void:
	var rotation_ids: PackedStringArray = []
	for week in range(1, 4):
		var rotation := RULES.rotation_for(week)
		rotation_ids.append(str(rotation.id))
		assert(rotation.enemies.size() == 2 and not str(rotation.focus).is_empty(), "Every weekly rotation should define two opponents and a training focus.")
	assert(rotation_ids[0] != rotation_ids[1] and rotation_ids[1] != rotation_ids[2] and RULES.rotation_for(4).id == rotation_ids[0], "Three sparring lessons should rotate predictably by week.")
	assert(RULES.grade_for(3) == "S" and RULES.grade_for(5) == "A" and RULES.grade_for(7) == "B" and RULES.grade_for(8) == "C", "Turn thresholds should produce stable sparring grades.")
	assert(RULES.bonus_xp_for_grade("S") == 4 and RULES.bonus_xp_for_grade("A") == 2 and RULES.bonus_xp_for_grade("B") == 1 and RULES.bonus_xp_for_grade("C") == 0, "Better grades should grant a bounded cultivation bonus.")
	var first := RULES.record_victory({}, 5)
	assert(first.new_best and first.grade == "A" and first.bonus_xp == 2 and first.record.best_turns == 5 and first.record.attempts == 1, "The first victory should establish a personal best and matching bonus.")
	var slower := RULES.record_victory(first.record, 7)
	assert(not slower.new_best and slower.record.best_turns == 5 and slower.record.attempts == 2, "A slower victory should count without replacing the best.")
	var faster := RULES.record_victory(slower.record, 3)
	assert(faster.new_best and faster.record.best_grade == "S" and "3回合" in RULES.record_text(faster.record), "A faster victory should replace and describe the record.")
	assert(RULES.normalize_record({"attempts": -2, "best_turns": -1}).attempts == 0, "Damaged records should normalize safely.")
	print("SparringRules tests passed.")
	quit()
