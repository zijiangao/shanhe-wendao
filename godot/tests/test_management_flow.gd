extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _settle() -> void:
	for frame in range(3):
		await process_frame

func _press(main: Node, prefix: String) -> void:
	var matches: Array = main.find_children("*", "Button", true, false).filter(func(button: Button): return button.text.begins_with(prefix))
	assert(matches.size() == 1 and not matches[0].disabled, "Expected one enabled choice: " + prefix)
	matches[0].pressed.emit()
	await _settle()

func _run() -> void:
	assert(str(ProjectSettings.get_setting("application/config/name")).ends_with("-tests"), "Use isolated saves.")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	var state = root.get_node("GameState")
	state.new_game()
	state.data.silver = 2000
	main._show_market_weapons()
	await _settle()
	await _press(main, "购买并装备 · 铁胎剑")
	await _press(main, "再买一件并装备 · 铁胎剑")
	assert(int(state.data.owned_weapons.iron_sword) == 2)
	await _press(main, "购买并装备 · 寒鸦刀")
	await _press(main, "卖出一件 · 铁胎剑")
	assert(int(state.data.owned_weapons.iron_sword) == 1 and str(state.data.equipped_weapon) == "cold_crow_blade")
	main._show_qingyun_tavern()
	await _settle()
	await _press(main, "招募 · 周慕白")
	await _press(main, "招募 · 柳如烟")
	var silver_before := int(state.data.silver)
	await _press(main, "已招募 · 周慕白")
	assert(str(state.data.active_disciple) == "zhou_mubai" and int(state.data.silver) == silver_before)
	await _press(main, "独自切磋")
	assert(str(state.data.active_disciple) == "" and not bool(state.data.acted_this_week))
	await _press(main, "返回")
	assert(main.screen == "location")
	assert(state.assign_hero_task("earn"))
	main._show_hero_tasks()
	await _settle()
	var task_buttons: Array = main.find_children("*", "Button", true, false).filter(func(button: Button): return button.text.begins_with("赚钱") or button.text.begins_with("修炼") or button.text.begins_with("采集"))
	assert(task_buttons.size() == 3 and task_buttons.all(func(button): return button.disabled))
	main._show_market_weapons()
	await _settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://management_preview.png")
	print("Management flow tests passed.")
	quit()
