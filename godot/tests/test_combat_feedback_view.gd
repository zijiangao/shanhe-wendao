extends SceneTree

const ENGINE := preload("res://scripts/battle/battle_engine.gd")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	var game_state: Node = root.get_node("GameState")
	game_state.new_game()
	game_state.data.energy = 3
	game_state.data.investigations = ["secret_route", "archer"]
	game_state.data.tutorial = {"map": true, "location": true, "battle": true, "battle_tactics": true}
	game_state.start_blackreed_battle()
	var battle: Dictionary = game_state.data.battle
	battle.enemies[0].x = 2
	battle.enemies[0].y = 3
	battle.enemies[0].exposure = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260719
	var outcome := ENGINE.player_action(battle, game_state.data, "skill", Vector2i(2, 3), rng)
	assert(bool(outcome.ok), "The feedback preview needs a valid skill impact.")
	game_state.data.battle = outcome.battle
	main_scene.screen = "battle"
	main_scene.battle_mode = "inspect"
	main_scene._rebuild()
	await create_timer(0.065).timeout
	await RenderingServer.frame_post_draw
	var output_path := "user://combat_feedback_preview.png"
	var result := main_scene.get_viewport().get_texture().get_image().save_png(output_path)
	var valid: bool = result == OK and str(game_state.data.battle.effect.get("type", "")) == "skill"
	print("Combat feedback preview saved to: %s" % ProjectSettings.globalize_path(output_path))
	quit(0 if valid else 11)
