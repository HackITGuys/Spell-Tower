extends Control
## The playfield: words fall toward the base, the player types them.

const GameOverScene := "res://scenes/game_over.tscn"
const MenuScene := "res://scenes/main_menu.tscn"
const BAR_CHARS := 20
const MAX_WIDTH := 960.0
const PRACTICE_MAX := 12

var model: ScoreModel
var powers := PowerUps.new()
var targeting := Targeting.new()
var review := ReviewQueue.new()
var picker: WordPicker
var lang := "en"
var mode := "show"          ## requested mode (show | listen)
var listening := false      ## listen mode actually active (a voice exists)
var words: Array[FallingWord] = []
var practice: Array[String] = []

var _hud_line: Label
var _bar_line: Label
var _playfield: Control
var _world: Control
var _msg: Label
var _base: Label
var _prompt: Label
var _power_buttons := {}
var _say_button: Button
var _keyboard: OnScreenKeyboard
var _spawn_timer: Timer
var _pause_panel: Control
var _blink := 0.0
var _prompt_flash := 0.0
var _ending := false
var _started := false
var _web_mobile := false     ## typing through the phone's own keyboard (WebKeys)
var _web_typed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var resuming := Settings.continue_game and Settings.has_resume()
	Settings.continue_game = false
	var saved := Settings.resume_state if resuming else {}
	lang = saved.get("lang", Settings.effective_word_lang())
	mode = saved.get("mode", Settings.mode)
	if not WordBank.load_language(lang):
		lang = "en"
		WordBank.load_language(lang)
	picker = WordBank.make_picker()
	picker.review = review
	var seeds: Array[String] = []
	for w in Stats.review_candidates(lang):
		if WordBank.entries.has(w):
			seeds.append(w)
	review.seed_words(seeds)
	review.box_changed.connect(func(w, b): Stats.set_box(lang, w, b))
	Stats.data["age_band"] = Stats.age_band(Settings.age)

	model = ScoreModel.new(Settings.effective_start_level())
	if resuming:
		model.resume(int(saved["level"]), int(saved.get("floor", 1)), int(saved.get("score", 0)))
	model.level_changed.connect(_on_level_changed)
	model.game_over.connect(_on_game_over)
	model.bar_changed.connect(func(_v): _update_hud())
	powers.changed.connect(_update_powers)
	powers.earned.connect(func(kind):
		Sfx.play("earn")
		_flash_msg(tr("MSG_POWERUP") % _power_name(kind), Term.ACCENT))

	_web_mobile = Settings.input_mode() == Settings.INPUT_WEB_MOBILE
	_build_ui()
	if _web_mobile:
		WebKeys.char_typed.connect(_on_web_char)
		WebKeys.backspace.connect(_release)
		WebKeys.set_active(true)
	_update_hud()
	_update_powers()
	_save_resume()
	_flash_msg(tr("MSG_GET_READY"), Term.FG)
	# Start after a short "get ready"; this also gives web TTS voices time to load.
	get_tree().create_timer(1.0, false).timeout.connect(_start_play)


