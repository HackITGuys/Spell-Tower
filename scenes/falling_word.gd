class_name FallingWord
extends Control
## One falling word, drawn as "[ word ]" with the typed part highlighted.

var text := ""
var d := 1
var typed := 0
var speed := 50.0
var alive := true
var had_mistakes := false
var y: float:
	get:
		return position.y

var _font: Font
var _font_size := 30
var _cell := 18.0
var _flash := 0.0
var _wiggle := 0.0


func setup(word: String, difficulty: int, fall_speed: float, font: Font, font_size: int) -> void:
	text = word
	d = difficulty
	speed = fall_speed
	_font = font
	_font_size = font_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


func retext(word: String, difficulty: int) -> void:
	text = word
	d = difficulty
	typed = 0
	had_mistakes = false
	_wiggle = 0.35
	_resize()


func _resize() -> void:
	_cell = _font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	var cells := 4 + text.length()
	size = Vector2(_cell * cells, _font.get_height(_font_size))
	pivot_offset = size / 2.0


func flash_wrong() -> void:
	had_mistakes = true
	_flash = 0.3


func _process(delta: float) -> void:
	if not alive:
		return
	position.y += speed * delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	if _wiggle > 0.0:
		_wiggle = maxf(0.0, _wiggle - delta)
		rotation = sin(_wiggle * 40.0) * 0.08 * (_wiggle / 0.35)
	else:
		rotation = 0.0
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	var targeted := typed > 0
	var base_col := Term.ERROR if _flash > 0.0 else Term.FG
	var bracket_col := Term.ACCENT if targeted else Term.DIM
	var asc := _font.get_ascent(_font_size)
	_glyph("[", 0, asc, bracket_col)
	var cell := 2
	for i in text.length():
		_glyph(text[i], cell, asc, Term.ACCENT if i < typed else base_col)
		cell += 1
	_glyph("]", cell + 1, asc, bracket_col)


func _glyph(ch: String, cell: int, asc: float, col: Color) -> void:
	draw_string(_font, Vector2(cell * _cell, asc), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, col)


## Destroyed by the player or a power-up.
func explode() -> void:
	alive = false
	typed = text.length()
	queue_redraw()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)


## Reached the base.
func crash() -> void:
	alive = false
	_flash = 10.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
