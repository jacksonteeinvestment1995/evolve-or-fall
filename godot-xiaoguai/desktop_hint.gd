extends Control
## The keyboard and mouse tutorial: a short "how to play" card shown on the first run on a computer (the phone has its own
## coach marks in touch_controls.gd). It never pauses the game and fades by itself; H or F1 brings it back later.

const SEEN_FILE := "user://desktop_hint_seen"
const SHOW_SECONDS := 30.0

var panel: PanelContainer
var close_button: Button
var _left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if first_run():
		show_hint()


## True on a computer (no touch screen, not a headless run) that has not seen the card yet.
func first_run() -> bool:
	if Engine.has_meta("desktop_hint"):
		return false
	if DisplayServer.get_name() == "headless" or preload("res://touch_controls.gd")._has_touchscreen():
		return false
	return not FileAccess.file_exists(SEEN_FILE)


func showing() -> bool:
	return panel != null


func show_hint() -> void:
	if panel != null:
		return
	_left = SHOW_SECONDS
	panel = PanelContainer.new()
	panel.position = Vector2(16, 190)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.1, 0.82)
	sb.border_color = Color("ffd84a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_child(_label("HOW TO PLAY", 22, Color("ffd84a")))
	box.add_child(_row(["W", "A", "S", "D"], "Move (or hold the left mouse button)"))
	box.add_child(_row([], "Biting is automatic: walk up to villagers"))
	box.add_child(_row(["SPACE"], "ROLL: dodge, and hit what you pass through"))
	box.add_child(_row(["SHIFT"], "Hold to sprint"))
	box.add_child(_row(["E"], "Build (costs bones)  ·  1 / 2 tower or wall"))
	box.add_child(_row(["X"], "Remove a building (get bones back)"))
	box.add_child(_row(["1", "2", "3"], "Pick a card when you level up"))
	box.add_child(_label("Grow, evolve, and beat the rival hero.", 15, Color(1, 1, 1, 0.8)))
	close_button = Button.new()
	close_button.text = "GOT IT  (H shows this again)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(0, 36)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.pressed.connect(dismiss)
	box.add_child(close_button)
	add_child(panel)
	panel.reset_size()


func dismiss() -> void:
	if panel != null:
		panel.queue_free()
		panel = null
		close_button = null
	if not Engine.has_meta("desktop_hint"):
		var f := FileAccess.open(SEEN_FILE, FileAccess.WRITE)
		if f != null:
			f.store_string("1")
			f.close()


func _process(delta: float) -> void:
	if panel == null:
		return
	_left -= delta
	panel.modulate.a = clampf(_left, 0.0, 1.0)
	if _left <= 0.0:
		dismiss()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_H or k.keycode == KEY_F1):
		if panel != null:
			dismiss()
		else:
			show_hint()
		get_viewport().set_input_as_handled()


## One line: key caps (if any) and what they do.
func _row(keys: Array, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caps := HBoxContainer.new()
	caps.add_theme_constant_override("separation", 3)
	caps.custom_minimum_size = Vector2(150, 0)
	caps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in keys:
		caps.add_child(_cap(k))
	row.add_child(caps)
	row.add_child(_label(text, 16, Color(1, 1, 1, 0.95)))
	return row


func _cap(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.24, 0.32)
	sb.border_color = Color(0.8, 0.82, 0.9)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_label(text, 15, Color("ffe08a")))
	return p


func _label(text: String, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l
