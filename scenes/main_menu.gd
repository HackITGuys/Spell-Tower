extends Control
## Title screen: player profile, settings (incl. start grade), start. On first launch (or
## "+ new player") it shows the new-player form instead.
## Rebuilt whenever the language, look or profile changes.

const GameScene := "res://scenes/game.tscn"
const MAX_WIDTH := 760.0

var _ui: Control
var _show_new_player := false
var _rebuild_queued := false
var _name_edit: LineEdit
var _name_error: Label
var _new_grade := Tuning.DEFAULT_GRADE
var _delete_armed := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Locale.locale_changed.connect(func(_c): _queue_build())
	Term.style_changed.connect(_queue_build)
	Settings.profile_changed.connect(_queue_build)
	_build()


func _queue_build() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_build.call_deferred()


func _build() -> void:
	_rebuild_queued = false
	_delete_armed = false
	_disconnect_web_keys()   # only the new-player form turns it back on
	if _ui != null:
		_ui.queue_free()
	# Scroll area spans the whole screen (scrollbar at the far right edge);
	# the content inside is width-capped and centred.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_ui = scroll
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	scroll.add_child(margin)
	var cap := WidthCap.new(MAX_WIDTH)
	margin.add_child(cap)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	cap.add_child(v)

	_add_title(v)
	if _show_new_player or not Settings.has_profiles():
		_build_new_player(v)
	else:
		_build_main(v)


func _add_title(v: VBoxContainer) -> void:
	var art := _label("   /\\\n  /  \\\n  |[]|\n  |  |\n__|__|__", Term.DIM)
	art.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(art)
	var title := _label(tr("APP_TITLE"), Term.FG)
	title.add_theme_font_override("font", Term.font_bold)
	title.add_theme_font_size_override("font_size", Term.sz(Term.TITLE_SIZE))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var tag := _label("> " + tr("APP_TAGLINE"), Term.DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tag)


# --- Main menu ----------------------------------------------------------------

