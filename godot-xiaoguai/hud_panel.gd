extends Control
## The top-left HUD, drawn with icons and bars instead of sentences, and animated:
##   row 1  level star, EXP bar, heart + HP bar, sun/moon + day number + time-left bar
##   row 2  bones, kills, villagers alive, village level
##   row 3  sprint bar, roll and lunge cooldown rings, buff and relic chips
##   row 4  what the build key does right now
## Bars ease toward their value, HP leaves a pale damage trail and beats faster when low, numbers pop when they
## change, the level star bursts on a level-up, cooldown rings flash when ready, and the sun, moon and chips move.
## main.gd calls set_info() with fresh values; everything else happens here.

const INK := Color(1, 1, 1, 0.95)
const SHADOW := Color(0, 0, 0, 0.6)
const BAR_W := 150.0
const BAR_H := 14.0
const PLATE := Rect2(-12, -8, 586, 130)

var info := {}
var _prev := {}
var _t := 0.0
var _font: Font = ThemeDB.fallback_font
var _plate_box := StyleBoxFlat.new()
var _bar_box := StyleBoxFlat.new()
var _fill_box := StyleBoxFlat.new()

# eased display values
var _xp := 0.0
var _hp := 0.0
var _hp_trail := 0.0
var _bones := 0.0
var _kills := 0.0
# short-lived effects
var _pop := {}            ## name -> 0..1, a number "pop" that decays
var _flash := {}          ## name -> 0..1, a ring or bar flash that decays
var _shake := 0.0
var _burst := 0.0         ## level-up burst, 1 -> 0
var _sparks: Array = []   ## {p, v, life, max, col, r}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560, 120)
	size = custom_minimum_size
	_plate_box.bg_color = Color(0.04, 0.05, 0.1, 0.5)
	_plate_box.border_color = Color(1, 1, 1, 0.14)
	_plate_box.set_border_width_all(1)
	_plate_box.set_corner_radius_all(12)
	_plate_box.shadow_color = Color(0, 0, 0, 0.35)
	_plate_box.shadow_size = 6
	_bar_box.bg_color = Color(0, 0, 0, 0.55)
	_bar_box.border_color = Color(1, 1, 1, 0.45)
	_bar_box.set_border_width_all(1)
	_bar_box.set_corner_radius_all(7)
	_fill_box.set_corner_radius_all(6)
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_info(d: Dictionary) -> void:
	if not _prev.is_empty():
		_notice_changes(d)
	else:
		_xp = float(d["xp"])
		_hp = float(d["hp"])
		_hp_trail = _hp
		_bones = float(d["bones"])
		_kills = float(d["kills"])
	info = d
	_prev = d.duplicate()


## Compare with the last values and start the matching effects.
func _notice_changes(d: Dictionary) -> void:
	if int(d["level"]) > int(_prev["level"]):
		_burst = 1.0
		_pop["level"] = 1.0
		for i in 16:
			_spark(Vector2(14, 16), Color("ffd84a"), 60.0)
	elif int(d["xp"]) > int(_prev["xp"]):
		_flash["xp"] = 1.0
		_spark(Vector2(34 + BAR_W * clampf(float(d["xp"]) / maxf(float(d["xp_max"]), 1.0), 0.0, 1.0), 17), Color("9fe0ff"), 24.0)
	if int(d["hp"]) < int(_prev["hp"]):
		_shake = 1.0
		_pop["hp"] = 1.0
		_flash["hp_hit"] = 1.0
	elif int(d["hp"]) > int(_prev["hp"]):
		_flash["hp_heal"] = 1.0
		_pop["hp"] = 0.6
		_spark(Vector2(226 + BAR_W * clampf(float(d["hp"]) / maxf(float(d["max_hp"]), 1.0), 0.0, 1.0), 17), Color("9cf09c"), 24.0)
	if int(d["bones"]) != int(_prev["bones"]):
		_pop["bones"] = 1.0
		if int(d["bones"]) > int(_prev["bones"]):
			_spark(Vector2(12, 44), Color("fff2c0"), 22.0)
	if int(d["kills"]) > int(_prev["kills"]):
		_pop["kills"] = 1.0
	if int(d["alive"]) != int(_prev["alive"]):
		_pop["alive"] = 0.6
	if int(d["village_level"]) != int(_prev["village_level"]):
		_pop["village"] = 1.0
	if bool(d["night"]) != bool(_prev["night"]):
		_flash["clock"] = 1.0
	for k in ["roll", "lunge"]:
		if float(_prev[k + "_cd"]) > 0.0 and float(d[k + "_cd"]) <= 0.0:
			_flash[k] = 1.0
	if float(_prev["sprint_cd"]) > 0.0 and float(d["sprint_cd"]) <= 0.0:
		_flash["sprint"] = 1.0


