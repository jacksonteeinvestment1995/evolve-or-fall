extends Control
## A small notice for web players whose browser draws the game on the CPU (graphics acceleration off): it names the
## setting to turn on. It shows when the graphics adapter looks like a software renderer, or when the frame rate stays
## very low for a while. It shows at most once per browser (a marker file in user://) and can be closed with one tap.

const SEEN_FILE := "user://perf_notice_seen"
const SOFTWARE_NAMES := ["swiftshader", "software", "llvmpipe", "basic render", "softpipe", "warp"]
const LOW_FPS := 24.0
const LOW_FPS_SECONDS := 10.0   ## how long the frame rate must stay under LOW_FPS
const GRACE_SECONDS := 20.0     ## no verdict while the game is loading and settling

var _low_time := 0.0
var _age := 0.0
var _shown := false
var panel: PanelContainer
var copy_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not enabled():
		set_process(false)
	elif software_renderer(_adapter_name()):
		call_deferred("show_notice")


## Web builds only (headless runs and tests can switch it on with the "perf_notice" meta), and only if not seen before.
func enabled() -> bool:
	if Engine.has_meta("perf_notice"):
		return true
	if DisplayServer.get_name() == "headless" or not OS.has_feature("web"):
		return false
	return not FileAccess.file_exists(SEEN_FILE)


static func software_renderer(adapter: String) -> bool:
	var a := adapter.to_lower()
	for n in SOFTWARE_NAMES:
		if a.contains(n):
			return true
	return false


func _adapter_name() -> String:
	return str(Engine.get_meta("fake_adapter", "")) if Engine.has_meta("fake_adapter") else RenderingServer.get_video_adapter_name()


func _process(delta: float) -> void:
	if _shown:
		return
	_age += delta
	if _age < GRACE_SECONDS:
		return
	if Engine.get_frames_per_second() < LOW_FPS and not get_tree().paused:
		_low_time += delta
		if _low_time >= LOW_FPS_SECONDS:
			show_notice()
	else:
		_low_time = maxf(_low_time - delta, 0.0)


func show_notice() -> void:
	if _shown:
		return
	_shown = true
	set_process(false)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	panel.position.y = 14.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.1, 0.94)
	sb.border_color = Color("ffd84a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_label("Game slow?", 22, Color("ffd84a")))
	var body := _label("Turn on graphics acceleration.\nTap COPY, open a new tab, paste the link, switch it on, restart the browser.", 16, Color(1, 1, 1, 0.92))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(minf(380.0, get_viewport_rect().size.x - 60.0), 0)
	box.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	copy_button = _button("COPY LINK")
	copy_button.pressed.connect(copy_link)
	row.add_child(copy_button)
	var ok := _button("CLOSE")
	ok.pressed.connect(dismiss)
	row.add_child(ok)
	add_child(panel)
	panel.reset_size()
	panel.position.x = (get_viewport_rect().size.x - panel.size.x) * 0.5


## A web page may not open the browser's own settings pages, so the link is copied for the player to paste in a new tab.
func settings_link() -> String:
	var edge := false
	if OS.has_feature("web"):
		edge = str(JavaScriptBridge.get_interface("navigator").userAgent).contains("Edg/")
	return ("edge" if edge else "chrome") + "://settings/system"


func copy_link() -> void:
	DisplayServer.clipboard_set(settings_link())
	if copy_button != null:
		copy_button.text = "COPIED - paste in new tab"


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(120, 44)
	b.add_theme_font_size_override("font_size", 18)
	return b


func dismiss() -> void:
	if panel != null:
		panel.queue_free()
		panel = null
	if not Engine.has_meta("perf_notice"):
		var f := FileAccess.open(SEEN_FILE, FileAccess.WRITE)
		if f != null:
			f.store_string("1")
			f.close()


func _label(text: String, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l
