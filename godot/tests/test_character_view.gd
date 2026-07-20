extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	main_scene.screen = "character"
	main_scene._rebuild()
	for frame in range(4):
		await process_frame

	var scrolls: Array = main_scene.find_children("*", "ScrollContainer", true, false)
	var has_scroll := not scrolls.is_empty()
	var scroll: ScrollContainer = scrolls[0] if has_scroll else null
	if scroll != null:
		scroll.scroll_vertical = 9999
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw

	# The trailing mastery label is the content that was silently clipped
	# outside the 1280x720 viewport before the info panel became scrollable.
	# Require it to actually be within the scroll container's visible rect,
	# not merely present somewhere in the node tree.
	var labels: Array = main_scene.find_children("*", "Label", true, false)
	var mastery_label: Label = null
	for label in labels:
		if "每使用3次" in str((label as Label).text):
			mastery_label = label
			break
	var reachable := false
	if scroll != null and mastery_label != null:
		var visible_rect := scroll.get_global_rect()
		var label_rect := mastery_label.get_global_rect()
		reachable = visible_rect.intersects(Rect2(label_rect.position, Vector2(1, 1)))

	var output_path := "user://character_preview.png"
	var result := main_scene.get_viewport().get_texture().get_image().save_png(output_path)
	var valid := result == OK and has_scroll and mastery_label != null and reachable
	print("Character preview saved to: %s" % ProjectSettings.globalize_path(output_path))
	if not valid:
		push_error("Character screen regression: has_scroll=%s mastery_label_found=%s reachable=%s" % [has_scroll, mastery_label != null, reachable])
	quit(0 if valid else 11)
