extends Node
## Audio: two buses (Music, SFX), a small pool for one-shots, and speed/surface-driven roll and grind loops.

const SFX_NAMES: PackedStringArray = [
	"ollie", "land", "land_hard", "crack", "flip", "grab", "trick", "bail", "bank", "bank_big", "combo_lost", "grind_start",
	"pickup", "skate_done", "go", "time_up", "ui_ok", "manual",
]
## Per-sound gain in dB from the Wavelength SFX set (audio/wavelength/levels.json): the files are peak-normalised,
## so this equalises how loud each one feels. The SFX bus sits 4.5 dB down to leave room for the boosts.
const LEVEL_DB: Dictionary = {
	"ollie": 0.0,
	"land": 0.0,
	"land_hard": 3.5,
	"crack": 3.0,
	"flip": 0.0,
	"grab": 1.0,
	"manual": -14.5,
	"bail": -3.0,
	"grind_start": 5.5,
	"trick": -5.5,
	"bank": -5.5,
	"bank_big": 1.0,
	"combo_lost": -8.0,
	"pickup": -9.0,
	"skate_done": -3.0,
	"go": -8.0,
	"time_up": -4.0,
	"ui_ok": -7.0,
	"roll_loop": -13.5,
	"roll_grass_loop": -14.0,
	"roll_wood_loop": -14.5,
	"grind_loop": -13.0,
}
const LOOP_NAMES: PackedStringArray = ["roll_loop", "roll_grass_loop", "roll_wood_loop", "grind_loop"]

var music_on: bool = true
var _pool: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _loops: Dictionary = {}          # name -> AudioStreamPlayer
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _fade_tw: Tween
var _music_track: String = ""
var _jingle: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _pool_i: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus("Music", -9.0)
	_make_bus("SFX", -4.5)
	var lp: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 700.0
	var mb: int = AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(mb) == 0:
		AudioServer.add_bus_effect(mb, lp)
		AudioServer.set_bus_effect_enabled(mb, 0, false)
	for n in SFX_NAMES:
		var s: AudioStream = load("res://assets/audio/sfx/%s.wav" % n)
		_streams[n] = s
	for i in 12:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for n in LOOP_NAMES:
		var s: AudioStreamWAV = load("res://assets/audio/sfx/%s.wav" % n)
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)   # frames; data.size() / 2 is wrong for QOA/ADPCM imports
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = s
		p.bus = "SFX"
		p.volume_db = -60.0
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM   # web default is Sample, which restarts looping buffers
		add_child(p)
		p.play()
		_loops[n] = p
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "SFX"
	_ambience.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_ambience)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_music)
	_jingle = AudioStreamPlayer.new()
	_jingle.bus = "Music"
	add_child(_jingle)
	_sting = AudioStreamPlayer.new()
	_sting.bus = "Music"
	add_child(_sting)
	music_on = Game.music_choice != "off"
	apply_settings()


func _make_bus(bus_name: String, db: float) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var i: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_volume_db(i, db)
	AudioServer.set_bus_send(i, "Master")


## Background sound of the place (wind, birds, distant traffic): a quiet loop under everything. "" stops it.
func play_ambience(ambience_name: String, vol_db: float = -12.0) -> void:
	if ambience_name == "":
		_ambience.stop()
		return
	var path: String = "res://assets/audio/ambience/%s.ogg" % ambience_name
	if not ResourceLoader.exists(path):
		return
	var s: AudioStreamOggVorbis = load(path)
	s.loop = true
	if _ambience.stream != s or not _ambience.playing:
		_ambience.stream = s
		_ambience.play()
	_ambience.volume_db = vol_db


## Pause menu: effects go quiet (the rolling loops would hold their last volume) and the music sounds muffled.
func set_paused(v: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), v)
	var mb: int = AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(mb) > 0:
		AudioServer.set_bus_effect_enabled(mb, 0, v)


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(Game.master_volume, 0.0001, 1.0)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)


