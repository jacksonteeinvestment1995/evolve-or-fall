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
		for f in DirAccess.get_files_at(DIR):
			if f.ends_with(".png"):
				_names.append(f.trim_suffix(".png"))
	return _names


## Texture for an exact file name (without .png), or null when missing.
static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[name] = t
	return t


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
static func draw(ci: CanvasItem, name: String, frame: int, size: float, flip: bool = false, modulate: Color = Color.WHITE) -> bool:
	var t := tex_flipped(name) if flip else tex(name)
	if t == null:
		return false
	var fh := t.get_height()
	var frames := maxi(1, t.get_width() / fh)
	var src := Rect2((frame % frames) * fh, 0, fh, fh)
	size *= sqrt(fh / 16.0)  # bigger frames are bigger forms, softened because the body also grows
	var dst := Rect2(-size * 0.5, -size * 0.6, size, size)
	ci.draw_texture_rect_region(t, dst, src, modulate)
	return true
