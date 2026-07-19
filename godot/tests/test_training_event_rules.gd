extends SceneTree

const RULES := preload("res://scripts/progression/training_event_rules.gd")

func _init() -> void:
	assert(RULES.chance_for_grade("S") == 45 and RULES.chance_for_grade("C") == 10, "Better grades should have a higher encounter chance.")
	assert(RULES.select("swordsmanship", "S", 44).size() > 0, "An S-grade roll inside its chance should select an event.")
	assert(RULES.select("swordsmanship", "S", 45).is_empty(), "A roll at the exclusive chance boundary should not select an event.")
	assert(RULES.select("invalid", "S", 0).is_empty() and RULES.select("mining", "S", 100).is_empty(), "Invalid specialties and rolls must be rejected.")
	var state := {
		"xp": 10, "silver": 5, "hp": 3, "max_hp": 20,
		"materials": {"herbs": 0, "ore": 0},
		"consumables": {"healing_powder": 0}
	}
	var risky := RULES.select("mining", "S", 1)
	assert(RULES.apply(state, risky), "A selected training event should apply to valid state data.")
	assert(state.silver == 15 and state.hp == 1, "Risky mining should grant silver while clamping injury above zero HP.")
	var medicine := RULES.select("herbalism", "S", 1)
	assert(RULES.apply(state, medicine) and state.consumables.healing_powder == 1, "Field medicine should grant a saved combat consumable.")
	assert(not RULES.apply(state, {}), "An empty event must not mutate state.")
	print("Training event rule tests passed.")
	quit()
