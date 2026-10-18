class_name BuildingSelectionView
extends Control

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")
const PAGE_SIZE := 6
const GOLD := Color("#dfbf74")
const TEXT := Color("#f5ecd9")
const MUTED := Color("#b2beb4")

signal option_selected(id: String)
signal browsing_changed(category: String, page: int)

var _mode := ""
var _state: Dictionary = {}
var _options: Array = []
var _categories: Array = []
var _active_category := ""
var _page := 0
var _panel: Panel
var _body: Control
var _title: Label
var _subtitle: Label
var _return_button: Button
var _footer_hint: Label
var _cards: Array[Button] = []
var _tabs: Dictionary = {}
var _previous: Button
var _next: Button
var _page_label: Label
var _empty_label: Label

func setup(background: Texture2D, title_text: String, prompt: String, options: Array, mode: String, state: Dictionary, categories: Array = [], category: String = "", page: int = 0) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_mode = mode
	_state = state
	_options = options.duplicate(true)
	_categories = categories.duplicate(true)
	_active_category = _first_category(category)
	_page = maxi(0, page)
	var art := TextureRect.new()
	art.name = "BuildingBackground"
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
	_panel.name = "BuildingPanel"
	_panel.add_theme_stylebox_override("panel", UI_THEME.box(Color("#14261fee")))
	add_child(_panel)
	_title = _label(title_text, 28, TEXT)
	_title.name = "BuildingTitle"
	_panel.add_child(_title)
	_subtitle = _label(prompt, 16, MUTED)
	_subtitle.name = "BuildingSubtitle"
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subtitle.max_lines_visible = 1
	_subtitle.clip_text = true
	_subtitle.tooltip_text = prompt
	_subtitle.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_subtitle)
	_body = Control.new()
	_body.name = "BuildingChoices"
	_panel.add_child(_body)
	var leave: Array = _leave_option()
	_return_button = _navigation_button(str(leave[0]))
	_return_button.name = "BuildingReturn"
	_return_button.set_meta("option_id", "leave")
	_return_button.tooltip_text = str(leave[1])
	_return_button.pressed.connect(func(): option_selected.emit("leave"))
	_panel.add_child(_return_button)
	_footer_hint = _label("悬停查看详情" if not _is_read_only() else "悬停查看武学说明", 13, MUTED)
	_footer_hint.name = "BuildingFooterHint"
	_footer_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(_footer_hint)
	_build_choices()
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	if not get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.connect(_layout)
	_layout()

func _first_category(preferred: String) -> String:
	for pair in _categories:
		if str(pair[0]) == preferred:
			return preferred
	return str(_categories[0][0]) if not _categories.is_empty() else ""

func _is_read_only() -> bool:
	if _options.is_empty():
		return false
	return bool(_metadata(_options[0]).get("read_only", false))

func _metadata(option: Array) -> Dictionary:
	for index in [5, 4]:
		if option.size() > index and option[index] is Dictionary:
			return option[index]
	return {}

func _content_options() -> Array:
	var rows := _options.filter(func(option: Array): return option.size() < 3 or str(option[2]) != "leave")
	if not _active_category.is_empty():
		rows = rows.filter(func(option: Array): return str(_metadata(option).get("category", "")) == _active_category)
	return rows

func _leave_option() -> Array:
	for option in _options:
		if option.size() >= 3 and str(option[2]) == "leave":
			return option
	return ["返回", "返回青云门。", "leave"]

func _page_count() -> int:
	return maxi(1, ceili(float(_content_options().size()) / PAGE_SIZE))

