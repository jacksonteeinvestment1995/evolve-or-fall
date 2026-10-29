extends RefCounted
## The level-up cards (skill, special, perk and evolution line picks), built from real controls so they read well on a
## phone: a big pixel icon in a frame, the name, ONE short line of what it does, a small coloured tag (LINE / GENERAL /
## SPECIAL / UPGRADE or the family), an AUTO tag for skills that fire by themselves, and rank pips (filled = owned,
## the glowing one = what this pick adds). The whole card is one button; keys 1..9 still pick on a desktop.
## Card data: {icon, name, short, tag, tag_col, accent, auto, rank, max}

const INK := Color(1, 0.97, 0.9)
const SOFT := Color(0.86, 0.84, 0.78)
const GOLD := Color("ffd84a")


## Card sizes for the menu: name and text fonts, icon frame, card height.
static func metrics(compact: bool) -> Dictionary:
	if compact:
		return {"name": 22, "text": 16, "icon": 64, "h": 80, "tag": 12}
	return {"name": 26, "text": 20, "icon": 80, "h": 104, "tag": 13}


static func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(bw)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 0
	b.content_margin_right = 0
	return b


static func _label(text: String, px: int, col: Color, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A small rounded tag such as LINE or AUTO.
static func tag(text: String, col: Color, px: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _box(Color(col, 0.22), Color(col, 0.9), 1, 6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	var l := _label(text, px, col.lightened(0.35))
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## One card. `key` is the 1-based number shown in the corner on a desktop (0 hides it).
static func card(d: Dictionary, w: float, m: Dictionary, key: int) -> Button:
	var accent: Color = d.get("accent", GOLD)
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, m["h"])
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = ""
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _box(Color(0.07, 0.08, 0.12, 0.95), Color(accent, 0.55), 2, 12))
	b.add_theme_stylebox_override("hover", _box(Color(0.12, 0.13, 0.19, 0.97), Color(accent, 0.95), 3, 12))
	b.add_theme_stylebox_override("pressed", _box(Color(accent.darkened(0.55), 0.98), Color(1, 1, 1, 0.95), 3, 12))
	b.add_theme_stylebox_override("hover_pressed", _box(Color(accent.darkened(0.55), 0.98), Color(1, 1, 1, 0.95), 3, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10 if side != "left" else 10)
	b.add_child(pad)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	pad.add_child(row)
	# the icon in a dark frame with a coloured rim
	var frame := Panel.new()
	frame.name = "IconFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h: float = m["h"]
	var isz: float = minf(float(m["icon"]), h - 16.0)
	var name_px: int = m["name"] if h >= 100.0 else (22 if h >= 76.0 else 19)
	frame.custom_minimum_size = Vector2(isz, isz)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _box(Color(0.02, 0.02, 0.05, 0.9), Color(accent, 0.8), 2, 10))
	row.add_child(frame)
	var tex := TextureRect.new()
	tex.name = "Icon"
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.texture = d.get("icon")
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 5
	tex.offset_top = 5
	tex.offset_right = -5
	tex.offset_bottom = -5
	frame.add_child(tex)
	if key > 0:
		var k := _label(str(key), m["tag"] + 1, GOLD, 5)
		k.position = Vector2(4, -2)
		frame.add_child(k)
	# the words: name and tags, the one short line, rank pips
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	# the name shrinks (down to 18 px) to fit beside its tags before it is cut with "..."
	var font0: Font = ThemeDB.fallback_font
	var tags_w := 0.0
	for tg in (["AUTO"] if bool(d.get("auto", false)) else []) + ([str(d.get("tag", ""))] if (str(d.get("tag", "")) != "" and w >= 300.0) else []):
		tags_w += font0.get_string_size(tg, HORIZONTAL_ALIGNMENT_LEFT, -1, m["tag"]).x + 18.0
	var name_w := w - 20.0 - isz - 12.0 - tags_w
	while name_px > 18 and font0.get_string_size(str(d.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x > name_w:
		name_px -= 1
	var name_l := _label(str(d.get("name", "")), name_px, INK, 4)
	name_l.name = "Name"
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_l)
	if bool(d.get("auto", false)):
		top.add_child(tag("AUTO", Color("7be07b"), m["tag"]))
	if str(d.get("tag", "")) != "" and w >= 300.0:  # a narrow card keeps just its coloured rim
		top.add_child(tag(str(d["tag"]), d.get("tag_col", accent), m["tag"]))
	# the short line: the biggest size (down to 14 px) at which the full text, or else the shorter one, fits the card;
	# past that it is cut with "..."
	var has_pips := int(d.get("max", 0)) > 1
	var text_w := w - 20.0 - isz - 12.0
	var room := h - 22.0 - font0.get_height(name_px) - (16.0 if has_pips else 0.0)
	var font: Font = ThemeDB.fallback_font
	var options: Array = [str(d.get("short", ""))]
	if d.has("short_narrow"):
		options.append(str(d["short_narrow"]))
	var words: String = options[options.size() - 1]
	var px := 15
	var found := false
	for size_try in range(int(m["text"]), 13, -1):
		for text in options:
			if not found and _text_h(font, text, text_w, size_try) <= room:
				words = text
				px = size_try
				found = true
		if found:
			break
	var short_l := _label(words, px, SOFT)
	var line_h := font.get_height(px) + 3.0
	short_l.max_lines_visible = maxi(1, int(room / line_h))
	short_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	short_l.name = "Short"
	short_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	short_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(short_l)
	if int(d.get("max", 0)) > 1:
		var pips := Pips.new()
		pips.have = int(d.get("rank", 0))
		pips.most = int(d["max"])
		pips.col = accent
		pips.custom_minimum_size = Vector2(16.0 * pips.most, 12)
		col.add_child(pips)
	return b


## How tall a wrapped label of this text comes out (lines times the label's line height).
static func _text_h(font: Font, text: String, width: float, px: int) -> float:
	var lines := ceili(font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, px).y / font.get_height(px) - 0.01)
	return lines * (font.get_height(px) + 3.0)


## Rank pips: filled for the ranks owned, a glowing one for the rank this pick adds, hollow for the rest.
class Pips extends Control:
	var have := 0
	var most := 1
	var col := Color.WHITE
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for i in most:
			var c := Vector2(6.0 + i * 16.0, size.y * 0.5)
			if i < have:
				draw_circle(c, 5.0, Color("ffd84a"))
			elif i == have:
				var g := 0.6 + 0.4 * sin(_t * 6.0)
				draw_circle(c, 7.5, Color(0.6, 1.0, 0.6, 0.25 * g))
				draw_circle(c, 5.0, Color(0.6, 1.0, 0.6, g))
			else:
				draw_arc(c, 4.5, 0, TAU, 16, Color(1, 1, 1, 0.35), 1.5)
