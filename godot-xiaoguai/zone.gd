extends Node2D
## A blast area. It shows a warning ring for `delay` seconds, then hits everything
## inside. Enemy zones (fireball, slam) hurt 小怪 and towers, so dodge or roll out.
## Player zones (Bone Nova, Roar) hurt, knock back and stun villagers.

const Sfx := preload("res://sfx.gd")

var radius := 50.0
var delay := 0.8
var damage := 2
var team := "enemy"
var color := Color(1.0, 0.45, 0.2)
var knock := 0.0           ## player zones: push villagers away at this speed
var stun := 0.0            ## player zones: seconds villagers are frozen
var source = null          ## the player, for team "player": hits earn EXP
var age := 0.0
var detonated := false
var warned := false


func _physics_process(delta: float) -> void:
	if not warned:
		warned = true
		if team == "enemy" and delay > 0.25:
			Sfx.play_at(get_tree(), "warn", global_position, -4.0)
	age += delta
	if not detonated and age >= delay:
		detonated = true
		Sfx.play_at(get_tree(), "explosion" if damage > 0 else "roar", global_position, -3.0)
		_detonate()
	if age >= delay + 0.25:
		queue_free()
	queue_redraw()


func _detonate() -> void:
	if team == "enemy":
		var pl = get_tree().get_first_node_in_group("player")
		if pl != null and pl.hp > 0 and pl.global_position.distance_to(global_position) <= radius + pl.body_radius * 0.5:
			pl.take_hit(damage, (pl.global_position - global_position).normalized())
		for t in get_tree().get_nodes_in_group("structures"):
			if t.global_position.distance_to(global_position) <= radius:
				t.take_hit(damage, Vector2.ZERO)
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) > radius:
			continue
		var away: Vector2 = (e.global_position - global_position).normalized()
		if damage > 0:
			e.take_hit(damage, away)
			if source != null and is_instance_valid(source):
				source.add_xp(1)
		if knock > 0.0:
			e.knock = away * knock
		if stun > 0.0:
			e.stun_left = maxf(e.stun_left, stun)


func _draw() -> void:
	if not detonated:
		var f := clampf(age / maxf(delay, 0.01), 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius * f, Color(color, 0.2))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.85), 2.0)
	else:
		var a := clampf(1.0 - (age - delay) / 0.25, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(color, 0.55 * a))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1, 1, 1, a), 3.0)
