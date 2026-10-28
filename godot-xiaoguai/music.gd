extends Node
## Background music. One track at a time with a short crossfade. Some tracks have an
## intro that plays once, then a loop. All tracks are CC0 except the last (CC-BY, credited).

const TRACKS := {
	"battle1": {"loop": "res://audio/music/boss1.ogg", "title": "Battle Theme 0", "by": "Wolfgang_ (CC0)"},
	"battle2": {"loop": "res://audio/music/boss2.ogg", "title": "Epic Boss Battle", "by": "Juhani Junkala (CC0)"},
	"battle3": {"intro": "res://audio/music/boss4_intro.ogg", "loop": "res://audio/music/boss4_loop.ogg",
			"title": "Boss Battle #2", "by": "nene (CC0)"},
	"final": {"loop": "res://audio/music/final.ogg", "title": "Blackmoor Colossus", "by": "Matthew Pablo (CC-BY 3.0)"},
	"night": {"loop": "res://audio/music/boss3.ogg", "title": "The Promise", "by": "Indieteur (CC0)"},
	# dark, fast battle music (all CC0 from opengameart.org)
	"dk_heavy_battle_1": {"loop": "res://audio/music/dk_heavy_battle_1.ogg", "title": "Heavy Battle 1", "by": "MintoDog (CC0)"},
	"dk_heavy_battle_2": {"loop": "res://audio/music/dk_heavy_battle_2.ogg", "title": "Heavy Battle 2", "by": "MintoDog (CC0)"},
	"dk_heavy_boss_1": {"loop": "res://audio/music/dk_heavy_boss_1.ogg", "title": "Heavy Boss Battle 1", "by": "MintoDog (CC0)"},
	"dk_heavy_boss_2": {"loop": "res://audio/music/dk_heavy_boss_2.ogg", "title": "Heavy Boss Battle 2", "by": "MintoDog (CC0)"},
	"dk_nene9": {"intro": "res://audio/music/dk_nene9_intro.ogg", "loop": "res://audio/music/dk_nene9_loop.ogg", "title": "Boss Battle #9 [Metal]", "by": "nene (CC0)"},
	"dk_nene8": {"intro": "res://audio/music/dk_nene8_intro.ogg", "loop": "res://audio/music/dk_nene8_loop.ogg", "title": "Boss Battle #8 Metal", "by": "nene (CC0)"},
	"dk_nene7": {"loop": "res://audio/music/dk_nene7.ogg", "title": "Boss Battle #7 (Metal)", "by": "nene (CC0)"},
	"dk_nene6": {"loop": "res://audio/music/dk_nene6.ogg", "title": "Boss Battle #6 Metal", "by": "nene (CC0)"},
	"dk_metal_chromatic": {"loop": "res://audio/music/dk_metal_chromatic.ogg", "title": "Metal (Chromatic, Electronic)", "by": "Pro Sensory (CC0)"},
	"dk_davieplier": {"loop": "res://audio/music/dk_davieplier.ogg", "title": "Heavy battle music", "by": "Davieplier (CC0)"},
	# situational tracks, made in code (synth_music.gd) and rendered to small ogg files in audio/synth/, so they need no licence
	"peace": {"loop": "res://audio/synth/peace.ogg", "title": "Quiet Meadow", "by": "generated in-game"},
	"danger": {"loop": "res://audio/synth/danger.ogg", "title": "Heartbeat", "by": "generated in-game"},
	"hidden": {"loop": "res://audio/synth/hidden.ogg", "title": "Something Stirs", "by": "generated in-game"},
	"meteor": {"loop": "res://audio/synth/meteor.ogg", "title": "Falling Sky", "by": "generated in-game"},
	"quake": {"loop": "res://audio/synth/quake.ogg", "title": "Ground Breaker", "by": "generated in-game"},
	"raid": {"loop": "res://audio/synth/raid.ogg", "title": "War Horn", "by": "generated in-game"},
	"treasure": {"loop": "res://audio/synth/treasure.ogg", "title": "Golden Rain", "by": "generated in-game"},
}
const FADE_SECONDS := 1.5

## The normal fighting music, by situation. Each track plays for TRACK_SECONDS, then the next one in
## the list starts (the first track of a pool always plays first).
## Each track plays for about a minute (looping as often as it needs to) before the next one in the pool.
const TRACK_SECONDS := 60.0
const POOLS := {
	"early": ["battle1", "dk_davieplier", "dk_metal_chromatic", "dk_nene7"],
	"mid": ["battle2", "dk_heavy_battle_1", "dk_nene6"],
	"late": ["battle3", "dk_heavy_battle_2", "dk_heavy_boss_1", "dk_nene8"],
	"night": ["night", "dk_heavy_boss_2", "dk_nene9"],
}

