extends Control
## The combo show: a big counter at the top of the screen that punches on every hit, grows with the chain, shakes,
## changes colour by tier (white, gold, orange, red, then a rainbow), slams a tier word down at the milestones, shows a
## bar of the time left before the chain breaks, and shatters when it breaks. Rolling through enemies adds the world
## side: a streak, sparks and a "x12" pop at every roll hit, a coloured trail behind the roll, a small camera punch, and
## a burst when a roll that hit two or more ends. Everything is drawn in code, never takes input, and the world pops
## are capped and free themselves.

const Sfx := preload("res://sfx.gd")
const MAX_POPS := 10         ## world pops alive at once (the oldest goes first)
const POP_LIFE := 0.45
const BURST_LIFE := 0.5
const SHOW_FROM := 2          ## the counter shows from this chain length (like the HUD item)
const WORDS := {5: "NICE", 10: "GREAT", 20: "BRUTAL", 30: "SAVAGE", 40: "UNSTOPPABLE", 60: "GODLIKE", 100: "LEGENDARY"}
const TIER_COLS := [Color("ffffff"), Color("ffe27a"), Color("ff9a2a"), Color("ff3838"), Color("c070ff")]
const SHARDS := 16

var main: Node
var _pl: Node = null
var font: Font = ThemeDB.fallback_font

var shown := 0                ## the number on the counter
var _punch := 0.0             ## 1 on a hit, falls to 0: the pop
var _tilt := 0.0
var _shake := 0.0
var _frac := 0.0              ## the time left of the chain, 0..1
var word := ""                ## the tier word on screen ("" none)
var _word_age := 9.0
var _word_col := Color.WHITE
var brk_age := -1.0           ## the shatter's age (-1: not breaking)
var _brk_count := 0
var _brk_col := Color.WHITE
var _shard_v := PackedVector2Array()
var _shard_p := PackedVector2Array()
var _anchor := Vector2(640, 92)
var _ui := 1.0
var _relayout_t := 0.0
var _drawn := false
var _was_rolling := false
var _roll_hits := 0
var pops: Array = []          ## the world pops alive (RollPop nodes)
var trail: Node2D = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shard_v.resize(SHARDS)
	_shard_p.resize(SHARDS)
	_hook_player()


## The colour tier of a chain length: 0 plain, 1 gold (x5), 2 orange (x10), 3 red (x20), 4 rainbow (x40).
static func tier_of(n: int) -> int:
	if n >= 40:
		return 4
	if n >= 20:
		return 3
	if n >= 10:
		return 2
	if n >= 5:
		return 1
	return 0


## The word slammed down when the chain reaches exactly n ("" when n is no milestone).
static func tier_word(n: int) -> String:
	if WORDS.has(n):
		return WORDS[n]
	if n > 100 and n % 50 == 0:
		return "BEYOND"
	return ""


static func tier_color(n: int, t: float = 0.0) -> Color:
	var tier := tier_of(n)
	if tier == 4:
		return Color.from_hsv(fposmod(0.78 + t * 0.6, 1.0), 0.55, 1.0)  # a rainbow that keeps turning
	return TIER_COLS[tier]


func _hook_player() -> void:
	var p = main.player if main != null else null
	if p == _pl:
		return
	_pl = p
	if _pl != null and _pl.has_signal("combo_hit"):
		_pl.combo_hit.connect(_on_hit)
		_pl.combo_broke.connect(_on_broke)


func _on_hit(n: int, at: Vector2, rolled: bool) -> void:
	if shown < SHOW_FROM and n >= SHOW_FROM:
		_relayout()
	shown = n
	brk_age = -1.0
	var tier := tier_of(n)
	_punch = 1.0 if rolled else 0.6
	_tilt = randf_range(-0.22, 0.22) * (1.0 if rolled else 0.5)
	_shake = 1.0 if rolled else 0.5
	var w := tier_word(n)
	if w != "":
		word = w
		_word_age = 0.0
		_word_col = tier_color(n, _now())
		Sfx.play(get_tree(), "s_buff", -6.0, 0.9 + 0.08 * tier)
	if rolled:
		_roll_hits += 1
		_spawn_pop(at, n, false)
		if main != null and main.has_method("punch"):
			main.punch(minf(0.012 + 0.004 * tier, 0.03))
			main.shake(1.5 + 0.7 * tier)
		Sfx.play(get_tree(), "hit", -3.0, minf(1.0 + 0.035 * n, 2.2))


