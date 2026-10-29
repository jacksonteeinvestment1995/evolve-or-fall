extends Control
## Touch controls in the style of a mobile MOBA:
##   left half   a floating joystick: put a thumb anywhere on the lower left and drag to walk (analog speed)
##   right side  one big ROLL button (a dodge that also hits every enemy it passes through; with the stick at rest it
##               rolls at the nearest enemy), with SPRINT (hold) and BUILD arced around it for the thumb, and SWAP
##               (tower / wall) and REMOVE close by
## Every button says what it does (a label under it), shows its cooldown as a dark sweep with the seconds left, and
## sinks in while pressed. On the first run a coach-mark layer points at each control for a few seconds (tap to close;
## the "?" button shows it again). Bites need no button: 小怪 bites nearby villagers by himself.
## They show only on a touchscreen (or after the first touch). While they are on, the game walks with the stick instead
## of click-to-walk, aims the lunge by itself, and builds in front of 小怪 (main.touch_mode). Each button presses the same
## input action as its keyboard key, so the game code does not know the difference.
## This node keeps running while the game is paused (a level-up menu), so it always sees a finger being lifted; any
## touch it holds is let go when a menu opens or closes (reset_touch), so the stick never stays stuck.

const STICK_R := 70.0         ## joystick radius on an upright screen
const STICK_R_WIDE := 50.0    ## and on a wide one (about 22% of the screen height across)
const MIN_HIT := 30.0         ## every button catches taps at least this far from its centre (about 52 CSS px across)
## On a wide screen the buttons follow MOBA proportions so the playfield stays clear: LUNGE about 15% of the screen
## height across, SPRINT / BUILD about 12%, SWAP / REMOVE about 10%, all tight in the bottom right corner.
const R_WIDE := {"roll": 35.0, "sprint": 27.0, "build": 27.0, "switch": 22.0, "remove": 22.0, "restart": 50.0}
const ROLL_AIM := 260.0       ## with the stick at rest a touch roll heads for the nearest enemy this close
const DEADZONE := 0.18
const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]
const HINT_SECONDS := 12.0
const HINT_FILE := "user://touch_hint.cfg"
const HELP_R := 20.0

const BUTTONS := [
	{"id": "roll", "action": "dodge", "r": 60.0, "hold": false, "col": Color("ff9a5a"), "label": "ROLL"},
	{"id": "sprint", "action": "sprint", "r": 38.0, "hold": true, "col": Color("ffd84a"), "label": "SPRINT"},
	{"id": "build", "action": "build", "r": 38.0, "hold": false, "col": Color("8fb8ff"), "label": "BUILD"},
	{"id": "switch", "action": "build_next", "r": 30.0, "hold": false, "col": Color("c8c8d8"), "label": "SWAP"},
	{"id": "remove", "action": "demolish", "r": 30.0, "hold": false, "col": Color("ff6a5a"), "label": "REMOVE"},
	{"id": "restart", "action": "restart", "r": 50.0, "hold": false, "col": Color("ffe08a"), "label": "AGAIN", "game_over": true},
]

## Where each button sits: [screen anchor (0..1), offset in layout pixels]. The combat buttons arc around LUNGE in the
## bottom right corner; on a wide screen SWAP and REMOVE move up beside the minimap, where there is room.
const PLACE_TALL := {
	"roll": [Vector2(1, 1), Vector2(-92, -176)], "sprint": [Vector2(1, 1), Vector2(-224, -170)],
	"build": [Vector2(1, 1), Vector2(-190, -272)], "switch": [Vector2(1, 1), Vector2(-92, -312)],
	"remove": [Vector2(1, 1), Vector2(-178, -380)],
	"restart": [Vector2(0.5, 0.62), Vector2.ZERO], "help": [Vector2(1, 0), Vector2(-26, 200)], "stick": [Vector2(0, 1), Vector2(84, -230)],
}
const PLACE_WIDE := {
	"roll": [Vector2(1, 1), Vector2(-60, -62)], "sprint": [Vector2(1, 1), Vector2(-150, -62)],
	"build": [Vector2(1, 1), Vector2(-128, -134)], "switch": [Vector2(1, 1), Vector2(-60, -148)],
	"remove": [Vector2(1, 1), Vector2(-206, -116)],
	"restart": [Vector2(0.5, 0.62), Vector2.ZERO], "help": [Vector2(1, 0), Vector2(-152, 24)], "stick": [Vector2(0, 1), Vector2(84, -92)],
}