func _start_play() -> void:
	if _ending:
		return
	if mode == "listen":
		var waited := 0.0
		while Speech.supported() and not Speech.available(lang) and waited < Speech.VOICE_WAIT:
			await get_tree().create_timer(0.25, false).timeout
			waited += 0.25
		if _ending or not is_inside_tree():
			return
	listening = mode == "listen" and Speech.available(lang)
	if mode == "listen" and OS.is_debug_build():
		print("[speech] ", Speech.debug_info(lang))
	if mode == "listen" and not listening:
		_flash_msg(tr("MSG_NO_VOICE"), Term.ERROR)
	_say_button.visible = listening
	_started = true
	if _web_mobile and not _web_typed:
		_flash_msg(tr("MSG_TAP_TO_TYPE"), Term.ACCENT)
	_spawn()
	_spawn_timer.start(Tuning.spawn_interval(model.level))


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	var cap := WidthCap.new(MAX_WIDTH)
	cap.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cap)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	cap.add_child(root)

	var top := MarginContainer.new()
	for side in ["left", "right", "top"]:
		top.add_theme_constant_override("margin_" + side, 12)
	root.add_child(top)
	var top_v := VBoxContainer.new()
	top.add_child(top_v)
	var top_row := HBoxContainer.new()
	top_v.add_child(top_row)
	_hud_line = Label.new()
	_hud_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_line.clip_text = true
	top_row.add_child(_hud_line)
	var pause_btn := Button.new()
	pause_btn.text = "||"
	pause_btn.focus_mode = Control.FOCUS_NONE
	Term.calm_button(pause_btn)
	pause_btn.pressed.connect(_toggle_pause)
	top_row.add_child(pause_btn)
	_bar_line = Label.new()
	top_v.add_child(_bar_line)

	_playfield = Control.new()
	_playfield.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_playfield.clip_contents = true
	_playfield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(_playfield)
	_world = Control.new()
	_world.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield.add_child(_world)
	_msg = Label.new()
	_msg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_font_size_override("font_size", Term.sz(44))
	_msg.modulate.a = 0.0
	_playfield.add_child(_msg)
	_playfield.resized.connect(_update_base)

	_base = Label.new()
	_base.clip_text = true
	root.add_child(_base)

	var bottom := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		bottom.add_theme_constant_override("margin_" + side, 8)
	root.add_child(bottom)
	var bottom_v := VBoxContainer.new()
	bottom.add_child(bottom_v)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", Term.sz(32))
	bottom_v.add_child(_prompt)

	var power_row := HBoxContainer.new()
	power_row.alignment = BoxContainer.ALIGNMENT_CENTER
	power_row.process_mode = Node.PROCESS_MODE_PAUSABLE
	bottom_v.add_child(power_row)
	for i in PowerUps.KINDS.size():
		var kind := PowerUps.KINDS[i]
		_power_buttons[kind] = _small_button(power_row, _use_power.bind(kind))
	_say_button = _small_button(power_row, _say_current)
	_say_button.text = "TAB:" + tr("POWER_SAY")
	_say_button.visible = false

	if Settings.show_keyboard():
		_keyboard = OnScreenKeyboard.new()
		_keyboard.process_mode = Node.PROCESS_MODE_PAUSABLE
		_keyboard.custom_minimum_size.y = 260
		_keyboard.set_layout(WordBank.lang_def.get("keyboard", []))
		_keyboard.letter_pressed.connect(_handle_char)
		_keyboard.release_pressed.connect(_release)
		bottom_v.add_child(_keyboard)

	_spawn_timer = Timer.new()
	_spawn_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_spawn_timer.timeout.connect(_spawn)
	add_child(_spawn_timer)

	_build_pause_panel()


func _small_button(parent: Control, on_press: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.add_theme_font_size_override("font_size", Term.sz(22))
	Term.calm_button(b)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func _build_pause_panel() -> void:
	_pause_panel = CenterContainer.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	add_child(_pause_panel)
	var panel := PanelContainer.new()
	_pause_panel.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var title := Label.new()
	title.text = tr("GAME_PAUSED")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", Term.sz(44))
	v.add_child(title)
	var resume := Button.new()
	resume.text = tr("GAME_RESUME")
	resume.pressed.connect(_toggle_pause)
	v.add_child(resume)
	var menu := Button.new()
	menu.text = tr("GAME_TO_MENU")
	menu.pressed.connect(_to_menu)
	v.add_child(menu)


func _update_hud() -> void:
	if _hud_line == null:
		return
	_hud_line.text = "%s %d   %s %d   %s %d" % [
		tr("HUD_LEVEL"), model.level, tr("HUD_SCORE"), model.score, tr("HUD_STREAK"), model.streak]
	var filled := int(round(model.bar / Tuning.BAR_MAX * BAR_CHARS))
	_bar_line.text = "[%s%s] %3d%%" % ["█".repeat(filled), "░".repeat(BAR_CHARS - filled), int(model.bar)]
	var col := Term.FG
	if model.bar < 25.0:
		col = Term.ERROR
	elif model.bar < 50.0:
		col = Term.ACCENT
	_bar_line.add_theme_color_override("font_color", col)


func _update_powers() -> void:
	for i in PowerUps.KINDS.size():
		var kind := PowerUps.KINDS[i]
		var b: Button = _power_buttons[kind]
		b.text = "%d:%s x%d" % [i + 1, _power_name(kind), powers.count(kind)]
		b.disabled = powers.count(kind) == 0


func _power_name(kind: String) -> String:
	return tr("POWER_" + kind.to_upper())


func _update_base() -> void:
	var n := int(_playfield.size.x / Term.char_width()) + 1
	_base.text = "═".repeat(maxi(1, n))


func _update_prompt() -> void:
	var typed := ""
	if targeting.has_target():
		typed = targeting.current.text.substr(0, targeting.current.typed)
	var cursor := "█" if fmod(_blink, 1.0) < 0.55 else " "
	_prompt.text = "> " + typed + cursor
	_prompt.add_theme_color_override("font_color", Term.ERROR if _prompt_flash > 0.0 else Term.ACCENT)


func _flash_msg(text: String, col: Color) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", col)
	_msg.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_msg, "modulate:a", 0.0, 0.5)


