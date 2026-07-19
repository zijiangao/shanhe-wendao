extends SceneTree

const RULES := preload("res://scripts/ui/tutorial_rules.gd")

func _initialize() -> void:
	var state := {
		"location": "qingyun",
		"tutorial": {"map": false, "location": false, "battle": false, "battle_tactics": false}
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
	RULES.mark_seen(state, "battle")
	assert(RULES.step_for("battle", state) == "battle_tactics", "The tactical concepts page should follow the basic battle controls.")
	var tactics_content: Dictionary = RULES.content("battle_tactics", "unused")
	for concept in ["护甲", "破绽", "疾步2", "穿云箭", "岩石"]:
		assert(concept in str(tactics_content.body), "The tactical tutorial should explain %s." % concept)
	RULES.mark_seen(state, "battle_tactics")
	assert(RULES.step_for("battle", state).is_empty(), "Both dismissed battle pages must stay completed.")
	RULES.reset(state)
	assert(not bool(state.tutorial.map) and not bool(state.tutorial.battle) and not bool(state.tutorial.battle_tactics), "Reset should restore all tutorial steps.")

	print("TutorialRules tests passed.")
	quit()