func _spark(p: Vector2, col: Color, speed: float) -> void:
	var a := randf() * TAU
	var life := randf_range(0.45, 0.9)
	_sparks.append({"p": p, "v": Vector2.from_angle(a) * randf_range(0.3, 1.0) * speed + Vector2(0, -10), "life": life, "max": life, "col": col, "r": randf_range(1.2, 2.4)})


func _process(delta: float) -> void:
	_t += delta
	if info.is_empty():
		return
	var k := 1.0 - exp(-delta * 9.0)
	_xp = lerpf(_xp, float(info["xp"]), k)
	_hp = lerpf(_hp, float(info["hp"]), k)
	# the pale trail waits a moment, then drains down to the real HP
	if _hp_trail < float(info["hp"]):
		_hp_trail = float(info["hp"])
	elif _hp_trail > _hp:
		_hp_trail = lerpf(_hp_trail, _hp, 1.0 - exp(-delta * 2.2))
	_bones = lerpf(_bones, float(info["bones"]), k)
	_kills = lerpf(_kills, float(info["kills"]), k)
	for key in _pop.keys():
		_pop[key] = maxf(float(_pop[key]) - delta * 3.0, 0.0)
	for key in _flash.keys():
		_flash[key] = maxf(float(_flash[key]) - delta * 1.8, 0.0)
	_shake = maxf(_shake - delta * 4.0, 0.0)
	_burst = maxf(_burst - delta * 1.2, 0.0)
	for s in _sparks:
		s["life"] -= delta
		s["p"] += s["v"] * delta
		s["v"] = s["v"] * (1.0 - delta * 2.0) + Vector2(0, 40.0 * delta)
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	if info.is_empty():
		return
	draw_style_box(_plate_box, PLATE)
	var night: bool = info["night"]
	var low: bool = float(info["hp"]) <= float(info["max_hp"]) * 0.3
	# row 1
	var x := 0.0
	_level_star(Vector2(x + 14, 16), int(info["level"]))
	x += 34.0
	var xp_max: float = float(info["xp_max"])
	_bar(Rect2(x, 10, BAR_W, BAR_H), _xp / maxf(xp_max, 1.0) if xp_max > 0.0 else 1.0, -1.0, Color("2f9fe8"), Color("8fe0ff"),
		"%d/%d" % [info["xp"], info["xp_max"]] if xp_max > 0.0 else "MAX", float(_flash.get("xp", 0.0)))
	x += BAR_W + 22.0
	var beat := 1.0 + (0.22 * maxf(sin(_t * 10.0), 0.0) if low else 0.1 * maxf(sin(_t * 3.2), 0.0)) + 0.35 * float(_pop.get("hp", 0.0))
	_heart(Vector2(x + 8, 16), 9.0 * beat, Color("ff5a4a") if not low else Color("ff2a2a").lerp(Color("ffb0a0"), 0.5 + 0.5 * sin(_t * 10.0)))
	x += 22.0
	var shake := Vector2(sin(_t * 70.0) * 2.5 * _shake, 0.0)
	var hp_max := maxf(float(info["max_hp"]), 1.0)
	_bar(Rect2(Vector2(x, 10) + shake, Vector2(BAR_W, BAR_H)), _hp / hp_max, _hp_trail / hp_max,
		Color("d8322a") if not low else Color("ff3030").lerp(Color("c01818"), 0.5 + 0.5 * sin(_t * 10.0)), Color("ff8a70"),
		"%d/%d" % [info["hp"], info["max_hp"]], float(_flash.get("hp_heal", 0.0)) - float(_flash.get("hp_hit", 0.0)) * 0.0, low)
	if float(_flash.get("hp_hit", 0.0)) > 0.0:
		draw_rect(Rect2(Vector2(x, 10) + shake, Vector2(BAR_W, BAR_H)), Color(1, 0.2, 0.2, 0.35 * float(_flash["hp_hit"])))
	x += BAR_W + 22.0
	var cf := float(_flash.get("clock", 0.0))
	if night:
		_moon(Vector2(x + 9, 16), 9.0)
	else:
		_sun(Vector2(x + 9, 16), 8.0)
	if cf > 0.0:
		draw_arc(Vector2(x + 9, 16), 10.0 + (1.0 - cf) * 18.0, 0, TAU, 28, Color(1, 1, 1, cf * 0.7), 2.0)
	x += 24.0
	_num(Vector2(x, 22), str(info["day"]), 16, Color("ffe08a") if not night else Color("b8c4ff"), "clock")
	x += 22.0
	var phase_col := Color("ffb020") if not night else Color("6a7cff")
	_bar(Rect2(x, 10, 70.0, BAR_H), float(info["phase_left"]) / maxf(float(info["phase_len"]), 1.0), -1.0, phase_col, phase_col.lightened(0.4), "", cf)
	# row 2
	var y := 44.0
	x = 0.0
	_bone(Vector2(x + 12, y + sin(_t * 2.0) * 0.8), 1.0 + 0.25 * float(_pop.get("bones", 0.0)))
	_num(Vector2(x + 28, y + 6), str(roundi(_bones)), 16, INK, "bones")
	x += 90.0
	_skull(Vector2(x + 10, y), 9.0 * (1.0 + 0.3 * float(_pop.get("kills", 0.0))))
	_num(Vector2(x + 26, y + 6), str(roundi(_kills)), 16, INK, "kills")
	x += 90.0
	_person(Vector2(x + 10, y), 1.0 + 0.2 * float(_pop.get("alive", 0.0)))
	_num(Vector2(x + 24, y + 6), "%d/%d" % [info["alive"], info["target_pop"]], 16, INK, "alive")
	x += 100.0
	_house(Vector2(x + 10, y), 1.0 + 0.3 * float(_pop.get("village", 0.0)))
	_num(Vector2(x + 26, y + 6), "%d/5" % info["village_level"], 16, INK, "village")
	# row 3
	y = 74.0
	x = 0.0
	var sprint_ready: bool = info["sprint_cd"] <= 0.0
	var running: bool = sprint_ready and float(info["sprint"]) < float(info["sprint_max"]) - 0.05
	_bolt(Vector2(x + 8 + (randf() - 0.5) * (1.2 if running else 0.0), y), 1.0 + 0.3 * float(_flash.get("sprint", 0.0)), Color("ffd84a") if sprint_ready else Color("8a8a8a"))
	var sprint_frac := float(info["sprint"]) / maxf(float(info["sprint_max"]), 0.001) if sprint_ready else 1.0 - float(info["sprint_cd"]) / maxf(float(info["sprint_cd_max"]), 0.001)
	_bar(Rect2(x + 20, y - 7, 70.0, BAR_H), sprint_frac, -1.0, Color("e8a010") if sprint_ready else Color("707078"), Color("fff080") if sprint_ready else Color("a0a0a8"), "", float(_flash.get("sprint", 0.0)))
	x += 112.0
	_ring(Vector2(x + 10, y), 10.0, float(info["roll_cd"]), float(info["roll_cd_max"]), Color("7be07b"), float(_flash.get("roll", 0.0)))
	_roll_mark(Vector2(x + 10, y), float(info["roll_cd"]) <= 0.0)
	x += 34.0
	_ring(Vector2(x + 10, y), 10.0, float(info["lunge_cd"]), float(info["lunge_cd_max"]), Color("ff7a5a"), float(_flash.get("lunge", 0.0)))
	_fang(Vector2(x + 10, y), float(info["lunge_cd"]) <= 0.0)
	x += 40.0
	for i in info["buffs"].size():
		var b: Dictionary = info["buffs"][i]
		_chip(Vector2(x + 10, y), b["color"], "%d" % b["secs"], i, int(b["secs"]) <= 3)
		x += 32.0
	for i in info["relics"].size():
		_diamond(Vector2(x + 8, y + sin(_t * 2.5 + i) * 1.2), 7.0, Color("c8a0ff"), i)
		_text(Vector2(x + 18, y + 5), "x%d" % info["relics"][i]["n"], 12, INK)
		x += 36.0
	# row 4: what E / X do right now
	y = 102.0
	x = 0.0
	var bob := sin(_t * 3.0) * 1.2
	if info["remove_refund"] >= 0:
		_cross(Vector2(x + 8, y), 6.0)
		_bone(Vector2(x + 30, y), 0.8)
		_text(Vector2(x + 44, y + 5), "+%d" % info["remove_refund"], 14, Color("9cf09c"))
		x += 96.0
		if info["upgrade_text"] != "":
			_text(Vector2(x, y + 5), "E", 14, Color("ffd84a"))
			_arrow_up(Vector2(x + 20, y + bob))
			_bone(Vector2(x + 38, y), 0.8)
			_text(Vector2(x + 52, y + 5), info["upgrade_text"], 14, Color("ffd84a"))
	else:
		if info["build_item"] == "tower":
			_tower(Vector2(x + 8, y + bob))
		else:
			_wall(Vector2(x + 8, y + bob))
		_bone(Vector2(x + 34, y), 0.8)
		var bad: bool = info["build_error"] != ""
		_text(Vector2(x + 48, y + 5), str(info["build_cost"]), 14, INK if not bad else Color("ff7a6a"))
		if bad:
			_text(Vector2(x + 84, y + 5), info["build_error"], 13, Color("ff7a6a"))
		else:
			var glow := 0.65 + 0.35 * sin(_t * 4.0)
			draw_circle(Vector2(x + 90, y), 9.0, Color(1, 0.85, 0.3, 0.18 * glow))
			_text(Vector2(x + 85, y + 5), "E", 14, Color(1, 0.85, 0.3, glow))
	# sparks on top of everything
	for s in _sparks:
		var a: float = float(s["life"]) / float(s["max"])
		draw_circle(s["p"], float(s["r"]) * (0.5 + a), Color(s["col"], a))