func _on_broke(n: int) -> void:
	shown = 0
	if n < 3:
		return
	_brk_count = n
	brk_age = 0.0
	_brk_col = tier_color(n, _now())
	for i in SHARDS:
		var ang := -PI * 0.5 + (float(i) / SHARDS - 0.5) * PI * 1.6 + randf_range(-0.15, 0.15)
		_shard_v[i] = Vector2.from_angle(ang) * randf_range(140.0, 300.0) * _ui
		_shard_p[i] = Vector2(randf_range(-30.0, 30.0), randf_range(-12.0, 12.0)) * _ui
	Sfx.play(get_tree(), "demolish", -10.0, 0.8)


func _now() -> float:
	return Time.get_ticks_msec() * 0.001


## A pop (or the end-of-roll burst) in the world at a spot; the oldest goes when there are too many.
func _spawn_pop(at: Vector2, n: int, burst: bool) -> void:
	if main == null:
		return
	for i in range(pops.size() - 1, -1, -1):
		if not is_instance_valid(pops[i]) or pops[i].is_queued_for_deletion():
			pops.remove_at(i)
	while pops.size() >= MAX_POPS:
		var old = pops.pop_front()
		old.queue_free()
	var p := RollPop.new()
	p.position = at
	p.count = n
	p.col = tier_color(n, _now())
	p.dir = _pl.roll_dir if _pl != null and _pl.get("roll_dir") != null and _pl.roll_dir != Vector2.ZERO else Vector2.RIGHT
	p.burst = burst
	p.hits = _roll_hits
	p.life = BURST_LIFE if burst else POP_LIFE
	main.add_child(p)
	pops.append(p)


## The world pops still alive.
func active_pops() -> int:
	var c := 0
	for p in pops:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			c += 1
	return c


## Where the counter sits: top centre, pushed down below anything of the HUD or the touch controls it would cover.
func _relayout() -> void:
	var vs := get_viewport_rect().size
	_ui = clampf(minf(vs.x, vs.y) / 720.0, 0.72, 1.0)
	var half := Vector2(120.0, 0.0) * _ui
	var top := 14.0
	var h := 150.0 * _ui
	var rects: Array = []
	if main != null:
		if main.has_method("hud_rects"):
			rects = main.hud_rects()
		var tu = main.get("touch_ui")
		if bool(main.get("touch_mode")) and tu != null and tu.has_method("ui_rects"):
			rects.append_array(tu.ui_rects())
	# first choice: along the top, in the widest gap between what sits there (the HUD plate and the minimap on a phone)
	var left := 0.0
	var right := vs.x
	var band := Rect2(0.0, top, vs.x, h)
	for r in rects:
		if r.intersects(band):
			if r.get_center().x < vs.x * 0.5:
				left = maxf(left, r.end.x + 6.0)
			else:
				right = minf(right, r.position.x - 6.0)
	if right - left >= half.x * 2.0:
		var cx := clampf(vs.x * 0.5, left + half.x, right - half.x)
		_anchor = Vector2(cx, top + 70.0 * _ui)
		return
	# otherwise centred, pushed down below whatever it would cover
	for pass_i in 4:
		var box := Rect2(vs.x * 0.5 - half.x, top, half.x * 2.0, h)
		var moved := false
		for r in rects:
			if r.intersects(box):
				top = r.end.y + 6.0
				moved = true
		if not moved:
			break
	top = minf(top, vs.y * 0.34 - h * 0.5)  # never down onto the player in the middle of the screen
	_anchor = Vector2(vs.x * 0.5, top + 70.0 * _ui)


