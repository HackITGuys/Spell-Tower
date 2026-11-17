extends Node
## Loads the language manifest and the active language's word file.
##
## Word file format (data/words/<code>.json):
##   { "lang": "en", "version": 1,
##     "tiers": { "0": ["a", ...], "1": ["cat", ...], ..., "10": [...] },
##   Tier = grade: 0 = pre-school, 1..10 = school grade.
##     "concepts": { "cat": "animal.cat" } }
## Expanded at load time into entries { id: "en:cat", w, d, concept }.

const MANIFEST := "res://data/languages.json"

var languages: Array = []  ## manifest entries (Dictionary)
var lang := ""  ## currently loaded word language
var lang_def: Dictionary = {}
var norm := TextNorm.new()
var entries: Dictionary = {}  ## word -> {id, w, d, concept}
## Object with local_adjust(lang, word) -> int. The Stats autoload at runtime.
var stats_provider: Object = null
## Future: word -> int, filled from the server (see docs). Always empty in v1.
var server_adjust: Dictionary = {}


func _ready() -> void:
	load_manifest()
	stats_provider = get_node_or_null("/root/Stats")


func load_manifest(path: String = MANIFEST) -> bool:
	var parsed: Variant = _read_json(path)
	if not (parsed is Dictionary) or not parsed.has("languages"):
		push_error("WordBank: bad manifest %s" % path)
		return false
	languages = parsed["languages"]
	return true


func has_language(code: String) -> bool:
	return not get_language(code).is_empty()


func get_language(code: String) -> Dictionary:
	for l: Dictionary in languages:
		if l.get("code", "") == code:
			return l
	return {}


func load_language(code: String) -> bool:
	if code == lang and not entries.is_empty():
		return true
	var def := get_language(code)
	if def.is_empty():
		push_error("WordBank: unknown language %s" % code)
		return false
	var parsed: Variant = _read_json(def["word_file"])
	if not (parsed is Dictionary) or not parsed.has("tiers"):
		push_error("WordBank: bad word file %s" % def["word_file"])
		return false
	lang = code
	lang_def = def
	norm = TextNorm.new(def)
	entries.clear()
	server_adjust.clear()
	var concepts: Dictionary = parsed.get("concepts", {})
	var tiers: Dictionary = parsed["tiers"]
	for t in tiers:
		var d := clampi(int(t), Tuning.MIN_GRADE, Tuning.MAX_GRADE)
		for raw: String in tiers[t]:
			var w := norm.normalize_word(raw)
			if not norm.is_valid_word(w):
				push_warning("WordBank[%s]: skipping '%s' (not in alphabet)" % [code, raw])
				continue
			entries[w] = {"id": code + ":" + w, "w": w, "d": d, "concept": concepts.get(w, "")}
	return true


func base_difficulty(word: String) -> int:
	return int(entries.get(word, {}).get("d", Tuning.DEFAULT_GRADE))


## base + local (this player's stats) + server (global stats, future), clamped.
func effective_difficulty(word: String) -> int:
	var d := base_difficulty(word)
	if stats_provider != null:
		d += int(stats_provider.local_adjust(lang, word))
	d += int(server_adjust.get(word, 0))
	return clampi(d, Tuning.MIN_GRADE, Tuning.MAX_GRADE)


func concept_of(word: String) -> String:
	return entries.get(word, {}).get("concept", "")


## tier -> Array[String], bucketed by effective difficulty.
func build_tiers() -> Dictionary:
	var tiers := {}
	for w: String in entries:
		var d := effective_difficulty(w)
		if not tiers.has(d):
			tiers[d] = []
		tiers[d].append(w)
	return tiers


func make_picker(seed_value: int = -1) -> WordPicker:
	return WordPicker.new(build_tiers(), seed_value)


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("WordBank: missing %s" % path)
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
