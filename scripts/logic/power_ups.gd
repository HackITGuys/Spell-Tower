class_name PowerUps
extends RefCounted
## Power-up charges:
##   AUTOSPELL +1 every AUTOSPELL_EVERY correctly spelled words,
##   SHAKE     replaces every SHAKE_EVERY_NTH of those AUTOSPELL rewards,
##   CLEAR     +1 for every level cleared (level-up).

signal changed
signal earned(kind: String)

const AUTOSPELL := "autospell"
const CLEAR := "clear"
const SHAKE := "shake"
const KINDS: Array[String] = [AUTOSPELL, CLEAR, SHAKE]

var charges := {AUTOSPELL: 1, CLEAR: 0, SHAKE: 1}
## Correctly spelled words this game (cumulative, mistakes don't reset it).
var correct_words := 0
## How many AUTOSPELL milestones have been reached (every Nth gives SHAKE).
var milestones := 0


func count(kind: String) -> int:
	return charges.get(kind, 0)


func grant(kind: String) -> bool:
	if charges.get(kind, 0) >= Tuning.POWERUP_MAX:
		return false
	charges[kind] += 1
	earned.emit(kind)
	changed.emit()
	return true


func use(kind: String) -> bool:
	if charges.get(kind, 0) <= 0:
		return false
	charges[kind] -= 1
	changed.emit()
	return true


func on_correct_word() -> void:
	correct_words += 1
	if correct_words % Tuning.AUTOSPELL_EVERY != 0:
		return
	milestones += 1
	if milestones % Tuning.SHAKE_EVERY_NTH == 0:
		grant(SHAKE)
	else:
		grant(AUTOSPELL)


func on_level_up() -> void:
	grant(CLEAR)