## The coach marks, shown one after another (STEP_SECONDS each): the controls they point at, and what to say.
const STEP_SECONDS := 2.4
const HINT_STEPS := [
	{"ids": ["stick"], "text": "Drag on the left side\nto MOVE"},
	{"ids": ["roll"], "text": "ROLL: dodge, and hit enemies\nyou pass through"},
	{"ids": ["sprint"], "text": "SPRINT: hold to run fast"},
	{"ids": ["build"], "text": "BUILD a tower or wall\n(costs bones)"},
	{"ids": ["switch", "remove"], "text": "SWAP tower / wall\nREMOVE: get 50% back"},
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
var _was_blocked := false
var _ready_flash := {}           ## button id -> 0..1, a ring when its cooldown ends
var _last_cd := {}
var hint_left := 0.0             ## seconds the coach marks stay up
var hint_used := {}              ## control id -> true once the player has used it (its mark fades)
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	main = get_parent().get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep seeing touches (and lifted fingers) while a menu pauses the game
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
	if visible:
		_first_run_hint()


static func _has_touchscreen() -> bool:
	if OS.has_feature("web"):
		var nav = JavaScriptBridge.get_interface("navigator")
		return nav != null and int(nav.maxTouchPoints) > 0
	return DisplayServer.is_touchscreen_available()


func _set_touch_mode(on: bool) -> void:
	if main != null:
		var was := bool(main.get("touch_mode"))
		main.set("touch_mode", on)
		if was != on and main.has_method("_fit_screen"):
			main._fit_screen()


## --- coach marks ---

## Show the coach marks once, on the very first run on this device.
func _first_run_hint() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(HINT_FILE) == OK and bool(cfg.get_value("touch", "hint_seen", false)):
		return
	show_hint()
	cfg.set_value("touch", "hint_seen", true)
	cfg.save(HINT_FILE)


func show_hint() -> void:
	hint_left = HINT_SECONDS
	hint_used.clear()


func hide_hint() -> void:
	hint_left = 0.0


func hint_showing() -> bool:
	return hint_left > 0.0


## The coach mark showing now (an index into HINT_STEPS).
func hint_step() -> int:
	return clampi(int((HINT_SECONDS - hint_left) / STEP_SECONDS), 0, HINT_STEPS.size() - 1)


## Using a control while its mark shows skips ahead to the next one (the last one closes the marks).
func _mark_used(id: String) -> void:
	if hint_left <= 0.0:
		return
	hint_used[id] = true
	var step := hint_step()
	if HINT_STEPS[step]["ids"].has(id):
		hint_left = HINT_SECONDS - STEP_SECONDS * (step + 1)


## --- layout ---

func _wide() -> bool:
	var vs := get_viewport_rect().size
	return vs.x >= vs.y


func _spot(id: String) -> Vector2:
	var vs := get_viewport_rect().size
	var p: Array = (PLACE_WIDE if _wide() else PLACE_TALL)[id]
	return Vector2(vs.x * float(p[0].x), vs.y * float(p[0].y)) + p[1]


## Where a button sits on the current screen.
func _pos(b: Dictionary) -> Vector2:
	return _spot(String(b["id"]))


## A button's radius on the current screen.
func _r(b: Dictionary) -> float:
	return float(R_WIDE.get(b["id"], b["r"])) if _wide() else float(b["r"])


func _stick_r() -> float:
	return STICK_R_WIDE if _wide() else STICK_R


func _help_r() -> float:
	return 16.0 if _wide() else HELP_R


## The screen rectangles the on-screen controls take (each button with its label, the idle stick, the "?"), so the
## notices can keep out of their way.
func ui_rects() -> Array:
	var out: Array = []
	if not visible or bool(main.get("game_over")):
		return out
	for b in BUTTONS:
		if bool(b.get("game_over", false)):
			continue
		var r := _r(b)
		var c := _pos(b)
		var px := _label_px(b)
		var hw := maxf(r, _font.get_string_size(_label_text(b), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x * 0.5 + 2.0)
		out.append(Rect2(c - Vector2(hw, r), Vector2(hw * 2.0, r + _label_gap() + px * 0.5 + 2.0 + r)))
	var sr := _stick_r()
	out.append(Rect2(_idle_stick() - Vector2(sr, sr), Vector2(sr * 2.0, sr * 2.0 + 24.0)))
	var hr := _help_r()
	out.append(Rect2(_spot("help") - Vector2(hr, hr), Vector2(hr, hr) * 2.0))
	return out


## The part of the screen where a thumb starts the stick.
func _zone() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(0.0, vs.y * 0.3, vs.x * 0.5, vs.y * 0.7)


func _idle_stick() -> Vector2:
	return _spot("stick")


func _place() -> void:
	for i in BUTTONS.size():
		var r := _r(BUTTONS[i])
		_pads[i].position = _pos(BUTTONS[i]) - Vector2(r, r)
		_pads[i].size = Vector2(r, r) * 2.0
	var z := _zone()
	_pads[BUTTONS.size()].position = z.position
	_pads[BUTTONS.size()].size = z.size


func _blocked() -> bool:
	return bool(main.get("menu_open")) or bool(main.get("game_over")) or get_tree().paused


## True over the on-screen build buttons (they take their own taps; the stick must not start there).
func _over_gui(p: Vector2) -> bool:
	var bar = main.get("hotbar")
	if bar == null:
		return false
	for b in bar:
		if is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_rect().grow(4.0).has_point(p):
			return true
	return false


## --- input ---

## Let go of everything: the stick, held buttons and pending taps (a menu opening or closing calls this).
func reset_touch() -> void:
	var had := _stick_id != -1 or not _down.is_empty() or not _release_next.is_empty()
	_stop_stick()
	for idx in _down:
		Input.action_release(_down[idx]["action"])
	_down.clear()
	for a in _release_next:
		Input.action_release(a)
	_release_next.clear()
	if visible or had:
		for b in BUTTONS:
			Input.action_release(b["action"])


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not visible:
			visible = true
			_set_touch_mode(true)
			_first_run_hint()
		var t: InputEventScreenTouch = event
		if t.pressed:
			if not _blocked() and t.position.distance_to(_spot("help")) <= maxf(_help_r() + 10.0, MIN_HIT):
				if hint_showing():
					hide_hint()
				else:
					show_hint()
				get_viewport().set_input_as_handled()
				return
			for b in BUTTONS:
				var go := bool(b.get("game_over", false))
				if go != bool(main.get("game_over")):
					continue
				if not go and _blocked():
					continue
				if t.position.distance_to(_pos(b)) <= maxf(_r(b) + 8.0, MIN_HIT):
					_down[t.index] = b
					if b["id"] == "roll":
						_aim_roll()
					Input.action_press(b["action"])
					if not bool(b["hold"]):
						_release_next.append(b["action"])
					_mark_used(String(b["id"]))
					get_viewport().set_input_as_handled()
					return
			if _stick_id == -1 and not _blocked() and _zone().has_point(t.position) and not _over_gui(t.position):
				_stick_id = t.index
				_stick_base = t.position
				_stick_pos = t.position
				_update_stick()
				_mark_used("stick")
				get_viewport().set_input_as_handled()
			elif hint_showing() and not _blocked() and not _over_gui(t.position):
				hide_hint()  # a tap anywhere else closes the coach marks
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


## With the stick at rest, turn 小怪 toward the nearest enemy close by, so the roll goes through it.
func _aim_roll() -> void:
	if _stick_vec != Vector2.ZERO:
		return
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or not pl.has_method("_nearest_enemy_to"):
		return
	var near = pl._nearest_enemy_to(ROLL_AIM)
	if near != null and near.global_position != pl.global_position:
		pl.facing = (near.global_position - pl.global_position).normalized()


func _update_stick() -> void:
	var v := _stick_pos - _stick_base
	var sr := _stick_r()
	if v.length() > sr:  # drag the base along so the thumb never runs out of room
		_stick_base = _stick_pos - v.normalized() * sr
		v = _stick_pos - _stick_base
	var f := v / sr
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
	if blocked != _was_blocked:
		reset_touch()  # a menu, the game-over screen or a pause just came or went: start clean
		_was_blocked = blocked
	# the pads only catch touches while the game is being played; menus and the game-over screen get plain taps
	for i in BUTTONS.size():
		var go: bool = bool(BUTTONS[i].get("game_over", false))
		var active := (go == bool(main.get("game_over"))) and (go or not blocked)
		_pads[i].mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	_pads[BUTTONS.size()].mouse_filter = Control.MOUSE_FILTER_IGNORE if blocked else Control.MOUSE_FILTER_STOP
	if not blocked and hint_left > 0.0:
		hint_left = maxf(hint_left - delta, 0.0)
	for b in BUTTONS:
		var id := String(b["id"])
		var cd := _cooldown(id).x
		if float(_last_cd.get(id, 0.0)) > 0.0 and cd <= 0.0:
			_ready_flash[id] = 1.0
		_last_cd[id] = cd
		_ready_flash[id] = maxf(float(_ready_flash.get(id, 0.0)) - delta * 2.5, 0.0)
	if visible:
		queue_redraw()


## --- drawing ---

func _draw() -> void:
	var held: Array = _down.values()
	var over := bool(main.get("game_over"))
	var menu := bool(main.get("menu_open"))
	var hint := hint_left > 0.0 and not over and not menu
	if hint:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0, 0, 0, 0.5 * clampf(hint_left, 0.0, 1.0)))
	# the stick: a faint hint where it will start, the real one under the thumb
	if not over and not menu:
		var live := _stick_id != -1
		var base := _stick_base if live else _idle_stick()
		var sr_ := _stick_r()
		draw_circle(base, sr_, Color(0.05, 0.06, 0.12, 0.4 if live else 0.24))
		draw_arc(base, sr_, 0, TAU, 48, Color(1, 1, 1, 0.6 if live else 0.45), 3.0)
		for i in 4:
			var d := Vector2.from_angle(i * TAU / 4.0 - PI / 2.0)
			draw_colored_polygon(PackedVector2Array([base + d * (sr_ - 10.0), base + d * (sr_ - 24.0) + d.orthogonal() * 8.0, base + d * (sr_ - 24.0) - d.orthogonal() * 8.0]), Color(1, 1, 1, 0.45 if live else 0.3))
		var knob := base + _stick_vec * sr_
		var kr := sr_ * 0.4
		draw_circle(knob, kr, Color(1, 1, 1, 0.5 if live else 0.25))
		draw_arc(knob, kr, 0, TAU, 28, Color(1, 1, 1, 0.85 if live else 0.4), 2.5)
		if not live:
			_label(base + Vector2(0, sr_ + (12.0 if _wide() else 18.0)), "MOVE", 12 if _wide() else 15, Color(1, 1, 1, 0.6))
		_help_button()
	for b in BUTTONS:
		var go := bool(b.get("game_over", false))
		if go != over or (not go and menu):
			continue
		_button(b, held.has(b))
	if hint:
		_draw_hints()