func _float_text(at: Vector2, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_color_override("font_color", col)
	_world.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", at.y - 60.0, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(l.queue_free)


## Show the correct spelling of a missed word just above the base.
func _show_correct_spelling(word: String, x: float) -> void:
	# Solid panel so it stays readable while other words fall past it.
	var l := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Term.BG
	box.border_color = Term.ACCENT
	box.set_border_width_all(2)
	box.set_content_margin_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	l.add_theme_stylebox_override("panel", box)
	l.z_index = 10
	var text := Label.new()
	text.text = word
	text.add_theme_font_override("font", Term.font_bold)
	text.add_theme_font_size_override("font_size", Term.sz(int(Term.WORD_SIZE * 1.4)))
	text.add_theme_color_override("font_color", Term.ACCENT)
	l.add_child(text)
	_world.add_child(l)
	var w := l.get_combined_minimum_size()
	l.position = Vector2(clampf(x, 8.0, maxf(8.0, _playfield.size.x - w.x - 8.0)), _playfield.size.y - w.y - 6.0)
	l.pivot_offset = w / 2.0
	l.scale = Vector2(0.6, 0.6)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(Tuning.MISS_FLASH_TIME)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func _shake(strength := 14.0) -> void:
	var tw := create_tween()
	for i in 8:
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - i / 8.0)
		tw.tween_property(_world, "position", off, 0.03)
	tw.tween_property(_world, "position", Vector2.ZERO, 0.03)


# --- Loop -------------------------------------------------------------------

func _process(delta: float) -> void:
	_blink += delta
	_prompt_flash = maxf(0.0, _prompt_flash - delta)
	_update_prompt()
	if get_tree().paused or _ending:
		return
	var limit := _playfield.size.y
	for w in words.duplicate():
		if w.alive and w.position.y + w.size.y >= limit:
			_on_missed(w)


func _max_words() -> int:
	var m := Tuning.max_words(model.level)
	return mini(m, Tuning.LISTEN_MAX_WORDS) if listening else m


func _spawn() -> void:
	if _ending or not _started:
		return
	_spawn_timer.wait_time = Tuning.spawn_interval(model.level) * (Tuning.LISTEN_FALL_FACTOR if listening else 1.0)
	if _alive_words().size() >= _max_words():
		return
	var txt := picker.pick(model.level, _blocked_initials())
	if txt == "":
		return
	var fw := FallingWord.new()
	var fall_time := Tuning.fall_time(model.level, txt.length())
	if listening:
		fall_time *= Tuning.LISTEN_FALL_FACTOR
	fw.setup(txt, WordBank.effective_difficulty(txt), _playfield.size.y / fall_time,
			Term.font, Term.sz(Term.WORD_SIZE), listening)
	fw.position = Vector2(_free_x(fw.size.x), -fw.size.y)
	_world.add_child(fw)
	words.append(fw)
	# Listen mode: a word is spoken when the player locks onto it (first
	# letter typed), not when it appears.


