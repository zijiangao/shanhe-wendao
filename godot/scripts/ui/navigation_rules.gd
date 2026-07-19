class_name NavigationRules
extends RefCounted

const OVERLAY_SCREENS := ["quests", "character", "achievements", "save", "settings", "credits", "dev"]

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
