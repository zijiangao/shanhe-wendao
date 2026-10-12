class_name SectView
extends Control

## Ground anchors are authored in the estate background's source pixels. Every
## hotspot keeps the original action text for keyboard/tooling access; its
## visible plaque is deliberately shorter than the action's explanation.
const UI_THEME := preload("res://scripts/ui/ui_theme.gd")
const SECT_RULES := preload("res://scripts/progression/sect_building_rules.gd")
const ATLAS_PATH := "res://assets/art/sect/buildings-atlas.png"
const PORTRAIT_PATH := "res://assets/art/portrait-gu-changfeng.png"
const BUILDING_REGIONS := [
	Rect2(0, 0, 507, 447), Rect2(501, 0, 344, 443), Rect2(846, 0, 408, 443),
	Rect2(0, 450, 442, 390), Rect2(438, 450, 414, 400), Rect2(852, 450, 402, 400),
	Rect2(0, 860, 442, 394), Rect2(442, 850, 410, 404), Rect2(852, 850, 402, 404),
]
const GOLD := Color("#dfbf74")
const INK := Color("#13231dcc")
const BUILDING_SLOTS := [
	{"id": "master", "name": "正殿", "tile": 0, "ground": Vector2(860, 330), "width": 225.0},
	{"id": "library", "name": "藏经阁", "tile": 1, "building": "library", "ground": Vector2(450, 435), "width": 175.0},
	{"id": "workshop", "name": "炼药坊", "tile": 2, "ground": Vector2(1240, 435), "width": 210.0},
	{"id": "train", "name": "演武场", "tile": 3, "building": "training_ground", "ground": Vector2(255, 645), "width": 190.0},
	{"id": "gathering", "name": "后山", "tile": 6, "ground": Vector2(495, 645), "width": 175.0},
	{"id": "forge", "name": "锻造坊", "tile": 4, "building": "forge", "ground": Vector2(1215, 645), "width": 190.0},
	{"id": "herb_garden", "name": "药圃", "tile": 6, "building": "herb_garden", "ground": Vector2(1450, 645), "width": 175.0},
	{"id": "qingyun_tavern", "name": "客栈", "tile": 5, "ground": Vector2(865, 695), "width": 168.0},
]

signal action_requested(id: String)

var _state: Dictionary = {}
var _actions: Dictionary = {}
var _atlas: Texture2D
var _hotspots: Array[Button] = []
var _title: Label
var _objective: Label
var _header: ColorRect
var _footer: ColorRect
var _footer_note: Label

func setup(background: Texture2D, state: Dictionary, objective: String, actions: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_hotspots.clear()
	_actions.clear()
	_state = state
	for action in actions:
		_actions[str(action.get("id", ""))] = action
	_atlas = load(ATLAS_PATH) if ResourceLoader.exists(ATLAS_PATH) else null
	var art := TextureRect.new()
	art.name = "EstateBackground"
	art.texture = background
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var shade := ColorRect.new()
	shade.name = "EstateShade"
	shade.color = Color("#0a171526")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_header = ColorRect.new()
	_header.name = "EstateHeader"
	_header.color = Color("#0b1b16d9")
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	_title = _label("青云门", 28, Color("#fff0cf"))
	_title.name = "EstateTitle"
	add_child(_title)
	_objective = _label(objective, 16, Color("#f5ecda"))
	_objective.name = "QuestObjective"
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_objective)
	for slot in BUILDING_SLOTS:
		if not _actions.has(str(slot.id)) and str(slot.id) != "herb_garden":
			continue
		_add_building(slot)
	_add_master()
	_footer = ColorRect.new()
	_footer.name = "EstateFooter"
	_footer.color = Color("#0b1b16db")
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_footer)
	_add_utility("map", "山门 · 返回舆图", 7, 0)
	_add_utility("sect_building", "营造亭 · 门派建设", 8, 2)
	_footer_note = _label("点击建筑入内 · 营造后庭院随之焕新", 13, Color("#d0d8c5"))
	_footer_note.name = "EstateHint"
	_footer_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_footer_note)
	if not resized.is_connected(_layout_estate):
		resized.connect(_layout_estate)
	if not get_viewport().size_changed.is_connected(_layout_estate):
		get_viewport().size_changed.connect(_layout_estate)
	_layout_estate()