func toggle_music() -> bool:
	music_on = not music_on
	apply_settings()
	return music_on


## Start a looping track from res://assets/audio/music/<track>.ogg (no restart if it is already playing).
func play_music(track: String = "grip_tape_summer") -> void:
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()                      # a restart during the results fade must not be faded out and stopped
		_fade_tw = null
	if _music_track == track and _music.playing:
		return
	var path: String = "res://assets/audio/music/%s.ogg" % track
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/music/grip_tape_summer.ogg"
	var m: AudioStreamOggVorbis = load(path)
	m.loop = true
	_music.stream = m
	_music.volume_db = 0.0
	_music_track = track
	_music.play()


func play(sfx_name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var s: AudioStream = _streams.get(sfx_name)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_pool_i]
	p.bus = "Master" if get_tree().paused else "SFX"     # menu clicks while the SFX bus is muted for pause
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = s
	p.volume_db = vol_db + float(LEVEL_DB.get(sfx_name, 0.0))
	p.pitch_scale = pitch
	p.play()


## Called every frame with the skater's state: keeps the right rolling loop audible.
func set_rolling(speed: float, surface: String, on_ground: bool, dt: float) -> void:
	var loud: float = clampf(speed / 11.0, 0.0, 1.0) if on_ground else 0.0
	var target: Dictionary = {"roll_loop": 0.0, "roll_grass_loop": 0.0, "roll_wood_loop": 0.0}
	match surface:
		"grass":
			target["roll_grass_loop"] = loud
		"wood":
			target["roll_wood_loop"] = loud
		_:
			target["roll_loop"] = loud
	for k in target:
		var p: AudioStreamPlayer = _loops[k]
		var want_db: float = -60.0 if target[k] < 0.02 else float(LEVEL_DB.get(k, 0.0)) + lerpf(-14.0, 0.0, target[k])
		p.volume_db = lerpf(p.volume_db, want_db, 1.0 - exp(-14.0 * dt))
		p.pitch_scale = 0.7 + clampf(speed, 0.0, 14.0) * 0.045


func set_grinding(active: bool, speed: float, dt: float) -> void:
	var p: AudioStreamPlayer = _loops["grind_loop"]
	var want_db: float = float(LEVEL_DB.get("grind_loop", 0.0)) + lerpf(-8.0, 0.0, clampf(speed / 10.0, 0.0, 1.0)) if active else -60.0
	p.volume_db = lerpf(p.volume_db, want_db, 1.0 - exp(-20.0 * dt))
	p.pitch_scale = 0.85 + clampf(speed, 0.0, 14.0) * 0.03


## Fade the looping theme out (the results jingle takes over).
func fade_music(seconds: float = 0.6) -> void:
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(_music, "volume_db", -40.0, seconds)
	_fade_tw.tween_callback(_music.stop)
	_music_track = ""


## One-shot musical stinger from res://assets/audio/jingles/<name>.ogg. slot 1 = the second player, so a
## sting can sit on top of a jingle.
func play_jingle(jingle_name: String, vol_db: float = 0.0, slot: int = 0) -> void:
	var path: String = "res://assets/audio/jingles/%s.ogg" % jingle_name
	if not ResourceLoader.exists(path):
		return
	var m: AudioStreamOggVorbis = load(path)
	m.loop = false
	var p: AudioStreamPlayer = _sting if slot == 1 else _jingle
	p.stream = m
	p.volume_db = vol_db
	p.play()


## Gameplay track for the current music choice.
func gameplay_track() -> String:
	return "rail_rush" if Game.music_choice == "hype" else "grip_tape_summer"


## cruise -> hype -> off -> cruise. Returns the new choice.
func cycle_music_choice() -> String:
	match Game.music_choice:
		"cruise":
			Game.music_choice = "hype"
		"hype":
			Game.music_choice = "off"
		_:
			Game.music_choice = "cruise"
	Game.save()
	music_on = Game.music_choice != "off"
	apply_settings()
	return Game.music_choice
