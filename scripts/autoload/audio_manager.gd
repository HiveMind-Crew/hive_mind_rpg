extends Node
## AudioManager autoload (issue #25): central playback for the placeholder
## audio pass. SFX round-robin through a small pool of players so overlapping
## combat sounds don't cut each other off; the ambient drone loops by
## replaying itself on finished. Streams load lazily and degrade to a
## one-time warning when an asset is missing or not yet imported, so a bad
## asset can never take the game down. Sources/licenses: assets/audio/LICENSES.md.

const SFX_STREAM_PATHS: Dictionary[StringName, String] = {
	&"melee_swing": "res://assets/audio/sfx_melee_swing.wav",
	&"relic_cast": "res://assets/audio/sfx_relic_cast.wav",
	&"dash": "res://assets/audio/sfx_dash.wav",
	&"hit": "res://assets/audio/sfx_hit.wav",
	&"death": "res://assets/audio/sfx_death.wav",
}
const AMBIENT_STREAM_PATHS: Dictionary[StringName, String] = {
	&"forest_drone": "res://assets/audio/ambient_forest_drone.wav",
}
const DEFAULT_AMBIENT: StringName = &"forest_drone"
const SFX_PLAYER_COUNT: int = 8
const SFX_VOLUME_DB: float = -6.0
const AMBIENT_VOLUME_DB: float = -14.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
var _ambient_player: AudioStreamPlayer
var _current_ambient_id: StringName = &""
var _stream_cache: Dictionary[String, AudioStream] = {}
var _warned_paths: Dictionary[String, bool] = {}


func _ready() -> void:
	for _index: int in SFX_PLAYER_COUNT:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = SFX_VOLUME_DB
		add_child(player)
		_sfx_players.append(player)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.volume_db = AMBIENT_VOLUME_DB
	# WAV loop points live in import metadata this placeholder pass doesn't
	# rely on; replaying on finished keeps the drone going regardless.
	_ambient_player.finished.connect(_on_ambient_finished)
	add_child(_ambient_player)
	play_ambient(DEFAULT_AMBIENT)


## Returns false only for unknown ids; playback itself is best-effort so a
## missing/unimported asset warns once instead of erroring every swing.
func play_sfx(sfx_id: StringName) -> bool:
	if not SFX_STREAM_PATHS.has(sfx_id):
		push_warning("AudioManager has no SFX named '%s'." % sfx_id)
		return false
	var stream: AudioStream = _get_stream(SFX_STREAM_PATHS[sfx_id])
	if stream != null:
		var player: AudioStreamPlayer = _sfx_players[_next_sfx_player]
		_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
		player.stream = stream
		player.play()
	return true


func play_ambient(ambient_id: StringName = DEFAULT_AMBIENT) -> bool:
	if not AMBIENT_STREAM_PATHS.has(ambient_id):
		push_warning("AudioManager has no ambient loop named '%s'." % ambient_id)
		return false
	_current_ambient_id = ambient_id
	var stream: AudioStream = _get_stream(AMBIENT_STREAM_PATHS[ambient_id])
	if stream != null:
		_ambient_player.stream = stream
		_ambient_player.play()
	return true


func stop_ambient() -> void:
	_current_ambient_id = &""
	_ambient_player.stop()


func get_current_ambient_id() -> StringName:
	return _current_ambient_id


func is_ambient_playing() -> bool:
	return _current_ambient_id != StringName()


func _on_ambient_finished() -> void:
	if is_ambient_playing():
		_ambient_player.play()


func _get_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		if not _warned_paths.has(path):
			_warned_paths[path] = true
			push_warning("AudioManager could not find audio stream '%s'." % path)
		return null
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		if not _warned_paths.has(path):
			_warned_paths[path] = true
			push_warning("AudioManager could not load '%s' as an AudioStream." % path)
		return null
	_stream_cache[path] = stream
	return stream