## Random x that doesn't overlap words still near the top.
func _free_x(width: float) -> float:
	var max_x := maxf(8.0, _playfield.size.x - width - 8.0)
	var best := randf_range(8.0, max_x)
	for attempt in 8:
		var x := randf_range(8.0, max_x)
		var ok := true
		for w in _alive_words():
			if w.position.y < w.size.y * 3.0 and x < w.position.x + w.size.x + 16.0 \
					and w.position.x < x + width + 16.0:
				ok = false
				break
		if ok:
			return x
		best = x
	return best


func _alive_words() -> Array[FallingWord]:
	var out: Array[FallingWord] = []
	for w in words:
		if is_instance_valid(w) and w.alive:
			out.append(w)
	return out


func _blocked_initials() -> Dictionary:
	var b := {}
	for w in _alive_words():
		b[w.text[0]] = true
	return b


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	get_viewport().set_input_as_handled()
	if get_tree().paused:
		if k.keycode == KEY_ESCAPE or k.keycode == KEY_ENTER:
			_toggle_pause()
		return
	match k.keycode:
		KEY_ESCAPE:
			if targeting.has_target():
				_release()
			else:
				_toggle_pause()
		KEY_BACKSPACE:
			_release()
		KEY_TAB:
			_say_current()
		KEY_1, KEY_KP_1:
			_use_power(PowerUps.AUTOSPELL)
		KEY_2, KEY_KP_2:
			_use_power(PowerUps.CLEAR)
		KEY_3, KEY_KP_3:
			_use_power(PowerUps.SHAKE)
		_:
			if k.unicode > 0 and not _web_mobile:
				_handle_char(String.chr(k.unicode))


func _handle_char(raw: String) -> void:
	if _ending or get_tree().paused:
		return
	var ch := WordBank.norm.normalize_char(raw)
	if ch == "":
		return
	var r := targeting.handle(ch, _alive_words())
	match r:
		Targeting.Result.NO_MATCH:
			Sfx.play("key")
			_prompt_flash = 0.2
		Targeting.Result.LOCKED:
			Sfx.play("lock")
			if listening:
				Speech.say(targeting.current.text, lang, true)
		Targeting.Result.ADVANCED:
			Sfx.play("key")
		Targeting.Result.WRONG:
			Sfx.play("wrong")
			var w: FallingWord = targeting.current
			w.flash_wrong()
			Stats.record_wrong_letter(lang, w.text)
			model.on_wrong_letter()
			_prompt_flash = 0.25
		Targeting.Result.COMPLETED:
			_on_completed(targeting.finish())
	_update_prompt()


func _on_web_char(ch: String) -> void:
	_web_typed = true
	_handle_char(ch)


func _exit_tree() -> void:
	if _web_mobile:
		WebKeys.set_active(false)
		WebKeys.char_typed.disconnect(_on_web_char)
		WebKeys.backspace.disconnect(_release)


func _release() -> void:
	targeting.release()
	_update_prompt()


## Listen mode: say the targeted word again (or the nearest one, before locking).
func _say_current() -> void:
	if not listening or _ending:
		return
	var w: FallingWord = targeting.current if targeting.has_target() else Targeting.nearest(_alive_words())
	if w != null:
		Speech.say(w.text, lang, true)


func _toggle_pause() -> void:
	if _ending:
		return
	var p := not get_tree().paused
	get_tree().paused = p
	_pause_panel.visible = p
	if p:
		Speech.stop()
	if _web_mobile:
		WebKeys.set_active(not p)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _ending and is_inside_tree() \
			and not get_tree().paused:
		_toggle_pause()


# --- Events -----------------------------------------------------------------

func _on_completed(w: FallingWord) -> void:
	Sfx.play("hit")
	var pts := model.on_word_completed(w.d, w.text.length(), w.had_mistakes)
	Stats.record_completed(lang, w.text, w.had_mistakes)
	if w.had_mistakes:
		review.failed(w.text)
		_add_practice(w.text)
	else:
		review.succeeded(w.text)
		powers.on_correct_word()
	_float_text(w.position, "+%d" % pts, Term.ACCENT)
	_remove(w)
	w.explode()
	_update_hud()


