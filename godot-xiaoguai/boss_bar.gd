extends Control
## The boss health bar. It shows while a hidden boss is awake near 小怪: its name, a bar with a notch at each of
## its two phase changes, a gold flash while its weak point is open, and ENRAGED once it has lost two thirds.

const W := 360.0
const H := 18.0
const SHOW_RANGE := 900.0

var _boss = null
var _shown := 0.0          ## fade 0..1
var _hp_trail := 1.0
var _t := 0.0
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W, 52)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta
	var pl = get_tree().get_first_node_in_group("player")
	var best = null
	var best_d := SHOW_RANGE
	if pl != null:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.is_queued_for_deletion() or (int(e.get("secret")) < 0 and not bool(e.get("hero_rival"))) or bool(e.get("calm")):
				continue
			var d: float = e.global_position.distance_to(pl.global_position)
			if d < best_d:
				best_d = d
				best = e
	_boss = best
	_shown = move_toward(_shown, 1.0 if _boss != null else 0.0, delta * 3.0)
	if _boss != null:
		var f := float(_boss.hp) / maxf(1.0, float(_boss.max_hp))
		_hp_trail = f if f > _hp_trail else lerpf(_hp_trail, f, 1.0 - exp(-delta * 2.0))
	# top centre on a wide screen, under the HUD on a tall one
	var vs := get_viewport_rect().size
	position = Vector2(16, 140) if vs.y > vs.x else Vector2((vs.x - W) * 0.5, 10)
	visible = _shown > 0.01
	if visible:
		queue_redraw()


func _draw() -> void:
	if _boss == null:
		return
	var a := _shown
	var f := float(_boss.hp) / maxf(1.0, float(_boss.max_hp))
	var enraged: bool = bool(_boss.get("enraged"))
	var exposed: bool = float(_boss.get("exposed_left")) > 0.0
	var name_col := Color(1, 0.55, 0.45, a) if enraged else Color(1, 1, 1, a)
	var title: String = _boss.form_name().to_upper() + ((" - LV %d" % _boss.rival_level) if bool(_boss.get("hero_rival")) else "")
	_font.draw_string(get_canvas_item(), Vector2(1, 15), title, HORIZONTAL_ALIGNMENT_CENTER, W, 16, Color(0, 0, 0, 0.7 * a))
	_font.draw_string(get_canvas_item(), Vector2(0, 14), title, HORIZONTAL_ALIGNMENT_CENTER, W, 16, name_col)
	var r := Rect2(0, 22, W, H)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.6 * a)
	back.border_color = Color(1, 1, 1, 0.5 * a)
	back.set_border_width_all(1)
	back.set_corner_radius_all(9)
	draw_style_box(back, r)
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(7)
	var inner := r.grow(-2.0)
	fill.bg_color = Color(1, 0.92, 0.85, 0.7 * a)
	draw_style_box(fill, Rect2(inner.position, Vector2(inner.size.x * clampf(_hp_trail, 0.0, 1.0), inner.size.y)))
	var col := Color("c04030") if f > 0.66 else (Color("e08030") if f > 0.33 else Color("ff3030"))
	if exposed:
		col = Color("ffd84a").lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 16.0))
	fill.bg_color = Color(col, a)
	if f > 0.0:
		draw_style_box(fill, Rect2(inner.position, Vector2(maxf(inner.size.x * f, 4.0), inner.size.y)))
		draw_rect(Rect2(inner.position + Vector2(2, 1), Vector2(maxf(inner.size.x * f - 4.0, 0.0), inner.size.y * 0.35)), Color(1, 1, 1, 0.25 * a))
	for notch in [0.33, 0.66]:
		draw_line(Vector2(inner.position.x + inner.size.x * notch, r.position.y + 1), Vector2(inner.position.x + inner.size.x * notch, r.end.y - 1), Color(1, 1, 1, 0.6 * a), 2.0)
	if exposed:
		_font.draw_string(get_canvas_item(), Vector2(0, 50), "WEAK POINT OPEN", HORIZONTAL_ALIGNMENT_CENTER, W, 12, Color(1, 0.9, 0.4, a * (0.6 + 0.4 * sin(_t * 12.0))))
	elif enraged:
		_font.draw_string(get_canvas_item(), Vector2(0, 50), "ENRAGED", HORIZONTAL_ALIGNMENT_CENTER, W, 12, Color(1, 0.4, 0.3, a * (0.7 + 0.3 * sin(_t * 8.0))))
