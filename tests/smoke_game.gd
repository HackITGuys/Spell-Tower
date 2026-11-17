extends SceneTree
## Scripted play-through of the real game scene (autoloads, spawning, input,
## power-ups, level changes, game over). Run with a fixed timestep:
##   godot --headless --path . --fixed-fps 60 --script res://tests/smoke_game.gd [-- nb [0]]
## User args: UI + word language (default en), optional start grade (default 2;
## 0 = pre-school).

const PLAY_FRAMES := 60 * 90  # 90 s typing perfectly
const IDLE_FRAMES := 60 * 480  # then stop typing until game over (falling back through
# every stage climbed takes a few minutes of game time)

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
var _lang := "en"
var _grade := 2  # enough nb words with æ/ø/å in the first pools
var _peak_score := 0


func _initialize() -> void:
	var settings := root.get_node("Settings")
	settings.persist = false
	root.get_node("Stats").persist = false
	settings.best = {}
	settings.force_input_mode = "osk"  # exercise the on-screen keyboard build
	var args := OS.get_cmdline_user_args()
	_lang = args[0] if args.size() > 0 else "en"
	_grade = int(args[1]) if args.size() > 1 else _grade
	settings.word_lang = _lang
	settings.ui_locale = _lang  # Locale's _ready re-applies this after _initialize
	settings.grade = _grade
	root.get_node("Locale").apply(_lang)
	if _active_locale() != _lang:
		_fail("UI locale %s not applied (got %s)" % [_lang, _active_locale()])
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
		if _active_locale() != _lang:
			_fail("UI locale %s not active in the game" % _lang)
		if _start_level != Tuning.first_level_of_grade(_grade):
			_fail(
				"start grade %d should start at its first stage (got %s)" % [_grade, Tuning.level_label(_start_level)]
			)
		_game.model.level_changed.connect(_on_level_changed)
		_game.model.game_over.connect(func(): _game_over_seen = true)
		return false

	if not is_instance_valid(_game) or not ("model" in _game):
		return _finish()
	var m = _game.model
	_max_level = maxi(_max_level, m.level)
	_peak_score = maxi(_peak_score, m.score)

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


func _on_level_changed(_level: int, delta: int) -> void:
	if delta < 0:
		_saw_level_down = true


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
	print(
		(
			"start %s, max %s, typed %d words, level-down seen: %s"
			% [Tuning.level_label(_start_level), Tuning.level_label(_max_level), _typed_words, _saw_level_down]
		)
	)
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
	if r.is_empty():
		_fail("no result recorded")
	if _peak_score <= 0:
		_fail("never scored any points")
	if (r.get("practice", []) as Array).is_empty():
		_fail("practice list empty despite misses")
	if int(r.get("high_score", 0)) < int(r.get("score", 0)):
		_fail("high score not updated")
	print("practice: %s" % [r.get("practice", [])])
	print("smoke[%s grade %d]: %s" % [_lang, _grade, "OK" if _failures == 0 else "%d failures" % _failures])
	quit(1 if _failures > 0 else 0)
	return true


func _active_locale() -> String:
	return TranslationServer.get_locale().split("_")[0]


func _game_lang() -> String:
	return str(root.get_node("Settings").last_result.get("lang", ""))