func _on_missed(w: FallingWord) -> void:
	if targeting.current == w:
		targeting.current = null
	Sfx.play("miss")
	Stats.record_missed(lang, w.text)
	review.failed(w.text)
	_add_practice(w.text)
	_show_correct_spelling(w.text, w.position.x)
	if listening:
		Speech.say(w.text, lang, true)
	var p := model.on_word_missed()
	_float_text(Vector2(w.position.x, _playfield.size.y - 110.0), "-%d" % int(round(p)), Term.ERROR)
	_remove(w)
	w.crash()
	_shake(8.0)
	_base.add_theme_color_override("font_color", Term.ERROR)
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(_base):
			_base.remove_theme_color_override("font_color"))
	_update_hud()


func _add_practice(word: String) -> void:
	if not practice.has(word) and practice.size() < PRACTICE_MAX:
		practice.append(word)


func _remove(w: FallingWord) -> void:
	words.erase(w)


func _on_level_changed(new_level: int, delta: int) -> void:
	if delta > 0:
		Sfx.play("level_up")
		_flash_msg(tr("MSG_LEVEL_UP"), Term.FG)
		powers.on_level_up()
	else:
		Sfx.play("level_down")
		_flash_msg(tr("MSG_LEVEL_DOWN"), Term.ERROR)
	_spawn_timer.wait_time = Tuning.spawn_interval(new_level)
	_save_resume()
	_update_hud()


## The "continue" save: the start of the current level.
func _save_resume() -> void:
	Settings.set_resume({
		"lang": lang,
		"mode": mode,
		"level": model.level,
		"floor": model.floor_level,
		"score": model.score,
	})


func _on_game_over() -> void:
	if _ending:
		return
	_ending = true
	_spawn_timer.stop()
	Speech.stop()
	for w in _alive_words():
		w.crash()
	words.clear()
	_flash_msg(tr("GAMEOVER_TITLE"), Term.ERROR)
	Stats.save_data()
	Settings.clear_resume()
	var new_best := Settings.record_score(lang, model.score)
	Settings.last_result = {
		"lang": lang,
		"score": model.score,
		"best": Settings.best_for(lang),
		"high_score": Settings.high_score(),
		"new_best": new_best,
		"level": model.max_level_reached,
		"words": model.words_done,
		"missed": model.words_missed,
		"accuracy": int(round(model.overall_accuracy() * 100.0)),
		"practice": practice.duplicate(),
	}
	get_tree().create_timer(1.5).timeout.connect(func():
		get_tree().change_scene_to_file(GameOverScene))


func _to_menu() -> void:
	get_tree().paused = false
	Speech.stop()
	Stats.save_data()
	Settings.record_score(lang, model.score)
	get_tree().change_scene_to_file(MenuScene)


# --- Power-ups ----------------------------------------------------------------

func _use_power(kind: String) -> void:
	if _ending or get_tree().paused or powers.count(kind) == 0:
		return
	var alive := _alive_words()
	if alive.is_empty():
		return
	Sfx.play("power")
	match kind:
		PowerUps.AUTOSPELL:
			var w: FallingWord = targeting.current if targeting.has_target() else Targeting.nearest(alive)
			if w == null:
				return
			powers.use(kind)
			if targeting.current == w:
				targeting.finish()
			var pts := model.on_word_cleared(w.d, w.text.length(), 1.0)
			_float_text(w.position, "+%d" % pts, Term.ACCENT)
			_remove(w)
			w.explode()
		PowerUps.CLEAR:
			powers.use(kind)
			targeting.current = null
			var total := 0
			for w in alive:
				total += model.on_word_cleared(w.d, w.text.length(), Tuning.CLEAR_POINTS_FACTOR)
				_remove(w)
				w.explode()
			_float_text(Vector2(_playfield.size.x / 2.0 - 40.0, _playfield.size.y / 2.0), "+%d" % total, Term.ACCENT)
			_shake(18.0)
		PowerUps.SHAKE:
			powers.use(kind)
			targeting.release()
			var blocked := {}
			for w in alive:
				var txt := picker.pick(model.level, blocked)
				if txt == "":
					txt = w.text
				blocked[txt[0]] = true
				w.retext(txt, WordBank.effective_difficulty(txt))
				w.position.x = clampf(w.position.x, 8.0, maxf(8.0, _playfield.size.x - w.size.x - 8.0))
			_shake(10.0)
	_update_hud()
	_update_prompt()
