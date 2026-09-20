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
	game_state.data.week = 11
	assert(save_manager._write(TEST_PATH, game_state.data))
	assert(int(save_manager._read_dictionary(TEST_PATH + ".bak").week) == 8, "Saving after recovery must preserve the last healthy backup.")
	assert(DirAccess.make_dir_absolute(TEST_PATH + ".tmp") == OK)
	assert(not save_manager._write(TEST_PATH, game_state.data), "An unavailable temporary file must fail safely.")
	assert(int(save_manager._read_dictionary(TEST_PATH).week) == 11 and int(save_manager._read_dictionary(TEST_PATH + ".bak").week) == 8)
	assert(DirAccess.remove_absolute(TEST_PATH + ".tmp") == OK)
	game_state.data.week = 8

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
	assert(save_manager.save_auto())
	game_state.data.week = 12
	assert(save_manager.save_auto())
	DirAccess.remove_absolute(save_manager.AUTO_PATH)
	assert(save_manager.auto_exists(), "Continue must work with a backup-only autosave.")
	assert(save_manager.load_auto() and int(game_state.data.week) == 8)
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