# --- pieces ---

func _text(p: Vector2, s: String, size_px: int, col: Color) -> void:
	_font.draw_string(get_canvas_item(), p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, SHADOW)
	_font.draw_string(get_canvas_item(), p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


## A number that swells and settles when its value changes.
func _num(p: Vector2, s: String, size_px: int, col: Color, key: String) -> void:
	var pop := float(_pop.get(key, 0.0))
	if pop <= 0.0:
		_text(p, s, size_px, col)
		return
	var sc := 1.0 + 0.45 * pop
	draw_set_transform(p, 0.0, Vector2(sc, sc))
	_text(Vector2.ZERO, s, size_px, col.lerp(Color(1, 0.95, 0.6), pop))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A glossy rounded bar. `trail` (if >= 0) is the pale damage trail behind the fill.
func _bar(r: Rect2, frac: float, trail: float, col: Color, hi: Color, label: String, flash: float = 0.0, pulse: bool = false) -> void:
	draw_style_box(_bar_box, r)
	var inner := r.grow(-2.0)
	frac = clampf(frac, 0.0, 1.0)
	if trail >= 0.0 and trail > frac:
		_fill_box.bg_color = Color(1, 0.92, 0.85, 0.75)
		draw_style_box(_fill_box, Rect2(inner.position, Vector2(maxf(inner.size.x * clampf(trail, 0.0, 1.0), 0.0), inner.size.y)))
	if frac > 0.0:
		var fw := maxf(inner.size.x * frac, 4.0)
		var fill := Rect2(inner.position, Vector2(fw, inner.size.y))
		_fill_box.bg_color = col
		draw_style_box(_fill_box, fill)
		# gloss: a light strip on the top half, a dark one at the bottom
		draw_rect(Rect2(fill.position + Vector2(2, 1), Vector2(fw - 4.0, inner.size.y * 0.38)), Color(hi, 0.45))
		draw_rect(Rect2(fill.position + Vector2(2, inner.size.y * 0.72), Vector2(fw - 4.0, inner.size.y * 0.22)), Color(0, 0, 0, 0.18))
		# a shimmer sweeping across the filled part
		var sx := fposmod(_t * 55.0, r.size.x + 40.0) - 20.0
		var x0 := clampf(sx, fill.position.x + 2.0, fill.end.x - 2.0)
		var x1 := clampf(sx + 9.0, fill.position.x + 2.0, fill.end.x - 2.0)
		if x1 > x0:
			draw_rect(Rect2(x0, fill.position.y + 1.0, x1 - x0, inner.size.y - 2.0), Color(1, 1, 1, 0.28))
		if flash > 0.0:
			draw_rect(fill, Color(1, 1, 1, 0.4 * flash))
	if pulse:
		draw_style_box(_pulse_box(0.35 + 0.35 * sin(_t * 10.0)), r.grow(2.0))
	if label != "":
		_font.draw_string(get_canvas_item(), r.position + Vector2(1, r.size.y - 2.0), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, SHADOW)
		_font.draw_string(get_canvas_item(), r.position + Vector2(0, r.size.y - 3.0), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color(1, 1, 1, 0.97))


func _pulse_box(a: float) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0, 0, 0, 0)
	b.border_color = Color(1, 0.2, 0.2, a)
	b.set_border_width_all(2)
	b.set_corner_radius_all(9)
	return b