func _build_main(v: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)

	# Player
	var player_opt := _row(grid, tr("MENU_PLAYER"))
	for p in Settings.profiles():
		player_opt.add_item(p["name"])
		player_opt.set_item_metadata(player_opt.item_count - 1, p["id"])
		if p["id"] == Settings.current_id():
			player_opt.select(player_opt.item_count - 1)
	player_opt.add_item(tr("MENU_NEW_PLAYER"))
	player_opt.set_item_metadata(player_opt.item_count - 1, "")
	player_opt.item_selected.connect(func(i):
		var id: String = player_opt.get_item_metadata(i)
		if id == "":
			_new_grade = Settings.grade
			_show_new_player = true
			_queue_build()
		else:
			Settings.select_profile(id))

	# Interface language
	var ui_opt := _row(grid, tr("MENU_UI_LANGUAGE"))
	for l in Locale.available():
		_item(ui_opt, l["name"], l["code"], l["code"] == Locale.current())
	ui_opt.item_selected.connect(func(i):
		Settings.ui_locale = ui_opt.get_item_metadata(i)
		Settings.save_settings()
		Locale.apply(Settings.ui_locale))

	# Word language
	var word_opt := _row(grid, tr("MENU_WORD_LANGUAGE"))
	_item(word_opt, tr("MENU_FOLLOW_UI"), "", Settings.word_lang == "")
	for l: Dictionary in WordBank.languages:
		_item(word_opt, l["name"], l["code"], l["code"] == Settings.word_lang)
	word_opt.item_selected.connect(func(i):
		Settings.word_lang = word_opt.get_item_metadata(i)
		Settings.save_settings()
		_queue_build())

	# Start grade (every game starts at its first stage)
	var grade_opt := _row(grid, tr("MENU_START_GRADE"))
	_fill_grades(grade_opt, Settings.grade)
	grade_opt.item_selected.connect(func(i):
		Settings.grade = grade_opt.get_item_metadata(i)
		Settings.save_settings())

	# Colour
	var col_opt := _row(grid, tr("MENU_COLOUR"))
	for p in Term.PALETTES:
		_item(col_opt, tr(p["key"]), p["id"], p["id"] == Settings.palette)
	col_opt.item_selected.connect(func(i):
		Settings.palette = col_opt.get_item_metadata(i)
		Settings.save_settings()
		Term.apply(Settings.palette, Settings.text_size))

	# Text size
	var size_opt := _row(grid, tr("MENU_TEXT_SIZE"))
	for t in Term.TEXT_SIZES:
		_item(size_opt, tr(t["key"]), t["id"], t["id"] == Settings.text_size)
	size_opt.item_selected.connect(func(i):
		Settings.text_size = size_opt.get_item_metadata(i)
		Settings.save_settings()
		Term.apply(Settings.palette, Settings.text_size))

	# Sound
	var snd_opt := _row(grid, tr("MENU_SOUND"))
	_item(snd_opt, tr("OPT_ON"), true, Settings.sound)
	_item(snd_opt, tr("OPT_OFF"), false, not Settings.sound)
	snd_opt.item_selected.connect(func(i):
		Settings.sound = snd_opt.get_item_metadata(i)
		Settings.save_settings()
		Sfx.play("hit"))

	# Start
	var start_btn := _big_button(v, tr("MENU_START"))
	start_btn.pressed.connect(_start)
	start_btn.grab_focus.call_deferred()

	var lang := Settings.effective_word_lang()
	var scores := _label("%s   %s" % [tr("MENU_BEST") % Settings.best_for(lang), tr("MENU_ALL_TIME") % Settings.high_score()], Term.ACCENT)
	scores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scores.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(scores)

	for key in ["MENU_HELP_1", "MENU_HELP_2", "MENU_HELP_3"]:
		var h := _label("  " + tr(key), Term.DIM)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_theme_font_size_override("font_size", Term.sz(20))
		v.add_child(h)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	v.add_child(bottom)
	var del := Button.new()
	del.text = tr("MENU_DELETE_PLAYER") + " " + Settings.current_name()
	del.add_theme_font_size_override("font_size", Term.sz(20))
	del.pressed.connect(func():
		if not _delete_armed:
			_delete_armed = true
			del.text = tr("MENU_DELETE_CONFIRM")
			del.add_theme_color_override("font_color", Term.ERROR)
			return
		Settings.delete_profile(Settings.current_id())
		_queue_build())
	bottom.add_child(del)
	if not OS.has_feature("web"):
		var quit := Button.new()
		quit.text = tr("MENU_QUIT")
		quit.add_theme_font_size_override("font_size", Term.sz(20))
		quit.pressed.connect(func(): get_tree().quit())
		bottom.add_child(quit)


## Pre-school, Grade 1 .. Grade 10.
func _fill_grades(opt: OptionButton, selected: int) -> void:
	for g in range(Tuning.MIN_GRADE, Tuning.MAX_GRADE + 1):
		_item(opt, Tuning.grade_name(g), g, g == selected)


# --- New player -----------------------------------------------------------------

