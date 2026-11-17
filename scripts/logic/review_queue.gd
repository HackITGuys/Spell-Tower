class_name ReviewQueue
extends RefCounted
## Failed words come back (simple Leitner boxes, counted in word spawns).
##
##   failed(w)     -> box 0, due again after REVIEW_GAPS[0] spawns
##   succeeded(w)  -> next box, longer gap; past the last box it "graduates"
##   take_due()    -> a due word whose first letter isn't on screen
##
## box_changed(word, box) lets the game persist boxes in Stats. A graduated word
## reports box == REVIEW_GAPS.size().

signal box_changed(word: String, box: int)

var spawn_index := 0
var _box := {}  ## word -> box
var _due := {}  ## word -> spawn index when due


func size() -> int:
	return _box.size()


func has(word: String) -> bool:
	return _box.has(word)


func box_of(word: String) -> int:
	return _box.get(word, -1)


func due_at(word: String) -> int:
	return _due.get(word, -1)


func tick() -> void:
	spawn_index += 1


## Words from earlier games (worst first). Staggered so they don't all arrive at once.
func seed_words(words: Array) -> void:
	var i := 0
	for w: String in words:
		if _box.has(w):
			continue
		_box[w] = 0
		_due[w] = spawn_index + Tuning.REVIEW_SEED_START + i * Tuning.REVIEW_SEED_SPREAD
		i += 1


func failed(word: String) -> void:
	_box[word] = 0
	_due[word] = spawn_index + Tuning.REVIEW_GAPS[0]
	box_changed.emit(word, 0)


func succeeded(word: String) -> void:
	if not _box.has(word):
		return
	var b: int = _box[word] + 1
	if b >= Tuning.REVIEW_GAPS.size():
		_box.erase(word)
		_due.erase(word)
		box_changed.emit(word, Tuning.REVIEW_GAPS.size())
		return
	_box[word] = b
	_due[word] = spawn_index + Tuning.REVIEW_GAPS[b]
	box_changed.emit(word, b)


## Earliest due word whose initial isn't blocked, or "". The word is
## rescheduled immediately (so it isn't lost if it never gets an outcome,
## e.g. replaced by SHAKE); failed()/succeeded() override that schedule.
func take_due(blocked: Dictionary = {}) -> String:
	var best := ""
	var best_due := 1 << 62
	for w: String in _due:
		var d: int = _due[w]
		if d <= spawn_index and d < best_due and not blocked.has(w[0]):
			best = w
			best_due = d
	if best != "":
		_due[best] = spawn_index + Tuning.REVIEW_GAPS[_box[best]]
	return best
