extends Node

signal achievement_unlocked(api_name: String, title: String)

const LOCAL_BACKEND := preload("res://scripts/steam/local_steam_backend.gd")
const LIVE_BACKEND := preload("res://scripts/steam/godot_steam_backend.gd")
const ACHIEVEMENTS_PATH := "res://data/steam_achievements.json"
const RELEASE_ACHIEVEMENT_COUNT := 20
const TRAINING_RULES := preload("res://scripts/progression/training_minigame_rules.gd")
const HERBARIUM_RULES := preload("res://scripts/progression/herbarium_rules.gd")
const MINERALOGY_RULES := preload("res://scripts/progression/mineralogy_rules.gd")

var backend
var definitions: Array = []
var definitions_by_id: Dictionary = {}

func _ready() -> void:
	_load_definitions()
	if not use_backend(LIVE_BACKEND.new()):
		use_backend(LOCAL_BACKEND.new())
	GameState.state_changed.connect(_on_game_state_changed)
	evaluate_state(GameState.data)

func _process(_delta: float) -> void:
	if backend != null and backend.has_method("poll"):
		backend.poll()

func _exit_tree() -> void:
	if backend != null and backend.has_method("shutdown"):
		backend.shutdown()

func use_backend(next_backend) -> bool:
	if next_backend == null or not next_backend.has_method("initialize"):
		return false
	backend = next_backend
	return bool(backend.initialize())

func backend_name() -> String:
	return str(backend.backend_name()) if backend != null and backend.has_method("backend_name") else "Unavailable"

func is_live() -> bool:
	return bool(backend.is_live()) if backend != null and backend.has_method("is_live") else false

func connection_status() -> String:
	if not is_live():
		return "%s · 本地模拟（等待 App ID/SDK）" % backend_name()
	if backend.has_method("account_stats_ready") and not bool(backend.account_stats_ready()):
		return "%s · 统计同步中" % backend_name()
	return "%s · 已连接" % backend_name()

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

func progress_text(api_name: String, state: Dictionary) -> String:
	match api_name:
		"ACH_SPECIALTY_MASTERY":
			var highest := maxi(int(state.get("swordsmanship", 0)), maxi(int(state.get("bladesmanship", 0)), maxi(int(state.get("herbalism", 0)), int(state.get("mining", 0)))))
			return "进度 %d/10" % mini(10, maxi(0, highest))
		"ACH_PERFECT_TRAINING":
			var best := 0
			for record in TRAINING_RULES.normalize_records(state.get("training_records", {})).values():
				best = maxi(best, int(record.best_score))
			return "最高 %d/%d" % [best, TRAINING_RULES.MAX_TOTAL_SCORE]
		"ACH_HERBARIUM_COMPLETE":
			return "药谱 %d/%d" % [HERBARIUM_RULES.discovered_count(state.get("herbarium", {})), HERBARIUM_RULES.SPECIMENS.size()]
		"ACH_MINERALOGY_COMPLETE":
			return "矿谱 %d/%d" % [MINERALOGY_RULES.discovered_count(state.get("mineralogy", {})), MINERALOGY_RULES.SPECIMENS.size()]
	return ""

func release_data_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if definitions.is_empty():
		errors.append("No Steam achievement definitions were loaded.")
	var ids: Dictionary = {}
	for definition in definitions:
		var api_name := str(definition.get("api_name", ""))
		if not api_name.begins_with("ACH_"):
			errors.append("Invalid achievement API name: %s" % api_name)
		if ids.has(api_name):
			errors.append("Duplicate achievement API name: %s" % api_name)
		ids[api_name] = true
		if str(definition.get("title", "")).strip_edges().is_empty():
			errors.append("Achievement %s has no title." % api_name)
		if str(definition.get("description", "")).strip_edges().is_empty():
			errors.append("Achievement %s has no description." % api_name)
		if typeof(definition.get("hidden", null)) != TYPE_BOOL:
			errors.append("Achievement %s has no boolean hidden flag." % api_name)
	return errors

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
	var flags: Array = state.get("flags", [])
	if "training_s_grade" in flags: unlock("ACH_TRAINING_EXCELLENCE")
	if "spar_s_grade" in flags: unlock("ACH_SPAR_MASTER")
	if "training_event_seen" in flags: unlock("ACH_FORTUNATE_ENCOUNTER")
	if "crafted_healing_powder" in flags: unlock("ACH_FIELD_APOTHECARY")
	if "tempered_blade" in flags: unlock("ACH_FIRST_TEMPER")
	var highest_specialty := maxi(int(state.get("swordsmanship", 0)), maxi(int(state.get("bladesmanship", 0)), maxi(int(state.get("herbalism", 0)), int(state.get("mining", 0)))))
	backend.set_stat("STAT_HIGHEST_SPECIALTY", highest_specialty)
	if highest_specialty >= 10: unlock("ACH_SPECIALTY_MASTERY")
	var records := TRAINING_RULES.normalize_records(state.get("training_records", {}))
	for discipline in records:
		if int(records[discipline].best_score) >= TRAINING_RULES.MAX_TOTAL_SCORE:
			unlock("ACH_PERFECT_TRAINING")
			break
	if HERBARIUM_RULES.discovered_count(state.get("herbarium", {})) >= HERBARIUM_RULES.SPECIMENS.size():
		unlock("ACH_HERBARIUM_COMPLETE")
	if MINERALOGY_RULES.discovered_count(state.get("mineralogy", {})) >= MINERALOGY_RULES.SPECIMENS.size():
		unlock("ACH_MINERALOGY_COMPLETE")

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
