extends SceneTree

const POLICY := preload("res://scripts/release/demo_policy.gd")

func _initialize() -> void:
	var fresh := {"quest_stage": "meet_master", "flags": []}
	assert(not POLICY.is_demo_complete(fresh, true), "A fresh demo save should remain playable.")
	assert(POLICY.should_end_after_victory("blackreed", true), "The Blackreed victory is the intended demo boundary.")
	assert(not POLICY.should_end_after_victory("huashan_trial", true), "Later full-game battles must not define the demo boundary.")
	assert(not POLICY.should_end_after_victory("qingyun_spar", true), "Optional sparring must return the player to Qingyun in the demo.")
	assert(not POLICY.should_end_after_victory("blackreed", false), "The full build must never apply the demo cutoff.")
	var completed := {"quest_stage": "return_master", "flags": ["villain_revealed"]}
	assert(POLICY.is_demo_complete(completed, true), "A completed demo save should be recognized after restart.")
	var choosing := {"quest_stage": "return_master", "flags": ["villain_revealed"], "pending_reward": {"battle_id": "blackreed"}}
	assert(not POLICY.is_demo_complete(choosing, true), "The demo cutoff must wait until the player chooses a battle reward.")
	assert(not POLICY.should_redirect_screen("victory", choosing, true), "An unresolved reward screen must remain accessible in the demo.")
	assert(POLICY.should_redirect_screen("map", completed, true), "Completed demo saves must not enter full-game locations.")
	assert(not POLICY.should_redirect_screen("achievements", completed, true), "Completed demo players should still be able to inspect achievements.")
	assert(not POLICY.is_demo_complete(completed, false), "The same save must continue normally in the full build.")

	print("DemoPolicy tests passed.")
	quit()
