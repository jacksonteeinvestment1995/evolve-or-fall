class_name Sprites
## Loads the pixel art in art/export. Each PNG is a horizontal strip of square frames.
## Needs the editor import step (godot --headless --import) after new PNGs are added.

const DIR := "res://art/export/"
const LINE_PREFIX := ["farmer", "woodsman", "hunter", "militia", "knight", "priest", "mage", "smith", "thief", "noble"]
const HIDDEN_FILE := ["hidden_parasite_hero", "hidden_dark_hero", "hidden_god"]

static var _cache := {}
static var _names: PackedStringArray = PackedStringArray()


static func _all_names() -> PackedStringArray:
	if _names.is_empty():
		var seen := {}
		for f in DirAccess.get_files_at(DIR):
			# in an exported game the folder lists "x.png.import" (or ".remap") instead of "x.png"
			var n := f
			if n.ends_with(".import") or n.ends_with(".remap"):
				n = n.get_basename()
			if n.ends_with(".png") and not seen.has(n):
				seen[n] = true
				_names.append(n.trim_suffix(".png"))
	return _names


## Texture for an exact file name (without .png), or null when missing.
static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[name] = t
	return t


## A small icon scaled up with hard edges (for menu buttons), or null.
## Frame 0 of a strip scaled up with hard edges (a form's picture for a menu), or null.
## A warm, packed-earth tile for village paths, generated once.
static func dirt_tex() -> Texture2D:
	if _cache.has("#dirt"):
		return _cache["#dirt"]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for y in 32:
		for x in 32:
			var n := rng.randf()
			var c := Color(0.74, 0.58, 0.38)
			if n < 0.18:
				c = Color(0.66, 0.5, 0.32)
			elif n > 0.86:
				c = Color(0.82, 0.68, 0.46)
			img.set_pixel(x, y, c)
	for i in 7:
		var px := rng.randi_range(2, 28)
		var py := rng.randi_range(2, 28)
		for dx in 2:
			for dy in 2:
				img.set_pixel(px + dx, py + dy, Color(0.55, 0.46, 0.38))
		img.set_pixel(px, py, Color(0.7, 0.62, 0.52))
	var t := ImageTexture.create_from_image(img)
	_cache["#dirt"] = t
	return t


static func first_frame_icon(name: String, factor: int = 3) -> Texture2D:
	var key := "%s#first%d" % [name, factor]
	if _cache.has(key):
		return _cache[key]
	var t := tex(name)
	var out: Texture2D = null
	if t != null:
		var fh := t.get_height()
		var img := t.get_image().get_region(Rect2i(0, 0, fh, fh))
		img.resize(fh * factor, fh * factor, Image.INTERPOLATE_NEAREST)
		out = ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


static func icon(name: String, factor: int = 2) -> Texture2D:
	var key := "%s#icon%d" % [name, factor]
	if _cache.has(key):
		return _cache[key]
	var t := tex(name)
	var out: Texture2D = null
	if t != null:
		var img := t.get_image()
		img.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
		out = ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


## The same strip mirrored left to right, frame by frame (frame order is kept).
static func tex_flipped(name: String) -> Texture2D:
	var key := name + "#flip"
	if _cache.has(key):
		return _cache[key]
	var t := tex(name)
	var out: Texture2D = null
	if t != null:
		var img := t.get_image()
		var fh := img.get_height()
		for i in img.get_width() / fh:
			var frame := img.get_region(Rect2i(i * fh, 0, fh, fh))
			frame.flip_x()
			img.blit_rect(frame, Rect2i(0, 0, fh, fh), Vector2i(i * fh, 0))
		out = ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


## The strip with every frame's pupils moved one pixel (two on big sprites) toward look
## (each part -1, 0 or 1; look is in screen terms, flip mirrors the whole sprite afterwards).
## Pupils are dark pixels touching an eye white (near-white); a sprite without eyes comes back unchanged.
static func tex_look(name: String, look: Vector2i, flip: bool) -> Texture2D:
	if look == Vector2i.ZERO:
		return tex_flipped(name) if flip else tex(name)
	var key := "%s#look%d,%d,%s" % [name, look.x, look.y, flip]
	if _cache.has(key):
		return _cache[key]
	var t := tex(name)
	var out: Texture2D = null
	if t != null:
		var img := t.get_image()
		var fh := img.get_height()
		var step := 2 if fh >= 32 else 1
		var d := Vector2i(-look.x if flip else look.x, look.y) * step
		for i in img.get_width() / fh:
			_shift_pupils(img, Rect2i(i * fh, 0, fh, fh), d)
			if flip:
				var frame := img.get_region(Rect2i(i * fh, 0, fh, fh))
				frame.flip_x()
				img.blit_rect(frame, Rect2i(0, 0, fh, fh), Vector2i(i * fh, 0))
		out = ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


static func _is_white(c: Color) -> bool:
	return c.a > 0.5 and c.r > 0.82 and c.g > 0.82 and c.b > 0.82


static func _shift_pupils(img: Image, area: Rect2i, d: Vector2i) -> void:
	var pupils: Array[Vector2i] = []
	var whites := {}
	var white_col := Color.WHITE
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if _is_white(img.get_pixel(x, y)):
				whites[Vector2i(x, y)] = true
				white_col = img.get_pixel(x, y)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.r < 0.35 and c.g < 0.35 and c.b < 0.35:
				for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if whites.has(Vector2i(x, y) + n):
						pupils.append(Vector2i(x, y))
						break
	if pupils.is_empty():
		_shift_dark_eyes(img, area, d)
		return
	var cols := {}
	for q in pupils:
		cols[q] = img.get_pixel(q.x, q.y)
	for q in pupils:
		img.set_pixel(q.x, q.y, white_col)
	for q in pupils:
		var to: Vector2i = q + d
		if whites.has(to) or cols.has(to):
			img.set_pixel(to.x, to.y, cols[q])
		else:
			img.set_pixel(q.x, q.y, cols[q])  # no room to move: stay put