func _level_star(c: Vector2, lv: int) -> void:
	var sc := 1.0 + 0.4 * float(_pop.get("level", 0.0)) + 0.04 * sin(_t * 2.5)
	if _burst > 0.0:
		draw_arc(c, 14.0 + (1.0 - _burst) * 30.0, 0, TAU, 32, Color(1, 0.9, 0.4, _burst * 0.8), 3.0)
		draw_circle(c, 18.0 * _burst, Color(1, 0.9, 0.4, 0.25 * _burst))
	draw_circle(c, 17.0, Color(1, 0.8, 0.3, 0.12 + 0.08 * sin(_t * 2.5)))
	var pts := PackedVector2Array()
	var spin := _burst * TAU * 0.5
	for i in 10:
		var r := (14.0 if i % 2 == 0 else 7.5) * sc
		pts.append(c + Vector2.from_angle(-PI / 2.0 + spin + i * TAU / 10.0) * r)
	draw_colored_polygon(pts, Color("f0b030"))
	draw_colored_polygon(PackedVector2Array([c, pts[0], pts[1], pts[2]]), Color("ffd868"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color("7a4a10"), 1.5)
	_font.draw_string(get_canvas_item(), c + Vector2(-14, 5), str(lv), HORIZONTAL_ALIGNMENT_CENTER, 28, 12, Color("3a2008"))


func _heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(0, 1), s * 1.25, Color(col, 0.16))
	draw_circle(c + Vector2(-s * 0.45, -s * 0.2), s * 0.55, col)
	draw_circle(c + Vector2(s * 0.45, -s * 0.2), s * 0.55, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.98, 0.0), c + Vector2(s * 0.98, 0.0), c + Vector2(0, s * 0.95)]), col)
	draw_circle(c + Vector2(-s * 0.5, -s * 0.35), s * 0.2, Color(1, 1, 1, 0.55))


