extends SceneTree

func _initialize() -> void:
	var valid := true
	var state = load("res://autoload/game_state.gd").new()
	root.add_child(state)
	state.new_game()
	state.data.energy = 3
	var quest_stage := str(state.data.quest_stage)
	valid = _check(state.start_qingyun_spar_battle(), "Qingyun sparring should be available as repeatable training.") and valid
	valid = _check(str(state.data.battle.battle_id) == "qingyun_spar" and state.data.battle.enemies.size() == 2, "Sparring should use its short two-opponent encounter.") and valid
	valid = _check(str(state.data.battle.rotation_id) == "swift_swords", "The first week should use the swift-sword lesson.") and valid
	valid = _check(int(state.data.week) == 2 and int(state.data.energy) == 2, "Sparring should spend exactly one week and energy.") and valid
	state.finish_battle(true)
	valid = _check(str(state.data.quest_stage) == quest_stage and "玄铁令" not in state.data.items and "villain_revealed" not in state.data.flags, "Optional sparring must not advance or contaminate the main story.") and valid
	valid = _check(str(state.data.pending_reward.battle_id) == "qingyun_spar" and int(state.data.xp) == 8, "S-grade sparring should grant its base and performance rewards together.") and valid
	valid = _check(str(state.data.pending_reward.grade) == "S" and int(state.data.pending_reward.performance_xp) == 4 and state.data.pending_reward.new_best, "Sparring should grade the victory, reward performance, and expose a new record.") and valid
	valid = _check(state.claim_pending_reward("fellowship") and int(state.data.faction_relations.qingyun) == 2, "Sparring should add the selected reward to the starting Qingyun relationship.") and valid

	state.new_game()
	state.data.energy = 3
	state.data.hp = 1
	valid = _check(state.start_qingyun_spar_battle(), "A second sparring match should remain available.") and valid
	state.finish_battle(false)
	valid = _check(int(state.data.hp) == int(state.data.max_hp) and int(state.data.silver) == 30, "A nonlethal sparring defeat should heal the hero without a silver penalty.") and valid

	print("Qingyun sparring tests passed." if valid else "Qingyun sparring tests failed.")
	quit(0 if valid else 1)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
	return condition
