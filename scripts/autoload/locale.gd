extends Node
## UI language handling on top of Godot's TranslationServer.
## Translations come from i18n/ui.csv (one column per locale), registered in
## project.godot -> internationalization/locale/translations.

signal locale_changed(code: String)

## OS locales that should map onto one of ours.
const ALIASES := {"no": "nb"}


func _ready() -> void:
	apply(Settings.ui_locale)


## [{code, name}] for every registered UI translation. Name is the native name.
func available() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var paths: PackedStringArray = ProjectSettings.get_setting(
			"internationalization/locale/translations", PackedStringArray())
	for p in paths:
		var t := load(p) as Translation
		if t == null:
			continue
		var name := String(t.get_message("LOCALE_NAME"))
		out.append({"code": t.locale, "name": name if name != "" else t.locale})
	return out


func has_locale(code: String) -> bool:
	for l in available():
		if l["code"] == code:
			return true
	return false


## "" -> OS language (with aliases) -> "en".
func resolve(code: String) -> String:
	if code != "" and has_locale(code):
		return code
	var os_lang := OS.get_locale_language()
	os_lang = ALIASES.get(os_lang, os_lang)
	if has_locale(os_lang):
		return os_lang
	return "en"


func current() -> String:
	return TranslationServer.get_locale()


func apply(code: String) -> void:
	var resolved := resolve(code)
	TranslationServer.set_locale(resolved)
	locale_changed.emit(resolved)
