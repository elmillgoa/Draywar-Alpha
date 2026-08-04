extends Node

## Thin audio floor — Steam S10.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S10 §11
##
## Autoload `AudioService`. Procedural short tones (no external packs). UI + SFX
## buses; master volume via SettingsService.

var _ui_player: AudioStreamPlayer = null
var _sfx_player: AudioStreamPlayer = null


func _ready() -> void:
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = String(BalanceSettings.BUS_UI)
	add_child(_ui_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = String(BalanceSettings.BUS_SFX)
	add_child(_sfx_player)
	EventBus.on_weapon_fired.connect(_on_weapon_fired)
	EventBus.on_docked.connect(_on_docked)
	EventBus.on_undocked.connect(_on_undocked)


func _exit_tree() -> void:
	if EventBus.on_weapon_fired.is_connected(_on_weapon_fired):
		EventBus.on_weapon_fired.disconnect(_on_weapon_fired)
	if EventBus.on_docked.is_connected(_on_docked):
		EventBus.on_docked.disconnect(_on_docked)
	if EventBus.on_undocked.is_connected(_on_undocked):
		EventBus.on_undocked.disconnect(_on_undocked)


func play_ui_click() -> void:
	_play(
		_ui_player,
		BalanceSettings.TONE_UI_CLICK_HZ,
		BalanceSettings.TONE_UI_CLICK_SEC,
		BalanceSettings.TONE_UI_CLICK_PEAK
	)


func play_ui_confirm() -> void:
	_play(
		_ui_player,
		BalanceSettings.TONE_UI_CONFIRM_HZ,
		BalanceSettings.TONE_UI_CONFIRM_SEC,
		BalanceSettings.TONE_UI_CONFIRM_PEAK
	)


func play_weapon() -> void:
	_play(
		_sfx_player,
		BalanceSettings.TONE_WEAPON_HZ,
		BalanceSettings.TONE_WEAPON_SEC,
		BalanceSettings.TONE_WEAPON_PEAK
	)


func play_dock() -> void:
	_play(
		_sfx_player,
		BalanceSettings.TONE_DOCK_HZ,
		BalanceSettings.TONE_DOCK_SEC,
		BalanceSettings.TONE_DOCK_PEAK
	)


func play_undock() -> void:
	_play(
		_sfx_player,
		BalanceSettings.TONE_UNDOCK_HZ,
		BalanceSettings.TONE_UNDOCK_SEC,
		BalanceSettings.TONE_UNDOCK_PEAK
	)


func _on_weapon_fired() -> void:
	play_weapon()


func _on_docked(_station_id: StringName) -> void:
	play_dock()


func _on_undocked(_station_id: StringName) -> void:
	play_undock()


func _play(player: AudioStreamPlayer, hz: float, seconds: float, peak: float) -> void:
	if player == null:
		return
	player.stream = make_tone(hz, seconds, peak)
	player.play()


## Tiny mono PCM beep (no asset files). Public for tests.
func make_tone(hz: float, seconds: float, peak: float) -> AudioStreamWAV:
	var sample_rate: int = BalanceSettings.TONE_SAMPLE_RATE
	var frame_count: int = maxi(1, int(float(sample_rate) * seconds))
	var data: PackedByteArray = PackedByteArray()
	data.resize(frame_count * BalanceSettings.TONE_BYTES_PER_SAMPLE)
	for i: int in range(frame_count):
		var t: float = float(i) / float(sample_rate)
		var env: float = 1.0 - (float(i) / float(frame_count))
		var sample: float = sin(TAU * hz * t) * peak * env
		var s16: int = clampi(
			int(sample * float(BalanceSettings.TONE_PCM_PEAK_INT)),
			BalanceSettings.TONE_PCM_MIN_INT,
			BalanceSettings.TONE_PCM_PEAK_INT
		)
		data.encode_s16(i * BalanceSettings.TONE_BYTES_PER_SAMPLE, s16)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
