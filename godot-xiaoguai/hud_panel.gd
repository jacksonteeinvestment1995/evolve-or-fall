extends Control
## The top-left HUD, drawn with icons and bars instead of sentences:
##   row 1  level star, EXP bar, heart + HP bar, sun/moon + day number + time-left bar
##   row 2  bones, kills, villagers alive, village level
##   row 3  sprint bar, roll and lunge cooldown rings, buff and relic chips
##   row 4  what the build key does right now
## main.gd fills `info` every frame it changes and this redraws.

const INK := Color(1, 1, 1, 0.95)
const SHADOW := Color(0, 0, 0, 0.55)
const BAR_W := 150.0
const BAR_H := 12.0

var info := {}
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560, 120)
	size = custom_minimum_size


func set_info(d: Dictionary) -> void:
	info = d
	queue_redraw()


func _draw() -> void:
	if info.is_empty():
		return
	# row 1
	var x := 0.0
	_level_star(Vector2(x + 14, 16), int(info["level"]))
	x += 34.0
	_bar(Vector2(x, 10), BAR_W, float(info["xp"]), float(info["xp_max"]), Color("5ac8fa"), "%d/%d" % [info["xp"], info["xp_max"]] if info["xp_max"] > 0 else "MAX")
	x += BAR_W + 22.0
	_heart(Vector2(x + 8, 16), 9.0)
	x += 22.0
	_bar(Vector2(x, 10), BAR_W, float(info["hp"]), float(info["max_hp"]), Color("e8453c"), "%d/%d" % [info["hp"], info["max_hp"]])
	x += BAR_W + 22.0
	var night: bool = info["night"]
	if night:
		_moon(Vector2(x + 9, 16), 9.0)
	else:
		_sun(Vector2(x + 9, 16), 8.0)
	x += 24.0
	_text(Vector2(x, 22), str(info["day"]), 16, Color("ffe08a") if not night else Color("b8c4ff"))
	x += 22.0
	_bar(Vector2(x, 10), 70.0, float(info["phase_left"]), float(info["phase_len"]), Color("ffd84a") if not night else Color("8a9cff"), "")
	# row 2
	var y := 44.0
	x = 0.0
	_bone(Vector2(x + 12, y), 1.0)
	_text(Vector2(x + 28, y + 6), str(info["bones"]), 16, INK)
	x += 90.0
	_skull(Vector2(x + 10, y), 9.0)
	_text(Vector2(x + 26, y + 6), str(info["kills"]), 16, INK)
	x += 90.0
	_person(Vector2(x + 10, y), 1.0)
	_text(Vector2(x + 24, y + 6), "%d/%d" % [info["alive"], info["target_pop"]], 16, INK)
	x += 100.0
	_house(Vector2(x + 10, y), 1.0)
	_text(Vector2(x + 26, y + 6), "%d/5" % info["village_level"], 16, INK)
	# row 3
	y = 74.0
	x = 0.0
	_bolt(Vector2(x + 8, y), 1.0, Color("ffd84a"))
	var sprint_ready: bool = info["sprint_cd"] <= 0.0
	_bar(Vector2(x + 20, y - 6), 70.0, float(info["sprint"]) if sprint_ready else float(info["sprint_cd_max"] - info["sprint_cd"]), float(info["sprint_max"]) if sprint_ready else float(info["sprint_cd_max"]), Color("ffd84a") if sprint_ready else Color("8a8a8a"), "")
	x += 112.0
	_ring(Vector2(x + 10, y), 10.0, float(info["roll_cd"]), float(info["roll_cd_max"]), Color("7be07b"))
	_roll_mark(Vector2(x + 10, y))
	x += 34.0
	_ring(Vector2(x + 10, y), 10.0, float(info["lunge_cd"]), float(info["lunge_cd_max"]), Color("ff7a5a"))
	_fang(Vector2(x + 10, y))
	x += 40.0
	for b in info["buffs"]:
		_chip(Vector2(x + 10, y), b["color"], "%d" % b["secs"])
		x += 32.0
	for r in info["relics"]:
		_diamond(Vector2(x + 8, y), 7.0, Color("c8a0ff"))
		_text(Vector2(x + 18, y + 5), "x%d" % r["n"], 12, INK)
		x += 36.0
	# row 4: what E / X do right now
	y = 102.0
	x = 0.0
	if info["remove_refund"] >= 0:
		_cross(Vector2(x + 8, y), 6.0)
		_bone(Vector2(x + 30, y), 0.8)
		_text(Vector2(x + 44, y + 5), "+%d" % info["remove_refund"], 14, Color("9cf09c"))
		x += 96.0
		if info["upgrade_text"] != "":
			_text(Vector2(x, y + 5), "E", 14, Color("ffd84a"))
			_arrow_up(Vector2(x + 20, y))
			_bone(Vector2(x + 38, y), 0.8)
			_text(Vector2(x + 52, y + 5), info["upgrade_text"], 14, Color("ffd84a"))
	else:
		if info["build_item"] == "tower":
			_tower(Vector2(x + 8, y))
		else:
			_wall(Vector2(x + 8, y))
		_bone(Vector2(x + 34, y), 0.8)
		_text(Vector2(x + 48, y + 5), str(info["build_cost"]), 14, INK if info["build_error"] == "" else Color("ff7a6a"))
		if info["build_error"] != "":
			_text(Vector2(x + 84, y + 5), info["build_error"], 13, Color("ff7a6a"))
		else:
			_text(Vector2(x + 84, y + 5), "E", 14, Color("ffd84a"))


