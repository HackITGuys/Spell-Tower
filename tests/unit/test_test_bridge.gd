extends GdUnitTestSuite
## The browser-test bridge (scripts/autoload/test_bridge.gd).


func test_inactive_outside_the_e2e_web_build() -> void:
	# Unit tests don't run in the "Web (e2e)" export, so the bridge must be off.
	assert_bool(TestBridge.active).is_false()


func test_rect_of_reports_canvas_pixels() -> void:
	var c: Control = auto_free(Control.new())
	add_child(c)
	c.position = Vector2(10, 20)
	c.size = Vector2(30, 40)
	var r: Array = TestBridge.rect_of(c)
	assert_int(r.size()).is_equal(4)
	assert_float(r[2]).is_greater(0.0)
	assert_float(r[3]).is_greater(0.0)
	assert_that(TestBridge.rect_of(null)).is_null()


func test_snapshot_lists_menu_steppers_and_start() -> void:
	var was_web: Variant = Settings.force_web
	Settings.force_web = true
	var menu: Control = auto_free(load("res://scenes/main_menu.tscn").instantiate())
	add_child(menu)
	await await_idle_frame()
	var state := {"buttons": [], "labels": [], "steppers": []}
	TestBridge._collect(menu, state)
	var labels: Array = state["steppers"].map(func(s): return s["label"])
	assert_array(labels).contains([tr("MENU_START_GRADE"), tr("MENU_WORD_LANGUAGE")])
	var buttons: Array = state["buttons"].map(func(b): return b["text"])
	assert_array(buttons).contains(["[ " + tr("MENU_START") + " ]"])
	Settings.force_web = was_web
