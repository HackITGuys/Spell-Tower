class_name Tuning
extends RefCounted
## All gameplay constants in one place. Tweak here, not in the scenes.

# --- Grades and stages -----------------------------------------------------
## A grade is a word list: 0 = pre-school (letters and first words), 1..10 =
## school grade 1..10. A word's tier `d` in the word files is its grade.
## Each grade is played as STAGES_PER_GRADE stages; beating the last stage moves
## the player up a grade. `level` is the running count over all stages:
## level 1 = pre-school stage 1, level 6 = grade 1 stage 1, ... MAX_LEVEL = grade 10 stage 5.
const MIN_GRADE := 0
const MAX_GRADE := 10
const STAGES_PER_GRADE := 5
const MAX_LEVEL := (MAX_GRADE - MIN_GRADE + 1) * STAGES_PER_GRADE
## Start grade of a new player (any grade can be picked in the menu).
const DEFAULT_GRADE := 1
## How many stages below the start you may fall before it's game over.
const LEVEL_DOWN_ALLOWANCE := 2
## Which grade a word comes from: the current grade, the grade just below, or
## any grade below that (each equally likely). Near the bottom, the share of a
## bucket with no grades in it goes to the current grade.
const WEIGHT_CURRENT_GRADE := 0.75
const WEIGHT_GRADE_BELOW := 0.15
const WEIGHT_LOWER_GRADES := 0.10
## Word pool of the current grade: each game picks a random POOL_START words of
## the grade for stage 1, and every later stage adds POOL_GROWTH more (capped at
## the grade's size). Lower grades always use all their words.
const POOL_START := 20
const POOL_GROWTH := 10
## Avoid repeating any of the last N words (on top of the per-grade shuffle bag).
const RECENT_MEMORY := 15

# --- Review (failed words come back) -------------------------------------
## Spawns until a failed word returns, per Leitner box. After the last box the
## word "graduates" and stops being reviewed.
const REVIEW_GAPS: Array[int] = [4, 10, 25]
## Failed words carried over from earlier games, seeded into a new game.
const REVIEW_SEED_LIMIT := 12
const REVIEW_SEED_START := 3
const REVIEW_SEED_SPREAD := 4

# --- Feedback ------------------------------------------------------------
## Seconds the correct spelling is shown at the base after a miss.
const MISS_FLASH_TIME := 1.6

# --- Bar ------------------------------------------------------------------
const BAR_MAX := 100.0
const BAR_START := 50.0
const BAR_RESET := 50.0
## Bar gain for an at-level word. ~9 clean words to level up from 50.
const BAR_GAIN := 6.0
const BAR_GAIN_MIN_FACTOR := 0.5
const BAR_GAIN_MAX_FACTOR := 2.0

# --- Penalties --------------------------------------------------------------
## Word reached the base: BASE * level_mult * (0.5 + accuracy) * streak_mult
const MISS_BASE_PENALTY := 10.0
const MISS_LEVEL_STEP := 0.05     # +5% per grade above 1
const MISS_STREAK_STEP := 0.05    # +5% per streak word ...
const MISS_STREAK_CAP := 10       # ... up to 10 words (= +50%)
## Wrong letter costs this fraction of a miss.
const WRONG_LETTER_FACTOR := 0.25
## Rolling accuracy window (word outcomes: clean 1.0, with mistakes 0.5, missed 0.0).
const ACCURACY_WINDOW := 20
const ACCURACY_DEFAULT := 0.5

# --- Score ----------------------------------------------------------------
const POINTS_PER_VALUE := 10.0
const COMBO_STEP := 0.1           # +10% per streak word
const COMBO_CAP := 2.0            # max x3 total
const CLEAR_POINTS_FACTOR := 0.5

# --- Spawning / movement ------------------------------------------------
## Seconds a 4-letter word needs to fall the whole playfield at grade 1, stage 1
## (v0.1 used 14.0; /0.9 makes the default drop speed 0.9x). Pre-school is slower.
const FALL_TIME_BASE := 14.0 / 0.9
const FALL_TIME_DECAY := 0.92     # per grade
## Speed-up per stage within a grade: +4% per stage (stage 5 = 1.16x stage 1).
## The next grade starts slower again (1.087x the previous grade's stage 1), and
## dropping back into the grade below lands on its fastest stage.
const FALL_STAGE_SPEEDUP := 0.04
const FALL_TIME_MIN := 4.5
const FALL_LENGTH_FACTOR := 0.05  # +5% fall time per letter beyond 4
const SPAWN_INTERVAL_BASE := 2.8
const SPAWN_INTERVAL_DECAY := 0.93   # per grade
const SPAWN_INTERVAL_MIN := 0.8
const MAX_WORDS_BASE := 3
const MAX_WORDS_CAP := 7

# --- Power-ups ----------------------------------------------------------
## +1 AUTOSPELL per this many correctly spelled words (cumulative, not a streak).
const AUTOSPELL_EVERY := 10
## Every Nth AUTOSPELL reward is a SHAKE instead.
const SHAKE_EVERY_NTH := 3
## CLEAR: +1 per level cleared (see PowerUps.on_level_up).
const POWERUP_MAX := 3


## Weight of a word's difficulty in points and bar gain (pre-school words = 0.5).
static func difficulty_weight(d: int) -> float:
	return maxf(0.5, float(d))


static func word_value(d: int, length: int) -> float:
	return difficulty_weight(d) * (1.0 + float(length) / 6.0)


static func grade_for_level(level: int) -> int:
	return clampi((level - 1) / STAGES_PER_GRADE + MIN_GRADE, MIN_GRADE, MAX_GRADE)


## 1..STAGES_PER_GRADE
static func stage_for_level(level: int) -> int:
	return (clampi(level, 1, MAX_LEVEL) - 1) % STAGES_PER_GRADE + 1


static func first_level_of_grade(grade: int) -> int:
	return (clampi(grade, MIN_GRADE, MAX_GRADE) - MIN_GRADE) * STAGES_PER_GRADE + 1


## "Pre-school", "Grade 3" (translated).
static func grade_name(grade: int) -> String:
	if grade <= MIN_GRADE:
		return String(TranslationServer.translate("GRADE_PRESCHOOL"))
	return String(TranslationServer.translate("GRADE_N")) % grade


## "Grade 3 · 2/5" = grade 3, stage 2 of 5.
static func level_label(level: int) -> String:
	return "%s · %d/%d" % [grade_name(grade_for_level(level)), stage_for_level(level), STAGES_PER_GRADE]


## Words of the current grade in play at a stage (before capping at the grade's size).
static func pool_size(stage: int) -> int:
	return POOL_START + POOL_GROWTH * (clampi(stage, 1, STAGES_PER_GRADE) - 1)


static func fall_time(level: int, length: int) -> float:
	var grade := grade_for_level(level)
	var stage := stage_for_level(level)
	var t := FALL_TIME_BASE * pow(FALL_TIME_DECAY, grade - 1) / (1.0 + FALL_STAGE_SPEEDUP * (stage - 1))
	t = maxf(FALL_TIME_MIN, t)
	return t * (1.0 + FALL_LENGTH_FACTOR * maxf(0.0, float(length - 4)))


static func spawn_interval(level: int) -> float:
	var grade := grade_for_level(level)
	return maxf(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_BASE * pow(SPAWN_INTERVAL_DECAY, grade - 1))


static func max_words(level: int) -> int:
	return mini(MAX_WORDS_CAP, MAX_WORDS_BASE + maxi(0, grade_for_level(level) - 1) / 2)