func _build_choices() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_cards.clear()
	_tabs.clear()
	_previous = null
	_next = null
	_page_label = null
	_empty_label = null
	if not _categories.is_empty():
		for pair in _categories:
			var tab := _navigation_button(str(pair[1]))
			tab.name = "Category_%s" % str(pair[0])
			tab.set_meta("category_id", str(pair[0]))
			tab.add_theme_stylebox_override("normal", UI_THEME.selectable_box(Color("#294438"), str(pair[0]) == _active_category))
			tab.pressed.connect(_change_category.bind(str(pair[0])))
			_body.add_child(tab)
			_tabs[str(pair[0])] = tab
	var entries := _content_options()
	_page = clampi(_page, 0, _page_count() - 1)
	var start := _page * PAGE_SIZE
	var finish := mini(entries.size(), start + PAGE_SIZE)
	for index in range(start, finish):
		_cards.append(_card(entries[index]))
	if entries.is_empty():
		_empty_label = _label("这一类尚无已习得武学。\n前往洛阳西市秘籍阁学习后，会在这里显示。", 18, MUTED)
		_empty_label.name = "BuildingEmpty"
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_body.add_child(_empty_label)
	if _page_count() > 1:
		_previous = _navigation_button("上一页")
		_previous.name = "BuildingPreviousPage"
		_previous.disabled = _page == 0
		_previous.pressed.connect(_change_page.bind(-1))
		_body.add_child(_previous)
		_next = _navigation_button("下一页")
		_next.name = "BuildingNextPage"
		_next.disabled = _page >= _page_count() - 1
		_next.pressed.connect(_change_page.bind(1))
		_body.add_child(_next)
		_page_label = _label("%d / %d 页" % [_page + 1, _page_count()], 15, MUTED)
		_page_label.name = "BuildingPageLabel"
		_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_body.add_child(_page_label)

func _card(option: Array) -> Button:
	var id := str(option[2])
	var metadata := _metadata(option)
	var disabled := option.size() > 3 and bool(option[3])
	var read_only := bool(metadata.get("read_only", false))
	var accent: Color = metadata.get("accent", GOLD)
	var color := Color("#2a3931") if read_only else (Color("#1c2b24") if disabled else Color("#293b39"))
	var button := Button.new()
	button.name = "BuildingOption_%s" % id
	button.text = "%s\n%s" % [str(option[0]), str(option[1])]
	button.clip_text = true
	button.set_meta("option_id", id)
	button.disabled = disabled
	button.tooltip_text = str(metadata.get("tooltip", str(option[1])))
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if read_only else Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 1)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_outline_color"]:
		button.add_theme_color_override(key, Color.TRANSPARENT)
	for entry in [["normal", color], ["hover", color.lightened(0.12) if not read_only else color], ["pressed", color.darkened(0.08) if not read_only else color], ["focus", color.lightened(0.16) if not read_only else color], ["disabled", color]]:
		var style := UI_THEME.box(entry[1])
		if entry[0] == "focus":
			style.border_color = accent
		button.add_theme_stylebox_override(entry[0], style)
	var stripe := ColorRect.new()
	stripe.name = "CardAccent"
	stripe.color = Color("#526258") if disabled and not read_only else accent
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(stripe)
	var icon: Texture2D = option[4] if option.size() > 4 and option[4] is Texture2D else null
	if icon != null:
		button.set_meta("card_icon", icon)
		var icon_rect := TextureRect.new()
		icon_rect.name = "CardIcon"
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon_rect)
	var title := _label(str(option[0]), 20, Color("#8a978e") if disabled and not read_only else TEXT)
	title.name = "CardTitle"
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_child(title)
	var detail := _label(str(option[1]).split("\n")[0], 15, Color("#849187") if disabled and not read_only else MUTED)
	detail.name = "CardDetail"
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_child(detail)
	var badge := _label(str(metadata.get("badge", "")), 12, GOLD)
	badge.name = "CardBadge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.visible = not badge.text.is_empty()
	button.add_child(badge)
	if not disabled:
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
	if category == _active_category:
		return
	_active_category = category
	_page = 0
	_build_choices()
	_layout()
	browsing_changed.emit(_active_category, _page)
	_tabs[_active_category].grab_focus()

func _change_page(direction: int) -> void:
	var page := clampi(_page + direction, 0, _page_count() - 1)
	if page == _page:
		return
	_page = page
	_build_choices()
	_layout()
	browsing_changed.emit(_active_category, _page)
	for card in _cards:
		if not card.disabled:
			card.grab_focus()
			return

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
	_layout_cards(dense)

