extends SceneTree

const FEEDBACK := preload("res://scripts/battle/combat_feedback.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var light := FEEDBACK.for_player_effect({"type": "damage"})
	var skill := FEEDBACK.for_player_effect({"type": "skill"})
	var guard := FEEDBACK.for_enemy_hit({"damage": 0, "blocked": 8, "impact": "heavy"})
	var heavy := FEEDBACK.for_enemy_hit({"damage": 12, "blocked": 0, "impact": "heavy"})
	assert(float(light.shake) > 0.0 and float(light.shake) < float(skill.shake), "Skills should feel stronger than normal player hits.")
	assert(float(heavy.shake) > float(light.shake) and str(heavy.cue) == "heavy_hit", "Heavy enemy hits need the strongest feedback and distinct cue.")
	assert(float(guard.shake) == 0.0 and float(guard.flash_alpha) == 0.0, "A full guard must not shake or flash like health damage.")
	for level in ["guard", "light", "normal", "heavy", "skill"]:
		var profile := FEEDBACK.profile(level)
		assert(profile.has("shake") and profile.has("flash_alpha") and profile.has("cue") and profile.has("pitch"), "Every feedback tier needs a complete runtime profile.")
	var view = load("res://scripts/battle/tactical_battle_view.gd").new()
	root.add_child(view)
	var settings = root.get_node("SettingsManager")
	var original: Dictionary = settings.data.duplicate(true)
	settings.data.screen_shake = false
	settings.data.combat_flashes = false
	assert(not view._screen_shake_enabled() and not view._combat_flashes_enabled(), "The tactical view must honor both accessibility toggles.")
	settings.data = original
	view.queue_free()
	print("CombatFeedback tests passed.")
	quit()
