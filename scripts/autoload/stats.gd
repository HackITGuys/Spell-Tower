extends Node
## Local per-profile, per-(language, word) spelling statistics.
## Stored in user://stats_<profile_id>.json. Nothing is sent anywhere in v1.
## See docs/languages-and-difficulty.md.
##
## Per word entry ("<lang>:<word>"):
##   a  = attempts (completed + missed)
##   c  = completed cleanly
##   x  = completed with at least one wrong letter
##   m  = missed (reached the base)
##   wl = wrong letters typed
##   b  = review box (0..REVIEW_GAPS.size(); == size means "graduated")

const VERSION := 1
## Need this many attempts before a word's local difficulty is adjusted.
const MIN_ATTEMPTS := 3
const ADJUST_CAP := 2

var data := {"version": VERSION, "words": {}}
var profile_id := ""
## Tests set this to false so they never touch the player's real stats.
var persist := true
var _dirty := false


func _ready() -> void:
	if not Settings.uses_profiles():
		persist = false  # web: nothing is stored
	use_profile(Settings.current_id())


static func path_for(id: String) -> String:
	return "user://stats_%s.json" % id


## Switch to another profile's stats (saving the current ones first).
func use_profile(id: String) -> void:
	save_data()
	profile_id = id
	data = {"version": VERSION, "words": {}}
	_dirty = false
	if id != "":
		load_data()


func delete_profile_data(id: String) -> void:
	if id == profile_id:
		data = {"version": VERSION, "words": {}}
		_dirty = false
		profile_id = ""
	if persist and FileAccess.file_exists(path_for(id)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(id)))


static func key(lang: String, word: String) -> String:
	return lang + ":" + word


## The player's start grade, stored with the stats for (future) server
## aggregation by (lang, word, grade). Replaces the old age band.
func set_grade(grade: int) -> void:
	data.erase("age_band")
	data["grade"] = grade


func entry(lang: String, word: String) -> Dictionary:
	var words: Dictionary = data["words"]
	var k := key(lang, word)
	if not words.has(k):
		words[k] = {"a": 0, "c": 0, "x": 0, "m": 0, "wl": 0, "b": 0}
	return words[k]


func peek(lang: String, word: String) -> Dictionary:
	return data["words"].get(key(lang, word), {})


func record_completed(lang: String, word: String, had_mistakes: bool) -> void:
	var e := entry(lang, word)
	e["a"] += 1
	if had_mistakes:
		e["x"] += 1
	else:
		e["c"] += 1
	_dirty = true


func record_missed(lang: String, word: String) -> void:
	var e := entry(lang, word)
	e["a"] += 1
	e["m"] += 1
	_dirty = true


func record_wrong_letter(lang: String, word: String) -> void:
	entry(lang, word)["wl"] += 1
	_dirty = true


func set_box(lang: String, word: String, box: int) -> void:
	entry(lang, word)["b"] = box
	_dirty = true


static func fail_rate(e: Dictionary) -> float:
	if e.is_empty() or int(e.get("a", 0)) == 0:
		return 0.0
	return float(int(e.get("x", 0)) + int(e.get("m", 0))) / float(e["a"])


## Words that were failed before and haven't graduated from review, worst first.
func review_candidates(lang: String, limit: int = Tuning.REVIEW_SEED_LIMIT) -> Array[String]:
	var prefix := lang + ":"
	var found: Array = []
	var words: Dictionary = data["words"]
	for k: String in words:
		if not k.begins_with(prefix):
			continue
		var e: Dictionary = words[k]
		if int(e.get("x", 0)) + int(e.get("m", 0)) == 0:
			continue
		if int(e.get("b", 0)) >= Tuning.REVIEW_GAPS.size():
			continue
		found.append([fail_rate(e), int(e.get("a", 0)), k.substr(prefix.length())])
	found.sort_custom(func(p, q): return p[0] > q[0] or (p[0] == q[0] and p[1] > q[1]))
	var out: Array[String] = []
	for f in found.slice(0, limit):
		out.append(f[2])
	return out


## 0..ADJUST_CAP tiers added to a word's base difficulty for this player.
func local_adjust(lang: String, word: String) -> int:
	var e := peek(lang, word)
	if e.is_empty() or int(e["a"]) < MIN_ATTEMPTS:
		return 0
	var r := fail_rate(e)
	if r >= 0.75:
		return mini(2, ADJUST_CAP)
	if r >= 0.5:
		return mini(1, ADJUST_CAP)
	return 0


func load_data() -> void:
	var path := path_for(profile_id)
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and int(parsed.get("version", 0)) == VERSION:
		data = parsed
		if not data.has("words"):
			data["words"] = {}


func save_data() -> void:
	if not _dirty or not persist or profile_id == "":
		return
	var f := FileAccess.open(path_for(profile_id), FileAccess.WRITE)
	if f == null:
		push_warning("Stats: cannot write %s" % path_for(profile_id))
		return
	f.store_string(JSON.stringify(data))
	_dirty = false


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_WM_CLOSE_REQUEST
		or what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_APPLICATION_FOCUS_OUT
	):
		save_data()
