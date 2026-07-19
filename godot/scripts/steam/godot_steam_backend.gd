class_name GodotSteamBackend
extends RefCounted

var api
var ready: bool = false
var stats_ready: bool = true
var pending_achievements: Dictionary = {}
var pending_stats: Dictionary = {}

func _init(injected_api = null) -> void:
	api = injected_api

func initialize() -> bool:
	if api == null:
		if not Engine.has_singleton("Steam"):
			return false
		api = Engine.get_singleton("Steam")
	if not _supports(["steamInitEx", "run_callbacks", "getAchievement", "setAchievement", "storeStats", "setStatInt", "getStatInt"]):
		return false
	var result = api.call("steamInitEx")
	ready = _init_succeeded(result)
	if ready and api.has_signal("current_stats_received"):
		stats_ready = false
		if not api.is_connected("current_stats_received", _on_current_stats_received):
			api.connect("current_stats_received", _on_current_stats_received)
	if ready and api.has_method("requestCurrentStats"):
		api.call("requestCurrentStats")
	return ready

func backend_name() -> String:
	return "GodotSteam Live" if ready else "GodotSteam Unavailable"

func is_live() -> bool:
	return ready

func account_stats_ready() -> bool:
	return ready and stats_ready

func poll() -> void:
	if ready:
		api.call("run_callbacks")

func shutdown() -> void:
	if not ready:
		return
	if api.has_method("steamShutdown"):
		api.call("steamShutdown")
	ready = false
	stats_ready = false

func unlock_achievement(api_name: String) -> bool:
	if not ready or bool(pending_achievements.get(api_name, false)) or (stats_ready and is_achievement_unlocked(api_name)):
		return false
	if not stats_ready:
		pending_achievements[api_name] = true
		return true
	if not bool(api.call("setAchievement", api_name)):
		return false
	return bool(api.call("storeStats"))

func is_achievement_unlocked(api_name: String) -> bool:
	if not ready:
		return false
	if bool(pending_achievements.get(api_name, false)):
		return true
	if not stats_ready:
		return false
	var result = api.call("getAchievement", api_name)
	if typeof(result) == TYPE_DICTIONARY:
		return bool(result.get("achieved", result.get("unlocked", false)))
	return bool(result)

func set_stat(stat_name: String, value: int) -> bool:
	if not ready:
		return false
	var normalized := maxi(0, value)
	if not stats_ready:
		if int(pending_stats.get(stat_name, -1)) == normalized:
			return false
		pending_stats[stat_name] = normalized
		return true
	if get_stat(stat_name) == normalized:
		return false
	if not bool(api.call("setStatInt", stat_name, normalized)):
		return false
	return bool(api.call("storeStats"))

func get_stat(stat_name: String) -> int:
	if not ready:
		return 0
	if pending_stats.has(stat_name):
		return int(pending_stats[stat_name])
	if not stats_ready:
		return 0
	var result = api.call("getStatInt", stat_name)
	if typeof(result) == TYPE_DICTIONARY:
		return int(result.get("stat", result.get("value", 0)))
	return int(result)

func _supports(methods: Array[String]) -> bool:
	for method in methods:
		if not api.has_method(method):
			return false
	return true

func _init_succeeded(result) -> bool:
	if typeof(result) == TYPE_DICTIONARY:
		return int(result.get("status", result.get("result", -1))) == 0
	return bool(result)

func _on_current_stats_received(_game_id: int, result: int, _user_id: int) -> void:
	if not ready or result != 1:
		return
	stats_ready = true
	var changed := false
	for api_name in pending_achievements:
		if bool(api.call("setAchievement", str(api_name))):
			changed = true
	for stat_name in pending_stats:
		if bool(api.call("setStatInt", str(stat_name), int(pending_stats[stat_name]))):
			changed = true
	pending_achievements.clear()
	pending_stats.clear()
	if changed:
		api.call("storeStats")
