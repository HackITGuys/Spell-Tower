extends Node
## Local, name-based player profiles (user://profiles.json).
##
## Each profile keeps its own preferences, scores and the "continue" save.
## Nothing but the nickname identifies a player, and nothing leaves the device.
## The familiar properties (Settings.age, Settings.ui_locale, …) read and write
## the current profile.

signal changed
signal profile_changed

const PATH := "user://profiles.json"
const VERSION := 1
const AGE_MIN := 4
const AGE_MAX := 15
const AGE_ADULT := 99
const NAME_MAX := 16
## How the player types, decided by platform (not a setting):
##   "osk"         native mobile app -> the game's own on-screen keyboard
##   "web_mobile"  browser on a phone/tablet -> the phone's own keyboard (WebKeys)
##   "keys"        desktop app / desktop browser -> physical keyboard
const INPUT_OSK := "osk"
const INPUT_WEB_MOBILE := "web_mobile"
const INPUT_KEYS := "keys"
const PLAY_MODES: Array[String] = ["show", "listen"]
const FORBIDDEN_NAME_CHARS := "<>/\\:*?\"|{}[]#%&$@=+;`~^"

const DEFAULTS := {
	"name": "",
	"anon_id": "",
	"ui_locale": "",      # "" = OS language
	"word_lang": "",      # "" = same as interface
	"age": 8,
	"start_level": 0,     # 0 = from age
	"mode": "show",       # show | listen (dictation)
	"palette": "green",
	"text_size": "m",
	"sound": true,
	"best": {},           # word lang -> best score
	"high_score": 0,      # all-time, any language
	"resume": {},         # {lang, mode, level, floor, score}; cleared on game over
}

## Tests set this to false so they never touch the player's real files.
var persist := true
## Runtime only: result of the last game, read by the game-over screen.
var last_result := {}
## Runtime only: the next game continues the saved one.
var continue_game := false
## Tests can force an input mode (e.g. "osk" to build the on-screen keyboard).
var force_input_mode := ""

var _data := {"version": VERSION, "current": "", "profiles": {}}
## The current profile (a guest profile until one is created/selected).
var profile: Dictionary = DEFAULTS.duplicate(true)

var ui_locale: String:
	get: return str(profile.get("ui_locale", ""))
	set(v): profile["ui_locale"] = v
var word_lang: String:
	get: return str(profile.get("word_lang", ""))
	set(v): profile["word_lang"] = v
var age: int:
	get: return int(profile.get("age", 8))
	set(v): profile["age"] = v
var start_level: int:
	get: return int(profile.get("start_level", 0))
	set(v): profile["start_level"] = v
var mode: String:
	get: return str(profile.get("mode", "show"))
	set(v): profile["mode"] = v
var palette: String:
	get: return str(profile.get("palette", "green"))
	set(v): profile["palette"] = v
var text_size: String:
	get: return str(profile.get("text_size", "m"))
	set(v): profile["text_size"] = v
var sound: bool:
	get: return bool(profile.get("sound", true))
	set(v): profile["sound"] = v
var best: Dictionary:
	get: return profile.get("best", {})
	set(v): profile["best"] = v
var resume_state: Dictionary:
	get: return profile.get("resume", {})


func _ready() -> void:
	load_settings()


# --- Persistence --------------------------------------------------------------

func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary) or int(parsed.get("version", 0)) != VERSION:
		return
	_data = parsed
	if not _data.has("profiles"):
		_data["profiles"] = {}
	for id in _data["profiles"]:
		_fill_defaults(_data["profiles"][id])
	var cur := str(_data.get("current", ""))
	if _data["profiles"].has(cur):
		profile = _data["profiles"][cur]
	elif not _data["profiles"].is_empty():
		_data["current"] = _data["profiles"].keys()[0]
		profile = _data["profiles"][_data["current"]]


## Kept under its old name: saves the current profile (and all others).
func save_settings() -> void:
	changed.emit()
	if not persist or not has_profiles():
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Settings: cannot write %s" % PATH)
		return
	f.store_string(JSON.stringify(_data, "\t"))


