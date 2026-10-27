extends SceneTree
func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	main.pause_on_menu = false
	var p = main.player
	p.choose_line(0)
	p.stage = 6
	p.learn("nova"); p.learn("roar"); p.learn("bolt")
	for i in 5:
		var v = main._spawn_villager(p.global_position + Vector2(40 + i * 12, -30 + i * 20), 0, 0, -1)
		v.skill_cd = 9999.0
	p.cast("nova")
	await create_timer(0.2).timeout
	p.cast("bolt", Vector2.RIGHT)
	SkillFx.spawn_tooth(main, p.global_position + Vector2(50, 0), Vector2.RIGHT, 1.6)
	await create_timer(0.12).timeout
	get_root().get_viewport().get_texture().get_image().save_png("C:/Users/jacks/Game/art-review/shots/fx_nova.png")
	quit()