func _build_new_player(v: VBoxContainer) -> void:
	var title := _label(tr("PROFILE_TITLE"), Term.FG)
	title.add_theme_font_size_override("font_size", Term.sz(36))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var name_label := _label(tr("PROFILE_NAME"), Term.FG)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.max_length = Settings.NAME_MAX
	_name_edit.placeholder_text = tr("PROFILE_NAME_HINT")
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(_t): _create_player())
	grid.add_child(_name_edit)
	var grade_opt := _row(grid, tr("PROFILE_GRADE"))
	_fill_grades(grade_opt, _new_grade)
	grade_opt.item_selected.connect(func(i): _new_grade = grade_opt.get_item_metadata(i))

	_name_error = _label("", Term.ERROR)
	_name_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_name_error)

	var ok := _big_button(v, tr("PROFILE_CREATE"))
	ok.pressed.connect(_create_player)
	if Settings.has_profiles():
		var cancel := Button.new()
		cancel.text = tr("PROFILE_CANCEL")
		cancel.pressed.connect(func():
			_show_new_player = false
			_queue_build())
		v.add_child(cancel)

	var privacy := _label(tr("PROFILE_PRIVACY"), Term.DIM)
	privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	privacy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	privacy.add_theme_font_size_override("font_size", Term.sz(20))
	v.add_child(privacy)

	if Settings.show_keyboard():
		# Our own keyboard types into the name field; no system keyboard.
		_name_edit.virtual_keyboard_enabled = false
		var ui_lang := Locale.current().split("_")[0]
		var layout: Array = WordBank.get_language(ui_lang).get("keyboard", WordBank.get_language("en").get("keyboard", []))
		var kb := OnScreenKeyboard.new()
		kb.custom_minimum_size.y = 240
		kb.set_layout(layout)
		kb.letter_pressed.connect(func(ch):
			if _name_edit.text.length() < Settings.NAME_MAX:
				_name_edit.text += ch
				_name_edit.caret_column = _name_edit.text.length()
				Sfx.play("key"))
		kb.release_pressed.connect(func():
			_name_edit.text = _name_edit.text.left(-1)
			_name_edit.caret_column = _name_edit.text.length()
			Sfx.play("key"))
		v.add_child(kb)
	elif Settings.input_mode() == Settings.INPUT_WEB_MOBILE:
		# Browser on a phone: tapping opens the phone's own keyboard (WebKeys).
		_name_edit.virtual_keyboard_enabled = false
		_name_edit.focus_mode = Control.FOCUS_NONE
		var hint := _label(tr("MSG_TAP_TO_TYPE"), Term.ACCENT)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(hint)
		_connect_web_keys()
	else:
		_name_edit.grab_focus.call_deferred()


func _connect_web_keys() -> void:
	if not WebKeys.char_typed.is_connected(_on_web_char):
		WebKeys.char_typed.connect(_on_web_char)
		WebKeys.backspace.connect(_on_web_backspace)
		WebKeys.enter.connect(_on_web_enter)
	WebKeys.set_active(true)


func _disconnect_web_keys() -> void:
	if WebKeys.char_typed.is_connected(_on_web_char):
		WebKeys.char_typed.disconnect(_on_web_char)
		WebKeys.backspace.disconnect(_on_web_backspace)
		WebKeys.enter.disconnect(_on_web_enter)
	WebKeys.set_active(false)


func _on_web_char(ch: String) -> void:
	if is_instance_valid(_name_edit) and _name_edit.text.length() < Settings.NAME_MAX:
		_name_edit.text += ch
		Sfx.play("key")


func _on_web_backspace() -> void:
	if is_instance_valid(_name_edit):
		_name_edit.text = _name_edit.text.left(-1)


func _on_web_enter() -> void:
	if is_instance_valid(_name_edit):
		_create_player()


func _exit_tree() -> void:
	_disconnect_web_keys()


func _create_player() -> void:
	var name := Settings.sanitize_name(_name_edit.text)
	if name.is_empty():
		_name_error.text = tr("PROFILE_ERR_EMPTY")
		return
	if Settings.name_taken(name):
		_name_error.text = tr("PROFILE_ERR_TAKEN")
		return
	_show_new_player = false
	_disconnect_web_keys()
	Settings.create_profile(name, _new_grade)   # emits profile_changed -> rebuild
	_queue_build()


# --- Helpers ------------------------------------------------------------------

func _row(grid: GridContainer, text: String) -> OptionButton:
	var l := _label(text, Term.FG)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.fit_to_longest_item = true
	grid.add_child(opt)
	return opt


func _item(opt: OptionButton, text: String, meta: Variant, selected: bool) -> void:
	opt.add_item(text)
	opt.set_item_metadata(opt.item_count - 1, meta)
	if selected:
		opt.select(opt.item_count - 1)


func _big_button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = "[ " + text + " ]"
	b.add_theme_font_size_override("font_size", Term.sz(40))
	parent.add_child(b)
	return b


func _label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	return l


func _start() -> void:
	get_tree().change_scene_to_file(GameScene)


func _unhandled_input(event: InputEvent) -> void:
	if _show_new_player or not Settings.has_profiles():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		get_viewport().set_input_as_handled()
		_start()
