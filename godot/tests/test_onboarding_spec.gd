extends SceneTree

const SPEC := preload("res://scripts/release/onboarding_spec.gd")

func _initialize() -> void:
	assert(SPEC.NEW_GAME_SCREEN == "location", "A new player should begin at the actionable Qingyun location instead of an extra map step.")
	assert(SPEC.OPENING_RETURN_SCREEN == "map", "Accepting the first mission should return directly to the travel map.")
	assert(SPEC.OPENING_DIALOGUE.size() <= 2, "The opening mission should establish stakes without delaying the first decision.")
	for event_id in ["clue_fisher", "clue_tracks"]:
		var entries := SPEC.dialogue_for(event_id)
		assert(entries.size() == 1, "Each required first-chapter clue should resolve in one readable dialogue beat.")
		assert(str(entries[0][1]).length() <= 45, "First-chapter clue copy should remain scannable.")
	print("Onboarding specification tests passed.")
	quit()

