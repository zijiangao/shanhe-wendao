extends SceneTree

const RULES := preload("res://scripts/progression/herbarium_rules.gd")

func _init() -> void:
	var state := {"herbarium": {}}
	var first := RULES.record(state, "S", 0)
	assert(first.id == "dewgrass" and first.first_discovery and first.xp == 2, "The first specimen should grant discovery cultivation.")
	var second := RULES.record(state, "S", 0)
	assert(second.id == "cloudleaf" and second.first_discovery, "High-grade gathering should prioritize an undiscovered eligible specimen.")
	RULES.record(state, "S", 0)
	var fourth := RULES.record(state, "S", 0)
	assert(fourth.id == "sevenstar_lotus" and RULES.discovered_count(state.herbarium) == 4, "Repeated excellent gathering should be able to complete the herbarium.")
	var repeat := RULES.record(state, "S", 0)
	assert(repeat.id == "dewgrass" and not repeat.first_discovery and repeat.xp == 0, "Duplicate specimens must not farm first-discovery rewards.")
	var low_state := {"herbarium": {}}
	assert(RULES.record(low_state, "C", 99).id == "dewgrass", "Low-grade gathering should only find the common specimen.")
	assert(RULES.record(low_state, "invalid", 0).is_empty(), "Unknown grades must not mutate the collection.")
	assert(RULES.collection_text({"dewgrass": 2}).contains("凝露草×2") and RULES.collection_text({"dewgrass": 2}).contains("？？？"), "The collection summary should show counts without revealing undiscovered specimens.")
	print("Herbarium rule tests passed.")
	quit()
