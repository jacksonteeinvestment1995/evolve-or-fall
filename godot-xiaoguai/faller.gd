extends Node2D
## One piece of treasure rain: a star falls from the sky and turns into its prize where it lands.
##   stone  an EXP stone      bones  a handful of bones      chest  a wooden or silver chest

const Popups := preload("res://popups.gd")
const Sfx := preload("res://sfx.gd")
const ExpStone := preload("res://exp_stone.gd")
const TreasureScript := preload("res://treasure.gd")

var kind := "stone"
var amount := 5
var fall := 0.9
var age := 0.0
var landed := false


func _ready() -> void:
	z_index = 6


func _physics_process(delta: float) -> void:
	age += delta
	if not landed and age >= fall:
		_land()
	if age >= fall + 0.5:
		queue_free()
		return
	queue_redraw()


func _land() -> void:
	landed = true
	var main = get_parent()
	Sfx.play(get_tree(), "coin", -8.0)
	match kind:
		"stone":
			ExpStone.spawn(main, global_position, amount)
		"bones":
			if main.get("bones") != null:
				main.set("bones", int(main.get("bones")) + amount)
			Popups.text(get_tree(), global_position + Vector2(0, -14), "+%d bones" % amount, Popups.HEAL, 12)
		"chest":
			var c = TreasureScript.new()
			c.tier = "silver" if randf() < 0.3 else "wood"
			c.position = global_position
			main.call_deferred("add_child", c)


func _draw() -> void:
	if not landed:
		var f := age / fall
		var head := Vector2(-40.0, -240.0) * (1.0 - f)
		var col := Color(0.6, 0.9, 1.0) if kind == "stone" else (Color(1.0, 0.85, 0.3) if kind == "bones" else Color(1.0, 0.6, 0.9))
		for i in 6:
			draw_circle(head + Vector2(8.0, 40.0).normalized() * float(i) * 9.0, 4.0 - float(i) * 0.55, Color(col, 0.7 - float(i) * 0.1))
		SkillFx._star(self, head, 6.0, Color(1, 1, 0.9))
		SkillFx._star(self, head, 3.5, col)
		# a soft target mark so you can see where it will land
		draw_polyline(PackedVector2Array([Vector2(-6, 8), Vector2(0, 11), Vector2(6, 8)]), Color(col, 0.5 * f), 1.6)
	else:
		var b := (age - fall) / 0.5
		for i in 8:
			var d := Vector2.from_angle(float(i) * TAU / 8.0)
			draw_line(d * 4.0, d * (6.0 + 16.0 * b), Color(1, 0.95, 0.6, 1.0 - b), 1.6)
		SkillFx._star(self, Vector2.ZERO, 8.0 * (1.0 - b), Color(1, 1, 0.9, 1.0 - b))
