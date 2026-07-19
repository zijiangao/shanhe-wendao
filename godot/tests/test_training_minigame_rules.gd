extends SceneTree

const RULES := preload("res://scripts/progression/training_minigame_rules.gd")

func _init() -> void:
	assert(RULES.options().size() == 4, "Training should offer four distinct specialties.")
	assert(RULES.score_round(true, 500) == 100, "Fast correct reactions should earn full points.")
	assert(RULES.score_round(true, 1200) == 70, "Slower correct reactions should receive partial points.")
	assert(RULES.score_round(false, 100) == 0, "Incorrect reactions should not earn points.")
	assert(RULES.grade(300) == "S" and RULES.grade(269) == "A", "Grade boundaries should be stable.")
	assert(RULES.grade(224) == "B" and RULES.grade(164) == "C", "Lower grade boundaries should be stable.")
	var herbs := RULES.outcome("herbalism", 280)
	assert(herbs.grade == "S" and herbs.specialty_gain == 3 and herbs.item == "上品药材", "Excellent herb gathering should yield specialty growth and premium herbs.")
	var mining := RULES.outcome("mining", 180)
	assert(mining.grade == "B" and mining.silver == 5, "Mining output should scale with the grade.")
	assert(RULES.outcome("invalid", 300).is_empty(), "Unknown specialties must be rejected.")
	print("Training minigame rule tests passed.")
	quit()
