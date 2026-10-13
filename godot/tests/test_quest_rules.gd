extends SceneTree

const RULES := preload("res://scripts/progression/quest_rules.gd")

func _initialize() -> void:
	var state := root.get_node("GameState")
	_test_fresh_and_interleaved(state)
	_test_legacy_migration(state)
	_test_validation()
	_test_monotonic_progress()
	_test_battle_round_trips(state)
	_test_optional_finale_companion(state)
	print("Independent quest rules and save migration tests passed.")
	quit()

func _test_fresh_and_interleaved(state: Node) -> void:
	state.new_game()
	assert(state.data.quest_stage == "explore", "A new game must not automatically assign a quest.")
	for id in RULES.REGION_IDS:
		assert(state.quest_progress(id) == "available", "Every region must begin available.")
	assert(state.set_quest_progress("huashan", "huashan_meet_companion"))
	assert(state.quest_progress("blackreed") == "available" and state.quest_progress("luoyang") == "available", "Starting Huashan must not imply earlier chapters were completed.")
	assert(state.set_quest_progress("emei", "emei_meet_su"))
	assert(state.set_quest_progress("luoyang", "luoyang_investigate"))
	assert(state.set_quest_progress("blackreed", "investigate"))
	assert(state.set_quest_progress("huashan", "huashan_trial"))
	assert(state.quest_progress("emei") == "emei_meet_su" and state.quest_progress("luoyang") == "luoyang_investigate", "Interleaving quests must retain each region's next step.")
	assert(state.set_quest_progress("blackreed", "chapter_complete"))
	assert(state.quest_progress("huashan") == "huashan_trial" and state.quest_progress("finale") == "available")
	var independent: Dictionary = state.data.duplicate(true)
	assert(state.import_data(JSON.parse_string(JSON.stringify(independent))))
	assert(state.data.quest_states == independent.quest_states, "Independent progress must survive a serialized save round trip.")
	var before: Dictionary = state.data.duplicate(true)
	assert(not state.set_quest_progress("luoyang", "huashan_trial"))
	assert(not state.set_quest_progress("unknown", "available"))
	assert(state.data == before, "Invalid quest transitions must not mutate the save.")
	state.new_game()
	state.data.erase("quest_states")
	state.data.quest_stage = "huashan_trial"
	assert(state.quest_progress("huashan") == "huashan_trial" and state.quest_progress("luoyang") == "chapter2_complete", "Old scalar-only state must remain usable.")
	assert(state.set_quest_progress("emei", "emei_meet_su"))
	assert(state.quest_progress("huashan") == "huashan_trial", "The first independent update must preserve a seeded legacy fixture.")
	state.new_game()
	assert(state.set_quest_progress("emei", "emei_complete"))
	assert(state.quest_progress("finale") == "available", "Completing Emei must not automatically accept the finale.")
	var emei_finished: Dictionary = state.data.duplicate(true)
	assert(state.import_data(JSON.parse_string(JSON.stringify(emei_finished))))
	assert(state.quest_progress("emei") == "emei_complete" and state.data.quest_stage == "emei_complete", "Emei completion must survive saving before the optional finale is started.")
	state.new_game()
	var stale_mirror: Dictionary = state.data.duplicate(true)
	stale_mirror.quest_stage = "game_complete"
	assert(state.import_data(stale_mirror))
	assert(state.data.quest_stage == "explore" and state.data.quest_states == RULES.DEFAULT_STAGES, "Loading an unstarted regional save must repair its stale scalar mirror without completing any quests.")

