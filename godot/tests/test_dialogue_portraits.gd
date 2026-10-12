extends SceneTree

const PORTRAITS := preload("res://scripts/ui/character_portraits.gd")
const DIALOGUE_SCENE := preload("res://scenes/ui/dialogue_view.tscn")
const EXPECTED_PORTRAITS := {
	"顾长风": "portrait-gu-changfeng.png",
	"沈羽": "portrait-shen-yu.png",
	"林清霜": "portrait-lin-qingshuang.png",
	"苏晚晴": "portrait-su-wanqing.png",
	"厉千秋": "portrait-li-qianqiu.png",
	"周慕白": "portrait-zhou-mubai.png",
	"柳如烟": "portrait-liu-ruyan.png",
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var settings := root.get_node("SettingsManager")
	settings.data = settings.defaults()
	var valid := true
	for speaker in EXPECTED_PORTRAITS:
		var texture := PORTRAITS.for_speaker(str(speaker))
		var identity_valid := texture != null and texture.resource_path.ends_with(str(EXPECTED_PORTRAITS[speaker]))
		valid = identity_valid and valid
		if not identity_valid:
			push_error("Missing or incorrect portrait for %s." % speaker)
	for speaker in ["厉无咎", "无尘僧", "旁白"]:
		valid = PORTRAITS.for_speaker(speaker) == null and valid

	# Exercise the real main-shell content bounds without starting a game or
	# invoking save callbacks. The wider fixture also reproduces the old
	# header's minimum width at 130%, which must not clip the dialogue.
	for scale in [1.0, 1.15, 1.3]:
		settings.data.ui_scale = scale
		settings.apply_settings()
		var content := Control.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_top = 70
		content.offset_bottom = -34
		content.custom_minimum_size.x = 1280
		root.add_child(content)
		await _settle()
		for speaker in ["顾长风", "沈羽", "周慕白", "柳如烟", "厉无咎"]:
			var view: Control = DIALOGUE_SCENE.instantiate()
			content.add_child(view)
			var requested := {"count": 0}
			view.continue_requested.connect(func(): requested.count += 1)
			var dialogue_text := "先察后动，绝不让无辜之人卷入。".repeat(50)
			view.setup(null, speaker, dialogue_text, 1, 3)
			await _settle()
			var case_valid := await _check_layout(view, speaker, dialogue_text)
			var next := view.find_child("ContinueButton", true, false) as Button
			next.pressed.emit()
			case_valid = int(requested.count) == 1 and next.text == "继续  2/3" and case_valid
			valid = case_valid and valid
			print("Dialogue portrait/layout scale=%s speaker=%s: %s" % [scale, speaker, "passed" if case_valid else "FAILED"])
			view.queue_free()
			await _settle()
		content.queue_free()
		await _settle()
	quit(0 if valid else 26)

func _check_layout(view: Control, speaker: String, dialogue_text: String) -> bool:
	var portrait_frame := view.find_child("PortraitFrame", true, false) as Control
	var portrait := view.find_child("SpeakerPortrait", true, false) as TextureRect
	var panel := view.find_child("DialoguePanel", true, false) as Control
	var name_label := view.find_child("SpeakerName", true, false) as Label
	var text := view.find_child("DialogueText", true, false) as Label
	var scroll := view.find_child("DialogueScroll", true, false) as ScrollContainer
	var next := view.find_child("ContinueButton", true, false) as Button
	if portrait_frame == null or portrait == null or panel == null or name_label == null or text == null or scroll == null or next == null:
		return false
	var area := view.get_global_rect().intersection(view.get_viewport_rect()).grow(1)
	var valid := name_label.text == speaker and text.text == dialogue_text
	valid = area.encloses(panel.get_global_rect()) and area.encloses(next.get_global_rect()) and valid
	valid = panel.get_global_rect().encloses(name_label.get_global_rect()) and valid
	valid = panel.get_global_rect().encloses(scroll.get_global_rect()) and scroll.size.y > 80 and valid
	if EXPECTED_PORTRAITS.has(speaker):
		valid = portrait_frame.visible and portrait.texture != null and valid
		valid = area.encloses(portrait_frame.get_global_rect()) and valid
		valid = portrait_frame.get_global_rect().end.x < panel.get_global_rect().position.x and valid
		valid = portrait_frame.size.x >= area.size.x * 0.24 and portrait_frame.size.x <= area.size.x * 0.3 and valid
	else:
		valid = not portrait_frame.visible and portrait.texture == null and valid
		valid = is_equal_approx(panel.get_global_rect().get_center().x, area.get_center().x) and valid
	var next_position := next.global_position
	scroll.scroll_vertical = 99999
	await _settle()
	# A long conversation must remain readable to the last line while the
	# continue action stays inside the content area at every supported scale.
	valid = scroll.scroll_vertical > 0 and next.global_position.is_equal_approx(next_position) and valid
	valid = text.get_global_rect().end.y <= scroll.get_global_rect().end.y + 2 and valid
	return valid

func _settle() -> void:
	for frame in range(5):
		await process_frame