func _layout_cards(dense: bool) -> void:
	var tab_height := 32.0 if dense else 36.0
	var tab_gap := 8.0
	if not _tabs.is_empty():
		var count := _tabs.size()
		var tab_width := (_body.size.x - tab_gap * (count - 1)) / count
		var index := 0
		for pair in _categories:
			var tab: Button = _tabs[str(pair[0])]
			tab.position = Vector2(index * (tab_width + tab_gap), 0)
			tab.size = Vector2(tab_width, tab_height)
			index += 1
	var grid_top := tab_height + 10 if not _tabs.is_empty() else 0.0
	var page_height := 30.0
	var has_pager := _page_label != null
	var grid_bottom: float = _body.size.y - (page_height + 8 if has_pager else 0.0)
	if has_pager:
		_previous.position = Vector2(0, _body.size.y - page_height)
		_previous.size = Vector2(96, page_height)
		_next.position = Vector2(_body.size.x - 96, _body.size.y - page_height)
		_next.size = Vector2(96, page_height)
		_page_label.position = Vector2(100, _body.size.y - page_height)
		_page_label.size = Vector2(_body.size.x - 200, page_height)
	if _empty_label != null:
		_empty_label.position = Vector2(0, grid_top)
		_empty_label.size = Vector2(_body.size.x, maxf(0, grid_bottom - grid_top))
		return
	var count := _cards.size()
	if count == 0:
		return
	var columns := 2 if count > 1 else 1
	var rows := ceili(float(count) / columns)
	var gap := 10.0
	var grid_height := maxf(0, grid_bottom - grid_top)
	var card_width := (_body.size.x - gap * (columns - 1)) / columns
	if count == 1:
		card_width = minf(card_width, 620.0)
	var card_height := (grid_height - gap * (rows - 1)) / rows
	if rows == 1:
		card_height = minf(card_height, 200.0)
	else:
		card_height = minf(card_height, 150.0)
	var total_height := card_height * rows + gap * (rows - 1)
	if total_height < grid_height and _tabs.is_empty():
		grid_top += (grid_height - total_height) * 0.5
	for index in range(count):
		var row: int = index / columns
		var in_row := mini(columns, count - row * columns)
		var row_width := in_row * card_width + gap * (in_row - 1)
		var row_left := (_body.size.x - row_width) * 0.5
		var column: int = index % columns
		_place_card(_cards[index], Vector2(row_left + column * (card_width + gap), grid_top + row * (card_height + gap)), Vector2(card_width, card_height), dense)

func _place_card(button: Button, at: Vector2, card_size: Vector2, dense: bool) -> void:
	button.position = at
	button.size = card_size
	var title: Label = button.get_node("CardTitle")
	var detail: Label = button.get_node("CardDetail")
	var badge: Label = button.get_node("CardBadge")
	var stripe: ColorRect = button.get_node("CardAccent")
	var icon: TextureRect = button.get_node_or_null("CardIcon") as TextureRect
	stripe.position = Vector2(0, 8)
	stripe.size = Vector2(3, maxf(0, card_size.y - 16))
	var text_left := 14.0
	if icon != null:
		var icon_size := minf(64.0, maxf(32.0, card_size.y - 28.0))
		icon.position = Vector2(14, (card_size.y - icon_size) * 0.5)
		icon.size = Vector2(icon_size, icon_size)
		text_left = 14 + icon_size + 12
	var title_height := 24.0 if dense else 28.0
	var detail_height := 18.0 if dense else 22.0
	detail.visible = card_size.y >= title_height + detail_height + 8
	var content_height := title_height + detail_height + 2 if detail.visible else title_height
	var top := maxf(3, (card_size.y - content_height) * 0.5)
	title.position = Vector2(text_left, top)
	title.size = Vector2(card_size.x - text_left - 14 - (92 if badge.visible else 0), title_height)
	title.add_theme_font_size_override("font_size", 17 if dense else (21 if card_size.x > _body.size.x * 0.8 else 20))
	detail.position = Vector2(text_left, top + title_height + 2)
	detail.size = Vector2(card_size.x - text_left - 14, detail_height)
	detail.add_theme_font_size_override("font_size", 13 if dense else 15)
	badge.position = Vector2(card_size.x - 104, top + 3)
	badge.size = Vector2(90, 18)
