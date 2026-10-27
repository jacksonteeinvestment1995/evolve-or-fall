extends Node
## The YouTube Playables SDK bridge. In a Playable (a web build running inside YouTube) it
## calls the SDK the certification asks for; everywhere else (desktop, tests, a plain
## browser) every call is a harmless no-op, so the same game runs in both places.
##
## Required by the Playables rules:
##   * the SDK script is loaded before the game (export preset: html/head_include)
##   * firstFrameReady() while a loading screen shows, then gameReady() once play can start
##   * pause everything on onPause, and only resume on onResume
##   * follow YouTube's mute (isAudioEnabled / onAudioEnabledChange)
## No eval(), no Page Visibility API, no outside network calls.

signal pause_changed(paused: bool)
signal audio_changed(enabled: bool)

const SDK_URL := "https://www.youtube.com/game_api/v1"  ## used by the export preset, listed here for reference

var active := false          ## true only inside YouTube Playables
var paused := false
var audio_enabled := true
var calls: Array[String] = []  ## what was called, in order (the tests read this)

var _yt = null
var _keep: Array = []        ## JavaScript callbacks must stay referenced or they are collected


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		return
	_yt = JavaScriptBridge.get_interface("ytgame")
	if _yt == null or not bool(_yt.IN_PLAYABLES_ENV):
		_yt = null
		return
	active = true
	var system = _yt.system
	audio_enabled = bool(system.isAudioEnabled())
	_keep.append(JavaScriptBridge.create_callback(_js_pause))
	_keep.append(JavaScriptBridge.create_callback(_js_resume))
	_keep.append(JavaScriptBridge.create_callback(_js_audio))
	system.onPause(_keep[0])
	system.onResume(_keep[1])
	system.onAudioEnabledChange(_keep[2])
	_apply_audio()


## Call when the first frame is on screen and a loading screen shows that loading is going on.
func first_frame_ready() -> void:
	calls.append("firstFrameReady")
	if active:
		var game = _yt.game
		game.firstFrameReady()


## Call when the game is ready for the player (the title screen is clickable).
func game_ready() -> void:
	calls.append("gameReady")
	if active:
		var game = _yt.game
		game.gameReady()


func _js_pause(_args) -> void:
	on_pause()


func _js_resume(_args) -> void:
	on_resume()


func _js_audio(args) -> void:
	on_audio_changed(bool(args[0]))


## YouTube asks the game to stop everything.
func on_pause() -> void:
	paused = true
	_apply_pause()
	pause_changed.emit(true)


## YouTube says the game may run again.
func on_resume() -> void:
	paused = false
	_apply_pause()
	pause_changed.emit(false)


## The YouTube mute button changed: nothing may play while it is muted.
func on_audio_changed(enabled: bool) -> void:
	audio_enabled = enabled
	_apply_audio()
	audio_changed.emit(enabled)


func _apply_pause() -> void:
	get_tree().paused = paused or _extra_pause()
	# music and effects stop too, and pick up again where they were
	for p in _all_players(get_tree().root):
		p.stream_paused = paused


func _apply_audio() -> void:
	AudioServer.set_bus_mute(0, not audio_enabled)


## The game's own pauses (title screen, menus) must survive a resume from YouTube.
func _extra_pause() -> bool:
	var level = get_parent()
	return level != null and level.has_method("wants_pause") and level.wants_pause()


func _all_players(node: Node) -> Array:
	var out: Array = []
	if node is AudioStreamPlayer:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_players(c))
	return out
