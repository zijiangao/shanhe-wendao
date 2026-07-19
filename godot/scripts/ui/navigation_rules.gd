class_name NavigationRules
extends RefCounted

const OVERLAY_SCREENS := ["quests", "character", "achievements", "save", "settings", "credits", "dev"]
const PAUSABLE_SCREENS := ["map", "location", "dialogue", "choice", "palace", "battle", "victory", "defeat", "final_choice", "ending", "demo_complete", "training"]
const MODAL_GAMEPLAY_SCREENS := ["dialogue", "choice", "battle", "defeat", "training", "pause"]

static func can_pause(screen: String) -> bool:
	return screen in PAUSABLE_SCREENS

static func blocks_header_navigation(screen: String) -> bool:
	return screen in MODAL_GAMEPLAY_SCREENS

static func should_save_on_quit(screen: String, state: Dictionary) -> bool:
	return screen != "menu" and not state.is_empty()

static func back_action(screen: String, previous_screen: String = "map") -> Dictionary:
	if screen in ["battle", "dialogue", "choice", "defeat"]:
		return {"allowed": false, "target": "", "message": _blocked_message(screen)}
	if screen in OVERLAY_SCREENS:
		var target := previous_screen
		if target == screen or target == "" or target in ["dialogue", "choice", "battle", "victory", "defeat"]:
			target = "map"
		return {"allowed": true, "target": target, "message": ""}
	var targets := {"location": "map", "palace": "location", "victory": "map", "map": "menu"}
	if targets.has(screen):
		return {"allowed": true, "target": targets[screen], "message": ""}
	return {"allowed": false, "target": "", "message": ""}

static func _blocked_message(screen: String) -> String:
	return {
		"battle": "战斗进行中，无法离开。",
		"dialogue": "请先完成当前对话。",
		"choice": "请先作出当前选择。",
		"defeat": "请选择重试战斗或接受战败。"
	}.get(screen, "当前无法返回。")
