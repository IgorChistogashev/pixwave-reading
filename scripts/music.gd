extends AudioStreamPlayer
## Original local loop. Quiet during all reading and adult panels.
const NORMAL_DB = -18.0
const QUIET_DB = -70.0
var enabled := true
var quiet := false
var fade: Tween

func _ready() -> void:
	var track: AudioStreamWAV = load("res://assets/audio/pixwave_meadow.wav")
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_begin = 0
	track.loop_end = roundi(track.get_length() * track.mix_rate)
	stream = track
	volume_db = NORMAL_DB if enabled else QUIET_DB
	if enabled:
		play()

func set_quiet(value: bool) -> void:
	quiet = value
	update_level()

func set_enabled(value: bool) -> void:
	enabled = value
	if enabled and not playing:
		play()
	update_level()

func update_level() -> void:
	if fade != null:
		fade.kill()
	fade = create_tween()
	fade.tween_property(self, "volume_db", QUIET_DB if quiet or not enabled else NORMAL_DB, 0.3)
	if not enabled:
		fade.tween_callback(stop)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		stream_paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		stream_paused = false
