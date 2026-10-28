extends Control
## Touch controls in the style of a mobile MOBA:
##   left half   a floating joystick: put a thumb anywhere on the lower left and drag to walk (analog speed)
##   right side  one big attack button (the lunge, aimed at the nearest enemy), with the roll, sprint (hold), build and
##               remove buttons arced around it for the thumb
## They show only on a touchscreen (or after the first touch). While they are on, the game walks with the stick instead
## of click-to-walk, aims the lunge by itself, and builds in front of 小怪 (main.touch_mode). Each button presses the same
## input action as its keyboard key, so the game code does not know the difference.

const STICK_R := 74.0
const DEADZONE := 0.18
const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

const BUTTONS := [
	{"id": "attack", "action": "lunge", "anchor": Vector2(1, 1), "off": Vector2(-112, -112), "r": 56.0, "hold": false, "col": Color("ff7a5a")},
	{"id": "roll", "action": "dodge", "anchor": Vector2(1, 1), "off": Vector2(-245, -118), "r": 36.0, "hold": false, "col": Color("7be07b")},
	{"id": "sprint", "action": "sprint", "anchor": Vector2(1, 1), "off": Vector2(-205, -228), "r": 34.0, "hold": true, "col": Color("ffd84a")},
	{"id": "build", "action": "build", "anchor": Vector2(1, 1), "off": Vector2(-100, -244), "r": 34.0, "hold": false, "col": Color("8fb8ff")},
	{"id": "remove", "action": "demolish", "anchor": Vector2(1, 1), "off": Vector2(-34, -322), "r": 26.0, "hold": false, "col": Color("ff6a5a")},
	{"id": "switch", "action": "build_next", "anchor": Vector2(1, 1), "off": Vector2(-172, -318), "r": 26.0, "hold": false, "col": Color("c8c8d8")},
	{"id": "restart", "action": "restart", "anchor": Vector2(0.5, 0.62), "off": Vector2(0, 0), "r": 50.0, "hold": false, "col": Color("ffe08a"), "game_over": true},
]

var main: Node
var _pads: Array = []            ## the Control behind each button (and the stick area last), so a press there never also walks
var _down := {}                  ## touch index -> button dict
var _release_next: Array = []    ## tap actions to let go of on the next frame
var _stick_id := -1
var _stick_base := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	main = get_parent().get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in BUTTONS.size() + 1:
		var pad := Control.new()
		pad.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(pad)
		_pads.append(pad)
	visible = _has_touchscreen()
	_set_touch_mode(visible)
	_place()
	get_viewport().size_changed.connect(_place)


static func _has_touchscreen() -> bool:
	if OS.has_feature("web"):
		var nav = JavaScriptBridge.get_interface("navigator")
		return nav != null and int(nav.maxTouchPoints) > 0
	return DisplayServer.is_touchscreen_available()


func _set_touch_mode(on: bool) -> void:
	if main != null:
		main.set("touch_mode", on)


## Where a button sits: relative to the screen corner it hugs, so it follows any screen shape.
func _pos(b: Dictionary) -> Vector2:
	var vs := get_viewport_rect().size
	return Vector2(vs.x * float(b["anchor"].x), vs.y * float(b["anchor"].y)) + b["off"]


## The part of the screen where a thumb starts the stick.
func _zone() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(0.0, vs.y * 0.3, vs.x * 0.5, vs.y * 0.7)


func _idle_stick() -> Vector2:
	return Vector2(150.0, get_viewport_rect().size.y - 170.0)


func _place() -> void:
	for i in BUTTONS.size():
		var r: float = BUTTONS[i]["r"]
		_pads[i].position = _pos(BUTTONS[i]) - Vector2(r, r)
		_pads[i].size = Vector2(r, r) * 2.0
	var z := _zone()
	_pads[BUTTONS.size()].position = z.position
	_pads[BUTTONS.size()].size = z.size


