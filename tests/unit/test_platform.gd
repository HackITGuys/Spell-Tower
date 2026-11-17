extends GdUnitTestSuite
## Platform-dependent behaviour: web (no profiles, nothing stored) and touch
## (the game's own keyboard, never the phone's).

var _settings_script := preload("res://scripts/autoload/settings.gd")


func _settings(web: bool, touch: bool) -> Node:
	var s: Node = auto_free(_settings_script.new())
	s.persist = false
	s.force_web = web
	s.force_touch = touch
	return s


func test_desktop_app_uses_profiles_and_keys() -> void:
	var s := _settings(false, false)
	assert_bool(s.uses_profiles()).is_true()
	assert_str(s.input_mode()).is_equal(s.INPUT_KEYS)
	assert_bool(s.show_keyboard()).is_false()


func test_mobile_app_uses_profiles_and_own_keyboard() -> void:
	var s := _settings(false, true)
	assert_bool(s.uses_profiles()).is_true()
	assert_str(s.input_mode()).is_equal(s.INPUT_OSK)
	assert_bool(s.show_keyboard()).is_true()


func test_phone_browser_has_no_profiles_and_uses_own_keyboard() -> void:
	var s := _settings(true, true)
	assert_bool(s.uses_profiles()).is_false()
	assert_str(s.input_mode()).is_equal(s.INPUT_OSK)


func test_desktop_browser_has_no_profiles_and_uses_keys() -> void:
	var s := _settings(true, false)
	assert_bool(s.uses_profiles()).is_false()
	assert_str(s.input_mode()).is_equal(s.INPUT_KEYS)


func test_web_never_stores_anything() -> void:
	var s := _settings(true, false)
	s.persist = true
	s._ready()
	assert_bool(s.persist).is_false()
	assert_bool(s.has_profiles()).is_false()


func test_forced_input_mode_wins() -> void:
	var s := _settings(false, false)
	s.force_input_mode = s.INPUT_OSK
	assert_bool(s.show_keyboard()).is_true()


func test_web_menu_has_no_player_screen() -> void:
	var was_web: Variant = Settings.force_web
	Settings.force_web = true
	var menu: Control = auto_free(load("res://scenes/main_menu.tscn").instantiate())
	add_child(menu)
	await await_idle_frame()
	var texts := _texts(menu)
	assert_array(texts).not_contains([tr("MENU_PLAYER"), tr("PROFILE_TITLE")])
	assert_array(texts).contains(["[ " + tr("MENU_START") + " ]", tr("MENU_START_GRADE")])
	assert_int(_count(menu, "LineEdit")).is_equal(0)
	assert_int(_count(menu, "OptionButton")).is_equal(0)
	assert_int(_count(menu, "Stepper")).is_equal(6)   # UI lang, word lang, grade, colour, size, sound
	Settings.force_web = was_web


func _texts(n: Node, out: Array = []) -> Array:
	if n is Label or n is Button:
		out.append(n.text)
	for c in n.get_children():
		_texts(c, out)
	return out


func _count(n: Node, type_name: String) -> int:
	var c := 1 if n.is_class(type_name) or (n.get_script() != null and n.get_script().get_global_name() == type_name) else 0
	for child in n.get_children():
		c += _count(child, type_name)
	return c
