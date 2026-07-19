extends SceneTree

const RULES := preload("res://scripts/ui/tutorial_rules.gd")

func _initialize() -> void:
	var state := {
		"location": "qingyun",
		"tutorial": {"map": false, "location": false, "battle": false}
	}
	assert(RULES.step_for("map", state) == "map", "The map tutorial should be shown first.")
	RULES.mark_seen(state, "map")
	assert(RULES.step_for("map", state).is_empty(), "A dismissed map tutorial must not repeat.")
	assert(RULES.step_for("location", state) == "location", "Qingyun should explain scene actions.")
	state.location = "blackreed"
	assert(RULES.step_for("location", state).is_empty(), "The location tutorial should not interrupt later locations.")
	assert(RULES.step_for("battle", state) == "battle", "The first battle should explain tactical controls.")
	var battle_content: Dictionary = RULES.content("battle", "unused")
	assert("2点行动点" in str(battle_content.body), "Battle tutorial should explain the action economy.")
	RULES.reset(state)
	assert(not bool(state.tutorial.map) and not bool(state.tutorial.battle), "Reset should restore all tutorial steps.")

	print("TutorialRules tests passed.")
	quit()
