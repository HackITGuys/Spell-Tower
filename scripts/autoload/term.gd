extends Node
## Terminal look: colour palette (derived from one base colour), text size,
## font, and the Theme applied to the root window. See docs/style-guide.md.

signal style_changed

## Base colours the player can choose. Everything else is derived (derive()).
const PALETTES: Array[Dictionary] = [
	{"id": "green", "key": "COLOR_GREEN", "base": Color(0.3, 1.0, 0.45)},
	{"id": "orange", "key": "COLOR_ORANGE", "base": Color(1.0, 0.6, 0.15)},
	{"id": "cyan", "key": "COLOR_CYAN", "base": Color(0.3, 0.88, 1.0)},
	{"id": "pink", "key": "COLOR_PINK", "base": Color(1.0, 0.42, 0.78)},
	{"id": "purple", "key": "COLOR_PURPLE", "base": Color(0.72, 0.55, 1.0)},
	{"id": "white", "key": "COLOR_WHITE", "base": Color(0.92, 0.92, 0.88)},
]
const TEXT_SIZES: Array[Dictionary] = [
	{"id": "s", "key": "TEXT_S", "scale": 0.85},
	{"id": "m", "key": "TEXT_M", "scale": 1.0},
	{"id": "l", "key": "TEXT_L", "scale": 1.2},
	{"id": "xl", "key": "TEXT_XL", "scale": 1.45},
]
## Candidate hues for the error colour, in order of preference (red first).
const ERROR_HUES: Array[float] = [0.0, 0.5, 0.15, 0.78]
const MIN_HUE_GAP := 0.12

# Base font sizes (before text-size scaling). Use sz() when applying them.
const FONT_SIZE := 26
const TITLE_SIZE := 56
const WORD_SIZE := 30
## Touch drags shorter than this (px) are taps, not scrolls (ScrollContainer.scroll_deadzone).
const SCROLL_DEADZONE := 24

var BG := Color(0.02, 0.035, 0.02)
var FG := Color(0.3, 1.0, 0.45)
var DIM := Color(0.15, 0.55, 0.25)
var ACCENT := Color(1.0, 0.76, 0.2)
var ERROR := Color(1.0, 0.32, 0.26)
var scale := 1.0
var palette_id := "green"
var text_size_id := "m"

var font: Font = preload("res://fonts/JetBrainsMono-Regular.ttf")
var font_bold: Font = preload("res://fonts/JetBrainsMono-Bold.ttf")
var theme: Theme


func _ready() -> void:
	apply(Settings.palette, Settings.text_size)


func sz(base: int) -> int:
	return int(round(base * scale))


func char_width(size: int = -1) -> float:
	if size < 0:
		size = sz(FONT_SIZE)
	return font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func apply(p_palette: String, p_text_size: String) -> void:
	palette_id = p_palette if find_palette(p_palette) != {} else "green"
	text_size_id = p_text_size if find_text_size(p_text_size) != {} else "m"
	var c := derive(find_palette(palette_id)["base"])
	BG = c["bg"]
	FG = c["fg"]
	DIM = c["dim"]
	ACCENT = c["accent"]
	ERROR = c["error"]
	scale = find_text_size(text_size_id)["scale"]
	theme = build_theme()
	if is_inside_tree():
		get_tree().root.theme = theme
		RenderingServer.set_default_clear_color(BG)
	style_changed.emit()


static func find_palette(id: String) -> Dictionary:
	for p in PALETTES:
		if p["id"] == id:
			return p
	return {}


static func find_text_size(id: String) -> Dictionary:
	for t in TEXT_SIZES:
		if t["id"] == id:
			return t
	return {}


static func hue_gap(a: float, b: float) -> float:
	var d := absf(fposmod(a, 1.0) - fposmod(b, 1.0))
	return minf(d, 1.0 - d)


## All UI colours from one base colour.
static func derive(base: Color) -> Dictionary:
	var grey := base.s < 0.15
	var bg := Color.from_hsv(base.h, 0.0 if grey else 0.6, 0.045)
	var dim := base.lerp(bg, 0.45)
	var accent := Color.from_hsv(0.13, 0.85, 1.0) if grey else Color.from_hsv(fposmod(base.h - 0.22, 1.0), 0.8, 1.0)
	var error := Color.from_hsv(0.0, 0.75, 1.0)
	for h in ERROR_HUES:
		var far_from_base := grey or hue_gap(h, base.h) >= MIN_HUE_GAP
		if far_from_base and hue_gap(h, accent.h) >= MIN_HUE_GAP:
			error = Color.from_hsv(h, 0.75, 1.0)
			break
	return {"bg": bg, "fg": base, "dim": dim, "accent": accent, "error": error}


func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = sz(FONT_SIZE)

	t.set_color("font_color", "Label", FG)

	var normal := _box(BG, FG)
	var hover := _box(FG, FG)
	var pressed := _box(ACCENT, ACCENT)
	var disabled := _box(BG, DIM)
	var focus := _box(Color(0, 0, 0, 0), ACCENT, false)
	for type in ["Button"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, FG)
		t.set_color("font_hover_color", type, BG)
		t.set_color("font_pressed_color", type, BG)
		t.set_color("font_hover_pressed_color", type, BG)
		t.set_color("font_focus_color", type, FG)
		t.set_color("font_disabled_color", type, DIM)
		t.set_color("icon_normal_color", type, FG)
		t.set_color("icon_hover_color", type, BG)

	var panel := _box(BG, FG)
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_stylebox("hover", "PopupMenu", _box(FG, FG))
	t.set_color("font_color", "PopupMenu", FG)
	t.set_color("font_hover_color", "PopupMenu", BG)
	t.set_color("font_disabled_color", "PopupMenu", DIM)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	t.set_stylebox("normal", "LineEdit", _box(BG, FG))
	t.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), ACCENT, false))
	t.set_color("font_color", "LineEdit", FG)
	t.set_color("font_placeholder_color", "LineEdit", DIM)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", DIM)
	return t


## Button that doesn't invert on hover (touch screens leave buttons "hovered").
func calm_button(b: Button) -> void:
	b.add_theme_stylebox_override("hover", theme.get_stylebox("focus", "Button"))
	b.add_theme_color_override("font_hover_color", ACCENT)


func _box(bg: Color, border: Color, fill := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.draw_center = fill
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