# --- pieces ---

func _text(p: Vector2, s: String, size_px: int, col: Color) -> void:
	_font.draw_string(get_canvas_item(), p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, SHADOW)
	_font.draw_string(get_canvas_item(), p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _bar(p: Vector2, w: float, v: float, vmax: float, col: Color, label: String) -> void:
	var f := clampf(v / maxf(vmax, 0.001), 0.0, 1.0)
	draw_rect(Rect2(p, Vector2(w, BAR_H)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(p + Vector2(1, 1), Vector2((w - 2.0) * f, BAR_H - 2.0)), col)
	draw_rect(Rect2(p, Vector2(w, BAR_H)), Color(1, 1, 1, 0.5), false, 1.0)
	if label != "":
		_font.draw_string(get_canvas_item(), p + Vector2(0, BAR_H - 2.0), label, HORIZONTAL_ALIGNMENT_CENTER, w, 11, Color(1, 1, 1, 0.95))


func _level_star(c: Vector2, lv: int) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var r := 14.0 if i % 2 == 0 else 7.5
		pts.append(c + Vector2.from_angle(-PI / 2.0 + i * TAU / 10.0) * r)
	draw_colored_polygon(pts, Color("f0b030"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color("7a4a10"), 1.5)
	_font.draw_string(get_canvas_item(), c + Vector2(-14, 5), str(lv), HORIZONTAL_ALIGNMENT_CENTER, 28, 12, Color("3a2008"))


func _heart(c: Vector2, s: float) -> void:
	draw_circle(c + Vector2(-s * 0.45, -s * 0.2), s * 0.55, Color("e8453c"))
	draw_circle(c + Vector2(s * 0.45, -s * 0.2), s * 0.55, Color("e8453c"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.98, 0.0), c + Vector2(s * 0.98, 0.0), c + Vector2(0, s * 0.95)]), Color("e8453c"))


func _sun(c: Vector2, r: float) -> void:
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8.0)
		draw_line(c + d * (r + 1.0), c + d * (r + 4.0), Color("ffd040"), 1.6)
	draw_circle(c, r, Color("ffd84a"))


func _moon(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color("dfe6ff"))
	draw_circle(c + Vector2(r * 0.55, -r * 0.3), r * 0.85, Color(0.1, 0.12, 0.25, 1.0))


func _bone(c: Vector2, s: float) -> void:
	var col := Color("f2ecd8")
	draw_line(c + Vector2(-7, 0) * s, c + Vector2(7, 0) * s, col, 3.0 * s)
	for sx in [-8.0, 8.0]:
		draw_circle(c + Vector2(sx, -2.2) * s, 2.6 * s, col)
		draw_circle(c + Vector2(sx, 2.2) * s, 2.6 * s, col)


func _skull(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(0, -1), r * 0.85, Color("ece8dc"))
	draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.3), Vector2(r, r * 0.6)), Color("ece8dc"))
	draw_circle(c + Vector2(-r * 0.38, -1), r * 0.25, Color("2a2a2a"))
	draw_circle(c + Vector2(r * 0.38, -1), r * 0.25, Color("2a2a2a"))


func _person(c: Vector2, s: float) -> void:
	draw_circle(c + Vector2(0, -5) * s, 3.6 * s, Color("f0c8a0"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 8) * s, c + Vector2(6, 8) * s, c + Vector2(4, -1) * s, c + Vector2(-4, -1) * s]), Color("c8503c"))


func _house(c: Vector2, s: float) -> void:
	draw_rect(Rect2(c + Vector2(-7, -1) * s, Vector2(14, 9) * s), Color("d8b888"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -1) * s, c + Vector2(9, -1) * s, c + Vector2(0, -9) * s]), Color("b04030"))
	draw_rect(Rect2(c + Vector2(-2, 3) * s, Vector2(4, 5) * s), Color("6a4020"))


func _bolt(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(2, -8) * s, c + Vector2(-5, 1) * s, c + Vector2(-1, 1) * s, c + Vector2(-3, 8) * s, c + Vector2(5, -2) * s, c + Vector2(1, -2) * s]), col)


func _ring(c: Vector2, r: float, cd: float, cd_max: float, col: Color) -> void:
	draw_circle(c, r, Color(0, 0, 0, 0.55))
	if cd <= 0.0:
		draw_arc(c, r - 1.0, 0, TAU, 24, col, 2.0)
	else:
		var f := 1.0 - clampf(cd / maxf(cd_max, 0.001), 0.0, 1.0)
		draw_arc(c, r - 1.0, -PI / 2.0, -PI / 2.0 + TAU * f, 24, Color(col, 0.5), 2.0)


func _roll_mark(c: Vector2) -> void:
	draw_arc(c, 4.5, 0.4, TAU - 0.9, 14, INK, 1.6)
	draw_colored_polygon(PackedVector2Array([c + Vector2(4.5, -3.5), c + Vector2(8.0, -0.5), c + Vector2(2.0, 0.5)]), INK)


func _fang(c: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -5), c + Vector2(4, -5), c + Vector2(0, 6)]), INK)


func _chip(c: Vector2, col: Color, label: String) -> void:
	draw_circle(c, 10.0, Color(col, 0.35))
	draw_arc(c, 10.0, 0, TAU, 20, col, 2.0)
	_font.draw_string(get_canvas_item(), c + Vector2(-10, 4), label, HORIZONTAL_ALIGNMENT_CENTER, 20, 11, INK)


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


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
