extends SceneTree

# ChoiceView's optional 5th tuple slot (an icon Texture2D) is exercised by
# every current shop/backpack test only with a null icon, since no real item
# art has shipped yet (UI_THEME.item_icon() always returns null right now).
# That leaves the actual "icon present" rendering branch in choice_view.gd
# completely untested by anything else. Verify it directly here using an
# already-shipped texture as a stand-in, so a real regression in that branch
# (wrong theme key, crash, icon not applied) would be caught well before any
# real item art exists to reveal it visually.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)

	var view: Control = load("res://scripts/ui/choice_view.gd").new()
	main_scene.add_child(view)
	var stand_in_icon: Texture2D = load("res://scripts/ui/ui_theme.gd").nav_icon("map")
	var options := [
		["带图选项", "这一行应当带有图标。", "with_icon", false, stand_in_icon],
		["无图选项", "这一行不应有图标。", "without_icon"],
	]
	view.setup(null, "测试提示", options, "测 试")
	for frame in range(2):
		await process_frame

	var buttons: Array = view.find_children("*", "Button", true, false)
	var iconed: Button = null
	var plain: Button = null
	for b in buttons:
		if "带图选项" in (b as Button).text:
			iconed = b
		elif "无图选项" in (b as Button).text:
			plain = b

	var valid := stand_in_icon != null and iconed != null and plain != null
	valid = valid and iconed.icon == stand_in_icon and plain.icon == null
	print("Choice view icon test %s." % ("passed" if valid else "failed"))
	quit(0 if valid else 21)