func _blocked() -> bool:
	return bool(main.get("menu_open")) or bool(main.get("game_over"))


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not visible:
			visible = true
			_set_touch_mode(true)
		var t: InputEventScreenTouch = event
		if t.pressed:
			for b in BUTTONS:
				var go := bool(b.get("game_over", false))
				if go != bool(main.get("game_over")):
					continue
				if not go and bool(main.get("menu_open")):
					continue
				if t.position.distance_to(_pos(b)) <= float(b["r"]) + 6.0:
					_down[t.index] = b
					Input.action_press(b["action"])
					if not bool(b["hold"]):
						_release_next.append(b["action"])
					get_viewport().set_input_as_handled()
					return
			if _stick_id == -1 and not _blocked() and _zone().has_point(t.position):
				_stick_id = t.index
				_stick_base = t.position
				_stick_pos = t.position
				_update_stick()
				get_viewport().set_input_as_handled()
		else:
			if t.index == _stick_id:
				_stop_stick()
				get_viewport().set_input_as_handled()
			elif _down.has(t.index):
				var b: Dictionary = _down[t.index]
				_down.erase(t.index)
				if bool(b["hold"]):
					Input.action_release(b["action"])
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index == _stick_id:
			_stick_pos = d.position
			_update_stick()
			get_viewport().set_input_as_handled()


func _update_stick() -> void:
	var v := _stick_pos - _stick_base
	if v.length() > STICK_R:  # drag the base along so the thumb never runs out of room
		_stick_base = _stick_pos - v.normalized() * STICK_R
		v = _stick_pos - _stick_base
	var f := v / STICK_R
	_stick_vec = f if f.length() > DEADZONE else Vector2.ZERO
	_hold_axis("move_left", "move_right", _stick_vec.x)
	_hold_axis("move_up", "move_down", _stick_vec.y)


## One stick axis drives a negative and a positive action; only the side being pushed is pressed.
func _hold_axis(neg: String, pos: String, v: float) -> void:
	if v < 0.0:
		Input.action_press(neg, -v)
		Input.action_release(pos)
	elif v > 0.0:
		Input.action_press(pos, v)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _stop_stick() -> void:
	_stick_id = -1
	_stick_vec = Vector2.ZERO
	for a in MOVE_ACTIONS:
		Input.action_release(a)


func _process(delta: float) -> void:
	_t += delta
	for a in _release_next:
		Input.action_release(a)
	_release_next.clear()
	var blocked := _blocked()
	if blocked and _stick_id != -1:
		_stop_stick()
	# the pads only catch touches while the game is being played; menus and the game-over screen get plain taps
	for i in BUTTONS.size():
		var go: bool = bool(BUTTONS[i].get("game_over", false))
		var active := (go == bool(main.get("game_over"))) and (go or not blocked)
		_pads[i].mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	_pads[BUTTONS.size()].mouse_filter = Control.MOUSE_FILTER_IGNORE if blocked else Control.MOUSE_FILTER_STOP
	if visible:
		queue_redraw()


