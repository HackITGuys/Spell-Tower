class_name Stepper
extends HBoxContainer
## A touch-friendly picker: "[ < ]  Grade 3  [ > ]". It replaces OptionButton,
## whose popup list was hard to use on phones.
##   - tap < or > to step (wraps around at the ends)
##   - tap the value to step forward
##   - with keyboard focus on the value: Left / Right step, Enter steps forward
## Options are (text, value) pairs; value_changed passes the value.

signal value_changed(value: Variant)

const ARROW_MIN_WIDTH := 64.0

var _texts: Array[String] = []
var _values: Array = []
var _index := -1
var _prev: Button
var _value: Button
var _next: Button


func _init() -> void:
	add_theme_constant_override("separation", 6)
	_prev = _arrow("<", -1)
	_value = Button.new()
	_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_value.clip_text = true
	_value.pressed.connect(step.bind(1))
	_value.gui_input.connect(_on_value_input)
	add_child(_value)
	_next = _arrow(">", 1)


func add_option(text: String, value: Variant, selected := false) -> void:
	_texts.append(text)
	_values.append(value)
	if selected or _index < 0:
		_index = _texts.size() - 1
	_refresh()


func option_count() -> int:
	return _texts.size()


func selected_index() -> int:
	return _index


func selected_value() -> Variant:
	return _values[_index] if _index >= 0 else null


func selected_text() -> String:
	return _texts[_index] if _index >= 0 else ""


## Select without emitting value_changed. Returns false if the value isn't an option.
func select_value(value: Variant) -> bool:
	var i := _values.find(value)
	if i < 0:
		return false
	_index = i
	_refresh()
	return true


## Move by delta options (wrapping) and emit value_changed.
func step(delta: int) -> void:
	if _texts.size() < 2:
		return
	_index = posmod(_index + delta, _texts.size())
	_refresh()
	value_changed.emit(_values[_index])


## The focusable part, e.g. for grab_focus().
func focus_target() -> Control:
	return _value


func _arrow(text: String, delta: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.x = ARROW_MIN_WIDTH
	b.focus_mode = Control.FOCUS_NONE   # taps don't move keyboard focus
	b.pressed.connect(step.bind(delta))
	add_child(b)
	return b


func _on_value_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		step(-1)
		_value.accept_event()   # don't also move focus to a neighbour
	elif event.is_action_pressed("ui_right"):
		step(1)
		_value.accept_event()


func _refresh() -> void:
	_value.text = selected_text()
	var many := _texts.size() > 1
	_prev.disabled = not many
	_next.disabled = not many
