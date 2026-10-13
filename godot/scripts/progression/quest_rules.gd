class_name QuestRules
extends RefCounted

## Every region is available from the beginning. Each region owns its own
## progress; quest_stage is only the most recently followed story's mirror.
const REGION_IDS := ["blackreed", "luoyang", "huashan", "emei", "finale"]
const DEFAULT_STAGES := {"blackreed": "available", "luoyang": "available", "huashan": "available", "emei": "available", "finale": "available"}
const REGION_STAGES := {
	"blackreed": ["available", "meet_master", "investigate", "return_master", "chapter_complete"],
	"luoyang": ["available", "luoyang_investigate", "chapter2_complete"],
	"huashan": ["available", "huashan_meet_companion", "huashan_trial", "huashan_trial_complete", "chapter3_complete"],
	"emei": ["available", "emei_meet_su", "emei_investigate", "emei_trial", "emei_complete"],
	"finale": ["available", "final_assault", "final_choice", "game_complete"]
}
const LEGACY_STAGES := ["meet_master", "investigate", "return_master", "chapter_complete", "luoyang_investigate", "chapter2_complete", "huashan_meet_companion", "huashan_trial", "huashan_trial_complete", "chapter3_complete", "emei_meet_su", "emei_investigate", "emei_trial", "final_assault", "final_choice", "game_complete"]

static func stage(state: Dictionary, id: String) -> String:
	if not DEFAULT_STAGES.has(id):
		return ""
	# The regional dictionary is authoritative even when every quest is
	# still available. A stale scalar mirror must never complete other stories.
	if typeof(state.get("quest_states", null)) == TYPE_DICTIONARY:
		return str(_validated_states(state.quest_states)[id])
	return str(_legacy_states(str(state.get("quest_stage", "explore")))[id])

static func set_stage(state: Dictionary, id: String, next_stage: String) -> bool:
	if not valid_stage(id, next_stage):
		return false
	var saved := normalized_states(state.get("quest_states", null), str(state.get("quest_stage", "explore")))
	if REGION_STAGES[id].find(next_stage) < REGION_STAGES[id].find(str(saved[id])):
		return false
	saved[id] = next_stage
	state.quest_states = saved
	state.quest_stage = next_stage if next_stage != "available" else "explore"
	return true

static func valid_stage(id: String, value: String) -> bool:
	return REGION_STAGES.has(id) and value in REGION_STAGES[id]

static func region_for_stage(value: String) -> String:
	if value == "available":
		return ""
	for id in REGION_IDS:
		if value in REGION_STAGES[id]:
			return str(id)
	return ""

static func normalized_states(value: Variant, legacy_stage: String = "explore", metadata: Dictionary = {}) -> Dictionary:
	var saved := _validated_states(value)
	if typeof(value) == TYPE_DICTIONARY:
		return saved
	var migrated := _legacy_states(legacy_stage)
	# A victory could have been saved between reward creation and the old
	# UI's scalar stage write. Keep those rewards, and recover the winning
	# region without fabricating progress in unrelated regions.
	var flags: Array = metadata.get("flags", []) if typeof(metadata.get("flags", [])) == TYPE_ARRAY else []
	var items: Array = metadata.get("items", []) if typeof(metadata.get("items", [])) == TYPE_ARRAY else []
	var pending: Dictionary = metadata.get("pending_reward", {}) if typeof(metadata.get("pending_reward", {})) == TYPE_DICTIONARY else {}
	if "villain_revealed" in flags or "玄铁令" in items or str(pending.get("battle_id", "")) == "blackreed":
		_advance_to(migrated, "blackreed", "return_master")
	if "思过崖通行令" in items or str(pending.get("battle_id", "")) == "huashan_trial":
		_advance_to(migrated, "huashan", "huashan_trial_complete")
	if "su_trust" in flags:
		_advance_to(migrated, "emei", "emei_trial")
	if "武库钥印" in items or str(pending.get("battle_id", "")) == "wuku_finale":
		_advance_to(migrated, "emei", "emei_complete")
		_advance_to(migrated, "finale", "final_choice")
	if "game_complete" in flags or (typeof(metadata.get("ending", {})) == TYPE_DICTIONARY and not Dictionary(metadata.get("ending", {})).is_empty()):
		_advance_to(migrated, "emei", "emei_complete")
		_advance_to(migrated, "finale", "game_complete")
	return migrated

static func _validated_states(value: Variant) -> Dictionary:
	var result := DEFAULT_STAGES.duplicate(true)
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for id in REGION_IDS:
		var saved_stage := str(value.get(id, "available"))
		if valid_stage(str(id), saved_stage):
			result[id] = saved_stage
	return result

static func _legacy_states(legacy_stage: String) -> Dictionary:
	var result := DEFAULT_STAGES.duplicate(true)
	var index := LEGACY_STAGES.find(legacy_stage)
	if index < 0:
		var region := region_for_stage(legacy_stage)
		if not region.is_empty():
			result[region] = legacy_stage
		return result
	if index >= 3:
		result.blackreed = "chapter_complete"
	elif index > 0:
		result.blackreed = legacy_stage
	if index >= 5:
		result.luoyang = "chapter2_complete"
	elif index == 4:
		result.luoyang = "luoyang_investigate"
	if index >= 9:
		result.huashan = "chapter3_complete"
	elif index >= 6:
		result.huashan = legacy_stage
	if index >= 13:
		result.emei = "emei_complete"
	elif index == 12:
		result.emei = "emei_trial"
	elif index >= 10:
		result.emei = legacy_stage
	if index >= 13:
		result.finale = legacy_stage
	return result

static func _advance_to(value: Dictionary, id: String, next_stage: String) -> void:
	if REGION_STAGES[id].find(next_stage) > REGION_STAGES[id].find(str(value[id])):
		value[id] = next_stage
