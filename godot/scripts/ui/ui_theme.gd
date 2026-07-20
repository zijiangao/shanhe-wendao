class_name UITheme
extends RefCounted

const PANEL_FRAME := preload("res://assets/ui/panel_frame.png")
const BUTTON_NORMAL := preload("res://assets/ui/button_frame_normal.png")
const BUTTON_HOVER := preload("res://assets/ui/button_frame_hover.png")
const BUTTON_PRESSED := preload("res://assets/ui/button_frame_pressed.png")
const LOGO_WORDMARK := preload("res://assets/ui/logo_wordmark.png")
const NAV_ICONS := {
	"map": preload("res://assets/ui/nav_icon_map.png"),
	"quests": preload("res://assets/ui/nav_icon_quest.png"),
	"character": preload("res://assets/ui/nav_icon_character.png"),
	"achievements": preload("res://assets/ui/nav_icon_achievement.png"),
	"save": preload("res://assets/ui/nav_icon_save.png"),
	"settings": preload("res://assets/ui/nav_icon_settings.png"),
}
const ACHIEVEMENT_BADGE_LOCKED := preload("res://assets/ui/achievement_badge_locked.png")
const ACHIEVEMENT_BADGE_UNLOCKED := preload("res://assets/ui/achievement_badge_unlocked.png")
const MAP_MARKERS := {
	"visited": preload("res://assets/ui/map_marker_visited.png"),
	"current": preload("res://assets/ui/map_marker_current.png"),
	"locked": preload("res://assets/ui/map_marker_locked.png"),
}

## Flat panel/row style for small elements (list rows, log boxes, tooltips)
## where a full ornamental frame would be too heavy.
static func box(color: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.border_color = color.lightened(0.18)
	b.set_border_width_all(1)
	b.set_corner_radius_all(3)
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	return b

## Dark-jade multiply tint matching the game's existing dark-panel palette
## (#172820/#294438), for screens that pair the frame with light text.
const DARK_TINT := Color(0.24, 0.3, 0.26)
## Near-neutral tint for screens that want the frame's natural light
## parchment tone (paired with dark text, e.g. the character sheet).
const PARCHMENT_TINT := Color(0.94, 0.9, 0.82)

## Ink-wash panel frame for major screen backgrounds (settings, achievements,
## character, pause). Tint defaults to the natural parchment tone.
## content_margin is deliberately left at the StyleBox default (auto): it does
## not scale reliably with the panel's actual on-screen size, so callers
## should reserve their own clearance via framed_panel()'s MarginContainer
## instead of relying on this stylebox's own margins for text clearance.
static func panel_box(tint: Color = PARCHMENT_TINT) -> StyleBoxTexture:
	var b := StyleBoxTexture.new()
	b.texture = PANEL_FRAME
	b.texture_margin_left = 96
	b.texture_margin_right = 96
	b.texture_margin_top = 62
	b.texture_margin_bottom = 62
	b.modulate_color = tint
	return b

## Builds a framed panel (PanelContainer + panel_box background) at the given
## position/size, with a MarginContainer reserving enough clearance that
## child content never collides with the frame's painted border, and returns
## the inner VBoxContainer ready to receive content.
static func framed_panel(parent: Node, pos: Vector2, panel_size: Vector2, tint: Color = PARCHMENT_TINT, separation: int = 12) -> VBoxContainer:
	var bg := PanelContainer.new()
	bg.position = pos
	bg.size = panel_size
	bg.add_theme_stylebox_override("panel", panel_box(tint))
	parent.add_child(bg)
	return _framed_content(bg, separation)

## Same as framed_panel() but fills the given parent-relative offsets
## (PRESET_FULL_RECT-style) instead of an explicit position/size.
static func framed_panel_rect(parent: Node, left: float, top: float, right: float, bottom: float, tint: Color = PARCHMENT_TINT, separation: int = 12) -> VBoxContainer:
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = left
	bg.offset_top = top
	bg.offset_right = right
	bg.offset_bottom = bottom
	bg.add_theme_stylebox_override("panel", panel_box(tint))
	parent.add_child(bg)
	return _framed_content(bg, separation)

static func _framed_content(bg: PanelContainer, separation: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 52)
	margin.add_theme_constant_override("margin_bottom", 36)
	bg.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	margin.add_child(vbox)
	return vbox

static func _button_stylebox(texture: Texture2D, tint: Color) -> StyleBoxTexture:
	var b := StyleBoxTexture.new()
	b.texture = texture
	b.texture_margin_left = 42
	b.texture_margin_right = 42
	b.texture_margin_top = 34
	b.texture_margin_bottom = 34
	b.content_margin_left = 16
	b.content_margin_right = 16
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	b.modulate_color = tint
	return b

## Ink-wash button frame textures tinted per action color, replacing the old
## flat StyleBoxFlat rectangle used for every button in the game.
static func action_button(text_value: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("#f5ecd9"))
	button.add_theme_stylebox_override("normal", _button_stylebox(BUTTON_NORMAL, color))
	button.add_theme_stylebox_override("hover", _button_stylebox(BUTTON_HOVER, color.lightened(0.2)))
	button.add_theme_stylebox_override("pressed", _button_stylebox(BUTTON_PRESSED, color.darkened(0.1)))
	button.add_theme_stylebox_override("focus", _button_stylebox(BUTTON_HOVER, color.lightened(0.32)))
	button.add_theme_stylebox_override("disabled", _button_stylebox(BUTTON_NORMAL, color.darkened(0.35)))
	button.add_theme_color_override("font_disabled_color", Color("#c9c2ad"))
	return button

static func nav_icon(id: String) -> Texture2D:
	return NAV_ICONS.get(id)

static func achievement_badge(unlocked: bool) -> Texture2D:
	return ACHIEVEMENT_BADGE_UNLOCKED if unlocked else ACHIEVEMENT_BADGE_LOCKED

static func map_marker(state: String) -> Texture2D:
	return MAP_MARKERS.get(state, MAP_MARKERS.locked)

## Shop/backpack item icons (weapons, armor, goods) are looked up by the same
## ids ShopRules already uses, via load() rather than preload(): unlike the
## other art in this file, these files may not exist yet on a given checkout
## (production is a separate, external art-generation step -- see
## ASSET_PROVENANCE.md), and preload() would break the whole project's import
## if any one were missing. Screens using this must render without an icon
## when it returns null rather than assuming one is always available.
static func item_icon(id: String) -> Texture2D:
	var path := "res://assets/ui/item_%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null
