extends SceneTree

const DRAG_SCROLL := preload("res://scripts/ui/drag_scroll_container.gd")

var scroll: ScrollContainer
var button: Button
var presses := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	scroll = DRAG_SCROLL.new()
	scroll.position = Vector2(100, 100)
	scroll.size = Vector2(360, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(340, 900)
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	button = Button.new()
	button.text = "drag target"
	button.custom_minimum_size = Vector2(340, 60)
	button.pressed.connect(func(): presses += 1)
	list.add_child(button)
	for index in range(8):
		var filler := Button.new()
		filler.text = "row %d" % index
		filler.custom_minimum_size = Vector2(340, 70)
		list.add_child(filler)
	await _settle()
	var bar := scroll.get_v_scroll_bar()
	assert(bar.visible and bar.max_value > bar.page, "The drag test needs a real overflowing list.")
	var start := button.get_global_rect().get_center()
	_push_button(start, true)
	_push_motion(start + Vector2(0, -20))
	_push_motion(start + Vector2(0, -95))
	_push_button(start + Vector2(0, -95), false)
	await _settle()
	assert(scroll.scroll_vertical > 0, "A left-button drag should move the scroll container.")
	assert(presses == 0, "A drag that starts on a button must not also click that button.")

	scroll.scroll_vertical = 0
	await _settle()
	var click := button.get_global_rect().get_center()
	_push_button(click, true)
	_push_button(click, false)
	await _settle()
	assert(presses == 1, "A stationary left click must still activate the button.")
	print("Drag scroll tests passed.")
	quit()

func _push_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	root.push_input(event)

func _push_motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = Vector2.ZERO
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)

func _settle() -> void:
	for frame in range(5):
		await process_frame