func _process(delta: float) -> void:
	_hook_player()
	if _pl == null or not is_instance_valid(_pl):
		return
	# the roll: a fresh roll starts its hit count; a roll that hit 2+ ends in a burst
	var rolling: bool = float(_pl.roll_left) > 0.0
	if rolling and not _was_rolling:
		_roll_hits = 0
	if _was_rolling and not rolling and _roll_hits >= 2 and int(_pl.combo) > 0:
		_spawn_pop(_pl.global_position, int(_pl.combo), true)
		if main != null and main.has_method("punch"):
			main.punch(0.03)
			main.shake(4.0 + float(tier_of(int(_pl.combo))))
		Sfx.play(get_tree(), "s_blast", -8.0, 1.2)
	_was_rolling = rolling
	if trail == null and main != null:
		trail = RollTrail.new()
		trail.fx = self
		main.add_child(trail)
	if trail != null:
		trail.tick(_pl, rolling, delta)
	_punch = maxf(_punch - delta * 4.0, 0.0)
	_shake = maxf(_shake - delta * 3.0, 0.0)
	_word_age += delta
	if int(_pl.combo) == 0 and shown > 0:
		shown = 0
	if shown > 0:
		_frac = clampf(float(_pl.combo_t) / maxf(float(_pl.combo_window()), 0.01), 0.0, 1.0)
		_relayout_t -= delta
		if _relayout_t <= 0.0:
			_relayout_t = 1.0
			_relayout()
	if brk_age >= 0.0:
		brk_age += delta
		if brk_age > 0.7:
			brk_age = -1.0
	var active := shown >= SHOW_FROM or brk_age >= 0.0
	if active or _drawn:
		_drawn = active
		queue_redraw()


func _draw() -> void:
	if shown >= SHOW_FROM:
		_draw_counter()
	if brk_age >= 0.0:
		_draw_break()


