extends Node2D
## A crack in the ground from an earthquake: it splits open, shows a dark gap with a lit edge, then
## slowly closes. Purely visual.

const LIFE := 5.0

var seed_value := 1
var age := 0.0
var _lines: Array = []


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var main_dir := r.randf() * TAU
	for b in r.randi_range(2, 3):
		var pts := PackedVector2Array([Vector2.ZERO])
		var a := main_dir + (float(b) - 1.0) * 0.9 + r.randf_range(-0.3, 0.3)
		var p := Vector2.ZERO
		for s in r.randi_range(5, 8):
			a += r.randf_range(-0.6, 0.6)
			p += Vector2.from_angle(a) * r.randf_range(12.0, 24.0)
			pts.append(p)
		_lines.append(pts)


func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var open := smoothstep(0.0, 0.5, age)
	var close := 1.0 - smoothstep(3.5, LIFE, age)
	var w := 5.0 * open * close
	for pts in _lines:
		var shown := PackedVector2Array()
		var count := maxi(2, int(ceil(pts.size() * open)))
		for i in count:
			shown.append(pts[i])
		draw_polyline(shown, Color(0.9, 0.6, 0.3, 0.6 * close), w + 2.0)
		draw_polyline(shown, Color(0.06, 0.03, 0.02, 0.95 * close), w)
	if age < 0.6:
		for i in 6:
			var d := Vector2.from_angle(float(i) * 1.05)
			draw_circle(d * 10.0 * (1.0 + age * 6.0), 2.0 * (1.0 - age / 0.6), Color(0.6, 0.45, 0.3, 0.7))
