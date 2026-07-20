extends SceneTree

const RULES := preload("res://scripts/progression/reward_rules.gd")

func _initialize() -> void:
	_test_reward_catalog()
	_test_each_reward_axis()
	_test_invalid_choice_is_safe()
	print("RewardRules tests passed.")
	quit()

func _test_reward_catalog() -> void:
	for battle_id in ["qingyun_spar", "blackreed", "huashan_trial", "wuku_finale"]:
		var base := RULES.base_for(battle_id)
		var choices := RULES.choices_for(battle_id)
		assert(int(base.xp) > 0 and int(base.silver) >= 0 and not str(base.item).is_empty(), "Every encounter needs a complete base reward.")
		assert(choices.size() == 3, "Every encounter should offer exactly three mutually exclusive choices.")
		var ids: PackedStringArray = []
		for choice in choices:
			ids.append(str(choice.id))
			assert(not str(choice.title).is_empty() and not str(choice.description).is_empty(), "Reward choices need player-facing copy.")
		assert(ids.size() == Array(ids).duplicate().size() and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2], "Choice IDs must be unique per encounter.")

func _test_each_reward_axis() -> void:
	var state := _state()
	assert(RULES.apply_choice(state, "blackreed", "temper"), "A valid cultivation reward should apply.")
	assert(int(state.xp) == 8 and int(state.skill_mastery.cloud) == 1, "Cultivation rewards should improve both XP and mastery.")
	state = _state()
	state.qi = 3
	assert(RULES.apply_choice(state, "blackreed", "supplies"), "A valid supply reward should apply.")
	assert(int(state.silver) == 15 and int(state.qi) == 20, "Supply rewards should grant money and restore qi.")
	state = _state()
	assert(RULES.apply_choice(state, "huashan_trial", "fellowship"), "A valid relationship reward should apply.")
	assert(int(state.renown) == 2 and int(state.faction_relations.huashan) == 2, "Relationship rewards should affect long-term route values.")
	state = _state()
	assert(RULES.apply_choice(state, "qingyun_spar", "fellowship"), "Sparring should support a Qingyun relationship reward.")
	assert(int(state.renown) == 1 and int(state.faction_relations.qingyun) == 1, "Sparring fellowship should reward its home faction.")

func _test_invalid_choice_is_safe() -> void:
	var state := _state()
	var before := state.duplicate(true)
	assert(not RULES.apply_choice(state, "blackreed", "not-a-choice"), "Unknown rewards must be rejected.")
	assert(state == before, "Rejected rewards must not mutate progression.")

func _state() -> Dictionary:
	return {"xp": 0, "silver": 0, "renown": 0, "qi": 10, "skill_mastery": {"cloud": 0, "frost": 0, "frost_guard": 0}, "alignment": {"heroism": 0, "strategy": 0, "authority": 0}, "faction_relations": {"qingyun": 0, "huashan": 0, "emei": 0, "shaolin": 0}}