static func _fill_defaults(p: Dictionary) -> void:
	for k in DEFAULTS:
		if not p.has(k):
			p[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary else DEFAULTS[k]


# --- Profiles -----------------------------------------------------------------

func has_profiles() -> bool:
	return not _data["profiles"].is_empty()


func current_id() -> String:
	return str(_data.get("current", "")) if has_profiles() else ""


func current_name() -> String:
	return str(profile.get("name", ""))


## [{id, name}] sorted by name.
func profiles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _data["profiles"]:
		out.append({"id": id, "name": _data["profiles"][id]["name"]})
	out.sort_custom(func(a, b): return String(a["name"]).naturalnocasecmp_to(b["name"]) < 0)
	return out


## Trimmed, single-spaced, no odd characters, max NAME_MAX, first letter upper-case.
static func sanitize_name(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var ch := raw[i]
		if ch.unicode_at(0) < 32 or FORBIDDEN_NAME_CHARS.contains(ch):
			continue
		out += ch
	while out.contains("  "):
		out = out.replace("  ", " ")
	out = out.strip_edges().left(NAME_MAX).strip_edges()
	if out.is_empty():
		return ""
	return out[0].to_upper() + out.substr(1)


func name_taken(name: String) -> bool:
	for id in _data["profiles"]:
		if String(_data["profiles"][id]["name"]).to_lower() == name.to_lower():
			return true
	return false


## Returns the new profile id, or "" if the name is empty/taken.
## The new profile inherits the current look and language so switching feels natural.
func create_profile(raw_name: String, p_age: int) -> String:
	var name := sanitize_name(raw_name)
	if name.is_empty() or name_taken(name):
		return ""
	var p := DEFAULTS.duplicate(true)
	for k in ["ui_locale", "palette", "text_size", "sound"]:
		p[k] = profile.get(k, DEFAULTS[k])
	p["name"] = name
	p["age"] = p_age
	p["anon_id"] = _random_id(8)
	var id := _random_id(4)
	while _data["profiles"].has(id):
		id = _random_id(4)
	_data["profiles"][id] = p
	select_profile(id)
	return id


func select_profile(id: String) -> void:
	if not _data["profiles"].has(id):
		return
	_data["current"] = id
	profile = _data["profiles"][id]
	save_settings()
	_apply_profile()


func delete_profile(id: String) -> void:
	if not _data["profiles"].has(id):
		return
	_data["profiles"].erase(id)
	if is_inside_tree():
		Stats.delete_profile_data(id)
	if _data.get("current", "") == id:
		if has_profiles():
			select_profile(profiles()[0]["id"])
			return
		_data["current"] = ""
		var keep := profile
		profile = DEFAULTS.duplicate(true)
		for k in ["ui_locale", "palette", "text_size", "sound"]:
			profile[k] = keep.get(k, DEFAULTS[k])
		if persist:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		_apply_profile()
	else:
		save_settings()


func _apply_profile() -> void:
	if not is_inside_tree():
		return
	Stats.use_profile(current_id())
	Locale.apply(ui_locale)
	Term.apply(palette, text_size)
	profile_changed.emit()


# --- Derived settings -----------------------------------------------------------

func age_start_level() -> int:
	if age >= AGE_ADULT:
		return Tuning.MAX_TIER
	return Tuning.start_level_for_age(age)


func effective_start_level() -> int:
	return start_level if start_level > 0 else age_start_level()


## Word language actually used: explicit choice, else the UI language, else "en".
func effective_word_lang() -> String:
	if word_lang != "" and WordBank.has_language(word_lang):
		return word_lang
	var ui := TranslationServer.get_locale().split("_")[0]
	if WordBank.has_language(ui):
		return ui
	return "en"


func input_mode() -> String:
	if force_input_mode != "":
		return force_input_mode
	if OS.has_feature("web"):
		if OS.has_feature("web_android") or OS.has_feature("web_ios"):
			return INPUT_WEB_MOBILE
		return INPUT_KEYS
	if OS.has_feature("android") or OS.has_feature("ios"):
		return INPUT_OSK
	return INPUT_KEYS


func show_keyboard() -> bool:
	return input_mode() == INPUT_OSK


# --- Scores and resume ------------------------------------------------------------

func best_for(lang: String) -> int:
	return int(best.get(lang, 0))


func high_score() -> int:
	return int(profile.get("high_score", 0))


## Updates the per-language best and the all-time high score.
## Returns true if it's a new best for that language.
func record_score(lang: String, score: int) -> bool:
	var new_best := score > best_for(lang)
	if new_best:
		var b := best
		b[lang] = score
		best = b
	if score > high_score():
		profile["high_score"] = score
	save_settings()
	return new_best


func has_resume() -> bool:
	return not resume_state.is_empty() and int(resume_state.get("level", 0)) > 0


func set_resume(state: Dictionary) -> void:
	profile["resume"] = state.duplicate()
	save_settings()


func clear_resume() -> void:
	profile["resume"] = {}
	save_settings()


static func _random_id(bytes: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s := ""
	for i in bytes:
		s += "%02x" % rng.randi_range(0, 255)
	return s
