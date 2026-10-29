extends Control
## The skill bar at the bottom middle: an icon for every skill 小怪 has learned. Skills that fire by
## themselves show a clockwise cooldown sweep (the dark wedge shrinks clockwise until the skill is ready) and
## the seconds left. Passive skills and special skills show their rank.

const SkillsData := preload("res://skills.gd")

const SLOT := 40.0
const GAP := 6.0
const PER_ROW := 14

## Phone layouts change these: fewer slots per row, bigger slots, and rows growing down from the top left.
var slot := SLOT
var per_row := PER_ROW
var from_top := false

var main_node: Node2D
var _t := 0.0


func setup(main: Node2D) -> void:
	main_node = main
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_layout(SLOT, PER_ROW, false)


## Size the bar for `n` slots of `s` pixels a row; `top` lays the rows out left-aligned from the top.
func set_layout(s: float, n: int, top: bool) -> void:
	slot = s
	per_row = n
	from_top = top
	custom_minimum_size = Vector2(per_row * (slot + GAP), 2.0 * (slot + GAP))
	size = custom_minimum_size


## How tall the rows in use are right now (0 with no skills).
func used_height() -> float:
	if main_node == null or main_node.player == null:
		return 0.0
	var n: int = main_node.player.skills.size() + main_node.player.specials.size()
	return ceili(n / float(per_row)) * (slot + GAP)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## The picture for a skill id: ordinary skill, form skill or special.
func icon_for(id: String) -> Texture2D:
	var name := ""
	if SkillsData.SPECIALS.has(id):
		name = "icon_sp_" + id
	elif SkillsData.form_skills().has(id):
		name = "icon_fs_" + id
	elif id == "magnet":
		name = "icon_magnet"
	elif id == "doom":
		name = "icon_roar"
	else:
		name = "icon_" + str(main_node.SKILL_ICONS.get(id, id))
	return Sprites.icon(name, 2)


## Seconds a skill waits between uses at its current rank (the same maths the player uses).
func full_cooldown(id: String, rank: int) -> float:
	var info: Dictionary = SkillsData.info(id)
	var base := float(info.get("cd", 0.0))
	if base <= 0.0:
		return 0.0
	return base * (1.0 - 0.1 * (rank - 1)) * (0.65 if main_node.player.specials.has("stormcaller") else 1.0)


func _draw() -> void:
	if main_node == null or main_node.player == null:
		return
	var p = main_node.player
	var ids: Array = []
	for id in p.skills:
		ids.append(id)
	for id in p.specials:
		ids.append(id)
	if ids.is_empty():
		return
	# auto skills first, so the ones with a cooldown sit together
	ids.sort_custom(func(a, b):
		var aa: bool = SkillsData.info(a).has("auto")
		var ab: bool = SkillsData.info(b).has("auto")
		return aa if aa != ab else str(a) < str(b))
	var rows := ceili(ids.size() / float(per_row))
	for r in rows:
		var in_row := mini(per_row, ids.size() - r * per_row)
		var row_w := in_row * (slot + GAP) - GAP
		var x0 := 0.0 if from_top else (size.x - row_w) * 0.5
		var y := float(r) * (slot + GAP) if from_top else size.y - (slot + 2.0) - float(rows - 1 - r) * (slot + GAP)
		for i in in_row:
			var id: String = ids[r * per_row + i]
			_slot(Rect2(x0 + i * (slot + GAP), y, slot, slot), id, p)


func _slot(rect: Rect2, id: String, p) -> void:
	var is_special := SkillsData.SPECIALS.has(id)
	var info: Dictionary = SkillsData.info(id) if not is_special else SkillsData.SPECIALS[id]
	var rank: int = 1 if is_special else int(p.skills.get(id, 1))
	var cd_total := 0.0 if is_special else full_cooldown(id, rank)
	var cd_left: float = float(p.skill_cd.get(id, 0.0)) if cd_total > 0.0 else 0.0
	draw_rect(rect, Color(0.05, 0.05, 0.1, 0.8))
	var tex := icon_for(id)
	if tex != null:
		draw_texture_rect(tex, rect.grow(-2.0), false)
	var ready := cd_total > 0.0 and cd_left <= 0.0
	if cd_left > 0.0:
		# the dark wedge starts full and is eaten away clockwise from 12 o'clock
		var f := clampf(cd_left / cd_total, 0.0, 1.0)
		var c := rect.get_center()
		var r := slot * 0.75
		var pts := PackedVector2Array([c])
		var a0 := -PI * 0.5 + TAU * (1.0 - f)
		var a1 := -PI * 0.5 + TAU
		for i in 25:
			var a := lerpf(a0, a1, float(i) / 24.0)
			var q := c + Vector2(cos(a), sin(a)) * r
			pts.append(Vector2(clampf(q.x, rect.position.x, rect.end.x), clampf(q.y, rect.position.y, rect.end.y)))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.62))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, slot * 0.62), "%.0f" % ceilf(cd_left), HORIZONTAL_ALIGNMENT_CENTER, slot, 15 if slot <= SLOT else 18, Color(1, 1, 1, 0.95))
	var border := Color(0.8, 0.8, 0.9, 0.5)
	if ready:
		border = Color(0.5, 1.0, 0.6, 0.6 + 0.4 * sin(_t * 6.0))
	elif is_special:
		border = Color(1.0, 0.85, 0.3, 0.9)
	draw_rect(rect, border, false, 2.0)
	if not is_special and int(info.get("max", 1)) > 1:
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(slot - 14.0, slot - 3.0), str(rank), HORIZONTAL_ALIGNMENT_LEFT, 14, 12 if slot <= SLOT else 15, Color(1, 1, 0.7))
