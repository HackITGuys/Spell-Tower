class_name OnScreenKeyboard
extends Control
## Terminal-style on-screen keyboard drawn by the game (no system IME, no
## autocorrect). Layout comes from the word language's "keyboard" rows.
## Handles multi-touch directly so fast two-thumb typing isn't dropped.

signal letter_pressed(ch: String)
signal release_pressed

const BACK := "<-"
const GAP := 6.0

var rows: Array = []
var _keys: Array[Dictionary] = []  ## {rect: Rect2, ch: String}
var _lit := {}  ## key index -> remaining highlight time
var _key_size := Vector2(60, 72)


func set_layout(p_rows: Array) -> void:
	rows = p_rows.duplicate()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	_keys.clear()
	if rows.is_empty() or size.x <= 0.0:
		return
	var max_len := 0
	for r in rows:
		max_len = maxi(max_len, String(r).length())
	max_len = maxi(max_len, String(rows[-1]).length() + 2)  # room for <-
	var kw := floorf((size.x - GAP * (max_len + 1)) / max_len)
	var kh := clampf(kw * 1.3, 56.0, 96.0)
	_key_size = Vector2(kw, kh)
	custom_minimum_size.y = rows.size() * (kh + GAP) + GAP
	for ri in rows.size():
		var row := String(rows[ri])
		var labels: Array[String] = []
		for i in row.length():
			labels.append(row[i])
		if ri == rows.size() - 1:
			labels.append(BACK)
		var widths: Array[float] = []
		var total := 0.0
		for l in labels:
			var w := kw * 2.0 + GAP if l == BACK else kw
			widths.append(w)
			total += w
		total += GAP * (labels.size() - 1)
		var x := (size.x - total) / 2.0
		var yy := GAP + ri * (kh + GAP)
		for i in labels.size():
			_keys.append({"rect": Rect2(x, yy, widths[i], kh), "ch": labels[i]})
			x += widths[i] + GAP
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.device != InputEvent.DEVICE_ID_EMULATION
	):
		pos = event.position
	if pos == Vector2.INF:
		return
	var local := get_global_transform_with_canvas().affine_inverse() * pos
	for i in _keys.size():
		if _keys[i]["rect"].has_point(local):
			_lit[i] = 0.12
			queue_redraw()
			var ch: String = _keys[i]["ch"]
			if ch == BACK:
				release_pressed.emit()
			else:
				letter_pressed.emit(ch)
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	if _lit.is_empty():
		return
	for k in _lit.keys():
		_lit[k] -= delta
		if _lit[k] <= 0.0:
			_lit.erase(k)
	queue_redraw()


func _draw() -> void:
	var font := Term.font
	var fs := int(clampf(_key_size.y * 0.42, 20.0, 40.0))
	for i in _keys.size():
		var r: Rect2 = _keys[i]["rect"]
		var lit := _lit.has(i)
		if lit:
			draw_rect(r, Term.ACCENT, true)
		draw_rect(r, Term.FG if not lit else Term.ACCENT, false, 2.0)
		var label: String = _keys[i]["ch"]
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var p := (
			r.position + Vector2((r.size.x - ts.x) / 2.0, (r.size.y - font.get_height(fs)) / 2.0 + font.get_ascent(fs))
		)
		draw_string(font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Term.BG if lit else Term.FG)
