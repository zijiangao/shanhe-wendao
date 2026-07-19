class_name DemoPolicy
extends RefCounted

const FEATURE_NAME := "demo"
const PLAYABLE_SCREENS := ["map", "location", "dialogue", "choice", "palace", "battle", "victory"]

static func is_demo_build() -> bool:
	return OS.has_feature(FEATURE_NAME)

static func should_end_after_victory(battle_id: String, demo_build: bool = is_demo_build()) -> bool:
	return demo_build and battle_id == "blackreed"

static func is_demo_complete(state: Dictionary, demo_build: bool = is_demo_build()) -> bool:
	if not demo_build:
		return false
	return "villain_revealed" in state.get("flags", []) or str(state.get("quest_stage", "meet_master")) in ["return_master", "chapter_complete", "luoyang_investigate", "chapter2_complete", "huashan_meet_companion", "huashan_trial", "huashan_trial_complete", "chapter3_complete", "emei_meet_su", "emei_investigate", "emei_trial"]

static func should_redirect_screen(screen: String, state: Dictionary, demo_build: bool = is_demo_build()) -> bool:
	return screen in PLAYABLE_SCREENS and is_demo_complete(state, demo_build)
