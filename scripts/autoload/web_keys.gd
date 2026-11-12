extends Node
## Phone keyboard for the web build on phones/tablets (Settings.input_mode()
## == "web_mobile").
##
## The game has no text field while playing, so a hidden <input> is added to
## the page with autocorrect / autocomplete / autocapitalise / spellcheck off.
## Tapping the game focuses it (inside the tap, as iOS requires), which opens
## the phone's own keyboard. Typed characters are queued in JS and polled here.
##
## The input always holds one sentinel space, so Backspace is detectable even
## on Android keyboards that don't send key codes (value becomes empty).

signal char_typed(ch: String)
signal backspace
signal enter

const JS_SETUP := """
(function () {
	if (window.__stKeys) return;
	var inp = document.createElement('input');
	inp.type = 'text';
	inp.autocomplete = 'off';
	inp.spellcheck = false;
	inp.setAttribute('autocorrect', 'off');
	inp.setAttribute('autocapitalize', 'none');
	inp.setAttribute('enterkeyhint', 'done');
	inp.setAttribute('aria-hidden', 'true');
	inp.tabIndex = -1;
	/* 16px font stops iOS zooming in; top-left so the page doesn't scroll. */
	Object.assign(inp.style, {position: 'fixed', left: '0', top: '0', width: '1px', height: '1px',
		opacity: '0', border: '0', padding: '0', margin: '0', fontSize: '16px', zIndex: '-1'});
	inp.value = ' ';
	document.body.appendChild(inp);
	var st = {input: inp, queue: '', wanted: false};
	window.__stKeys = st;
	var reset = function () { inp.value = ' '; try { inp.setSelectionRange(1, 1); } catch (e) {} };
	inp.addEventListener('input', function () {
		var v = inp.value;
		if (v.length === 0) { st.queue += '\\b'; }
		else { st.queue += (v.charAt(0) === ' ' ? v.substring(1) : v); }
		reset();
	});
	inp.addEventListener('keydown', function (e) {
		if (e.key === 'Enter') { st.queue += '\\n'; e.preventDefault(); }
		else if (e.key === 'Backspace' && inp.value === ' ') { st.queue += '\\b'; e.preventDefault(); }
		e.stopPropagation();
	});
	inp.addEventListener('keyup', function (e) { e.stopPropagation(); });
	var focusIfWanted = function () { if (st.wanted) { inp.focus({preventScroll: true}); reset(); } };
	var canvas = document.getElementById('canvas') || document.querySelector('canvas');
	(canvas || document).addEventListener('touchend', focusIfWanted);
	(canvas || document).addEventListener('click', focusIfWanted);
	st.take = function () { var q = st.queue; st.queue = ''; return q; };
	st.want = function (on) {
		st.wanted = on;
		if (on) { focusIfWanted(); } else { inp.blur(); }
	};
})();
"""

var active := false
var _installed := false


func needed() -> bool:
	return OS.has_feature("web") and Settings.input_mode() == Settings.INPUT_WEB_MOBILE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if needed():
		JavaScriptBridge.eval(JS_SETUP, true)
		_installed = true


## Start/stop listening. While on, a tap on the game opens the phone keyboard
## (we also try to open it right away; browsers allow that after a recent tap).
func set_active(on: bool) -> void:
	active = on and _installed
	if _installed:
		JavaScriptBridge.eval("window.__stKeys.want(%s)" % ("true" if active else "false"), true)


func _process(_delta: float) -> void:
	if not active:
		return
	var q: Variant = JavaScriptBridge.eval("window.__stKeys.take()", true)
	if not (q is String) or q == "":
		return
	for i in q.length():
		var ch: String = q[i]
		if ch == "\b":
			backspace.emit()
		elif ch == "\n":
			enter.emit()
		else:
			char_typed.emit(ch)
