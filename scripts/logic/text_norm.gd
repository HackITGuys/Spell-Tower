class_name TextNorm
extends RefCounted
## Per-language text normalisation for words and typed characters.
##
## - casefold: explicit char->char mapping applied BEFORE lower-casing
##   (e.g. Turkish {"I": "ı", "İ": "i"}).
## - equivalents: typed char -> canonical char (e.g. Norwegian {"ä": "æ"} so a
##   Swedish/German keyboard still works).
## - alphabet: only these characters are accepted; everything else is ignored.
##
## Word files must be authored in Unicode NFC (validated by tests): Godot has no
## built-in NFC normaliser, and physical keyboards emit precomposed letters.

var alphabet: Dictionary = {}
var casefold: Dictionary = {}
var equivalents: Dictionary = {}


func _init(lang_def: Dictionary = {}) -> void:
	var alpha: String = lang_def.get("alphabet", "abcdefghijklmnopqrstuvwxyz")
	for i in alpha.length():
		alphabet[alpha[i]] = true
	casefold = lang_def.get("casefold", {})
	equivalents = lang_def.get("equivalents", {})


func lower(s: String) -> String:
	var out := ""
	for i in s.length():
		var ch := s[i]
		out += casefold.get(ch, ch)
	return out.to_lower()


## Returns the canonical character, or "" if it isn't part of the alphabet.
func normalize_char(ch: String) -> String:
	if ch.length() != 1:
		return ""
	var c := lower(ch)
	c = equivalents.get(c, c)
	return c if alphabet.has(c) else ""


func normalize_word(w: String) -> String:
	return lower(w.strip_edges())


func is_valid_word(w: String) -> bool:
	if w.is_empty():
		return false
	for i in w.length():
		if not alphabet.has(w[i]):
			return false
	return true
