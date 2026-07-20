extends SceneTree

var events: Array[String] = []
var connected_view: Control = null

func _initialize() -> void:
	call_deferred("_run")

func _press(keycode: int) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	for frame in range(3):
		await process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	for frame in range(2):
		await process_frame

const KEYCODES := {"up": KEY_UP, "right": KEY_RIGHT, "down": KEY_DOWN, "left": KEY_LEFT}

func _on_direction(d: String) -> void:
	events.append(d)

# A correct-but-not-final press rebuilds the screen and replaces
# active_training_view with a new instance (see _training_direction_selected
# in main.gd), so the listener must be reattached before each press rather
# than trusting a reference captured once at the start.
func _ensure_listener(main_scene: Control) -> void:
	var current: Control = main_scene.active_training_view
	if current != connected_view:
		current.direction_selected.connect(_on_direction)
		connected_view = current

func _run() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	main_scene.screen = "location"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame
	main_scene._start_training("swordsmanship")
	# Rounds now open in a "pending start" state (see TRAINING_READY_DELAY in
	# main.gd) where input is deliberately ignored until the read-it-first
	# grace window elapses. Wait past it before pressing anything, or every
	# press below would be silently dropped and this test would fail for a
	# reason unrelated to the keyboard-focus regression it actually guards.
	await create_timer(main_scene.TRAINING_READY_DELAY + 0.15).timeout
	for frame in range(4):
		await process_frame

	var content: Control = main_scene.content
	_ensure_listener(main_scene)

	# Case 1: force focus onto one of the minigame's own direction buttons,
	# as _focus_first_content_control() could do in normal play. Godot must
	# refuse the grab entirely (buttons are focus_mode NONE) rather than let
	# a subsequent arrow press get consumed by focus-navigation instead of
	# reaching _unhandled_input.
	var round_buttons: Array = content.find_children("*", "Button", true, false)
	var button_grab_refused: bool = true
	if not round_buttons.is_empty():
		var probe := round_buttons[0] as Button
		probe.grab_focus()
		await process_frame
		button_grab_refused = not probe.has_focus() and root.gui_get_focus_owner() == null

	var target: String = str(main_scene.training_challenge.get("targets", [""])[0])
	await _press(KEYCODES[target])
	var case1_ok: bool = events == [target]

	# Case 2: force focus onto a header nav button (outside the minigame
	# entirely) after the screen has already settled, then press the next
	# expected direction. The header is laid out horizontally, so it has
	# real left/right focus neighbors that could swallow ui_left/ui_right
	# via its own navigation even though the minigame's own buttons are safe.
	_ensure_listener(main_scene)
	var header_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(
		func(b: Button): return not content.is_ancestor_of(b)
	)
	var case2_ok := false
	var targets: Array = main_scene.training_challenge.get("targets", [])
	if not header_buttons.is_empty() and int(main_scene.training_input_index) < targets.size():
		(header_buttons[0] as Button).grab_focus()
		await process_frame
		var target2: String = str(targets[main_scene.training_input_index])
		await _press(KEYCODES[target2])
		case2_ok = events == [target, target2]

	var valid := button_grab_refused and case1_ok and case2_ok
	if not valid:
		push_error("Training keyboard-input regression: button_grab_refused=%s case1_ok=%s case2_ok=%s events=%s" % [button_grab_refused, case1_ok, case2_ok, events])
	print("Training keyboard input test %s." % ("passed" if valid else "failed"))
	quit(0 if valid else 22)
