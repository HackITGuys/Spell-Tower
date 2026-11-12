extends Control

const GameScene := "res://scenes/game.tscn"
const MenuScene := "res://scenes/main_menu.tscn"
const MAX_WIDTH := 760.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var r: Dictionary = Settings.last_result
	# Full-width scroll area (scrollbar at the screen edge), capped content inside.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var cap := WidthCap.new(MAX_WIDTH)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(cap)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	cap.add_child(v)

	_add(v, tr("GAMEOVER_TITLE"), Term.ERROR, Term.sz(Term.TITLE_SIZE))
	if r.get("new_best", false):
		_add(v, tr("GAMEOVER_NEW_BEST"), Term.ACCENT, Term.sz(34))
	_add(v, tr("GAMEOVER_SCORE") % r.get("score", 0), Term.FG)
	_add(v, tr("GAMEOVER_BEST") % r.get("best", 0), Term.ACCENT)
	_add(v, tr("GAMEOVER_ALL_TIME") % r.get("high_score", 0), Term.ACCENT)
	_add(v, tr("GAMEOVER_LEVEL") % r.get("level", 1), Term.FG)
	_add(v, tr("GAMEOVER_WORDS") % [r.get("words", 0), r.get("missed", 0)], Term.FG)
	_add(v, tr("GAMEOVER_ACCURACY") % r.get("accuracy", 0), Term.FG)

	var practice: Array = r.get("practice", [])
	if not practice.is_empty():
		_add(v, "", Term.FG)
		_add(v, tr("GAMEOVER_PRACTISE"), Term.DIM)
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 20)
		v.add_child(flow)
		for w: String in practice:
			var l := Label.new()
			l.text = w
			l.add_theme_font_override("font", Term.font_bold)
			l.add_theme_font_size_override("font_size", Term.sz(Term.WORD_SIZE))
			l.add_theme_color_override("font_color", Term.ACCENT)
			flow.add_child(l)
		_add(v, "", Term.FG)

	var retry := Button.new()
	retry.text = "[ " + tr("GAMEOVER_RETRY") + " ]"
	retry.add_theme_font_size_override("font_size", Term.sz(36))
	retry.pressed.connect(func(): get_tree().change_scene_to_file(GameScene))
	v.add_child(retry)
	var menu := Button.new()
	menu.text = tr("GAMEOVER_MENU")
	menu.pressed.connect(func(): get_tree().change_scene_to_file(MenuScene))
	v.add_child(menu)
	retry.grab_focus.call_deferred()


func _add(parent: Control, text: String, col: Color, size := -1) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size if size > 0 else Term.sz(Term.FONT_SIZE))
	parent.add_child(l)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(MenuScene)