func _sun(c: Vector2, r: float) -> void:
	draw_circle(c, r + 5.0, Color(1, 0.85, 0.3, 0.14 + 0.06 * sin(_t * 2.0)))
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8.0 + _t * 0.6)
		var ray := 3.0 + 1.2 * sin(_t * 3.0 + i)
		draw_line(c + d * (r + 1.0), c + d * (r + 1.0 + ray), Color("ffd040"), 1.6)
	draw_circle(c, r, Color("ffd84a"))
	draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.4, Color(1, 1, 0.8, 0.6))


func _moon(c: Vector2, r: float) -> void:
	draw_circle(c, r + 5.0, Color(0.6, 0.7, 1.0, 0.12 + 0.05 * sin(_t * 1.5)))
	draw_circle(c, r, Color("dfe6ff"))
	draw_circle(c + Vector2(r * 0.55, -r * 0.3), r * 0.85, Color(0.12, 0.14, 0.28, 1.0))
	for i in 3:
		var tw := 0.5 + 0.5 * sin(_t * 3.0 + i * 2.1)
		var sp := c + Vector2(r * (1.1 + 0.3 * i), -r * (0.9 - 0.7 * i))
		draw_circle(sp, 1.1, Color(1, 1, 1, 0.3 + 0.7 * tw))


