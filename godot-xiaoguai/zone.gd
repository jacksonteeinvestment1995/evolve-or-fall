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
var status := ""           ## player zones: a status put on every villager hit (burn, chill...)
var status_time := 0.0
var fx := ""                ## sprite strip in art/export drawn when the blast goes off (4 frames)
var age := 0.0
var style := ""            ## player zones: "nova", "roar" or "doom" draw their own styled effect
var dur := 0.25            ## seconds the burst stays on screen after it goes off
var detonated := false
var warned := false
var hit_sound := ""        ## player zones: the skill whose sound plays when the blast lands on villagers


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
	if age >= delay + dur:
		queue_free()
	queue_redraw()


func _detonate() -> void:
	if team == "enemy":
		var pl = get_tree().get_first_node_in_group("player")
		if pl != null and pl.hp > 0 and pl.global_position.distance_to(global_position) <= radius + pl.body_radius * 0.5:
			pl.take_hit(damage, (pl.global_position - global_position).normalized())
			Sfx.play(get_tree(), "hit_blast", -2.0)
		for t in get_tree().get_nodes_in_group("structures"):
			if t.global_position.distance_to(global_position) <= radius:
				t.take_hit(damage, Vector2.ZERO)
		return
	Juice.light(get_parent(), global_position, color, radius / 55.0, 1.5, 0.4)
	if damage > 0:
		Juice.scorch(get_parent(), global_position, radius * 0.7, color)
		Juice.punch(get_parent(), clampf(radius / 6000.0, 0.01, 0.03))
	var landed := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) > radius:
			continue
		landed = true
		var away: Vector2 = (e.global_position - global_position).normalized()
		if damage > 0:
			e.take_hit(damage, away)
			if source != null and is_instance_valid(source):
				source.add_xp(1)
		if status != "" and is_instance_valid(e) and not e.is_queued_for_deletion():
			e.apply_status(status, status_time)
		if knock > 0.0:
			e.knock = away * knock
		if stun > 0.0:
			e.stun_left = maxf(e.stun_left, stun)
	if landed and hit_sound != "":
		SkillSounds.play_at(get_tree(), hit_sound, global_position, -3.0)


func _draw() -> void:
	if not detonated:
		var f := clampf(age / maxf(delay, 0.01), 0.0, 1.0)
		if team == "enemy":
			SkillFx.draw_danger_warn(self, radius, f, color)
			return
		draw_circle(Vector2.ZERO, radius * f, Color(color, 0.2))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.85), 2.0)
	else:
		if team == "enemy" and style == "":
			SkillFx.draw_danger_burst(self, radius, clampf((age - delay) / maxf(dur, 0.01), 0.0, 1.0), color)
			return
		var a := clampf(1.0 - (age - delay) / 0.25, 0.0, 1.0)
		if style != "":
			var st := clampf((age - delay) / dur, 0.0, 1.0)
			match style:
				"nova":
					SkillFx.draw_bone_nova(self, radius, st, color)
				"roar":
					SkillFx.draw_roar(self, radius, st, color)
				"doom":
					SkillFx.draw_doom(self, radius, st, color)
				_:
					SkillFx.draw_burst(self, style, radius, st, color)
			return
		var t: Texture2D = Sprites.tex(fx) if fx != "" else null
		if t != null:
			var fh := t.get_height()
			var frame := clampi(int((1.0 - a) * 4.0), 0, t.get_width() / fh - 1)
			draw_circle(Vector2.ZERO, radius, Color(color, 0.15 * a))
			draw_texture_rect_region(t, Rect2(-radius, -radius, radius * 2.0, radius * 2.0), Rect2(frame * fh, 0, fh, fh), Color(1, 1, 1, minf(1.0, a * 1.6)))
			return
		draw_circle(Vector2.ZERO, radius, Color(color, 0.55 * a))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1, 1, 1, a), 3.0)
