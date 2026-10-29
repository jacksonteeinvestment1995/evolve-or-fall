extends Node2D

const Sfx := preload("res://sfx.gd")
## A projectile. Villager bolts (team "enemy") hurt 小怪 and towers; 小怪's Spirit Bolt
## (team "player") hurts villagers. Trees stop them. A piercing bolt passes through what it
## hits (once each).

var dir := Vector2.RIGHT
var speed := 220.0
var damage := 1
var team := "enemy"
var life := 2.0
var radius := 5.0
var color := Color.WHITE
var pierce := false
var effect := ""           ## "slow" makes a hit slow 小怪 for 3 seconds
var source = null          ## the player, for team "player": hits earn EXP
var hit_ids: Array[int] = []
var hit_sound := ""        ## player bolts: the skill whose sound plays where it hits a villager


func _physics_process(delta: float) -> void:
	position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var level = get_parent()
	if level.has_method("is_solid_at") and level.is_solid_at(global_position):
		queue_free()
		return
	if team == "enemy":
		var pl = get_tree().get_first_node_in_group("player")
		if pl != null and pl.hp > 0 and not (pl.get_instance_id() in hit_ids) \
				and global_position.distance_to(pl.global_position) < pl.body_radius + radius:
			hit_ids.append(pl.get_instance_id())
			pl.take_hit(damage, dir)
			Sfx.play(get_tree(), _enemy_hit_sound(), -3.0)
			if effect == "slow":
				pl.slow_left = 3.0
			if not pierce:
				queue_free()
				return
		for t in get_tree().get_nodes_in_group("structures"):
			if not (t.get_instance_id() in hit_ids) and global_position.distance_to(t.global_position) < 14.0 + radius:
				hit_ids.append(t.get_instance_id())
				t.take_hit(damage, dir)
				if not pierce:
					queue_free()
					return
	else:
		for e in get_tree().get_nodes_in_group("enemies"):
			var id: int = e.get_instance_id()
			if id in hit_ids:
				continue
			if global_position.distance_to(e.global_position) < 10.0 + radius:
				hit_ids.append(id)
				e.take_hit(damage, dir)
				if hit_sound != "":
					SkillSounds.play_at(get_tree(), hit_sound, e.global_position, -2.0)
				if status != "" and is_instance_valid(e) and not e.is_queued_for_deletion():
					e.apply_status(status, status_time)
				if not pierce:
					queue_free()
					return
	queue_redraw()


var style := ""            ## "spirit" draws a ghost wisp; the volley skills use acid, spear, orb, glob, fire, claw, seed, rock, hell
var sprite := ""           ## a pixel-art strip drawn along the flight (the hunters' arrow)
var status := ""           ## player bolts: a status put on every villager hit
var status_time := 0.0


func _draw() -> void:
	if team == "enemy":
		# every villager projectile gets a red streak and a pulsing danger rim, so it is never mistaken for 小怪's
		draw_line(-dir * radius * 6.0, -dir * radius * 1.5, Color(1.0, 0.2, 0.15, 0.45), maxf(2.0, radius * 0.9))
		draw_arc(Vector2.ZERO, radius * 2.1, 0.0, TAU, 14, Color(1.0, 0.25, 0.2, 0.35 + 0.3 * sin(Time.get_ticks_msec() * 0.02)), 1.6)
	if team == "player":
		# 小怪's own projectiles glow and leave a shimmering tail
		SkillFx.glow(self, Vector2.ZERO, radius * 3.2, color, 1.0)
		SkillFx.sparkle_trail(self, dir, radius, color, float(get_instance_id() % 17))
	if sprite != "":
		var st := Sprites.tex(sprite)
		if st != null:
			var fh := st.get_height()
			var frame := int(Time.get_ticks_msec() / 90.0) % maxi(1, st.get_width() / fh)
			draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
			draw_texture_rect_region(st, Rect2(-fh * 0.5, -fh * 0.5, fh, fh), Rect2(frame * fh, 0, fh, fh))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
	if style == "spirit":
		SkillFx.draw_wisp(self, dir, radius, color)
		return
	if style != "":
		SkillFx.draw_bolt(self, style, dir, radius, color)
		return
	draw_line(-dir * radius * 2.5, Vector2.ZERO, Color(color, 0.4), radius)
	draw_circle(Vector2.ZERO, radius, color)


## How an enemy projectile sounds when it lands on 小怪, by what it looks like.
func _enemy_hit_sound() -> String:
	if sprite != "" or style == "arrow" or style == "javelin":
		return "hit_pierce"
	match style:
		"axe":
			return "hit_axe"
		"net", "mud":
			return "hit_goo"
		"spore", "shadow", "divine", "magic", "holy":
			return "hit_magic"
	return "hit_blast" if effect == "" and radius > 8.0 else "hit_magic"
