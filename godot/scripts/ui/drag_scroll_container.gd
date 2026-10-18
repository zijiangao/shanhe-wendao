class_name DragScrollContainer
extends ScrollContainer

## Left-button drag scrolling for the remaining long option lists (the market
## and other ChoiceView screens). The card layouts for sect buildings do not
## create a scroll container at all; this is the fallback for lists that still
## need one.
const DRAG_THRESHOLD := 6.0

var _dragging := false
var _moved := false
var _start_y := 0.0
var _start_scroll := 0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			if _can_start_drag(mouse.position):
				_dragging = true
				_moved = false
				_start_y = mouse.position.y
				_start_scroll = scroll_vertical
		elif _dragging:
			if _moved:
				get_viewport().set_input_as_handled()
			_dragging = false
			_moved = false
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		if not (motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_dragging = false
			_moved = false
			return
		var delta: float = motion.position.y - _start_y
		if absf(delta) >= DRAG_THRESHOLD:
			_moved = true
			scroll_vertical = _start_scroll - int(delta)
			get_viewport().set_input_as_handled()

func _can_start_drag(viewport_position: Vector2) -> bool:
	if not is_visible_in_tree() or not get_global_rect().has_point(viewport_position):
		return false
	var bar := get_v_scroll_bar()
	if bar == null or not bar.visible or bar.get_global_rect().has_point(viewport_position):
		return false
	return bar.max_value > bar.page
