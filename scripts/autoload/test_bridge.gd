extends Node
## Browser end-to-end test bridge. Active ONLY in the "Web (e2e)" export (custom
## feature tag "e2e"); in every other build it does nothing.
##
## Godot draws everything on one <canvas>, so Playwright (tests/e2e/) can't find
## buttons in the page. A few times a second this publishes the game's state as
## window.spelltowerState (plain JSON). Every rectangle is [x, y, w, h] in canvas
## pixels; the tests scale them to page coordinates and tap/click there.

const PUBLISH_EVERY_FRAMES := 5

var active := false
var _frame := 0


func _ready() -> void:
	active = OS.has_feature("web") and OS.has_feature("e2e")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if not active:
		return
	_frame += 1
	if _frame % PUBLISH_EVERY_FRAMES != 0:
		return
	JavaScriptBridge.eval("window.spelltowerState = %s;" % JSON.stringify(snapshot()), true)


## The published state. Also usable from GDScript tests.
func snapshot() -> Dictionary:
	var scene := get_tree().current_scene
	var state := {
		"scene": _scene_name(scene),
		"frame": Engine.get_process_frames(),
		"paused": get_tree().paused,
		"input_mode": Settings.input_mode(),
		"uses_profiles": Settings.uses_profiles(),
		"start_grade": Settings.grade,
		"buttons": [],
		"labels": [],
		"steppers": [],
	}
	if scene == null:
		return state
	_collect(scene, state)
	if state["scene"] == "game":
		state["game"] = _game_state(scene)
	return state


static func _scene_name(scene: Node) -> String:
	if scene == null:
		return ""
	match scene.scene_file_path:
		"res://scenes/main_menu.tscn":
			return "menu"
		"res://scenes/game.tscn":
			return "game"
		"res://scenes/game_over.tscn":
			return "game_over"
	return scene.scene_file_path


func _collect(n: Node, state: Dictionary) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is Stepper:
		var st := n as Stepper
		var label := ""
		var index := st.get_index()
		if index > 0 and st.get_parent().get_child(index - 1) is Label:
			label = (st.get_parent().get_child(index - 1) as Label).text
		(
			state["steppers"]
			. append(
				{
					"label": label,
					"value": st.selected_text(),
					"prev": rect_of(st.get_child(0)),
					"next": rect_of(st.get_child(2)),
				}
			)
		)
		return
	if n is Button:
		state["buttons"].append({"text": (n as Button).text, "rect": rect_of(n), "disabled": (n as Button).disabled})
	elif n is Label and (n as Label).text != "":
		state["labels"].append({"text": (n as Label).text, "rect": rect_of(n)})
	for c in n.get_children():
		_collect(c, state)


func _game_state(game: Node) -> Dictionary:
	var model: ScoreModel = game.get("model")
	var words: Array = []
	for w in game.call("_alive_words"):
		words.append({"text": w.text, "typed": w.typed, "rect": rect_of(w)})
	var out := {
		"level": model.level,
		"grade": Tuning.grade_for_level(model.level),
		"stage": Tuning.stage_for_level(model.level),
		"score": model.score,
		"words_done": model.words_done,
		"over": model.is_over,
		"words": words,
		"hud": rect_of(game.get("_hud_line")),
		"playfield": rect_of(game.get("_playfield")),
		"keyboard": null,
	}
	var kb: OnScreenKeyboard = game.get("_keyboard")
	if kb != null and kb.is_visible_in_tree():
		var xf := kb.get_viewport().get_screen_transform() * kb.get_global_transform_with_canvas()
		var keys: Array = []
		for k in kb.get("_keys"):
			var r: Rect2 = xf * (k["rect"] as Rect2)
			keys.append({"ch": k["ch"], "rect": [r.position.x, r.position.y, r.size.x, r.size.y]})
		out["keyboard"] = {"rect": rect_of(kb), "keys": keys}
	return out


## [x, y, w, h] of a Control in canvas (window) pixels.
static func rect_of(c: Variant) -> Variant:
	if not (c is Control):
		return null
	var ctl := c as Control
	var xf := ctl.get_viewport().get_screen_transform() * ctl.get_global_transform_with_canvas()
	var r: Rect2 = xf * Rect2(Vector2.ZERO, ctl.size)
	return [r.position.x, r.position.y, r.size.x, r.size.y]
