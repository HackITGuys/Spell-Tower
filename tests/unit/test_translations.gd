extends SpellTestSuite
## UI translations: every locale has every key.


func test_translations() -> void:
	var paths: PackedStringArray = ProjectSettings.get_setting(
		"internationalization/locale/translations", PackedStringArray()
	)
	check(paths.size() >= 2, "at least two UI locales registered")
	var tables: Array[Translation] = []
	for path in paths:
		var t := load(path) as Translation
		check(t != null, "loads %s" % path)
		if t != null:
			tables.append(t)
	if tables.is_empty():
		return
	var reference := tables[0]
	var keys := reference.get_message_list()
	check(keys.size() > 10, "reference has keys")
	for t in tables:
		check(t.get_message_list().size() == keys.size(), "%s has same key count" % t.locale)
		for k in keys:
			check(String(t.get_message(k)) != "", "%s has %s" % [t.locale, k])
		check(String(t.get_message("LOCALE_NAME")) != "", "%s has native name" % t.locale)
