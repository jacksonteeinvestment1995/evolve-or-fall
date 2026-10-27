extends Node2D
## A toxic fog bank that drifts across the map. Everything inside it is poisoned: villagers and 小怪 alike.

var radius := 170.0
var drift := Vector2.RIGHT * 26.0
var life := 36.0
var age := 0.0
var _tick := 0.0


func _ready() -> void:
	z_index = 5


func _physics_process(delta: float) -> void:
	age += delta
	position += drift * delta
	if age >= life:
		queue_free()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.6
		_poison()
	queue_redraw()


func _poison() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.global_position.distance_to(global_position) <= radius:
			e.apply_status("poison", 3.0)
	var pl = get_tree().get_first_node_in_group("player")
	if pl != null and pl.hp > 0 and pl.global_position.distance_to(global_position) <= radius:
		pl.take_hit(1, Vector2.ZERO)  # the invulnerability after a hit makes this about once a second


func _draw() -> void:
	var fade := smoothstep(0.0, 3.0, age) * (1.0 - smoothstep(life - 4.0, life, age))
	for i in 18:
		var a := float(i) * 2.399 + age * 0.25
		var rr := radius * (0.2 + 0.75 * fposmod(float(i) * 0.37, 1.0))
		var c := Vector2.from_angle(a) * rr
		var pr := radius * (0.22 + 0.1 * sin(age * 0.8 + float(i)))
		draw_circle(c, pr, Color(0.45, 0.75, 0.25, 0.16 * fade))
		draw_circle(c + Vector2(-pr * 0.25, -pr * 0.25), pr * 0.55, Color(0.7, 0.95, 0.4, 0.1 * fade))
	for i in 6:
		var b := fposmod(age * 0.5 + float(i) * 0.17, 1.0)
		draw_circle(Vector2.from_angle(float(i) * 1.7) * radius * (0.3 + 0.5 * b), 2.0, Color(0.8, 1.0, 0.4, 0.5 * fade * (1.0 - b)))
