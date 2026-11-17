extends GdUnitTestSuite
## The < value > picker that replaced drop-downs in the menus.


func _stepper(values: Array, selected: Variant = null) -> Stepper:
	var st: Stepper = auto_free(Stepper.new())
	for v in values:
		st.add_option("opt %s" % v, v, v == selected)
	return st


func test_first_option_is_selected_by_default() -> void:
	var st := _stepper([1, 2, 3])
	assert_int(st.selected_value()).is_equal(1)
	assert_str(st.selected_text()).is_equal("opt 1")


func test_selected_flag_picks_the_option() -> void:
	assert_int(_stepper([1, 2, 3], 2).selected_value()).is_equal(2)


func test_step_wraps_and_emits() -> void:
	var st := _stepper(["a", "b", "c"])
	var seen: Array = []
	st.value_changed.connect(func(v): seen.append(v))
	st.step(-1)
	st.step(1)
	st.step(1)
	assert_array(seen).is_equal(["c", "a", "b"])
	assert_str(st.selected_value()).is_equal("b")


func test_select_value_is_silent_and_checks_membership() -> void:
	var st := _stepper([0, 5, 10])
	var seen: Array = []
	st.value_changed.connect(func(v): seen.append(v))
	assert_bool(st.select_value(10)).is_true()
	assert_bool(st.select_value(7)).is_false()
	assert_int(st.selected_value()).is_equal(10)
	assert_array(seen).is_empty()


func test_single_option_does_not_step() -> void:
	var st := _stepper(["only"])
	var seen: Array = []
	st.value_changed.connect(func(v): seen.append(v))
	st.step(1)
	assert_array(seen).is_empty()
	assert_str(st.selected_value()).is_equal("only")


func test_tapping_the_value_steps_forward() -> void:
	var st := _stepper(["a", "b"])
	(st.focus_target() as Button).pressed.emit()
	assert_str(st.selected_value()).is_equal("b")
	(st.focus_target() as Button).pressed.emit()
	assert_str(st.selected_value()).is_equal("a")


func test_arrow_keys_step_when_focused() -> void:
	var st := _stepper([1, 2, 3])
	add_child(st)
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	st.focus_target().gui_input.emit(right)
	assert_int(st.selected_value()).is_equal(2)
	var left := InputEventAction.new()
	left.action = "ui_left"
	left.pressed = true
	st.focus_target().gui_input.emit(left)
	st.focus_target().gui_input.emit(left)
	assert_int(st.selected_value()).is_equal(3)