## Eyes with no white (dark slits on a coloured face): dark pixels with an opaque pixel on all four
## sides slide one step toward the look direction, as long as they stay on the face.
static func _shift_dark_eyes(img: Image, area: Rect2i, d: Vector2i) -> void:
	var eyes: Array[Vector2i] = []
	for y in range(area.position.y + 1, area.end.y - 1):
		for x in range(area.position.x + 1, area.end.x - 1):
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.r < 0.14 and c.g < 0.14 and c.b < 0.2:
				var ok := true
				for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if img.get_pixel(x + n.x, y + n.y).a < 0.5:
						ok = false
				if ok:
					eyes.append(Vector2i(x, y))
	if eyes.is_empty():
		return
	var dark := img.get_pixel(eyes[0].x, eyes[0].y)
	var face := img.get_pixel(eyes[0].x + 1, eyes[0].y)
	var is_eye := {}
	for q in eyes:
		is_eye[q] = true
	for q in eyes:
		img.set_pixel(q.x, q.y, face)
	for q in eyes:
		var to: Vector2i = q + Vector2i(signi(d.x), signi(d.y))
		var tc := img.get_pixel(to.x, to.y)
		if tc.a > 0.5 and tc.r > 0.3:
			img.set_pixel(to.x, to.y, dark)
		else:
			img.set_pixel(q.x, q.y, dark)


## First plain (non attack / walk / night) file that starts with the prefix, e.g. "farmer_2_".
static func find(prefix: String) -> String:
	for n in _all_names():
		if n.begins_with(prefix) and not n.ends_with("_attack") and not n.ends_with("_walk"):
			return n
	return ""


static func villager(line: int, stage: int, secret: int) -> String:
	if secret >= 0:
		return HIDDEN_FILE[secret]
	return find("%s_%d_" % [LINE_PREFIX[line], stage + 1])


static func _slug(form_name: String) -> String:
	return form_name.to_lower().replace(" ", "_").replace("-", "_")


## Hero art for a line, by form number (0 = Xiao Guai base, 1 to 10 = his evolution). The line is
## found from its first form's name; unfinished forms fall back to the nearest earlier one with
## art. Returns "" when the line has no art yet, so the caller can draw its placeholder.
static func hero(forms: Array, form: int) -> String:
	if form <= 0:
		return "xiaoguai_base"
	var first := _slug(forms[0])
	var prefix := ""
	for n in _all_names():
		if n.ends_with("_01_" + first):
			prefix = n.trim_suffix("_01_" + first)
			break
	if prefix == "":
		return ""
	for f in range(form, 0, -1):
		var n := find("%s_%02d_" % [prefix, f])
		if n != "":
			return n
	return ""


## Draw frame `frame` of a strip centred on the origin, `size` pixels wide on screen.
static func draw(ci: CanvasItem, name: String, frame: int, size: float, flip: bool = false, modulate: Color = Color.WHITE, look: Vector2i = Vector2i.ZERO, walk: float = -1.0) -> bool:
	var t := tex_look(name, look, flip)
	if t == null:
		return false
	var fh := t.get_height()
	var frames := maxi(1, t.get_width() / fh)
	var src := Rect2((frame % frames) * fh, 0, fh, fh)
	size *= sqrt(fh / 16.0)  # bigger frames are bigger forms, softened because the body also grows
	var dst := Rect2(-size * 0.5, -size * 0.6, size, size)
	if walk < 0.0:
		ci.draw_texture_rect_region(t, dst, src, modulate)
		return true
	# Walking: the body is drawn in ONE piece (no slices, so no seams) and only the feet are separate.
	#  - a one-pixel hop and a one-pixel waddle, both snapped to whole sprite pixels;
	#  - the body is stretched down by the hop so it always touches the feet;
	#  - the feet (bottom fifth) split down the middle, one lifting a pixel at a time.
	var s := sin(walk)
	var px := size / float(fh)
	var leg_row := int(fh * 0.8)
	var hop := (px if absf(s) > 0.55 else 0.0)
	var lean := px * (1.0 if s > 0.55 else (-1.0 if s < -0.55 else 0.0))
	var body_h := leg_row * px
	ci.draw_texture_rect_region(t, Rect2(dst.position.x + lean, dst.position.y - hop, size, body_h + hop), Rect2(src.position.x, src.position.y, fh, leg_row), modulate)
	var leg_h := (fh - leg_row) * px
	var half_w := fh * 0.5
	var lift_l := (px if s > 0.55 else 0.0)
	var lift_r := (px if s < -0.55 else 0.0)
	var ly := dst.position.y + body_h
	ci.draw_texture_rect_region(t, Rect2(dst.position.x, ly - lift_l, size * 0.5, leg_h), Rect2(src.position.x, src.position.y + leg_row, half_w, fh - leg_row), modulate)
	ci.draw_texture_rect_region(t, Rect2(dst.position.x + size * 0.5, ly - lift_r, size * 0.5, leg_h), Rect2(src.position.x + half_w, src.position.y + leg_row, half_w, fh - leg_row), modulate)
	return true
