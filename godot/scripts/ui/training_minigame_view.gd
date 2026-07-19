class_name TrainingMinigameView
extends Control

const RULES := preload("res://scripts/progression/training_minigame_rules.gd")

signal direction_selected(direction: String)
signal continue_requested

var prompt_label: Label
var progress_label: Label
var feedback_label: Label
var buttons: Dictionary = {}

func setup(discipline: String, round_index: int, target: String, scores: Array, result: Dictionary = {}) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var spec: Dictionary = RULES.DISCIPLINES[discipline]
	var backdrop := ColorRect.new()
	backdrop.color = Color("#d4c8ae")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var frame := PanelContainer.new()
	frame.position = Vector2(170, 42)
	frame.size = Vector2(940, 550)
	frame.add_theme_stylebox_override("panel", _box(Color("#172820")))
	add_child(frame)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	frame.add_child(page)

	var title := Label.new()
	title.text = str(spec.title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color("#f2dfb3"))
	page.add_child(title)
	var description := Label.new()
	description.text = str(spec.description)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 17)
	description.add_theme_color_override("font_color", Color("#c8c3b7"))
	page.add_child(description)

	if not result.is_empty():
		_show_result(page, result, spec)
		return

	progress_label = Label.new()
	progress_label.text = "第 %d / %d 回合    当前得分 %d" % [round_index + 1, RULES.ROUND_COUNT, _sum(scores)]
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_color_override("font_color", Color("#dfbf74"))
	page.add_child(progress_label)
	prompt_label = Label.new()
	prompt_label.text = "看招：%s" % RULES.DIRECTION_LABELS[target]
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 42)
	prompt_label.add_theme_color_override("font_color", spec.accent)
	page.add_child(prompt_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.custom_minimum_size = Vector2(0, 190)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	page.add_child(grid)
	for direction in ["blank", "up", "blank2", "left", "down", "right"]:
		if direction.begins_with("blank"):
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(180, 72)
			grid.add_child(spacer)
			continue
		var button := Button.new()
		button.text = "%s  %s" % [{"up": "↑", "right": "→", "down": "↓", "left": "←"}[direction], RULES.DIRECTION_LABELS[direction]]
		button.custom_minimum_size = Vector2(180, 72)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_stylebox_override("normal", _box(Color("#294438")))
		button.add_theme_stylebox_override("hover", _box(Color("#365b4b")))
		button.add_theme_stylebox_override("focus", _box(spec.accent.darkened(0.3)))
		button.pressed.connect(func(): direction_selected.emit(direction))
		buttons[direction] = button
		grid.add_child(button)
	feedback_label = Label.new()
	feedback_label.text = "方向键 / WASD / 手柄方向 / 点击按钮"
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", Color("#aeb9b1"))
	page.add_child(feedback_label)

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or prompt_label == null:
		return
	var direction := ""
	if event.is_action_pressed("ui_up"):
		direction = "up"
	elif event.is_action_pressed("ui_right"):
		direction = "right"
	elif event.is_action_pressed("ui_down"):
		direction = "down"
	elif event.is_action_pressed("ui_left"):
		direction = "left"
	if direction != "":
		get_viewport().set_input_as_handled()
		direction_selected.emit(direction)

func set_locked() -> void:
	prompt_label = null
	for button in buttons.values():
		(button as Button).disabled = true

func _show_result(page: VBoxContainer, result: Dictionary, spec: Dictionary) -> void:
	var grade := Label.new()
	grade.text = str(result.grade)
	grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade.add_theme_font_size_override("font_size", 96)
	grade.add_theme_color_override("font_color", spec.accent)
	page.add_child(grade)
	var verdict := Label.new()
	verdict.text = {"S": "炉火纯青", "A": "行云流水", "B": "渐入佳境", "C": "尚需磨炼"}[str(result.grade)]
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict.add_theme_font_size_override("font_size", 24)
	verdict.add_theme_color_override("font_color", Color("#f2dfb3"))
	page.add_child(verdict)
	var score := Label.new()
	score.text = "总分 %d / 300\n%s" % [int(result.score), RULES.reward_text(result)]
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 21)
	score.add_theme_color_override("font_color", Color("#e9e1cf"))
	page.add_child(score)
	var done := Button.new()
	done.text = "收功 · 返回青云门"
	done.custom_minimum_size.y = 54
	done.add_theme_font_size_override("font_size", 18)
	done.add_theme_stylebox_override("normal", _box(Color("#8b493b")))
	done.pressed.connect(func(): continue_requested.emit())
	page.add_child(done)

func _sum(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = color.lightened(0.18)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box