func _bone(c: Vector2, s: float) -> void:
	var col := Color("f2ecd8")
	draw_line(c + Vector2(-7, 0) * s, c + Vector2(7, 0) * s, col, 3.0 * s)
	for sx in [-8.0, 8.0]:
		draw_circle(c + Vector2(sx, -2.2) * s, 2.6 * s, col)
		draw_circle(c + Vector2(sx, 2.2) * s, 2.6 * s, col)
	draw_line(c + Vector2(-5, -0.8) * s, c + Vector2(5, -0.8) * s, Color(1, 1, 1, 0.6), 1.0 * s)


func _skull(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(0, -1), r * 0.85, Color("ece8dc"))
	draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.3), Vector2(r, r * 0.6)), Color("ece8dc"))
	var glow := 0.5 + 0.5 * sin(_t * 2.0)
	draw_circle(c + Vector2(-r * 0.38, -1), r * 0.25, Color("2a2a2a"))
	draw_circle(c + Vector2(r * 0.38, -1), r * 0.25, Color("2a2a2a"))
	draw_circle(c + Vector2(-r * 0.38, -1), r * 0.1, Color(1, 0.3, 0.2, 0.4 + 0.5 * glow))
	draw_circle(c + Vector2(r * 0.38, -1), r * 0.1, Color(1, 0.3, 0.2, 0.4 + 0.5 * glow))


func _person(c: Vector2, s: float) -> void:
	var hop := absf(sin(_t * 2.2)) * -1.2
	draw_circle(c + Vector2(0, -5 + hop) * s, 3.6 * s, Color("f0c8a0"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 8) * s, c + Vector2(6, 8) * s, c + Vector2(4, -1 + hop) * s, c + Vector2(-4, -1 + hop) * s]), Color("c8503c"))


func _house(c: Vector2, s: float) -> void:
	draw_rect(Rect2(c + Vector2(-7, -1) * s, Vector2(14, 9) * s), Color("d8b888"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -1) * s, c + Vector2(9, -1) * s, c + Vector2(0, -9) * s]), Color("b04030"))
	draw_rect(Rect2(c + Vector2(-2, 3) * s, Vector2(4, 5) * s), Color("6a4020"))
	var smoke := fposmod(_t * 0.7, 1.0)
	draw_circle(c + Vector2(5 + smoke * 3.0, -9 * s - smoke * 7.0), 1.6 * (1.0 - smoke * 0.5), Color(1, 1, 1, 0.5 * (1.0 - smoke)))


func _bolt(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(2, -8) * s, c + Vector2(-5, 1) * s, c + Vector2(-1, 1) * s, c + Vector2(-3, 8) * s, c + Vector2(5, -2) * s, c + Vector2(1, -2) * s]), col)


## A cooldown ring: dim while charging, a bright full ring when ready, and a flash the moment it becomes ready.
func _ring(c: Vector2, r: float, cd: float, cd_max: float, col: Color, flash: float) -> void:
	draw_circle(c, r, Color(0, 0, 0, 0.55))
	if cd <= 0.0:
		draw_arc(c, r - 1.0, 0, TAU, 24, col, 2.0)
		draw_circle(c, r, Color(col, 0.10 + 0.07 * sin(_t * 3.0)))
	else:
		var f := 1.0 - clampf(cd / maxf(cd_max, 0.001), 0.0, 1.0)
		draw_arc(c, r - 1.0, -PI / 2.0, -PI / 2.0 + TAU * f, 24, Color(col, 0.55), 2.0)
	if flash > 0.0:
		draw_arc(c, r + (1.0 - flash) * 12.0, 0, TAU, 24, Color(col, flash), 2.5)
		draw_circle(c, r, Color(1, 1, 1, 0.35 * flash))


