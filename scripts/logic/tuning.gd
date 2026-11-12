class_name Tuning
extends RefCounted
## All gameplay constants in one place. Tweak here, not in the scenes.

# --- Levels / tiers -------------------------------------------------------
const MIN_TIER := 1
const MAX_TIER := 10
## How many levels below the start level you may fall before it's game over.
const LEVEL_DOWN_ALLOWANCE := 2
## Weight of picking tier (level + offset).
const TIER_WEIGHTS := {0: 0.60, -1: 0.25, 1: 0.15}
## Avoid repeating any of the last N words (on top of the per-tier shuffle bag).
const RECENT_MEMORY := 15

# --- Review (failed words come back) -------------------------------------
## Spawns until a failed word returns, per Leitner box. After the last box the
## word "graduates" and stops being reviewed.
const REVIEW_GAPS: Array[int] = [4, 10, 25]
## Failed words carried over from earlier games, seeded into a new game.
const REVIEW_SEED_LIMIT := 12
const REVIEW_SEED_START := 3
const REVIEW_SEED_SPREAD := 4

# --- Listen (dictation) mode --------------------------------------------
const LISTEN_FALL_FACTOR := 1.6   # words fall this much slower
const LISTEN_MAX_WORDS := 3       # cap on simultaneous words

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
const MISS_LEVEL_STEP := 0.05     # +5% per level above 1
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
## Seconds a 4-letter word needs to fall the whole playfield at level 1.
const FALL_TIME_BASE := 14.0
const FALL_TIME_DECAY := 0.92     # per level
const FALL_TIME_MIN := 4.5
const FALL_LENGTH_FACTOR := 0.05  # +5% fall time per letter beyond 4
const SPAWN_INTERVAL_BASE := 2.8
const SPAWN_INTERVAL_DECAY := 0.93
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


static func word_value(d: int, length: int) -> float:
	return float(d) * (1.0 + float(length) / 6.0)


static func tier_for_level(level: int) -> int:
	return clampi(level, MIN_TIER, MAX_TIER)


static func start_level_for_age(age: int) -> int:
	return clampi(age - 4, MIN_TIER, MAX_TIER)


static func fall_time(level: int, length: int) -> float:
	var t := maxf(FALL_TIME_MIN, FALL_TIME_BASE * pow(FALL_TIME_DECAY, level - 1))
	return t * (1.0 + FALL_LENGTH_FACTOR * maxf(0.0, float(length - 4)))


static func spawn_interval(level: int) -> float:
	return maxf(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_BASE * pow(SPAWN_INTERVAL_DECAY, level - 1))


static func max_words(level: int) -> int:
	return mini(MAX_WORDS_CAP, MAX_WORDS_BASE + (level - 1) / 2)
