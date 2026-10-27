extends RefCounted
## Damage numbers. Popups.damage(get_tree(), position, 7) shows a 7 floating up from a spot.
## There is a cap, so a huge fight does not bury the screen in numbers.

const FloaterScript := preload("res://floater.gd")
const MAX_ACTIVE := 70

static var enabled := true
static var active := 0

const WHITE := Color("ffffff")
const BIG := Color("ffd84a")        ## 6 or more damage
const TOWER := Color("9fd8ff")      ## damage done by towers
const HURT := Color("ff5a5a")       ## damage 小怪 takes
const HEAL := Color("6ee07a")
const BURN := Color("ff9a3a")
const POISON := Color("8fe84a")
const BLEED := Color("e04848")
const STRUCTURE := Color("ffb070")  ## damage to towers and walls


## Show some text (a number, "Dodge!") floating up from a spot.
static func text(tree: SceneTree, pos: Vector2, label: String, color: Color = WHITE, size: int = 14) -> bool:
	if not enabled or tree == null or active >= MAX_ACTIVE:
		return false
	var pl = tree.get_first_node_in_group("player")
	if pl == null or pl.get_parent() == null:
		return false
	var f = FloaterScript.new()
	f.text = label
	f.color = color
	f.font_size = size
	f.position = pos + Vector2(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0))
	active += 1
	pl.get_parent().add_child.call_deferred(f)
	return true


## A damage number. Big hits are yellow and larger.
static func damage(tree: SceneTree, pos: Vector2, amount: int, color: Color = WHITE) -> bool:
	if amount <= 0:
		return false
	if color == WHITE and amount >= 6:
		return text(tree, pos, str(amount), BIG, 20)
	return text(tree, pos, str(amount), color, 16 if amount >= 3 else 13)
