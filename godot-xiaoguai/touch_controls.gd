extends Control
## On-screen buttons for phones and tablets: roll, lunge, sprint (hold), build, remove and switch tower/wall.
## They only show once the device reports a touchscreen (or the first touch arrives). Walking needs no stick: tapping
## or holding the screen already walks (touch is turned into mouse clicks), so a second finger can press these.
## Each button presses the same input action as the keyboard key, so the game code does not know the difference.

const BUTTONS := [
	{"id": "roll", "action": "dodge", "anchor": Vector2(1, 1), "off": Vector2(-80, -100), "r": 46.0, "hold": false, "col": Color("7be07b")},
	{"id": "lunge", "action": "lunge", "anchor": Vector2(1, 1), "off": Vector2(-80, -205), "r": 38.0, "hold": false, "col": Color("ff7a5a")},
	{"id": "sprint", "action": "sprint", "anchor": Vector2(1, 1), "off": Vector2(-80, -305), "r": 38.0, "hold": true, "col": Color("ffd84a")},
	{"id": "build", "action": "build", "anchor": Vector2(0, 1), "off": Vector2(80, -100), "r": 44.0, "hold": false, "col": Color("8fb8ff")},
	{"id": "remove", "action": "demolish", "anchor": Vector2(0, 1), "off": Vector2(80, -205), "r": 34.0, "hold": false, "col": Color("ff6a5a")},
	{"id": "switch", "action": "build_next", "anchor": Vector2(0, 1), "off": Vector2(80, -305), "r": 34.0, "hold": false, "col": Color("c8c8d8")},
]

var _pads: Array = []            ## the Control behind each button, so hovering it blocks click-to-walk
var _down := {}                  ## touch index -> button dict
var _release_next: Array = []    ## tap actions to let go of on the next frame
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for b in BUTTONS:
		var pad := Control.new()
		pad.mouse_filter = Control.MOUSE_FILTER_STOP
		pad.size = Vector2(b["r"], b["r"]) * 2.0
		add_child(pad)
		_pads.append(pad)
	visible = _has_touchscreen()
	_place()
	get_viewport().size_changed.connect(_place)


## Where a button sits: relative to the screen corner it hugs, so it follows any screen shape.
func _pos(b: Dictionary) -> Vector2:
	var vs := get_viewport_rect().size
	return Vector2(vs.x * float(b["anchor"].x), vs.y * float(b["anchor"].y)) + b["off"]


func _place() -> void:
	for i in BUTTONS.size():
		_pads[i].position = _pos(BUTTONS[i]) - Vector2(BUTTONS[i]["r"], BUTTONS[i]["r"])


static func _has_touchscreen() -> bool:
	if OS.has_feature("web"):
		var nav = JavaScriptBridge.get_interface("navigator")
		return nav != null and int(nav.maxTouchPoints) > 0
	return DisplayServer.is_touchscreen_available()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not visible:
			visible = true
		var t: InputEventScreenTouch = event
		if t.pressed:
			for b in BUTTONS:
				if t.position.distance_to(_pos(b)) <= float(b["r"]) + 6.0:
					_down[t.index] = b
					Input.action_press(b["action"])
					if not bool(b["hold"]):
						_release_next.append(b["action"])
					get_viewport().set_input_as_handled()
					break
		elif _down.has(t.index):
			var b: Dictionary = _down[t.index]
			_down.erase(t.index)
			if bool(b["hold"]):
				Input.action_release(b["action"])
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	for a in _release_next:
		Input.action_release(a)
	_release_next.clear()
	if visible:
		queue_redraw()


func _draw() -> void:
	var held: Array = _down.values()
	for b in BUTTONS:
		var c: Vector2 = _pos(b)
		var r: float = b["r"]
		var col: Color = b["col"]
		var on: bool = held.has(b)
		draw_circle(c, r, Color(0.05, 0.06, 0.12, 0.5 if not on else 0.75))
		draw_arc(c, r - 1.5, 0, TAU, 40, Color(col, 0.9 if on else 0.6), 3.0)
		if on:
			draw_circle(c, r - 4.0, Color(col, 0.3))
		_icon(String(b["id"]), c, r * 0.5, Color(1, 1, 1, 0.95 if on else 0.8))


func _icon(id: String, c: Vector2, s: float, col: Color) -> void:
	match id:
		"roll":
			draw_arc(c, s * 0.8, 0.5, TAU - 0.8, 20, col, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.8, -s * 0.7), c + Vector2(s * 1.35, -s * 0.1), c + Vector2(s * 0.35, 0.0)]), col)
		"lunge":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.7, -s), c + Vector2(s * 0.7, -s), c + Vector2(0, s * 1.1)]), col)
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