func _test_legacy_migration(state: Node) -> void:
	var fixtures := [
		["meet_master", ["available", "available", "available", "available", "available"]],
		["investigate", ["investigate", "available", "available", "available", "available"]],
		["return_master", ["return_master", "available", "available", "available", "available"]],
		["chapter_complete", ["chapter_complete", "available", "available", "available", "available"]],
		["luoyang_investigate", ["chapter_complete", "luoyang_investigate", "available", "available", "available"]],
		["chapter2_complete", ["chapter_complete", "chapter2_complete", "available", "available", "available"]],
		["huashan_meet_companion", ["chapter_complete", "chapter2_complete", "huashan_meet_companion", "available", "available"]],
		["huashan_trial", ["chapter_complete", "chapter2_complete", "huashan_trial", "available", "available"]],
		["huashan_trial_complete", ["chapter_complete", "chapter2_complete", "huashan_trial_complete", "available", "available"]],
		["chapter3_complete", ["chapter_complete", "chapter2_complete", "chapter3_complete", "available", "available"]],
		["emei_meet_su", ["chapter_complete", "chapter2_complete", "chapter3_complete", "emei_meet_su", "available"]],
		["emei_investigate", ["chapter_complete", "chapter2_complete", "chapter3_complete", "emei_investigate", "available"]],
		["emei_trial", ["chapter_complete", "chapter2_complete", "chapter3_complete", "emei_trial", "available"]],
		["final_assault", ["chapter_complete", "chapter2_complete", "chapter3_complete", "emei_complete", "final_assault"]],
		["final_choice", ["chapter_complete", "chapter2_complete", "chapter3_complete", "emei_complete", "final_choice"]],
		["game_complete", ["chapter_complete", "chapter2_complete", "chapter3_complete", "emei_complete", "game_complete"]]
	]
	for fixture in fixtures:
		state.new_game()
		var legacy: Dictionary = state.data.duplicate(true)
		legacy.erase("quest_states")
		legacy.save_version = 12
		legacy.quest_stage = fixture[0]
		assert(state.import_data(legacy), "The legacy stage must remain loadable: " + str(fixture[0]))
		assert(int(state.data.save_version) == 13)
		for index in range(RULES.REGION_IDS.size()):
			var id: String = RULES.REGION_IDS[index]
			assert(state.quest_progress(id) == fixture[1][index], "Legacy migration lost progress for %s at %s." % [id, fixture[0]])
	for probe in [["blackreed", "investigate", "blackreed", "return_master"], ["huashan_trial", "huashan_trial", "huashan", "huashan_trial_complete"], ["wuku_finale", "final_assault", "finale", "final_choice"]]:
		state.new_game()
		var legacy: Dictionary = state.data.duplicate(true)
		legacy.erase("quest_states")
		legacy.save_version = 12
		legacy.quest_stage = probe[1]
		legacy.pending_reward = {"battle_id": probe[0], "turns": 3}
		assert(state.import_data(legacy))
		assert(state.quest_progress(probe[2]) == probe[3], "Legacy pending rewards must recover the completed battle step.")
		assert(state.data.pending_reward == legacy.pending_reward, "Migration must preserve the player's unclaimed reward.")

func _test_validation() -> void:
	var normalized := RULES.normalized_states({"blackreed": "not_a_stage", "luoyang": "huashan_trial", "huashan": "huashan_trial", "emei": 12, "finale": "final_assault", "unknown": "game_complete"}, "chapter_complete", {"flags": ["villain_revealed"]})
	assert(normalized.blackreed == "available" and normalized.luoyang == "available" and normalized.emei == "available")
	assert(normalized.huashan == "huashan_trial" and normalized.finale == "final_assault" and normalized.size() == RULES.REGION_IDS.size(), "Invalid entries must be repaired without overwriting valid independent progress.")
	assert(RULES.normalized_states([], "corrupt") == RULES.DEFAULT_STAGES)
	assert(RULES.stage({"quest_states": normalized, "quest_stage": "chapter_complete"}, "blackreed") == "available", "A stale scalar mirror must not overwrite the regional model.")
	var untouched := {"quest_states": RULES.DEFAULT_STAGES.duplicate(true), "quest_stage": "game_complete"}
	assert(RULES.normalized_states(untouched.quest_states, untouched.quest_stage, {"flags": ["game_complete"], "items": ["武库钥印"]}) == RULES.DEFAULT_STAGES, "An explicit unstarted regional save must remain unstarted despite stale legacy markers.")
	for id in RULES.REGION_IDS:
		assert(RULES.stage(untouched, str(id)) == "available", "A scalar mirror must not fabricate any quest progress in a new-format save.")
	assert(RULES.set_stage(untouched, "huashan", "huashan_meet_companion"))
	assert(RULES.stage(untouched, "blackreed") == "available" and RULES.stage(untouched, "luoyang") == "available", "Starting a quest from an all-available save must preserve untouched regions.")
	assert(RULES.stage({}, "unknown") == "")
	assert(RULES.region_for_stage("final_choice") == "finale" and RULES.region_for_stage("available") == "")
	assert(RULES.region_for_stage("emei_complete") == "emei")
	assert(RULES.stage({"quest_stage": "emei_complete"}, "emei") == "emei_complete" and RULES.stage({"quest_stage": "emei_complete"}, "huashan") == "available", "The new scalar Emei completion marker must not imply a linear chapter order.")

