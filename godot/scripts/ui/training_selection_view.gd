class_name TrainingSelectionView
extends Control

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")
const PAGE_SIZE := 4
const CATEGORIES := ["move", "internal", "lightness"]
const CATEGORY_NAMES := {"move": "招式", "internal": "内功", "lightness": "轻功"}
const DRILLS := ["swordsmanship", "bladesmanship", "fistsmanship", "staffsmanship"]
const GOLD := Color("#dfbf74")
const TEXT := Color("#f5ecd9")
const MUTED := Color("#b2beb4")

signal option_selected(id: String)
signal browsing_changed(category: String, page: int)

var active_category := ""
var current_page := 0
var _mode := "training"
var _state: Dictionary = {}
var _options: Array = []
var _categories := {"move": [], "internal": [], "lightness": []}
var _panel: Panel
var _body: Control
var _title: Label
var _subtitle: Label
var _return_button: Button
var _footer_hint: Label
var _cards: Array[Button] = []
var _tabs: Dictionary = {}
var _basic_heading: Label
var _advanced_heading: Label
var _previous: Button
var _next: Button
var _page_label: Label
var _empty_label: Label
var _drill_count := 0

func setup(background: Texture2D, prompt: String, options: Array, mode: String, state: Dictionary, category: String = "", page: int = 0) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_mode = mode
	_state = state
	_options = options.duplicate(true)
	_categories = {"move": [], "internal": [], "lightness": []}
	for option in _options:
		if option.size() < 3:
			continue
		var id := str(option[2])
		for key in CATEGORIES:
			if id.begins_with("train_%s_" % key):
				_categories[key].append(option)
	active_category = category if category in CATEGORIES else _first_category()
	current_page = clampi(page, 0, _page_count() - 1)
	var art := TextureRect.new()
	art.name = "TrainingBackground"
	art.texture = background
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#07110de0")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = Panel.new()
	_panel.name = "TrainingPanel"
	_panel.add_theme_stylebox_override("panel", UI_THEME.box(Color("#14261fee")))
	add_child(_panel)
	_title = _label({"training": "演武场", "wuxue_training": "武学修炼", "spar_focus": "实战切磋"}.get(_mode, "演武场"), 28, TEXT)
	_title.name = "TrainingTitle"
	_panel.add_child(_title)
	_subtitle = _label(prompt, 16, MUTED)
	_subtitle.name = "TrainingSubtitle"
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_panel.add_child(_subtitle)
	_body = Control.new()
	_body.name = "TrainingChoices"
	_panel.add_child(_body)
	var leave: Array = ["暂不修炼" if _mode == "training" else "返回", "", "leave"]
	for option in _options:
		if option.size() >= 3 and str(option[2]) == "leave":
			leave = option
	_return_button = _navigation_button(str(leave[0]))
	_return_button.name = "TrainingReturn"
	_return_button.set_meta("option_id", "leave")
	_return_button.tooltip_text = str(leave[1])
	_return_button.pressed.connect(func(): option_selected.emit("leave"))
	_panel.add_child(_return_button)
	_footer_hint = _label("本周已行动 · 返回门派后结束本周" if bool(_state.get("acted_this_week", false)) else "悬停查看详情", 13, MUTED)
	_footer_hint.name = "TrainingFooterHint"
	_footer_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(_footer_hint)
	_build_choices()
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	if not get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.connect(_layout)
	_layout()

func _first_category() -> String:
	for key in CATEGORIES:
		if not _categories[key].is_empty():
			return key
	return "move"

func _page_count() -> int:
	return maxi(1, ceili(float(_categories.get(active_category, []).size()) / PAGE_SIZE))

func _build_choices() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_cards.clear()
	_tabs.clear()
	_basic_heading = null
	_advanced_heading = null
	_previous = null
	_next = null
	_page_label = null
	_empty_label = null
	_drill_count = 0
	if _mode == "wuxue_training":
		_build_wuxue_choices()
		return
	if _mode == "training":
		_basic_heading = _label("基础修炼", 15, MUTED)
		_basic_heading.name = "TrainingBasicHeading"
		_body.add_child(_basic_heading)
		_advanced_heading = _label("进阶修行", 15, MUTED)
		_advanced_heading.name = "TrainingAdvancedHeading"
		_body.add_child(_advanced_heading)
		for id in DRILLS:
			_add_option_by_id(id)
		_drill_count = _cards.size()
		for id in ["wuxue_training", "qingyun_spar"]:
			_add_option_by_id(id)
	else:
		for option in _options:
			if option.size() >= 3 and str(option[2]) != "leave":
				_cards.append(_card(option))

func _add_option_by_id(id: String) -> void:
	for option in _options:
		if option.size() >= 3 and str(option[2]) == id:
			_cards.append(_card(option))
			return