func _label(c: Vector2, text: String, px: int, col: Color, w: float = 160.0) -> void:
	_font.draw_string_outline(get_canvas_item(), c + Vector2(-w * 0.5, px * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, w, px, 5, Color(0, 0, 0, 0.85 * col.a))
	_font.draw_string(get_canvas_item(), c + Vector2(-w * 0.5, px * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, w, px, col)


func _button(b: Dictionary, on: bool) -> void:
	var id := String(b["id"])
	var c: Vector2 = _pos(b)
	var r0 := _r(b)
	var r: float = r0 * (0.93 if on else 1.0)
	var wide := _wide()
	var col: Color = b["col"]
	var big := id == "roll"
	var cdv := _cooldown(id)
	var cooling := cdv.x > 0.0
	var dim := 0.55 if cooling else 1.0
	# body: a dark disc with a coloured rim; the main button gets a warm filled face and a slow pulse
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, Color(0.04, 0.05, 0.1, 0.85 if on else 0.62))
	draw_circle(c, r - 4.0, Color(col, (0.42 if on else 0.18) * dim + (0.08 * sin(_t * 3.0) if big and not cooling else 0.0)))
	draw_arc(c, r - 1.5, 0, TAU, 48, Color(col, (1.0 if on else 0.85) * dim), 5.0 if big else 3.5)
	if big:
		draw_arc(c, r - 9.0, 0, TAU, 48, Color(col, 0.35 * dim), 2.0)
	# the cooldown: a dark sweep that shrinks clockwise, with the seconds left
	if cooling:
		var f := clampf(cdv.x / maxf(cdv.y, 0.001), 0.0, 1.0)
		var pts := PackedVector2Array([c])
		var a0 := -PI / 2.0 + TAU * (1.0 - f)
		for i in 33:
			pts.append(c + Vector2.from_angle(lerpf(a0, -PI / 2.0 + TAU, i / 32.0)) * (r - 3.0))
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0, 0, 0, 0.5))
	_icon(id, c, r * (0.4 if big else 0.46), Color(1, 1, 1, (1.0 if on else 0.92) * (0.6 if cooling else 1.0)))
	if cooling and cdv.x >= 0.95:
		_label(c, "%d" % ceili(cdv.x), (16 if big else 14) if wide else (24 if big else 20), Color(1, 1, 1, 0.95))
	# a ring that bursts out when it is ready again
	var fl := float(_ready_flash.get(id, 0.0))
	if fl > 0.0:
		draw_arc(c, r + (1.0 - fl) * 16.0, 0, TAU, 40, Color(col, fl), 3.0)
	# what it does, under it
	_label(c + Vector2(0, r0 + _label_gap()), _label_text(b), _label_px(b), Color(col.lightened(0.45), 0.98))


