extends Node

signal achievement_unlocked(api_name: String, title: String)

const LOCAL_BACKEND := preload("res://scripts/steam/local_steam_backend.gd")
const ACHIEVEMENTS_PATH := "res://data/steam_achievements.json"

var backend
var definitions: Array = []
var definitions_by_id: Dictionary = {}

func _ready() -> void:
	_load_definitions()
	use_backend(LOCAL_BACKEND.new())
	GameState.state_changed.connect(_on_game_state_changed)
	evaluate_state(GameState.data)

func use_backend(next_backend) -> bool:
	if next_backend == null or not next_backend.has_method("initialize"):
		return false
	backend = next_backend
	return bool(backend.initialize())

func backend_name() -> String:
	return str(backend.backend_name()) if backend != null and backend.has_method("backend_name") else "Unavailable"

func is_live() -> bool:
	return bool(backend.is_live()) if backend != null and backend.has_method("is_live") else false

func unlock(api_name: String) -> bool:
	if backend == null or not definitions_by_id.has(api_name):
		return false
	if not bool(backend.unlock_achievement(api_name)):
		return false
	var definition: Dictionary = definitions_by_id[api_name]
	achievement_unlocked.emit(api_name, str(definition.title))
	return true

func is_unlocked(api_name: String) -> bool:
	return backend != null and bool(backend.is_achievement_unlocked(api_name))

func unlocked_count() -> int:
	var count := 0
	for definition in definitions:
		if is_unlocked(str(definition.api_name)):
			count += 1
	return count

func evaluate_state(state: Dictionary) -> void:
	if state.is_empty() or backend == null:
		return
	var stage := str(state.get("quest_stage", "meet_master"))
	var later_stages := ["chapter2_complete", "huashan_meet_companion", "huashan_trial", "huashan_trial_complete", "chapter3_complete", "emei_meet_su", "emei_investigate", "emei_trial", "final_assault", "final_choice", "game_complete"]
	if stage != "meet_master": unlock("ACH_FIRST_STEPS")
	if "villain_revealed" in state.get("flags", []): unlock("ACH_BLACKREED_VICTORY")
	if stage in later_stages: unlock("ACH_PALACE_TRUTH")
	if "lin_qingshuang" in state.get("companions", []): unlock("ACH_SWORD_COMPANIONS")
	if "思过崖通行令" in state.get("items", []): unlock("ACH_HUASHAN_TRIAL")
	if stage in ["emei_trial", "final_assault", "final_choice", "game_complete"]: unlock("ACH_EMEI_GUEST")
	if stage in ["final_choice", "game_complete"]: unlock("ACH_WUKU_VICTORY")
	var ending: Dictionary = state.get("ending", {})
	match str(ending.get("id", "")):
		"destroy": unlock("ACH_ENDING_DESTROY")
		"seal": unlock("ACH_ENDING_SEAL")
		"preserve": unlock("ACH_ENDING_PRESERVE")
	var mastery: Dictionary = state.get("skill_mastery", {})
	var highest_mastery := maxi(int(mastery.get("cloud", 0)), maxi(int(mastery.get("frost", 0)), int(mastery.get("frost_guard", 0))))
	backend.set_stat("STAT_HIGHEST_MASTERY", highest_mastery)
	if highest_mastery >= 3: unlock("ACH_PRACTICED_HAND")

func _on_game_state_changed() -> void:
	evaluate_state(GameState.data)

func _load_definitions() -> void:
	definitions.clear()
	definitions_by_id.clear()
	var file := FileAccess.open(ACHIEVEMENTS_PATH, FileAccess.READ)
	if file == null:
		push_error("Steam achievement definitions are missing.")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Steam achievement definitions must be an array.")
		return
	for value in parsed:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = value
		var api_name := str(definition.get("api_name", ""))
		if api_name.is_empty() or definitions_by_id.has(api_name):
			continue
		definitions.append(definition)
		definitions_by_id[api_name] = definition