func _build_wuxue_choices() -> void:
	for category in CATEGORIES:
		var tab := _navigation_button("%s · %d" % [CATEGORY_NAMES[category], _categories[category].size()])
		tab.name = "Category_%s" % category
		tab.set_meta("category_id", category)
		tab.add_theme_stylebox_override("normal", UI_THEME.selectable_box(Color("#294438"), category == active_category))
		tab.pressed.connect(_change_category.bind(category))
		_body.add_child(tab)
		_tabs[category] = tab
	var entries: Array = _categories.get(active_category, [])
	for index in range(current_page * PAGE_SIZE, mini(entries.size(), (current_page + 1) * PAGE_SIZE)):
		_cards.append(_card(entries[index]))
	if entries.is_empty():
		_empty_label = _label("尚未习得%s\n在秘籍阁学习后，即可在此修炼。" % CATEGORY_NAMES[active_category], 18, MUTED)
		_empty_label.name = "TrainingEmpty"
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_body.add_child(_empty_label)
	_previous = _navigation_button("上一页")
	_previous.name = "TrainingPreviousPage"
	_previous.disabled = current_page == 0
	_previous.pressed.connect(_change_page.bind(-1))
	_body.add_child(_previous)
	_next = _navigation_button("下一页")
	_next.name = "TrainingNextPage"
	_next.disabled = current_page >= _page_count() - 1
	_next.pressed.connect(_change_page.bind(1))
	_body.add_child(_next)
	_page_label = _label("%d / %d 页" % [current_page + 1, _page_count()], 15, MUTED)
	_page_label.name = "TrainingPageLabel"
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.add_child(_page_label)

func _card(option: Array) -> Button:
	var id := str(option[2])
	var metadata: Dictionary = {}
	for index in [4, 5]:
		if option.size() > index and option[index] is Dictionary:
			metadata = option[index]
	var disabled := option.size() > 3 and bool(option[3])
	var accent: Color = metadata.get("accent", GOLD)
	var color := Color("#233a30") if id in DRILLS else Color("#293b39")
	var button := Button.new()
	button.name = "TrainingOption_%s" % id
	button.text = str(option[0])
	button.clip_text = true
	button.set_meta("option_id", id)
	button.disabled = disabled
	button.tooltip_text = str(metadata.get("tooltip", "%s\n%s" % [option[0], option[1]]))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 1)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_outline_color"]:
		button.add_theme_color_override(key, Color.TRANSPARENT)
	for entry in [["normal", color], ["hover", color.lightened(0.12)], ["pressed", color.darkened(0.08)], ["focus", color.lightened(0.16)], ["disabled", Color("#1c2b24")]]:
		var style := UI_THEME.box(entry[1])
		if entry[0] == "focus":
			style.border_color = accent
		button.add_theme_stylebox_override(entry[0], style)
	var stripe := ColorRect.new()
	stripe.name = "CardAccent"
	stripe.color = Color("#526258") if disabled else accent
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(stripe)
	var title := _label(str(option[0]), 20, Color("#8a978e") if disabled else TEXT)
	title.name = "CardTitle"
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_child(title)
	var detail := _label(str(option[1]).split("\n")[0], 15, Color("#849187") if disabled else MUTED)
	detail.name = "CardDetail"
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_child(detail)
	var badge := _label(str(metadata.get("badge", "")), 12, GOLD)
	badge.name = "CardBadge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.visible = not badge.text.is_empty()
	button.add_child(badge)
	button.pressed.connect(func(): option_selected.emit(id))
	_body.add_child(button)
	return button

func _navigation_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_disabled_color", Color("#64756b"))
	for entry in [["normal", Color("#294438")], ["hover", Color("#37594a")], ["pressed", Color("#20392e")], ["focus", Color("#416452")], ["disabled", Color("#192a22")]]:
		button.add_theme_stylebox_override(entry[0], UI_THEME.box(entry[1]))
	return button

func _label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _change_category(category: String) -> void:
	if category == active_category:
		return
	active_category = category
	current_page = 0
	_build_choices()
	_layout()
	browsing_changed.emit(active_category, current_page)
	_tabs[active_category].grab_focus()

func _change_page(direction: int) -> void:
	var page := clampi(current_page + direction, 0, _page_count() - 1)
	if page == current_page:
		return
	current_page = page
	_build_choices()
	_layout()
	browsing_changed.emit(active_category, current_page)
	for card in _cards:
		if not card.disabled:
			card.grab_focus()
			return
	_tabs[active_category].grab_focus()

