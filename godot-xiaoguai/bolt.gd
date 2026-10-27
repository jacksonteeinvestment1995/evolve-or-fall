extends Node2D
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
				if source != null and is_instance_valid(source):
					source.add_xp(1)
				if not pierce:
					queue_free()
					return
	queue_redraw()


var style := ""            ## "spirit" draws a ghost wisp instead of a plain ball


func _draw() -> void:
	if style == "spirit":
		SkillFx.draw_wisp(self, dir, radius, color)
		return
	draw_line(-dir * radius * 2.5, Vector2.ZERO, Color(color, 0.4), radius)
	draw_circle(Vector2.ZERO, radius, color)