var volume_db := -18.0
var current := ""
var pool_name := ""      ## the pool being played ("" for a single situational track)
var pool_index := 0
var track_time := 0.0    ## seconds the current pool track has been playing
var _last_pos := 0.0
var _front: AudioStreamPlayer
var _back: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing while a menu pauses the game
	_front = AudioStreamPlayer.new()
	_back = AudioStreamPlayer.new()
	add_child(_front)
	add_child(_back)
	_fetch_music_pack()


## The web build ships its streamed music as a separate pack that is downloaded once the game is running.
const MUSIC_PACK := "music.pck"
const FIRST_TRACK := "dk_davieplier"   ## the one big-music track that ships in the first download
var pack_loaded := false


func _fetch_music_pack() -> void:
	if not OS.has_feature("web"):
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h, body: PackedByteArray):
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and not body.is_empty():
			var f := FileAccess.open("user://" + MUSIC_PACK, FileAccess.WRITE)
			if f != null:
				f.store_buffer(body)
				f.close()
				pack_loaded = ProjectSettings.load_resource_pack("user://" + MUSIC_PACK)
		if not pack_loaded:
			push_warning("Music pack could not be loaded (%d/%d)" % [result, code])
		http.queue_free())
	# the pack sits next to the page: the page address without its file name, query or hash
	var href := str(JavaScriptBridge.get_interface("location").href).split("?")[0].split("#")[0]
	var base := href.trim_suffix("/") if href.ends_with("/") else href.get_base_dir()
	http.request(base + "/" + MUSIC_PACK)


## "Title, by Composer (license)" for the track playing now, or "".
func credit_text() -> String:
	if current == "":
		return ""
	return "%s, by %s" % [TRACKS[current]["title"], TRACKS[current]["by"]]


## Start a track (or do nothing if it is already playing).
func play_track(id: String) -> bool:
	if id == current or not TRACKS.has(id):
		return false
	var info: Dictionary = TRACKS[id]
	var loop_stream: AudioStream = _load(info["loop"], true)
	if loop_stream == null and OS.has_feature("web") and not pack_loaded and id != FIRST_TRACK and not info["loop"].begins_with("res://audio/synth/"):
		# the music pack is still downloading: the one small track in the first download covers the wait
		return play_track(FIRST_TRACK)
	if loop_stream == null:
		return false
	current = id
	track_time = 0.0
	_last_pos = 0.0
	# the old front player fades out, and becomes the next back player
	var old := _front
	_front = _back
	_back = old
	var first: AudioStream = loop_stream
	if info.has("intro"):
		var intro := _load(info["intro"], false)
		if intro != null:
			first = intro
			_front.finished.connect(func():
				if current == id:
					_front.stream = loop_stream
					_front.play(), CONNECT_ONE_SHOT)
	_front.stream = first
	_front.volume_db = -60.0
	_front.play()
	create_tween().tween_property(_front, "volume_db", volume_db, FADE_SECONDS)
	if _back.playing:
		var fade := create_tween()
		fade.tween_property(_back, "volume_db", -60.0, FADE_SECONDS)
		fade.tween_callback(_back.stop)
	return true


func _load(path: String, loop: bool) -> AudioStream:
	if not ResourceLoader.exists(path):
		if not OS.has_feature("web") or pack_loaded:
			push_warning("Music file missing or not imported yet: " + path)
		return null
	var s = load(path)
	if s is AudioStreamOggVorbis:
		s.loop = loop
	return s


## Play a pool: stay on it while the situation lasts, and rotate through its tracks, each three times.
func play_pool(name: String) -> void:
	if not POOLS.has(name):
		return
	if pool_name == name and POOLS[name].has(current):
		return
	pool_name = name
	pool_index = 0
	track_time = 0.0
	_last_pos = 0.0
	play_track(POOLS[name][0])


## A single track outside the pools (events, danger, the final form...).
func play_single(id: String) -> bool:
	pool_name = ""
	return play_track(id)


func _process(delta: float) -> void:
	if pool_name == "" or current == "" or not _front.playing:
		return
	track_time += delta
	if track_time >= TRACK_SECONDS:
		track_time = 0.0
		pool_index = (pool_index + 1) % POOLS[pool_name].size()
		play_track(POOLS[pool_name][pool_index])


func stop() -> void:
	current = ""
	_front.stop()
	_back.stop()