func _roll_mark(c: Vector2, ready: bool) -> void:
	var a0 := (_t * 2.5 if ready else 0.0)
	draw_arc(c, 4.5, a0 + 0.4, a0 + TAU - 0.9, 14, INK if ready else Color(1, 1, 1, 0.5), 1.6)
	var tip := c + Vector2.from_angle(a0) * 4.5
	draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -3.5).rotated(a0), tip + Vector2(3.5, 0).rotated(a0), tip + Vector2(0, 3.5).rotated(a0)]), INK if ready else Color(1, 1, 1, 0.5))


func _fang(c: Vector2, ready: bool) -> void:
	var s := 1.0 + (0.08 * sin(_t * 6.0) if ready else 0.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -5) * s, c + Vector2(4, -5) * s, c + Vector2(0, 6) * s]), INK if ready else Color(1, 1, 1, 0.5))


## A buff: a glowing disc with a spinning arc, blinking when it is about to run out.
func _chip(c: Vector2, col: Color, label: String, idx: int, ending: bool) -> void:
	var blink := 1.0 if not ending else 0.4 + 0.6 * absf(sin(_t * 8.0))
	draw_circle(c, 10.0 + sin(_t * 3.0 + idx) * 0.6, Color(col, 0.35 * blink))
	draw_arc(c, 10.0, _t * 2.5, _t * 2.5 + TAU * 0.7, 18, Color(col, blink), 2.2)
	draw_arc(c, 10.0, _t * 2.5 + TAU * 0.7, _t * 2.5 + TAU, 8, Color(col, 0.25 * blink), 1.2)
	_font.draw_string(get_canvas_item(), c + Vector2(-10, 4), label, HORIZONTAL_ALIGNMENT_CENTER, 20, 11, Color(1, 1, 1, blink))


func _diamond(c: Vector2, r: float, col: Color, idx: int) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.5, 0), c + Vector2(0, 0), c + Vector2(-r * 0.5, 0)]), col.lightened(0.35))
	var tw := maxf(sin(_t * 2.0 + idx * 1.7), 0.0)
	if tw > 0.0:
		draw_line(c + Vector2(-r, -r) * 0.6, c + Vector2(-r, -r) * 0.6 + Vector2(0, 0), Color(1, 1, 1, tw), 1.0)
		draw_circle(c + Vector2(r * 0.3, -r * 0.4), 1.4 * tw, Color(1, 1, 1, tw))


func _cross(c: Vector2, r: float) -> void:
	draw_line(c + Vector2(-r, -r), c + Vector2(r, r), Color("ff6a5a"), 3.0)
	draw_line(c + Vector2(-r, r), c + Vector2(r, -r), Color("ff6a5a"), 3.0)


func _arrow_up(c: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 1), c + Vector2(2, 1), c + Vector2(2, 7), c + Vector2(-2, 7), c + Vector2(-2, 1), c + Vector2(-6, 1)]), Color("ffd84a"))


func _tower(c: Vector2) -> void:
	draw_rect(Rect2(c + Vector2(-5, -4), Vector2(10, 12)), Color("8a96a8"))
	for dx in [-5.0, -1.5, 2.0]:
		draw_rect(Rect2(c + Vector2(dx, -8), Vector2(3, 4)), Color("8a96a8"))
	draw_rect(Rect2(c + Vector2(-1.5, 1), Vector2(3, 7)), Color("3a4252"))


func _wall(c: Vector2) -> void:
	draw_rect(Rect2(c + Vector2(-8, -5), Vector2(16, 12)), Color("8a8478"))
	draw_line(c + Vector2(-8, 1), c + Vector2(8, 1), Color("4a4640"), 1.2)
	draw_line(c + Vector2(0, -5), c + Vector2(0, 1), Color("4a4640"), 1.2)
	draw_line(c + Vector2(-4, 1), c + Vector2(-4, 7), Color("4a4640"), 1.2)
	draw_line(c + Vector2(4, 1), c + Vector2(4, 7), Color("4a4640"), 1.2)