func _test_monotonic_progress() -> void:
	for id in RULES.REGION_IDS:
		var completed := {"quest_states": RULES.DEFAULT_STAGES.duplicate(true), "quest_stage": "explore"}
		var region_stages: Array = RULES.REGION_STAGES[id]
		var final_stage: String = region_stages.back()
		assert(RULES.set_stage(completed, str(id), final_stage))
		var before: Dictionary = completed.duplicate(true)
		for earlier_stage in region_stages.slice(0, region_stages.size() - 1):
			assert(not RULES.set_stage(completed, str(id), str(earlier_stage)), "A completed region must reject backward progress.")
			assert(completed == before, "A rejected backward step must leave every region and the scalar mirror untouched.")
		assert(RULES.set_stage(completed, str(id), final_stage), "Focusing on the same step remains valid.")
	var active := {"quest_states": RULES.DEFAULT_STAGES.duplicate(true), "quest_stage": "explore"}
	assert(RULES.set_stage(active, "huashan", "huashan_trial"))
	var before: Dictionary = active.duplicate(true)
	assert(not RULES.set_stage(active, "huashan", "huashan_meet_companion") and active == before, "A started quest must not replay earlier rewards through a backward update.")

func _test_battle_round_trips(state: Node) -> void:
	state.new_game()
	assert(state.set_quest_progress("emei", "emei_investigate"))
	assert(state.set_quest_progress("huashan", "huashan_trial"))
	state.data.companions = ["lin_qingshuang"]
	assert(state.start_huashan_trial_battle())
	var opening: Dictionary = state.data.duplicate(true)
	assert(state.import_data(JSON.parse_string(JSON.stringify(opening))))
	assert(_equivalent(opening.battle, state.data.battle) and _equivalent(opening.battle_retry, state.data.battle_retry), "Migration must preserve an in-progress battle and its retry checkpoint.")
	assert(state.quest_progress("emei") == "emei_investigate" and state.quest_progress("luoyang") == "available")
	state.finish_battle(false)
	var defeated: Dictionary = state.data.duplicate(true)
	assert(state.import_data(JSON.parse_string(JSON.stringify(defeated))))
	assert(state.data.battle.is_empty() and _equivalent(defeated.battle_retry, state.data.battle_retry))
	assert(state.retry_last_battle())
	assert(state.quest_progress("huashan") == "huashan_trial" and state.quest_progress("emei") == "emei_investigate", "Retrying a battle must not change other quests.")
	state.finish_battle(true)
	assert(state.set_quest_progress("huashan", "huashan_trial_complete"))
	var victory: Dictionary = state.data.duplicate(true)
	assert(state.import_data(JSON.parse_string(JSON.stringify(victory))))
	assert(_equivalent(victory.pending_reward, state.data.pending_reward) and state.data.quest_states == victory.quest_states)
	assert(state.claim_pending_reward("temper"))
	assert(state.quest_progress("blackreed") == "available" and state.quest_progress("emei") == "emei_investigate", "Claiming an independent region's reward must not fabricate earlier completion.")

func _test_optional_finale_companion(state: Node) -> void:
	for has_lin in [false, true]:
		state.new_game()
		assert(state.set_quest_progress("emei", "emei_complete"))
		assert(state.set_quest_progress("finale", "final_assault"))
		state.data.flags = ["su_trust"]
		if has_lin:
			state.data.companions = ["lin_qingshuang"]
		assert(state.start_final_battle())
		assert(state.data.battle.has("ally") == has_lin, "The finale must only include a recruited companion.")
		assert(("林清霜" in str(state.data.battle.result)) == has_lin)
		var finale: Dictionary = state.data.duplicate(true)
		assert(state.import_data(JSON.parse_string(JSON.stringify(finale))))
		assert(state.data.battle.has("ally") == has_lin and _equivalent(finale.battle, state.data.battle))
		state.finish_battle(true)
		assert(state.set_quest_progress("finale", "final_choice"))
		state.complete_game("seal")
		assert(state.quest_progress("finale") == "game_complete" and state.data.quest_stage == "game_complete")
		assert(state.quest_progress("blackreed") == "available" and state.quest_progress("luoyang") == "available", "Completing the finale must preserve optional untouched regions.")
		assert(("林清霜" in str(state.data.ending.story)) == has_lin)
		assert("武库钥印" in str(state.data.ending.story), "An ending reached before Blackreed must use the token the player actually owns.")
		var ending: Dictionary = state.data.duplicate(true)
		assert(state.import_data(JSON.parse_string(JSON.stringify(ending))))
		assert(_equivalent(ending.ending, state.data.ending) and state.data.quest_states == ending.quest_states)

func _equivalent(expected: Variant, actual: Variant) -> bool:
	# Existing save validation may add neutral battle defaults, and JSON
	# decodes numbers as floats. Every original gameplay field must survive.
	if expected is Dictionary:
		if not actual is Dictionary:
			return false
		for key in expected:
			if not actual.has(key) or not _equivalent(expected[key], actual[key]):
				return false
		return true
	if expected is Array:
		if not actual is Array or expected.size() != actual.size():
			return false
		for index in range(expected.size()):
			if not _equivalent(expected[index], actual[index]):
				return false
		return true
	if (expected is int or expected is float) and (actual is int or actual is float):
		return float(expected) == float(actual)
	return expected == actual
