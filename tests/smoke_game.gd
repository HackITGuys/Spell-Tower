extends SceneTree
## Scripted play-through of the real game scene (autoloads, spawning, input,
## power-ups, level changes, game over). Run with a fixed timestep:
##   godot --headless --path . --fixed-fps 60 --script res://tests/smoke_game.gd [-- nb [listen]]
## User args: UI + word language (default en), optional 'listen' for dictation mode.
## Headless has no TTS voice, so 'listen' exercises the no-voice fallback.

const PLAY_FRAMES := 60 * 90    # 90 s typing perfectly
const IDLE_FRAMES := 60 * 240   # then stop typing until game over

var _frame := 0
var _game: Node
var _failures := 0
var _max_level := 0
var _start_level := 0
var _saw_level_down := false
var _game_over_seen := false
var _typed_words := 0
var _non_ascii_words := 0
var _game_ref: Node
var _game_listening := false
var _lang := "en"
var _mode := "show"
var _resume_seen := false
var _continue := false


func _initialize() -> void:
	var settings := root.get_node("Settings")
	settings.persist = false
	root.get_node("Stats").persist = false
	settings.best = {}
	settings.age = 6
	settings.start_level = 0
	settings.force_input_mode = "osk"   # exercise the on-screen keyboard build
	var args := OS.get_cmdline_user_args()
	_lang = args[0] if args.size() > 0 else "en"
	_mode = args[1] if args.size() > 1 else "show"
	settings.word_lang = _lang
	settings.mode = _mode
	_continue = args.size() > 2 and args[2] == "continue"
	if _continue:
		settings.set_resume({"lang": _lang, "mode": _mode, "level": 5, "floor": 3, "score": 777})
		settings.continue_game = true
	root.get_node("Locale").apply(_lang)
	var expected_quit := "AVSLUTT" if _lang == "nb" else "QUIT"
	if TranslationServer.translate("MENU_QUIT") != expected_quit:
		_fail("UI locale %s not applied (got %s)" % [_lang, TranslationServer.translate("MENU_QUIT")])
	change_scene_to_file("res://scenes/game.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _game == null:
		_game = current_scene
		if _game == null or not ("model" in _game):
			_game = null
			return false
		_start_level = _game.model.level
		_game_ref = _game
		if _continue:
			if _game.model.level != 5 or _game.model.score != 777 or _game.model.floor_level != 3:
				_fail("continue didn't restore level/score/floor (%d/%d/%d)" % [_game.model.level, _game.model.score, _game.model.floor_level])
			if root.get_node("Settings").continue_game:
				_fail("continue flag not consumed")
		_game.model.level_changed.connect(func(_l, d): if d < 0: _saw_level_down = true)
		_game.model.game_over.connect(func(): _game_over_seen = true)
		return false

	if not is_instance_valid(_game) or not ("model" in _game):
		return _finish()
	var m = _game.model
	_max_level = maxi(_max_level, m.level)
	var settings := root.get_node("Settings")
	if settings.has_resume() and int(settings.resume_state["level"]) == m.level:
		_resume_seen = true

	_game_listening = _game_listening or _game.listening
	if _frame < PLAY_FRAMES and _frame % 6 == 0:
		_type_one_letter()
	if _frame == PLAY_FRAMES / 2:
		_game._use_power("autospell")
		_game._use_power("shake")
	if _game_over_seen and _frame > PLAY_FRAMES:
		return _finish()
	if _frame > PLAY_FRAMES + IDLE_FRAMES:
		_fail("no game over after idling")
		return _finish()
	return false


func _type_one_letter() -> void:
	var t = _game.targeting
	if t.has_target():
		var w = t.current
		var word: String = w.text
		_game._handle_char(w.text[w.typed].to_upper())
		if not t.has_target():
			_count(word)
		return
	var alive: Array = _game._alive_words()
	if alive.is_empty():
		return
	var w = alive[0]
	_game._handle_char(w.text[0].to_upper())  # also exercises normalisation
	if not t.has_target():
		_count(w.text)


func _count(word: String) -> void:
	_typed_words += 1
	for i in word.length():
		if word.unicode_at(i) > 127:
			_non_ascii_words += 1
			return


func _fail(msg: String) -> void:
	_failures += 1
	printerr("  FAIL " + msg)


func _finish() -> bool:
	var settings := root.get_node("Settings")
	var r: Dictionary = settings.last_result
	print("start level %d, max level %d, typed %d words, level-down seen: %s" % [_start_level, _max_level, _typed_words, _saw_level_down])
	print("result: %s" % r)
	if _game_lang() != _lang:
		_fail("word language %s not used (got %s)" % [_lang, _game_lang()])
	if _lang == "nb" and _non_ascii_words == 0:
		_fail("no words with æ/ø/å were typed")
	print("non-ascii words typed: %d" % _non_ascii_words)
	if _typed_words < 20:
		_fail("typed too few words (%d)" % _typed_words)
	if _max_level <= _start_level:
		_fail("never levelled up")
	if not _game_over_seen:
		_fail("game over not reached")
	if not _saw_level_down:
		_fail("never levelled down before game over")
	if r.is_empty() or int(r.get("score", 0)) <= 0:
		_fail("no result recorded")
	if not _resume_seen:
		_fail("resume save never matched the current level")
	if settings.has_resume():
		_fail("resume not cleared on game over")
	if (r.get("practice", []) as Array).is_empty():
		_fail("practice list empty despite misses")
	if int(r.get("high_score", 0)) < int(r.get("score", 0)):
		_fail("high score not updated")
	if _mode == "listen" and _game_listening:
		_fail("listen mode active without a voice")
	print("practice: %s" % [r.get("practice", [])])
	print("smoke[%s %s]: %s" % [_lang, _mode, "OK" if _failures == 0 else "%d failures" % _failures])
	quit(1 if _failures > 0 else 0)
	return true


func _game_lang() -> String:
	return str(root.get_node("Settings").last_result.get("lang", ""))

