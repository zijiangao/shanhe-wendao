extends Node

const STORY_PATH := "res://data/story_content.json"
var story: Dictionary = {}

func _ready() -> void:
	reload_content()

func reload_content() -> bool:
	if not FileAccess.file_exists(STORY_PATH):
		push_error("Story content is missing: %s" % STORY_PATH)
		return false
	var file := FileAccess.open(STORY_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Story content JSON is invalid.")
		return false
	story = parsed
	return true

func dialogue(id: String) -> Array:
	var source: Array = story.get("dialogues", {}).get(id, [])
	var result: Array = []
	for entry in source:
		result.append([str(entry.get("speaker", "旁白")), str(entry.get("text", ""))])
	return result

func has_dialogue(id: String) -> bool:
	return not dialogue(id).is_empty()