func _add_building(slot: Dictionary) -> void:
	var id := str(slot.id)
	var action: Dictionary = _actions.get(id, {"id": id, "text": "药圃 · 查看门派建设"})
	var button := _hotspot("Building_%s" % id, action)
	button.set_meta("ground", slot.ground)
	button.set_meta("image_width", float(slot.width))
	button.set_meta("kind", "building")
	var building_id := str(slot.get("building", ""))
	var level := SECT_RULES.level(_state, building_id) if not building_id.is_empty() else -1
	button.set_meta("building_level", level)
	var is_empty_plot := id == "herb_garden" and level == 0
	var image := TextureRect.new()
	image.name = "BuildingImage"
	image.texture = _tile(int(slot.tile))
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.visible = not is_empty_plot
	if level == 0:
		image.modulate = Color(0.58, 0.62, 0.56, 0.78)
	elif level == 2:
		image.modulate = Color(1.04, 1.01, 0.89)
	elif level == 3:
		image.modulate = Color(1.12, 1.07, 0.87)
	button.add_child(image)
	if level > 0:
		var foundation := Panel.new()
		foundation.name = "RestoredFoundation"
		foundation.add_theme_stylebox_override("panel", _flat_style(Color("#c5b99580"), Color("#ebd6a19c"), 1))
		foundation.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foundation.visible = false
		button.add_child(foundation)
		button.move_child(foundation, 0)
		for index in range(level):
			var flag := Panel.new()
			flag.name = "UpgradeFlag%d" % (index + 1)
			var flag_style := _flat_style(Color("#97643d") if index % 2 == 0 else Color("#884a36"), Color("#b29456"), 1)
			flag_style.set_corner_radius_all(0)
			flag.add_theme_stylebox_override("panel", flag_style)
			flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(flag)
			var mast := ColorRect.new()
			mast.name = "Mast"
			mast.color = Color("#bfa06b")
			mast.position = Vector2(-2, 0)
			mast.size = Vector2(1, 22)
			mast.mouse_filter = Control.MOUSE_FILTER_IGNORE
			flag.add_child(mast)
	if is_empty_plot:
		var plot := Panel.new()
		plot.name = "ReservedHerbPlot"
		plot.add_theme_stylebox_override("panel", _flat_style(Color("#62543d9c"), Color("#bda679b0"), 1))
		plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(plot)
		for index in range(4):
			var furrow := ColorRect.new()
			furrow.name = "Furrow%d" % index
			furrow.color = Color("#332e218f")
			furrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			plot.add_child(furrow)
	var plaque := Panel.new()
	plaque.name = "BuildingPlaque"
	plaque.add_theme_stylebox_override("panel", _flat_style(INK, GOLD.darkened(0.3) if level < 3 else GOLD, 1))
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(plaque)
	var title := _label(str(slot.name), 18, Color("#fff0cf"))
	title.name = "BuildingName"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plaque.add_child(title)
	var detail := _building_detail(id, level, action)
	var status := _label(detail, 13, GOLD if level > 0 else Color("#c3c9b6"))
	status.name = "BuildingStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plaque.add_child(status)
	if level >= 0:
		button.tooltip_text += "\n" + ("空地待开垦，前往营造亭修建药圃。" if is_empty_plot else SECT_RULES.effect_text(_state, building_id))
		if level == 0 and not is_empty_plot:
			button.tooltip_text += "；原有功能可照常使用。"

func _add_master() -> void:
	if not _actions.has("master"):
		return
	var button := _hotspot("SectMaster", _actions.master)
	button.set_meta("ground", Vector2(860, 475))
	button.set_meta("kind", "master")
	var portrait := TextureRect.new()
	portrait.name = "MasterPortrait"
	portrait.texture = load(PORTRAIT_PATH) if ResourceLoader.exists(PORTRAIT_PATH) else null
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(portrait)
	var name_label := _label("顾长风", 20, Color("#fff0cf"))
	name_label.name = "MasterName"
	button.add_child(name_label)
	var role := _label("掌门 · 拜见师父", 13, GOLD)
	role.name = "MasterRole"
	button.add_child(role)
	var backing := Panel.new()
	backing.name = "MasterBacking"
	backing.add_theme_stylebox_override("panel", _flat_style(Color("#13231dbc"), Color("#dfbf7466"), 1))
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(backing)
	button.move_child(backing, 0)

