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
	# more everyday fighting music (all CC0 from opengameart.org), so every run can open with a different tune
	"ng_battle_a": {"loop": "res://audio/music/ng_battle_a.ogg", "title": "Battle Theme A", "by": "cynicmusic (CC0)"},
	"ng_pursuit": {"loop": "res://audio/music/ng_pursuit.ogg", "title": "Determined Pursuit", "by": "Emma_MA (CC0)"},
	"ng_serpents": {"loop": "res://audio/music/ng_serpents.ogg", "title": "Ancient Power of Serpents", "by": "Kevin MacLeod (CC0)"},
	"ng_legend": {"loop": "res://audio/music/ng_legend.ogg", "title": "A Legend Will Rise", "by": "CodeManu (CC0)"},
	"ng_unexplored": {"loop": "res://audio/music/ng_unexplored.ogg", "title": "Unexplored", "by": "Bo Jingles and TAD (CC0)"},
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
	"early": ["battle1", "dk_davieplier", "dk_metal_chromatic", "dk_nene7", "ng_legend", "ng_unexplored"],
	"mid": ["battle2", "dk_heavy_battle_1", "dk_nene6", "ng_battle_a", "ng_pursuit"],
	"late": ["battle3", "dk_heavy_battle_2", "dk_heavy_boss_1", "dk_nene8", "ng_serpents"],
	"night": ["night", "dk_heavy_boss_2", "dk_nene9"],
}

## Every track is normalized to the same loudness (art/tools/normalize_music.py), so one volume fits them all.
var volume_db := -11.0
var current := ""
var pool_name := ""      ## the pool being played ("" for a single situational track)
var pool_index := 0
var random_start := false   ## a real run starts each pool on a random track, so every launch sounds different
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
	random_start = DisplayServer.get_name() != "headless" and not Engine.has_meta("deterministic_map")
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
				if pack_loaded:
					_retry_pool()
		if not pack_loaded:
			push_warning("Music pack could not be loaded (%d/%d)" % [result, code])
		http.queue_free())
	# the pack sits next to the page: the page address without its file name, query or hash
	var href := str(JavaScriptBridge.get_interface("location").href).split("?")[0].split("#")[0]
	var base := href.trim_suffix("/") if href.ends_with("/") else href.get_base_dir()
	http.request(base + "/" + MUSIC_PACK)


## The pack just arrived: if the small stand-in track is playing for a pool, switch to the track the pool really wanted.
func _retry_pool() -> void:
	if pool_name != "" and current == FIRST_TRACK and POOLS[pool_name][pool_index] != FIRST_TRACK:
		var want: String = POOLS[pool_name][pool_index]
		current = ""
		play_track(want)


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
	var player := _front   # (kept, so a later swap cannot make the intro handler act on the wrong player)
	_kill_fade(player)     # a fade left over from this player's last turn must not touch the new track
	for c in player.finished.get_connections():
		player.finished.disconnect(c["callable"])
	var first: AudioStream = loop_stream
	if info.has("intro"):
		var intro := _load(info["intro"], false)
		if intro != null:
			first = intro
			player.finished.connect(func():
				if current == id and player == _front:
					player.stream = loop_stream
					player.play(), CONNECT_ONE_SHOT)
	player.stream = first
	player.volume_db = -60.0
	player.play()
	_fade(player, volume_db, false)
	if _back.playing:
		_fade(_back, -60.0, true)
	return true


var _fades := {}   ## player -> its running fade tween


func _kill_fade(p: AudioStreamPlayer) -> void:
	var t = _fades.get(p)
	if t != null and is_instance_valid(t):
		t.kill()
	_fades.erase(p)


## Fade one player to a volume; the old track is stopped when its fade-out ends (only if it was not reused meanwhile).
func _fade(p: AudioStreamPlayer, to_db: float, then_stop: bool) -> void:
	_kill_fade(p)
	var tw := create_tween()
	_fades[p] = tw
	tw.tween_property(p, "volume_db", to_db, FADE_SECONDS)
	if then_stop:
		tw.tween_callback(func():
			if p != _front:
				p.stop())


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
	pool_index = randi() % POOLS[name].size() if random_start else 0
	track_time = 0.0
	_last_pos = 0.0
	play_track(POOLS[name][pool_index])


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
	_kill_fade(_front)
	_kill_fade(_back)
	_front.stop()
	_back.stop()
