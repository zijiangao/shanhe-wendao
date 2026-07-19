class_name LocalSteamBackend
extends RefCounted

const DEFAULT_PATH := "user://steam_local.cfg"

var path: String
var unlocked: Dictionary = {}
var stats: Dictionary = {}

func _init(storage_path: String = DEFAULT_PATH) -> void:
	path = storage_path

func initialize() -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return true
	for key in config.get_section_keys("achievements"):
		unlocked[str(key)] = bool(config.get_value("achievements", key, false))
	for key in config.get_section_keys("stats"):
		stats[str(key)] = int(config.get_value("stats", key, 0))
	return true

func backend_name() -> String:
	return "Local Simulation"

func is_live() -> bool:
	return false

func unlock_achievement(api_name: String) -> bool:
	if bool(unlocked.get(api_name, false)):
		return false
	unlocked[api_name] = true
	flush()
	return true

func is_achievement_unlocked(api_name: String) -> bool:
	return bool(unlocked.get(api_name, false))

func set_stat(stat_name: String, value: int) -> bool:
	var normalized := maxi(0, value)
	if int(stats.get(stat_name, 0)) == normalized:
		return false
	stats[stat_name] = normalized
	flush()
	return true

func get_stat(stat_name: String) -> int:
	return int(stats.get(stat_name, 0))

func flush() -> bool:
	var config := ConfigFile.new()
	for key in unlocked:
		config.set_value("achievements", key, bool(unlocked[key]))
	for key in stats:
		config.set_value("stats", key, int(stats[key]))
	return config.save(path) == OK

func reset_for_tests() -> void:
	unlocked.clear()
	stats.clear()
	flush()
