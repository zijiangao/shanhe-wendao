extends SceneTree

const RULES := preload("res://scripts/battle/difficulty_rules.gd")

func _initialize() -> void:
	var source := {"enemies": [{"name": "敌人", "hp": 20, "max_hp": 20, "attack": 8}]}
	var story: Dictionary = RULES.apply_to_battle(source.duplicate(true), "story")
	assert(str(story.difficulty) == "story", "A battle should keep a stable difficulty snapshot.")
	assert(int(story.enemies[0].hp) == 16 and int(story.enemies[0].attack) == 6, "Story mode should reduce enemy health and attack.")
	var master: Dictionary = RULES.apply_to_battle(source.duplicate(true), "master")
	assert(int(master.enemies[0].hp) == 24 and int(master.enemies[0].attack) == 10, "Master mode should increase enemy health and rounded attack.")
	var fallback: Dictionary = RULES.apply_to_battle(source.duplicate(true), "unknown")
	assert(str(fallback.difficulty) == "standard" and int(fallback.enemies[0].hp) == 20, "Unknown difficulty should use unchanged standard values.")
	var easy_recovery: Dictionary = RULES.defeat_recovery("story", 45, 30)
	assert(int(easy_recovery.hp) == 34 and int(easy_recovery.silver) == 30, "Story defeat recovery should be generous and free.")
	var hard_recovery: Dictionary = RULES.defeat_recovery("master", 45, 10)
	assert(int(hard_recovery.hp) == 15 and int(hard_recovery.silver) == 0 and int(hard_recovery.loss) == 10, "Master defeat loss should never make silver negative.")
	print("DifficultyRules tests passed.")
	quit()
