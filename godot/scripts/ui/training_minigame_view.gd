class_name TrainingMinigameView
extends Control

const RULES := preload("res://scripts/progression/training_minigame_rules.gd")

signal direction_selected(direction: String)
signal continue_requested

var prompt_label: Label
var progress_label: Label
var feedback_label: Label
var buttons: Dictionary = {}
var discipline_id: String = ""
var round_started_ms: int = 0
var timing_fill: ColorRect
var timing_window: ColorRect
var timing_ideal_ms: int = 0

func setup(discipline: String, round_index: int, challenge: Dictionary, input_index: int, scores: Array, started_ms: int, last_feedback: String = "", result: Dictionary = {}, streak: int = 0, best_streak: int = 0, last_quality: String = "") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	discipline_id = discipline
	round_started_ms = started_ms
	timing_ideal_ms = int(challenge.get("ideal_ms", 1000 if discipline == "bladesmanship" else 1200))
	var spec: Dictionary = RULES.DISCIPLINES[discipline]
	var backdrop := ColorRect.new()
	backdrop.color = Color("#d4c8ae")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var frame := PanelContainer.new()
	frame.position = Vector2(170, 24)
	frame.size = Vector2(940, 570)
	frame.add_theme_stylebox_override("panel", _box(Color("#172820")))
	add_child(frame)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8 if not result.is_empty() else 14)
	frame.add_child(page)

	var title := Label.new()
	title.text = str(spec.title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color("#f2dfb3"))
	page.add_child(title)
	if not result.is_empty():
		_show_result(page, result, spec)
		return
	var description := Label.new()
	description.text = str(spec.description)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 17)
	description.add_theme_color_override("font_color", Color("#c8c3b7"))
	page.add_child(description)

	progress_label = Label.new()
	progress_label.text = "第 %d / %d 回合    当前得分 %d" % [round_index + 1, RULES.ROUND_COUNT, _sum(scores)]
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_color_override("font_color", Color("#dfbf74"))
	page.add_child(progress_label)
	var streak_label := Label.new()
	streak_label.text = "势如破竹 · %d 连" % streak if streak >= 2 else "连续获得 85 分以上可提升连击奖励"
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_label.add_theme_font_size_override("font_size", 18)
	streak_label.add_theme_color_override("font_color", spec.accent.lightened(0.22) if streak >= 2 else Color("#829087"))
	page.add_child(streak_label)
	prompt_label = Label.new()
	prompt_label.text = str(challenge.get("prompt", "凝神准备"))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 42)
	prompt_label.add_theme_color_override("font_color", spec.accent)
	page.add_child(prompt_label)
	var mechanic := Label.new()
	var targets: Array = challenge.get("targets", [])
	var step_text := "第 %d / %d 式" % [mini(input_index + 1, targets.size()), targets.size()] if targets.size() > 1 else str(challenge.get("timing", ""))
	mechanic.text = "%s%s · %s" % [str(spec.mechanic), " · 进阶" if bool(challenge.get("advanced", false)) else "", step_text]
	mechanic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mechanic.add_theme_font_size_override("font_size", 17)
	mechanic.add_theme_color_override("font_color", Color("#dfbf74"))
	page.add_child(mechanic)
	if discipline in ["bladesmanship", "mining"]:
		_add_timing_meter(page, spec)

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
	feedback_label.text = (last_feedback + "\n" if last_feedback != "" else "") + "方向键 / 自定义键位 / 手柄方向 / 点击按钮"
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", _quality_color(last_quality) if last_feedback != "" else Color("#aeb9b1"))
	page.add_child(feedback_label)
	if last_feedback != "":
		feedback_label.modulate.a = 0.0
		feedback_label.position.y = 8.0
		var feedback_tween := create_tween().set_parallel(true)
		feedback_tween.tween_property(feedback_label, "modulate:a", 1.0, 0.16)
		feedback_tween.tween_property(feedback_label, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if streak >= 2:
		streak_label.scale = Vector2(0.88, 0.88)
		streak_label.pivot_offset = streak_label.size * 0.5
		create_tween().tween_property(streak_label, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(_delta: float) -> void:
	if timing_fill == null or round_started_ms <= 0:
		return
	var elapsed := maxi(0, Time.get_ticks_msec() - round_started_ms)
	var ratio := clampf(float(elapsed) / 2200.0, 0.0, 1.0)
	timing_fill.position.x = 700.0 * ratio - 3.0
	var ideal := timing_ideal_ms
	var in_window := absi(elapsed - ideal) <= 150
	timing_fill.color = Color("#f4d878") if in_window else Color("#75877c")
	if timing_window != null:
		timing_window.modulate.a = 0.72 + 0.28 * sin(float(elapsed) * 0.018) if in_window else 0.55

func _add_timing_meter(page: VBoxContainer, spec: Dictionary) -> void:
	var track := Control.new()
	track.custom_minimum_size = Vector2(700, 18)
	track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(track)
	var background := ColorRect.new()
	background.color = Color("#0d1812")
	background.position = Vector2.ZERO
	background.size = Vector2(700, 18)
	track.add_child(background)
	var ideal := timing_ideal_ms
	timing_window = ColorRect.new()
	timing_window.color = Color(spec.accent, 0.8)
	timing_window.position = Vector2(700.0 * float(ideal - 150) / 2200.0, 0)
	timing_window.size = Vector2(700.0 * 300.0 / 2200.0, 18)
	track.add_child(timing_window)
	timing_fill = ColorRect.new()
	timing_fill.color = Color("#75877c")
	timing_fill.position = Vector2(-3, -5)
	timing_fill.size = Vector2(6, 28)
	track.add_child(timing_fill)

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
	grade.add_theme_font_size_override("font_size", 78)
	grade.add_theme_color_override("font_color", spec.accent)
	page.add_child(grade)
	var verdict := Label.new()
	verdict.text = {"S": "炉火纯青", "A": "行云流水", "B": "渐入佳境", "C": "尚需磨炼"}[str(result.grade)]
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict.add_theme_font_size_override("font_size", 24)
	verdict.add_theme_color_override("font_color", Color("#f2dfb3"))
	page.add_child(verdict)
	var score := Label.new()
	var streak_text := "\n最佳连击 %d" % int(result.get("best_streak", 0)) if int(result.get("best_streak", 0)) >= 2 else ""
	score.text = "总分 %d / %d%s\n%s" % [int(result.score), RULES.MAX_TOTAL_SCORE, streak_text, RULES.reward_text(result)]
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 19)
	score.add_theme_color_override("font_color", Color("#e9e1cf"))
	page.add_child(score)
	var event: Dictionary = result.get("event", {})
	var discovery: Dictionary = result.get("herb_discovery", {})
	if not discovery.is_empty():
		var herb_card := PanelContainer.new()
		herb_card.add_theme_stylebox_override("panel", _box(Color("#294438")))
		page.add_child(herb_card)
		var herb_text := Label.new()
		herb_text.text = "%s药谱 · %s（%s）\n%s%s" % ["新收录 " if bool(discovery.get("first_discovery", false)) else "再采得 ", str(discovery.name), str(discovery.rarity), str(discovery.description), "\n首次发现：修为 +%d" % int(discovery.xp) if int(discovery.get("xp", 0)) > 0 else ""]
		herb_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		herb_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		herb_text.add_theme_font_size_override("font_size", 15)
		herb_text.add_theme_color_override("font_color", Color("#d8e5cf"))
		herb_card.add_child(herb_text)
	var mineral: Dictionary = result.get("mineral_discovery", {})
	if not mineral.is_empty():
		var mineral_card := PanelContainer.new()
		mineral_card.add_theme_stylebox_override("panel", _box(Color("#443b31")))
		page.add_child(mineral_card)
		var mineral_text := Label.new()
		mineral_text.text = "%s矿谱 · %s（%s）\n%s%s" % ["新收录 " if bool(mineral.get("first_discovery", false)) else "再掘得 ", str(mineral.name), str(mineral.rarity), str(mineral.description), "\n首次鉴矿：银两 +%d" % int(mineral.silver) if int(mineral.get("silver", 0)) > 0 else ""]
		mineral_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mineral_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mineral_text.add_theme_font_size_override("font_size", 15)
		mineral_text.add_theme_color_override("font_color", Color("#e5d8c7"))
		mineral_card.add_child(mineral_text)
	if not event.is_empty():
		var event_card := PanelContainer.new()
		event_card.add_theme_stylebox_override("panel", _box(Color(spec.accent, 0.18)))
		page.add_child(event_card)
		var event_text := Label.new()
		event_text.text = "奇遇 · %s\n%s\n%s" % [str(event.title), str(event.body), str(event.reward)]
		event_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_text.add_theme_font_size_override("font_size", 15)
		event_text.add_theme_color_override("font_color", Color("#f2dfb3"))
		event_card.add_child(event_text)
	var done := Button.new()
	done.text = "收功 · 返回青云门"
	done.custom_minimum_size.y = 48
	done.add_theme_font_size_override("font_size", 18)
	done.add_theme_stylebox_override("normal", _box(Color("#8b493b")))
	done.pressed.connect(func(): continue_requested.emit())
	page.add_child(done)

func _sum(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total

func _quality_color(quality: String) -> Color:
	return {
		"perfect": Color("#f4d878"),
		"great": Color("#9fd5b8"),
		"ok": Color("#c7c2ad"),
		"miss": Color("#d27a68")
	}.get(quality, Color("#dfbf74"))

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
