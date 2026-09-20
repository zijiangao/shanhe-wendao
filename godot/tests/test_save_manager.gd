extends SceneTree

const TEST_PATH := "user://codex_save_recovery_test.json"

func _initialize() -> void:
	_cleanup()
	var game_state := root.get_node("GameState")
	var save_manager := root.get_node("SaveManager")
	game_state.new_game()
	game_state.data.week = 8
	assert(save_manager._write(TEST_PATH, game_state.data), "Initial test save should succeed.")
	game_state.data.week = 9
	assert(save_manager._write(TEST_PATH, game_state.data), "Second save should rotate the previous save to backup.")
	assert(FileAccess.file_exists(TEST_PATH + ".bak"), "A successful overwrite should retain one backup generation.")

	var corrupt := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	assert(corrupt != null, "The primary test save should be writable.")
	corrupt.store_string("not valid json")
	corrupt.close()
	assert(save_manager._load(TEST_PATH), "Loading should recover from a valid backup.")
	assert(int(game_state.data.week) == 8, "Backup recovery should restore the previous generation.")

	_cleanup()
	assert(str(ProjectSettings.get_setting("application/config/name")).ends_with("-tests"))
	assert(save_manager.save_slot(3))
	game_state.data.week = 10
	assert(save_manager.save_slot(3))
	DirAccess.remove_absolute("user://save_3.json")
	assert(save_manager.slot_exists(3), "Backup-only slots must remain available.")
	assert(int(save_manager.slot_summary(3).week) == 8)
	assert(save_manager.load_slot(3) and int(game_state.data.week) == 8)
	assert(not save_manager.slot_exists(0) and save_manager.slot_summary(4).is_empty())
	print("SaveManager tests passed.")
	quit()

func _cleanup() -> void:
	var directory := DirAccess.open("user://")
	if directory == null:
		return
	for path in [TEST_PATH, TEST_PATH + ".bak", TEST_PATH + ".tmp"]:
		var relative: String = str(path).trim_prefix("user://")
		if directory.file_exists(relative):
			directory.remove(relative)