func _layout() -> void:
	if _panel == null:
		return
	var available := Vector2(minf(size.x, maxf(0, get_viewport_rect().size.x - global_position.x)), minf(size.y, maxf(0, get_viewport_rect().size.y - global_position.y)))
	if available.x <= 0 or available.y <= 0:
		return
	var dense := available.y < 390
	var margin := 12.0
	_panel.position = Vector2((available.x - minf(940, available.x - margin * 2)) * 0.5, margin)
	_panel.size = Vector2(minf(940, available.x - margin * 2), available.y - margin * 2)
	var padding := 14.0 if dense else 20.0
	var width := _panel.size.x - padding * 2
	_title.position = Vector2(padding, 10)
	_title.size = Vector2(width, 34 if not dense else 28)
	_title.add_theme_font_size_override("font_size", 24 if dense else 28)
	_subtitle.visible = _panel.size.y >= 330
	_subtitle.position = Vector2(padding, 46)
	_subtitle.size = Vector2(width, 24)
	var body_top := 78.0 if _subtitle.visible else 48.0
	_return_button.size = Vector2(minf(220, width), 36 if dense else 40)
	_return_button.position = Vector2((_panel.size.x - _return_button.size.x) * 0.5, _panel.size.y - 12 - _return_button.size.y)
	_footer_hint.position = Vector2(14, _return_button.position.y)
	_footer_hint.size = Vector2(maxf(0, _return_button.position.x - 28), _return_button.size.y)
	_body.position = Vector2(padding, body_top)
	_body.size = Vector2(width, maxf(0, _return_button.position.y - 12 - body_top))
	if _mode == "training":
		_layout_home(dense)
	elif _mode == "wuxue_training":
		_layout_wuxue(dense)
	else:
		var card_width := (_body.size.x - 12) * 0.5
		var height := minf(140, _body.size.y)
		for index in range(_cards.size()):
			_place_card(_cards[index], Vector2(index * (card_width + 12), (_body.size.y - height) * 0.5), Vector2(card_width, height), dense)

func _layout_home(dense: bool) -> void:
	var headings := _body.size.y >= 220
	_basic_heading.visible = headings
	_advanced_heading.visible = headings
	var heading_space := 26.0 if headings else 0.0
	var gap := 8.0
	var row_height := (_body.size.y - heading_space * 2 - gap * 2) / 3.0
	var card_width := (_body.size.x - 12) * 0.5
	_basic_heading.position = Vector2.ZERO
	_basic_heading.size = Vector2(_body.size.x, 20)
	for index in range(_drill_count):
		_place_card(_cards[index], Vector2((index % 2) * (card_width + 12), heading_space + (index / 2) * (row_height + gap)), Vector2(card_width, row_height), dense)
	var advanced_top := heading_space + row_height * 2 + gap * 2
	_advanced_heading.position = Vector2(0, advanced_top)
	_advanced_heading.size = Vector2(_body.size.x, 20)
	for index in range(_drill_count, _cards.size()):
		_place_card(_cards[index], Vector2((index - _drill_count) * (card_width + 12), advanced_top + heading_space), Vector2(card_width, row_height), dense)

func _layout_wuxue(dense: bool) -> void:
	var tab_height := 32.0 if dense else 36.0
	var tab_width := (_body.size.x - 16) / 3.0
	for index in range(CATEGORIES.size()):
		var tab: Button = _tabs[CATEGORIES[index]]
		tab.position = Vector2(index * (tab_width + 8), 0)
		tab.size = Vector2(tab_width, tab_height)
	var page_height := 30.0
	var page_top := _body.size.y - page_height
	_previous.position = Vector2(0, page_top)
	_previous.size = Vector2(96, page_height)
	_next.position = Vector2(_body.size.x - 96, page_top)
	_next.size = Vector2(96, page_height)
	_page_label.position = Vector2(100, page_top)
	_page_label.size = Vector2(_body.size.x - 200, page_height)
	var grid_top := tab_height + 10
	var grid_height := page_top - 10 - grid_top
	var card_size := Vector2((_body.size.x - 12) * 0.5, (grid_height - 10) * 0.5)
	for index in range(_cards.size()):
		_place_card(_cards[index], Vector2((index % 2) * (card_size.x + 12), grid_top + (index / 2) * (card_size.y + 10)), card_size, dense)
	if _empty_label != null:
		_empty_label.position = Vector2(0, grid_top)
		_empty_label.size = Vector2(_body.size.x, grid_height)

func _place_card(button: Button, at: Vector2, card_size: Vector2, dense: bool) -> void:
	button.position = at
	button.size = card_size
	var title: Label = button.get_node("CardTitle")
	var detail: Label = button.get_node("CardDetail")
	var badge: Label = button.get_node("CardBadge")
	var stripe: ColorRect = button.get_node("CardAccent")
	stripe.position = Vector2(0, 8)
	stripe.size = Vector2(3, maxf(0, card_size.y - 16))
	var title_height := 24.0 if dense else 28.0
	var detail_height := 18.0 if dense else 22.0
	detail.visible = card_size.y >= title_height + detail_height + 8
	var content_height := title_height + detail_height + 2 if detail.visible else title_height
	var top := maxf(3, (card_size.y - content_height) * 0.5)
	title.position = Vector2(14, top)
	title.size = Vector2(card_size.x - 28 - (84 if badge.visible else 0), title_height)
	title.add_theme_font_size_override("font_size", 17 if dense else 20)
	detail.position = Vector2(14, top + title_height + 2)
	detail.size = Vector2(card_size.x - 28, detail_height)
	detail.add_theme_font_size_override("font_size", 13 if dense else 15)
	badge.position = Vector2(card_size.x - 94, top + 3)
	badge.size = Vector2(80, 18)