func _draw() -> void:
	var held: Array = _down.values()
	var over := bool(main.get("game_over"))
	var menu := bool(main.get("menu_open"))
	# the stick: a faint hint where it will start, the real one under the thumb
	if not over and not menu:
		var live := _stick_id != -1
		var base := _stick_base if live else _idle_stick()
		draw_circle(base, STICK_R, Color(0.05, 0.06, 0.12, 0.38 if live else 0.2))
		draw_arc(base, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.55 if live else 0.22), 3.0)
		for i in 4:
			var d := Vector2.from_angle(i * TAU / 4.0 - PI / 2.0)
			draw_colored_polygon(PackedVector2Array([base + d * (STICK_R - 12.0), base + d * (STICK_R - 24.0) + d.orthogonal() * 7.0, base + d * (STICK_R - 24.0) - d.orthogonal() * 7.0]), Color(1, 1, 1, 0.4 if live else 0.18))
		var knob := base + _stick_vec * STICK_R
		draw_circle(knob, 30.0, Color(1, 1, 1, 0.5 if live else 0.2))
		draw_arc(knob, 30.0, 0, TAU, 28, Color(1, 1, 1, 0.8 if live else 0.3), 2.5)
	for b in BUTTONS:
		var go := bool(b.get("game_over", false))
		if go != over or (not go and menu):
			continue
		var c: Vector2 = _pos(b)
		var r: float = b["r"]
		var col: Color = b["col"]
		var on: bool = held.has(b)
		var big: bool = b["id"] == "attack"
		draw_circle(c, r, Color(0.05, 0.06, 0.12, 0.8 if on else 0.55))
		if big:
			draw_circle(c, r - 6.0, Color(col, 0.14 + 0.06 * sin(_t * 3.0)))
			draw_arc(c, r - 6.0, 0, TAU, 40, Color(col, 0.35), 2.0)
		draw_arc(c, r - 1.5, 0, TAU, 40, Color(col, 0.95 if on else 0.7), 4.0 if big else 3.0)
		if on:
			draw_circle(c, r - 4.0, Color(col, 0.35))
		# a cooldown sweep over the buttons that have one
		var cd := _cooldown(String(b["id"]))
		if cd.x > 0.0:
			var f := clampf(cd.x / maxf(cd.y, 0.001), 0.0, 1.0)
			draw_arc(c, r * 0.5, -PI / 2.0, -PI / 2.0 + TAU * f, 28, Color(1, 1, 1, 0.55), r * 0.9)
		_icon(String(b["id"]), c, r * (0.42 if big else 0.5), Color(1, 1, 1, 0.95 if on else 0.82))


## (seconds left, full length) for the buttons that have a cooldown.
func _cooldown(id: String) -> Vector2:
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null:
		return Vector2.ZERO
	match id:
		"attack":
			return Vector2(float(pl.lunge_cd), float(pl.LUNGE_COOLDOWN))
		"roll":
			return Vector2(float(pl.roll_cd), float(pl.ROLL_COOLDOWN))
	return Vector2.ZERO


func _icon(id: String, c: Vector2, s: float, col: Color) -> void:
	match id:
		"attack":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.8, -s * 1.1), c + Vector2(s * 0.8, -s * 1.1), c + Vector2(0, s * 1.3)]), col)
			draw_line(c + Vector2(-s * 1.2, s * 0.9), c + Vector2(s * 1.2, -s * 0.9), Color(1, 0.5, 0.4, 0.9), 3.0)
		"roll":
			draw_arc(c, s * 0.8, 0.5, TAU - 0.8, 20, col, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.8, -s * 0.7), c + Vector2(s * 1.35, -s * 0.1), c + Vector2(s * 0.35, 0.0)]), col)
		"sprint":
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.3, -s * 1.1), c + Vector2(-s * 0.8, s * 0.2), c + Vector2(-s * 0.1, s * 0.2), c + Vector2(-s * 0.4, s * 1.1), c + Vector2(s * 0.8, -s * 0.3), c + Vector2(s * 0.1, -s * 0.3)]), col)
		"build":
			draw_rect(Rect2(c + Vector2(-s * 0.6, -s * 0.2), Vector2(s * 1.2, s * 1.1)), col)
			for dx in [-0.6, -0.1, 0.4]:
				draw_rect(Rect2(c + Vector2(s * dx, -s * 0.7), Vector2(s * 0.25, s * 0.4)), col)
		"remove":
			draw_line(c + Vector2(-s, -s), c + Vector2(s, s), col, 4.0)
			draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, 4.0)
		"switch":
			draw_line(c + Vector2(-s, -s * 0.4), c + Vector2(s, -s * 0.4), col, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s, -s * 0.9), c + Vector2(s * 1.4, -s * 0.4), c + Vector2(s, s * 0.1)]), col)
			draw_line(c + Vector2(-s, s * 0.4), c + Vector2(s, s * 0.4), col, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.1), c + Vector2(-s * 1.4, s * 0.4), c + Vector2(-s, s * 0.9)]), col)
		"restart":
			draw_arc(c, s * 0.9, 0.6, TAU - 0.5, 24, col, 5.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.9, -s * 1.1), c + Vector2(s * 1.5, -s * 0.2), c + Vector2(s * 0.3, -s * 0.1)]), col)