## A button's caption (BUILD shows what the next building costs).
func _label_text(b: Dictionary) -> String:
	if b["id"] == "build" and main.get("build_item") != null:
		return "BUILD %s" % main.build_cost(main.build_item, Vector2i(-1, -1))
	return String(b["label"])


func _label_px(b: Dictionary) -> int:
	var big: bool = b["id"] == "roll"
	return (12 if not big else 13) if _wide() else (15 if not big else 17)


## How far below a button's edge its caption's middle sits.
func _label_gap() -> float:
	return 9.0 if _wide() else 13.0


## The "?" button that brings the coach marks back.
func _help_button() -> void:
	var c := _spot("help")
	var hr := _help_r()
	var on := hint_left > 0.0
	draw_circle(c, hr, Color(0.04, 0.05, 0.1, 0.7))
	draw_arc(c, hr - 1.0, 0, TAU, 32, Color(1, 0.88, 0.55, 0.95 if on else 0.7), 2.5)
	_label(c + Vector2(0, 1), "?", int(hr * 1.1), Color(1, 0.92, 0.6, 1.0))


## (seconds left, full length) for the buttons that have a cooldown.
func _cooldown(id: String) -> Vector2:
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null:
		return Vector2.ZERO
	match id:
		"roll":
			return Vector2(float(pl.roll_cd), float(pl.ROLL_COOLDOWN))
		"sprint":
			return Vector2(float(pl.sprint_cd), float(pl.SPRINT_COOLDOWN))
	return Vector2.ZERO


