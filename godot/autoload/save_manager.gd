extends Node

const SLOT_COUNT := 3
const AUTO_PATH := "user://autosave.json"

func save_auto() -> bool:
	return _write(AUTO_PATH, GameState.data)

func save_slot(slot: int) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false
	return _write("user://save_%d.json" % slot, GameState.data)

func load_auto() -> bool:
	return _load(AUTO_PATH)

func load_slot(slot: int) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false
	return _load("user://save_%d.json" % slot)

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists("user://save_%d.json" % slot)

func slot_summary(slot: int) -> Dictionary:
	var path := "user://save_%d.json" % slot
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _write(path: String, value: Dictionary) -> bool:
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to open temporary save file: %s" % temporary_path)
		return false
	file.store_string(JSON.stringify(value, "  "))
	file.close()
	var directory := DirAccess.open("user://")
	if directory == null:
		push_error("Unable to access the save directory.")
		return false
	var relative_path := path.trim_prefix("user://")
	var relative_temporary_path := temporary_path.trim_prefix("user://")
	var backup_path := relative_path + ".bak"
	if FileAccess.file_exists(path):
		if directory.file_exists(backup_path):
			directory.remove(backup_path)
		var backup_error := directory.rename(relative_path, backup_path)
		if backup_error != OK:
			push_error("Unable to back up save file: %s" % path)
			return false
	var rename_error := directory.rename(relative_temporary_path, relative_path)
	if rename_error != OK:
		push_error("Unable to finalize save file: %s" % path)
		if directory.file_exists(backup_path):
			directory.rename(backup_path, relative_path)
		return false
	if directory.file_exists(backup_path):
		directory.remove(backup_path)
	return true

func _load(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open save file: %s" % path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Save file is invalid: %s" % path)
		return false
	GameState.import_data(parsed)
	return true
