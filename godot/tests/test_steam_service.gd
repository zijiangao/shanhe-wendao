extends SceneTree

const LOCAL_BACKEND := preload("res://scripts/steam/local_steam_backend.gd")
const LIVE_BACKEND := preload("res://scripts/steam/godot_steam_backend.gd")
const TEST_PATH := "user://codex_steam_service_test.cfg"

class FakeSteamApi extends RefCounted:
	signal current_stats_received(game_id: int, result: int, user_id: int)
	var achievements: Dictionary = {}
	var stats: Dictionary = {}
	var stored: int = 0
	var requested: bool = false
	var callbacks: int = 0
	var shutdown_called: bool = false

	func steamInitEx() -> Dictionary:
		return {"status": 0, "verbal": "OK"}

	func requestCurrentStats() -> bool:
		requested = true
		return true

	func run_callbacks() -> void:
		callbacks += 1

	func steamShutdown() -> void:
		shutdown_called = true

	func getAchievement(api_name: String) -> Dictionary:
		return {"achieved": bool(achievements.get(api_name, false))}

	func setAchievement(api_name: String) -> bool:
		achievements[api_name] = true
		return true

	func storeStats() -> bool:
		stored += 1
		return true

	func setStatInt(stat_name: String, value: int) -> bool:
		stats[stat_name] = value
		return true

	func getStatInt(stat_name: String) -> Dictionary:
		return {"stat": int(stats.get(stat_name, 0))}

func _initialize() -> void:
	_cleanup()
	var service = root.get_node("SteamService")
	if service.definitions.is_empty():
		service._load_definitions()
	var backend = LOCAL_BACKEND.new(TEST_PATH)
	assert(service.use_backend(backend), "The local Steam backend should initialize without the SDK.")
	assert(not service.is_live(), "The local backend must never claim a live Steam connection.")
	assert(service.definitions.size() == 11, "The commercial achievement set should include finale and ending awards.")
	assert(service.release_data_errors().is_empty(), "Shipping achievement metadata should satisfy the Steam release contract.")
	var ids: Dictionary = {}
	for definition in service.definitions:
		var api_name := str(definition.api_name)
		assert(api_name.begins_with("ACH_"), "Steam achievement API names should use a stable ACH_ prefix.")
		assert(not ids.has(api_name), "Achievement API names must be unique.")
		ids[api_name] = true

	var state := {
		"quest_stage": "game_complete",
		"flags": ["villain_revealed", "game_complete"],
		"companions": ["lin_qingshuang"],
		"items": ["思过崖通行令"],
		"skill_mastery": {"cloud": 3, "frost": 0, "frost_guard": 0},
		"ending": {"id": "destroy"}
	}
	service.evaluate_state(state)
	assert(service.unlocked_count() == 9, "One completed route should unlock progression plus exactly one of three endings.")
	state.ending.id = "seal"
	service.evaluate_state(state)
	state.ending.id = "preserve"
	service.evaluate_state(state)
	assert(service.unlocked_count() == service.definitions.size(), "Completing all ending routes should unlock the full achievement set.")
	assert(backend.get_stat("STAT_HIGHEST_MASTERY") == 3, "Steam stat progress should mirror the highest mastery.")
	assert(not service.unlock("ACH_FIRST_STEPS"), "Unlocking an existing achievement must be idempotent.")

	var fake_api := FakeSteamApi.new()
	var live_backend = LIVE_BACKEND.new(fake_api)
	assert(live_backend.initialize() and live_backend.is_live(), "A compatible GodotSteam API should initialize the live backend.")
	assert(fake_api.requested, "Live initialization should request current account stats.")
	assert(not live_backend.account_stats_ready(), "Live account data should remain pending until Steam sends its stats callback.")
	live_backend.poll()
	assert(fake_api.callbacks == 1, "The live backend should pump Steam callbacks once per poll.")
	assert(live_backend.unlock_achievement("ACH_FIRST_STEPS"), "Unlock requests should queue while Steam account stats are loading.")
	assert(live_backend.set_stat("STAT_HIGHEST_MASTERY", 5), "Stat updates should queue while Steam account stats are loading.")
	assert(fake_api.stored == 0, "Queued Steam progress must not flush before the stats callback.")
	fake_api.current_stats_received.emit(0, 1, 0)
	assert(live_backend.account_stats_ready(), "A successful Steam callback should mark account stats ready.")
	assert(fake_api.stored == 1, "Queued progress should merge into one storeStats call after account stats arrive.")
	assert(live_backend.is_achievement_unlocked("ACH_FIRST_STEPS") and live_backend.get_stat("STAT_HIGHEST_MASTERY") == 5, "Queued Steam progress should be visible after the callback.")
	assert(not live_backend.unlock_achievement("ACH_FIRST_STEPS"), "The live backend must keep achievement unlocks idempotent.")
	live_backend.shutdown()
	assert(fake_api.shutdown_called and not live_backend.is_live(), "Shutdown should release Steam and clear the live state.")

	var reloaded = LOCAL_BACKEND.new(TEST_PATH)
	assert(reloaded.initialize(), "The local achievement file should reload.")
	assert(reloaded.is_achievement_unlocked("ACH_EMEI_GUEST"), "Local achievement progress should persist across sessions.")
	_cleanup()
	print("SteamService tests passed.")
	quit()

func _cleanup() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