func _icon(id: String, c: Vector2, s: float, col: Color) -> void:
	match id:
		"roll":
			# a rolling arrow with two fangs inside: a dodge that bites what it passes
			draw_arc(c, s * 1.0, 0.5, TAU - 0.8, 28, col, 5.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 1.0, -s * 0.85), c + Vector2(s * 1.6, -s * 0.05), c + Vector2(s * 0.4, 0.05)]), col)
			for sx in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([c + Vector2(sx * s * 0.55, -s * 0.45), c + Vector2(sx * s * 0.1, -s * 0.45), c + Vector2(sx * s * 0.32, s * 0.5)]), col)
		"sprint":
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.3, -s * 1.15), c + Vector2(-s * 0.8, s * 0.2), c + Vector2(-s * 0.1, s * 0.2), c + Vector2(-s * 0.4, s * 1.15), c + Vector2(s * 0.8, -s * 0.3), c + Vector2(s * 0.1, -s * 0.3)]), col)
			_sprint_meter(c, s)
		"build":
			var item := String(main.get("build_item")) if main.get("build_item") != null else "tower"
			_tex(Sprites.tex("icon_build_" + item), c, s * 2.2, col)
		"remove":
			_tex(Sprites.tex("icon_build_remove"), c, s * 2.2, col)
		"switch":
			draw_line(c + Vector2(-s, -s * 0.4), c + Vector2(s * 0.9, -s * 0.4), col, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.8, -s * 0.85), c + Vector2(s * 1.35, -s * 0.4), c + Vector2(s * 0.8, s * 0.05)]), col)
			draw_line(c + Vector2(-s * 0.9, s * 0.4), c + Vector2(s, s * 0.4), col, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.05), c + Vector2(-s * 1.35, s * 0.4), c + Vector2(-s * 0.8, s * 0.85)]), col)
		"restart":
			draw_arc(c, s * 0.9, 0.6, TAU - 0.5, 24, col, 5.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.9, -s * 1.1), c + Vector2(s * 1.5, -s * 0.2), c + Vector2(s * 0.3, -s * 0.1)]), col)


