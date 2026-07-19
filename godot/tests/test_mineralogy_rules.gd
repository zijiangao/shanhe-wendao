extends SceneTree

const RULES := preload("res://scripts/progression/mineralogy_rules.gd")

func _init() -> void:
	var state := {"mineralogy": {}}
	var first := RULES.record(state, "S", 0)
	assert(first.id == "ironstone" and first.first_discovery and first.silver == 2, "The first mineral should grant a discovery appraisal bonus.")
	var second := RULES.record(state, "S", 0)
	assert(second.id == "silver_sand" and second.first_discovery, "High-grade mining should prioritize an undiscovered eligible mineral.")
	RULES.record(state, "S", 0)
	var fourth := RULES.record(state, "S", 0)
	assert(fourth.id == "star_marrow" and RULES.discovered_count(state.mineralogy) == 4, "Repeated excellent mining should be able to complete the mineral ledger.")
	var repeat := RULES.record(state, "S", 0)
	assert(repeat.id == "ironstone" and not repeat.first_discovery and repeat.silver == 0, "Duplicate minerals must not farm appraisal rewards.")
	var low_state := {"mineralogy": {}}
	assert(RULES.record(low_state, "C", 99).id == "ironstone", "Low-grade mining should only find the common mineral.")
	assert(RULES.record(low_state, "invalid", 0).is_empty(), "Unknown grades must not mutate the mineral ledger.")
	assert(RULES.collection_text({"ironstone": 2}).contains("青铁石×2") and RULES.collection_text({"ironstone": 2}).contains("？？？"), "The mineral summary should show counts without revealing undiscovered minerals.")
	print("Mineralogy rule tests passed.")
	quit()
