class_name ScoreModel
extends RefCounted
## Bar, score, streak, accuracy and level progression. No nodes, no timing.

signal level_changed(new_level: int, delta: int)
signal game_over
signal bar_changed(value: float)

var level: int
var start_level: int
var floor_level: int
var max_level_reached: int
var bar: float = Tuning.BAR_START
var score: int = 0
var streak: int = 0
var best_streak: int = 0
var words_done: int = 0
var words_missed: int = 0
var letters_wrong: int = 0
var is_over := false
var _outcomes: Array[float] = []


func _init(p_start_level: int) -> void:
	start_level = clampi(p_start_level, 1, 99)
	level = start_level
	max_level_reached = level
	floor_level = maxi(1, start_level - Tuning.LEVEL_DOWN_ALLOWANCE)


## Continue a saved game from the start of a level.
func resume(p_level: int, p_floor: int, p_score: int) -> void:
	level = maxi(1, p_level)
	floor_level = clampi(p_floor, 1, level)
	score = maxi(0, p_score)
	max_level_reached = level
	bar = Tuning.BAR_START


func accuracy() -> float:
	if _outcomes.is_empty():
		return Tuning.ACCURACY_DEFAULT
	var s := 0.0
	for o in _outcomes:
		s += o
	return s / _outcomes.size()


## Long-run accuracy for the game-over screen (0..1).
func overall_accuracy() -> float:
	var total := words_done + words_missed
	if total == 0:
		return 0.0
	return float(words_done) / float(total)


func combo_multiplier() -> float:
	return 1.0 + minf(Tuning.COMBO_CAP, streak * Tuning.COMBO_STEP)


func bar_gain_for(d: int) -> float:
	var factor := clampf(float(d) / float(Tuning.tier_for_level(level)),
			Tuning.BAR_GAIN_MIN_FACTOR, Tuning.BAR_GAIN_MAX_FACTOR)
	return Tuning.BAR_GAIN * factor


func miss_penalty() -> float:
	var level_mult := 1.0 + Tuning.MISS_LEVEL_STEP * (level - 1)
	var streak_mult := 1.0 + Tuning.MISS_STREAK_STEP * mini(streak, Tuning.MISS_STREAK_CAP)
	return Tuning.MISS_BASE_PENALTY * level_mult * (0.5 + accuracy()) * streak_mult


func wrong_letter_penalty() -> float:
	return miss_penalty() * Tuning.WRONG_LETTER_FACTOR


## Player finished typing a word. Returns points awarded.
func on_word_completed(d: int, length: int, had_mistakes: bool) -> int:
	if is_over:
		return 0
	words_done += 1
	if had_mistakes:
		_push_outcome(0.5)
	else:
		_push_outcome(1.0)
		streak += 1
		best_streak = maxi(best_streak, streak)
	var pts := int(round(Tuning.word_value(d, length) * Tuning.POINTS_PER_VALUE * combo_multiplier()))
	score += pts
	_change_bar(bar_gain_for(d))
	return pts


## Word removed by a power-up (CLEAR / AUTOSPELL). No streak, no accuracy change.
func on_word_cleared(d: int, length: int, factor: float) -> int:
	if is_over:
		return 0
	var pts := int(round(Tuning.word_value(d, length) * Tuning.POINTS_PER_VALUE * factor))
	score += pts
	_change_bar(bar_gain_for(d) * factor)
	return pts


## Word reached the base. Returns the bar penalty applied.
func on_word_missed() -> float:
	if is_over:
		return 0.0
	var p := miss_penalty()
	words_missed += 1
	_push_outcome(0.0)
	streak = 0
	score = maxi(0, score - int(round(p * Tuning.POINTS_PER_VALUE * 0.5)))
	_change_bar(-p)
	return p


func on_wrong_letter() -> float:
	if is_over:
		return 0.0
	var p := wrong_letter_penalty()
	letters_wrong += 1
	streak = 0
	_change_bar(-p)
	return p


func _push_outcome(v: float) -> void:
	_outcomes.append(v)
	while _outcomes.size() > Tuning.ACCURACY_WINDOW:
		_outcomes.pop_front()


func _change_bar(delta: float) -> void:
	bar += delta
	if bar >= Tuning.BAR_MAX:
		level += 1
		max_level_reached = maxi(max_level_reached, level)
		bar = Tuning.BAR_RESET
		level_changed.emit(level, 1)
	elif bar <= 0.0:
		if level <= floor_level:
			bar = 0.0
			is_over = true
			bar_changed.emit(bar)
			game_over.emit()
			return
		level -= 1
		bar = Tuning.BAR_RESET
		level_changed.emit(level, -1)
	bar_changed.emit(bar)