func _add_utility(id: String, caption: String, tile_index: int, column: int) -> void:
	if not _actions.has(id):
		return
	var button := _hotspot("Estate_%s" % id, _actions[id])
	button.set_meta("column", column)
	button.set_meta("kind", "utility")
	var icon := TextureRect.new()
	icon.name = "UtilityImage"
	icon.texture = _tile(tile_index)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var label := _label(caption, 16, Color("#fff0cf"))
	label.name = "UtilityName"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(label)

func _hotspot(node_name: String, action: Dictionary) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = str(action.get("text", ""))
	button.tooltip_text = button.text
	button.clip_text = true
	button.disabled = bool(action.get("disabled", false))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 1)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_outline_color"]:
		button.add_theme_color_override(color_name, Color.TRANSPARENT)
	button.add_theme_stylebox_override("normal", _flat_style(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("hover", _flat_style(Color("#17372d54"), GOLD, 1))
	button.add_theme_stylebox_override("pressed", _flat_style(Color("#10281fd0"), GOLD, 2))
	button.add_theme_stylebox_override("focus", _flat_style(Color("#18392f66"), GOLD, 2))
	button.add_theme_stylebox_override("disabled", _flat_style(Color("#13231d44"), Color.TRANSPARENT, 0))
	button.pressed.connect(_emit_action.bind(str(action.id)))
	add_child(button)
	_hotspots.append(button)
	return button

func _layout_estate() -> void:
	if _title == null:
		return
	# Some older outer screens retain a 1280px minimum width. Keep every
	# courtyard hotspot inside the visible viewport at 110-130% UI scale.
	var layout_width := minf(size.x, maxf(0.0, get_viewport_rect().size.x - global_position.x))
	var layout_height := minf(size.y, maxf(0.0, get_viewport_rect().size.y - global_position.y))
	if layout_width <= 0.0 or layout_height <= 0.0:
		return
	for background_name in ["EstateBackground", "EstateShade"]:
		get_node(background_name).size = Vector2(layout_width, layout_height)
	var header_height := 74.0 if layout_width >= 800.0 else 104.0
	_header.position = Vector2.ZERO
	_header.size = Vector2(layout_width, header_height)
	_title.position = Vector2(26, 12)
	_title.size = Vector2(184, 42)
	_objective.position = Vector2(220, 16) if layout_width >= 800.0 else Vector2(26, 55)
	_objective.size = Vector2(maxf(200, layout_width - _objective.position.x - 26), 49)
	var footer_height := 50.0
	_footer.position = Vector2(0, layout_height - footer_height)
	_footer.size = Vector2(layout_width, footer_height)
	# Match the texture's centered crop exactly. Taller views fit the estate
	# across its width, preserving both side terraces instead of cropping them.
	var background: TextureRect = get_node("EstateBackground")
	var source_size := background.texture.get_size() if background.texture != null else Vector2(1672, 941)
	var art_scale := layout_width / source_size.x
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if art_scale < layout_height / source_size.y else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var art_origin := (Vector2(layout_width, layout_height) - source_size * art_scale) * 0.5
	for button in _hotspots:
		var column := int(button.get_meta("column", 1))
		var kind := str(button.get_meta("kind", "building"))
		if kind == "utility":
			button.size = Vector2(minf(245, layout_width * 0.26), 46)
			button.position = Vector2(22 if column == 0 else layout_width - button.size.x - 22, layout_height - 48)
			button.get_node("UtilityImage").position = Vector2(0, 0)
			button.get_node("UtilityImage").size = Vector2(58, 46)
			button.get_node("UtilityName").position = Vector2(62, 0)
			button.get_node("UtilityName").size = Vector2(button.size.x - 62, 46)
			continue
		var source_ground := Vector2(button.get_meta("ground"))
		var ground: Vector2 = art_origin + source_ground * art_scale
		if kind == "master":
			var card_size := Vector2(208, 74)
			button.size = card_size
			button.position = ground - card_size * 0.5
			button.get_node("MasterBacking").position = Vector2(0, 4)
			button.get_node("MasterBacking").size = Vector2(card_size.x, card_size.y - 8)
			button.get_node("MasterPortrait").position = Vector2(5, 4)
			button.get_node("MasterPortrait").size = Vector2(62, card_size.y - 8)
			button.get_node("MasterName").position = Vector2(75, 9)
			button.get_node("MasterName").size = Vector2(128, 28)
			button.get_node("MasterRole").position = Vector2(75, 42)
			button.get_node("MasterRole").size = Vector2(128, 22)
			continue
		var building_image: TextureRect = button.get_node("BuildingImage")
		var level := int(button.get_meta("building_level", -1))
		var image_size := building_image.texture.get_size() if building_image.texture != null else Vector2.ONE
		image_size *= float(button.get_meta("image_width")) * art_scale / image_size.x
		# Keep the rear hall's roof below the objective strip on shorter views.
		var available_height := maxf(24, ground.y - header_height - 4)
		# Plaques retain readable text sizes as the scenery scales. Reserve their
		# height above the front buildings so the upper entrances stay clickable.
		if source_ground.y == 645.0:
			available_height = minf(available_height, 210.0 * art_scale - 53.0)
		elif source_ground.y == 695.0:
			available_height = minf(available_height, 220.0 * art_scale - 43.0)
		if image_size.y > available_height:
			image_size *= available_height / image_size.y
		var plaque_width := maxf(clampf(layout_width * 0.115, 116, 146), image_size.x)
		button.size = Vector2(plaque_width, image_size.y + 47)
		button.position = ground - Vector2(plaque_width * 0.5, image_size.y)
		building_image.position = Vector2((plaque_width - image_size.x) * 0.5, 0)
		building_image.size = image_size
		if level > 0:
			button.get_node("RestoredFoundation").position = Vector2(23, image_size.y - 8)
			button.get_node("RestoredFoundation").size = Vector2(plaque_width - 46, 7)
			for index in range(level):
				var flag: Panel = button.get_node("UpgradeFlag%d" % (index + 1))
				flag.position = Vector2(plaque_width - 14 - index * 11, image_size.y - 30)
				flag.size = Vector2(8, 12)
		var plaque: Panel = button.get_node("BuildingPlaque")
		plaque.position = Vector2(0, image_size.y + 3)
		plaque.size = Vector2(plaque_width, 44)
		plaque.get_node("BuildingName").position = Vector2(3, 1)
		plaque.get_node("BuildingName").size = Vector2(plaque.size.x - 6, 23)
		plaque.get_node("BuildingStatus").position = Vector2(3, 24)
		plaque.get_node("BuildingStatus").size = Vector2(plaque.size.x - 6, 18)
		if button.has_node("ReservedHerbPlot"):
			var plot: Panel = button.get_node("ReservedHerbPlot")
			plot.size = Vector2(image_size.x * 0.82, image_size.y * 0.42)
			plot.position = Vector2((plaque_width - plot.size.x) * 0.5, image_size.y - plot.size.y)
			for index in range(4):
				var furrow: ColorRect = plot.get_node("Furrow%d" % index)
				furrow.position = Vector2(8, (index + 1) * plot.size.y / 5.0)
				furrow.size = Vector2(plot.size.x - 16, 3)
	_footer_note.position = Vector2(layout_width * 0.29, layout_height - 37)
	_footer_note.size = Vector2(layout_width * 0.42, 28)
	_footer_note.visible = layout_width >= 1000.0

func _building_detail(id: String, level: int, action: Dictionary) -> String:
	if id == "herb_garden" and level == 0:
		return "空地 · 待开垦"
	if level == 0:
		return "待整修 · 可入内"
	if level > 0:
		return "%d级 · %s" % [level, ["", "初成", "兴盛", "完备"][level]]
	match id:
		"master": return "主线 · 拜见师父" if "主线" in str(action.text) else "拜见师父"
		"workshop": return "丹药炼制"
		"gathering": return "采药 · 挖矿"
		"qingyun_tavern": return "招募弟子"
	return "点击入内"

func _tile(index: int) -> Texture2D:
	if _atlas == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = _atlas
	texture.region = BUILDING_REGIONS[index]
	texture.filter_clip = true
	return texture

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _flat_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(5)
	return style

func _emit_action(id: String) -> void:
	action_requested.emit(id)
