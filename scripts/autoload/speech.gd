extends Node
## Text-to-speech for dictation ("listen") mode, on top of DisplayServer.tts_*.
## Needs project setting audio/general/text_to_speech = true.
## Voices depend on the OS / browser; on the web they may load a moment late.

## Word language -> other language codes a voice may be registered under.
const ALIASES := {"nb": ["no", "nn"]}
const VOLUME := 90
const RATE := 0.85   # a little slower than normal for children


## Seconds the game waits for voices to appear before falling back to "show".
const VOICE_WAIT := 3.0


func _ready() -> void:
	# Browsers load voices lazily: the first query returns nothing and starts
	# the load. Ask once at startup so they're ready when a game begins.
	if supported():
		DisplayServer.tts_get_voices()


func supported() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)


func voice_for(lang: String) -> String:
	if not supported():
		return ""
	for code in [lang] + ALIASES.get(lang, []):
		var voices := DisplayServer.tts_get_voices_for_language(code)
		if voices.size() > 0:
			return voices[0]
	return ""


func available(lang: String) -> bool:
	return voice_for(lang) != ""


func say(text: String, lang: String, interrupt := false) -> void:
	var v := voice_for(lang)
	if v == "":
		return
	DisplayServer.tts_speak(text, v, VOLUME, 1.0, RATE, 0, interrupt)


func debug_info(lang: String) -> String:
	if not supported():
		return "tts not supported (check audio/general/text_to_speech)"
	var all := DisplayServer.tts_get_voices()
	var langs := {}
	for v in all:
		langs[v.get("language", "?")] = true
	return "voices=%d languages=%s chosen[%s]='%s'" % [all.size(), langs.keys(), lang, voice_for(lang)]


func stop() -> void:
	if supported():
		DisplayServer.tts_stop()