func _draw_counter() -> void:
	var now := _now()
	var tier := tier_of(shown)
	var col := tier_color(shown, now)
	var p := _punch
	var low := _frac < 0.3
	var fs := int((50.0 + minf(float(shown), 60.0) * 0.65) * _ui)
	var sc := 1.0 + 0.8 * p * p + (0.04 * sin(now * 18.0) if tier >= 3 else 0.0)
	var amp := (2.0 + 2.5 * tier) * _shake + (2.0 if low else 0.0) + (1.0 if tier >= 3 else 0.0)
	var jit := Vector2(randf_range(-amp, amp), randf_range(-amp, amp)) * _ui
	var rot := _tilt * p + (0.05 * sin(now * 9.0) if tier >= 4 else 0.0)
	var c := _anchor + jit
	# rays behind the number, spinning faster at higher tiers
	if tier >= 1:
		var rays := 8 + tier * 3
		var spin := now * (0.6 + 0.5 * tier)
		var r0 := 26.0 * _ui
		var r1 := (60.0 + 30.0 * p + 8.0 * tier) * _ui
		for i in rays:
			var d := Vector2.from_angle(spin + TAU * float(i) / rays)
			draw_line(c + d * r0, c + d * r1, Color(col, 0.16 + 0.3 * p), (5.0 + 3.0 * p) * _ui)
	draw_circle(c, (30.0 + 18.0 * p) * _ui, Color(col, 0.10 + 0.25 * p))
	# the number, with a chromatic split from the red tier on
	var s := "x%d" % shown
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(-w * 0.5, fs * 0.36)
	draw_set_transform(c, rot, Vector2(sc, sc))
	var outline := maxi(4, int(fs * 0.16))
	if tier >= 3:
		draw_string(font, at + Vector2(-4, 1) * _ui, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.1, 0.3, 0.6))
		draw_string(font, at + Vector2(4, -1) * _ui, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.9, 1.0, 0.6))
	draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(0.06, 0.02, 0.04, 0.95))
	var face := col.lerp(Color.WHITE, 0.75 * p)
	if low and int(now * 10.0) % 2 == 0:
		face = face.lerp(Color("ff4040"), 0.6)
	if tier >= 4:
		# the top tier: every letter its own colour of a turning rainbow
		var x := at.x
		for i in s.length():
			var ch := s.substr(i, 1)
			var cc := Color.from_hsv(fposmod(now * 0.8 + float(i) * 0.17, 1.0), 0.6, 1.0).lerp(Color.WHITE, 0.75 * p)
			draw_string(font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cc)
			x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	else:
		draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, face)
	# "COMBO" over it
	var small := int(17.0 * _ui)
	var lw := font.get_string_size("COMBO", HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	var la := Vector2(-lw * 0.5, -fs * 0.52)
	draw_string_outline(font, la, "COMBO", HORIZONTAL_ALIGNMENT_LEFT, -1, small, 4, Color(0, 0, 0, 0.9))
	draw_string(font, la, "COMBO", HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(1, 1, 1, 0.92))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the time left: a bar under the number that drains, and blinks when nearly out
	var bw := 150.0 * _ui
	var bh := 7.0 * _ui
	var bar := Rect2(_anchor.x - bw * 0.5, _anchor.y + fs * 0.66, bw, bh)
	draw_rect(bar.grow(2.0), Color(0, 0, 0, 0.7))
	var fill := col if not (low and int(now * 10.0) % 2 == 0) else Color("ff4040")
	draw_rect(Rect2(bar.position, Vector2(bw * _frac, bh)), fill)
	draw_rect(Rect2(bar.position, Vector2(bw * _frac, bh * 0.4)), Color(1, 1, 1, 0.35))
	# the tier word: slams down big, holds, fades
	if word != "" and _word_age < 1.1:
		var t := _word_age
		var ws := 2.6 - 1.6 * minf(t / 0.12, 1.0) if t < 0.12 else 1.0 + 0.12 * maxf(0.0, 1.0 - (t - 0.12) / 0.15)
		var wa := 1.0 - smoothstep(0.8, 1.1, t)
		var wsize := int(30.0 * _ui)
		var ww := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, wsize).x
		var wc := Vector2(_anchor.x, bar.end.y + 26.0 * _ui)
		if t < 0.25:
			var f := t / 0.25
			draw_circle(wc, (20.0 + 90.0 * f) * _ui, Color(_word_col, 0.45 * (1.0 - f)))
		draw_set_transform(wc, -0.06, Vector2(ws, ws))
		var wcol := _word_col if tier < 4 else tier_color(shown, now + 0.3)
		draw_string_outline(font, Vector2(-ww * 0.5, wsize * 0.36), word, HORIZONTAL_ALIGNMENT_LEFT, -1, wsize, 7, Color(0.05, 0.0, 0.05, wa))
		draw_string(font, Vector2(-ww * 0.5, wsize * 0.36), word, HORIZONTAL_ALIGNMENT_LEFT, -1, wsize, Color(wcol.lerp(Color.WHITE, 0.6 * maxf(0.0, 1.0 - t / 0.2)), wa))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The chain broke: the number drops and spins away grey while shards fly and fall.