## A pixel icon centred at `c`, `w` wide, keeping its hard edges.
func _tex(t: Texture2D, c: Vector2, w: float, col: Color) -> void:
	if t == null:
		return
	draw_texture_rect(t, Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w)), false, col)


## The sprint energy as a thin arc inside the ring while it is not cooling down.
func _sprint_meter(c: Vector2, s: float) -> void:
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or float(pl.sprint_cd) > 0.0:
		return
	var f := clampf(float(pl.sprint_energy) / maxf(float(pl.SPRINT_MAX), 0.001), 0.0, 1.0)
	if f < 0.999:
		draw_arc(c, s * 1.6, -PI / 2.0, -PI / 2.0 + TAU * f, 32, Color(1, 0.85, 0.3, 0.9), 3.0)


## The coach marks: the auto-bite note on top, then one bubble at a time with a line to the control it explains,
## progress dots, and how to close them.
func _draw_hints() -> void:
	var vs := get_viewport_rect().size
	var a := clampf(hint_left * 2.0, 0.0, 1.0)
	var wide := _wide()
	var top_y := 150.0 if wide else 70.0  # over the dimmed HUD when upright, so the bubbles never reach the buttons
	_bubble(Rect2(Vector2(vs.x * 0.5 - 190.0, top_y - 30.0), Vector2(380, 58)), "Bites are AUTOMATIC:\njust walk close to villagers!", 18, Color(1, 0.85, 0.35), a)
	var step := hint_step()
	var st: Dictionary = HINT_STEPS[step]
	var box_c := Vector2(vs.x * 0.42, top_y + 100.0) if wide else Vector2(vs.x * 0.5, top_y + 120.0)
	var box := Rect2(box_c - Vector2(150, 34), Vector2(300, 68))
	for id in st["ids"]:
		var target := _idle_stick() if id == "stick" else _pos(_button_def(id))
		var r := _stick_r() if id == "stick" else _r(_button_def(id))
		var from := Vector2(clampf(target.x, box.position.x + 20.0, box.end.x - 20.0), box.end.y if target.y > box.end.y else box.position.y)
		var tip := target + (from - target).normalized() * (r + 8.0)
		draw_line(from, tip, Color(1, 0.9, 0.6, 0.9 * a), 3.0)
		draw_circle(tip, 5.0, Color(1, 0.9, 0.6, a))
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_arc(target, r + 6.0 + 4.0 * pulse, 0, TAU, 48, Color(1, 0.9, 0.6, (0.6 + 0.4 * pulse) * a), 3.0)
		if id == "stick":
			# a thumb sliding to show the drag
			var k := fposmod(_t * 0.9, 1.0)
			draw_circle(target + Vector2.from_angle(-PI * 0.25) * r * 0.7 * sin(k * PI), 12.0, Color(1, 0.9, 0.6, 0.6 * a))
	var col := Color(1, 1, 1) if st["ids"][0] == "stick" else Color(_button_def(st["ids"][0])["col"]).lightened(0.45)
	_bubble(box, st["text"], 20, col, a)
	# progress dots and the way out, right under the top note
	var cx := vs.x * 0.5
	for i in HINT_STEPS.size():
		var dc := Vector2(cx - (HINT_STEPS.size() - 1) * 8.0 + i * 16.0, top_y + 38.0)
		draw_circle(dc, 4.0 if i == step else 3.0, Color(1, 0.9, 0.6, (1.0 if i <= step else 0.35) * a))
	_label(Vector2(cx, top_y + 54.0), "Tap anywhere to close", 14, Color(1, 1, 1, 0.85 * a), 300.0)


func _button_def(id: String) -> Dictionary:
	for b in BUTTONS:
		if b["id"] == id:
			return b
	return BUTTONS[0]


func _bubble(r: Rect2, text: String, px: int, col: Color, a: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.09, 0.92 * a)
	sb.border_color = Color(col, 0.9 * a)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, r)
	var lines := text.split("\n")
	var lh := px + 4.0
	var y0 := r.get_center().y - lh * (lines.size() - 1) * 0.5 + px * 0.35
	for i in lines.size():
		_font.draw_string(get_canvas_item(), Vector2(r.position.x, y0 + i * lh), lines[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, Color(col, a))
