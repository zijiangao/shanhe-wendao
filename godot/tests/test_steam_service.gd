extends SceneTree

const LOCAL_BACKEND := preload("res://scripts/steam/local_steam_backend.gd")
const TEST_PATH := "user://codex_steam_service_test.cfg"

func _initialize() -> void:
	_cleanup()
	var service = root.get_node("SteamService")
	if service.definitions.is_empty():
		service._load_definitions()
	var backend = LOCAL_BACKEND.new(TEST_PATH)
	assert(service.use_backend(backend), "The local Steam backend should initialize without the SDK.")
	assert(not service.is_live(), "The local backend must never claim a live Steam connection.")
	assert(service.definitions.size() == 7, "The initial commercial achievement set should remain complete.")
	var ids: Dictionary = {}
	for definition in service.definitions:
		var api_name := str(definition.api_name)
		assert(api_name.begins_with("ACH_"), "Steam achievement API names should use a stable ACH_ prefix.")
		assert(not ids.has(api_name), "Achievement API names must be unique.")
		ids[api_name] = true

	var state := {
		"quest_stage": "emei_trial",
		"flags": ["villain_revealed"],
		"companions": ["lin_qingshuang"],
		"items": ["思过崖通行令"],
		"skill_mastery": {"cloud": 3, "frost": 0, "frost_guard": 0}
	}
	service.evaluate_state(state)
	assert(service.unlocked_count() == service.definitions.size(), "A completed progression state should unlock all initial achievements.")
	assert(backend.get_stat("STAT_HIGHEST_MASTERY") == 3, "Steam stat progress should mirror the highest mastery.")
	assert(not service.unlock("ACH_FIRST_STEPS"), "Unlocking an existing achievement must be idempotent.")

	var reloaded = LOCAL_BACKEND.new(TEST_PATH)
	assert(reloaded.initialize(), "The local achievement file should reload.")
	assert(reloaded.is_achievement_unlocked("ACH_EMEI_GUEST"), "Local achievement progress should persist across sessions.")
	_cleanup()
	print("SteamService tests passed.")
	quit()

func _cleanup() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