func _draw_break() -> void:
	var t := brk_age
	var a := 1.0 - smoothstep(0.3, 0.7, t)
	var g := 900.0 * _ui
	var flash := maxf(0.0, 1.0 - t / 0.12)
	if flash > 0.0:
		draw_circle(_anchor, (40.0 + 80.0 * (1.0 - flash)) * _ui, Color(1, 1, 1, 0.35 * flash))
	for i in SHARDS:
		var q := _anchor + _shard_p[i] + _shard_v[i] * t + Vector2(0, 0.5 * g * t * t)
		var d := _shard_v[i].normalized().rotated(t * 9.0 * (1.0 if i % 2 == 0 else -1.0)) * 11.0 * _ui
		draw_line(q - d, q + d, Color(0, 0, 0, 0.7 * a), 9.0 * _ui)
		draw_line(q - d, q + d, Color(_brk_col, a), 6.0 * _ui)
		draw_line(q - d * 0.5, q + d * 0.5, Color(1, 1, 1, a), 2.0 * _ui)
	var fs := int((50.0 + minf(float(_brk_count), 60.0) * 0.65) * _ui)
	var s := "x%d" % _brk_count
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var col := _brk_col.lerp(Color(0.5, 0.5, 0.55), minf(t * 5.0, 1.0)).lerp(Color.WHITE, flash)
	# cracked in two: the left and right halves tumble apart and fall
	var cut := maxi(1, s.length() / 2)
	var halves := [s.substr(0, cut), s.substr(cut)]
	var x0 := -w * 0.5
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var part: String = halves[k]
		var pw := font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pc := _anchor + Vector2(x0 + pw * 0.5 + side * 70.0 * t * _ui, 0.5 * g * 0.7 * t * t - 40.0 * t * _ui)
		draw_set_transform(pc, side * (0.15 + 2.2 * t * t), Vector2.ONE * (1.0 + 0.25 * flash))
		draw_string_outline(font, Vector2(-pw * 0.5, fs * 0.36), part, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color(0, 0, 0, 0.85 * a))
		draw_string(font, Vector2(-pw * 0.5, fs * 0.36), part, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
		x0 += pw
	var bs := int(24.0 * _ui)
	var bw := font.get_string_size("BREAK!", HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
	var bsc := 1.6 - 0.6 * minf(t / 0.1, 1.0)
	draw_set_transform(_anchor + Vector2(randf_range(-2, 2), fs * 0.75 + randf_range(-2, 2)), 0.05, Vector2(bsc, bsc))
	draw_string_outline(font, Vector2(-bw * 0.5, bs * 0.36), "BREAK!", HORIZONTAL_ALIGNMENT_LEFT, -1, bs, 6, Color(0, 0, 0, a))
	draw_string(font, Vector2(-bw * 0.5, bs * 0.36), "BREAK!", HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color(1, 0.3, 0.25, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _exit_tree() -> void:
	if trail != null and is_instance_valid(trail):
		trail.queue_free()


## A roll hit in the world: a streak along the roll, a ring, sparks and the new count popping up big. The burst at the
## end of a roll is the same, larger, with how many the roll hit.
class RollPop extends Node2D:
	var count := 0
	var hits := 0
	var col := Color.WHITE
	var dir := Vector2.RIGHT
	var burst := false
	var life := 0.45
	var age := 0.0
	var _txt := ""
	var _sub := ""

	func _ready() -> void:
		z_index = 40
		_txt = "x%d" % count
		_sub = "%d HITS!" % hits if burst else ""

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := age / life
		var e := 1.0 - (1.0 - t) * (1.0 - t)
		var a := 1.0 - smoothstep(0.6, 1.0, t)
		var k := 2.0 if burst else 1.0
		# the flash and the ring
		if t < 0.3:
			draw_circle(Vector2.ZERO, (9.0 + 10.0 * t) * k * (1.0 - t / 0.3), Color(1, 1, 1, 0.9 * (1.0 - t / 0.3)))
		draw_arc(Vector2.ZERO, (6.0 + 22.0 * e) * k, 0.0, TAU, 20, Color(col, 0.85 * a), (3.0 - 2.0 * t) * k)
		# the streak along the roll
		if not burst:
			var n := dir.orthogonal()
			var ln := 30.0 * (0.3 + 0.7 * e)
			draw_line(-dir * ln, dir * ln * 0.5, Color(col, 0.5 * a), 7.0 * (1.0 - t))
			draw_line(-dir * ln * 1.1, dir * ln * 0.6, Color(1, 1, 1, a), 2.2 * (1.0 - t))
			draw_line(n * 5.0 - dir * ln * 0.6, n * 5.0 + dir * ln * 0.2, Color(col, 0.6 * a), 1.2)
			draw_line(-n * 5.0 - dir * ln * 0.6, -n * 5.0 + dir * ln * 0.2, Color(col, 0.6 * a), 1.2)
		# sparks
		var rays := 14 if burst else 7
		for i in rays:
			var ang := dir.angle() + (TAU * float(i) / rays if burst else (float(i) / rays - 0.5) * 2.4 + PI * 0.0)
			var d := Vector2.from_angle(ang + float(count) * 0.7)
			draw_line(d * (5.0 + 10.0 * e) * k, d * (10.0 + 22.0 * e) * k, Color(col.lightened(0.4), a), 1.6 * k * 0.8)
		# the number: pops in big, settles, rises and fades
		var font := ThemeDB.fallback_font
		var pop := lerpf(0.4, 1.8, minf(t / 0.12, 1.0)) if t < 0.12 else lerpf(1.8, 1.0, minf((t - 0.12) / 0.18, 1.0))
		var px := 14 if not burst else 18
		var y := -16.0 - 18.0 * e
		draw_set_transform(Vector2(0, y), -0.12 if not burst else 0.0, Vector2(pop, pop))
		var w := font.get_string_size(_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string_outline(font, Vector2(-w * 0.5, px * 0.36), _txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4, Color(0, 0, 0, 0.9 * a))
		draw_string(font, Vector2(-w * 0.5, px * 0.36), _txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col.lerp(Color.WHITE, maxf(0.0, 1.0 - t * 4.0)), a))
		if _sub != "":
			var sw := font.get_string_size(_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string_outline(font, Vector2(-sw * 0.5, px * 0.36 + 11.0), _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 0.9 * a))
			draw_string(font, Vector2(-sw * 0.5, px * 0.36 + 11.0), _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## One node for the whole game: a coloured ribbon and speed lines behind 小怪 while he rolls, brighter with every enemy
## the roll hits. A fixed ring of points, so nothing is allocated while it runs.
class RollTrail extends Node2D:
	const N := 10
	var fx = null
	var pts := PackedVector2Array()
	var count := 0
	var head := 0
	var fade := 0.0
	var dir := Vector2.RIGHT
	var col := Color.WHITE
	var power := 0.0

	func _ready() -> void:
		z_index = 3
		pts.resize(N)

	func tick(pl: Node, rolling: bool, delta: float) -> void:
		if rolling:
			if fade <= 0.0:
				count = 0
			fade = 0.22
			dir = pl.roll_dir if pl.roll_dir != Vector2.ZERO else Vector2.RIGHT
			var n: int = int(pl.combo)
			col = fx.tier_color(n, Time.get_ticks_msec() * 0.001) if n > 0 else Color(0.75, 0.9, 1.0)
			power = minf(float(fx._roll_hits) / 4.0, 1.0)
			head = (head + 1) % N
			pts[head] = pl.global_position
			count = mini(count + 1, N)
			queue_redraw()
		elif fade > 0.0:
			fade -= delta
			queue_redraw()
			if fade <= 0.0:
				count = 0

	func _draw() -> void:
		if count < 2 or fade <= 0.0:
			return
		var a := clampf(fade / 0.22, 0.0, 1.0)
		var w := 5.0 + 7.0 * power
		for i in count - 1:
			var p0: Vector2 = pts[(head - i + N) % N]
			var p1: Vector2 = pts[(head - i - 1 + N) % N]
			var f := 1.0 - float(i) / float(count - 1)
			draw_line(p0, p1, Color(col, (0.25 + 0.35 * power) * a * f), w * f + 2.0)
			draw_line(p0, p1, Color(1, 1, 1, 0.7 * a * f), 1.5 + 1.5 * power * f)
		# speed lines beside and behind him
		var tip: Vector2 = pts[head]
		var n := dir.orthogonal()
		var lines := 3 + int(power * 3.0)
		for i in lines:
			var side := (float(i) - (lines - 1) * 0.5) * 6.0
			var ln := 22.0 + 26.0 * power + 10.0 * fposmod(float(i) * 0.618 + Time.get_ticks_msec() * 0.01, 1.0)
			var s0 := tip + n * side - dir * (10.0 + absf(side))
			draw_line(s0, s0 - dir * ln, Color(col.lightened(0.3), 0.7 * a), 1.4)
