extends Control
## "TAP TO START": a phone browser keeps the game silent until the page gets a real tap, and the joystick and attack
## buttons read raw touches that do not count. This panel holds the game paused behind one big real Button; tapping it
## unlocks the sound and starts (or, after the app was switched away, continues) the game. main.gd opens and closes it.

signal started

var title := "TAP TO START"
var button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var name_l := _label("EVOLVE OR FALL", 34, Color("ffd84a"), 8)
	box.add_child(name_l)
	button = Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(280, 76)
	button.add_theme_font_size_override("font_size", 30)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, Color(1, 0.97, 0.88))
	button.add_theme_stylebox_override("normal", _box(Color(0.32, 0.16, 0.05, 0.95), Color("ffd84a")))
	button.add_theme_stylebox_override("hover", _box(Color(0.4, 0.2, 0.06, 0.95), Color("ffe88a")))
	button.add_theme_stylebox_override("pressed", _box(Color(0.55, 0.3, 0.08, 1.0), Color.WHITE))
	button.add_theme_stylebox_override("hover_pressed", _box(Color(0.55, 0.3, 0.08, 1.0), Color.WHITE))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func(): started.emit())
	box.add_child(button)
	box.add_child(_label("Sound on - best with headphones", 16, Color(1, 1, 1, 0.8), 4))


func _label(text: String, px: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	return l


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(3)
	b.set_corner_radius_all(14)
	b.shadow_color = Color(0, 0, 0, 0.4)
	b.shadow_size = 6
	return b
