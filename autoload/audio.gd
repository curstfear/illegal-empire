extends Node
## Звук игры. Щелчки интерфейса — из пака Kenney Interface Sounds (CC0).
## Шум города, монеты и сирена синтезируются здесь же, при запуске (никаких файлов).

const UI := "res://assets/audio/kenney_interface/"
const MIX_RATE := 22050

## Громкость шума города днём и ночью (дБ).
const AMBIENCE_DAY_DB := -16.0
const AMBIENCE_NIGHT_DB := -24.0

var _ui_sounds: Dictionary = {}
var _coin: AudioStreamWAV
var _siren: AudioStreamWAV
var _ambience_player := AudioStreamPlayer.new()
## Несколько плееров, чтобы звуки могли звучать одновременно.
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in ["click", "open", "close", "confirmation", "error", "select"]:
		var path: String = UI + {"click": "click_002", "open": "open_002", "close": "close_002",
				"confirmation": "confirmation_002", "error": "error_004", "select": "select_002"}[id] + ".ogg"
		if ResourceLoader.exists(path):
			_ui_sounds[id] = load(path)
	for i in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_coin = _make_coin()
	_siren = _make_siren()
	_ambience_player.stream = _make_ambience()
	_ambience_player.volume_db = AMBIENCE_DAY_DB
	add_child(_ambience_player)
	# Щелчок на любой кнопке в игре — без ручной привязки к каждой.
	get_tree().node_added.connect(_on_node_added)


func _process(_delta: float) -> void:
	# Шум города слышен только в партии; ночью тише.
	var in_game := GameState.session != null and get_tree().current_scene != null \
			and get_tree().current_scene.name == "Game"
	if in_game and not _ambience_player.playing:
		_ambience_player.play()
	elif not in_game and _ambience_player.playing:
		_ambience_player.stop()
	if in_game:
		var hour := Clock.minutes_of_day() / 60.0
		var night := hour >= 21.0 or hour < 6.0
		_ambience_player.volume_db = lerpf(_ambience_player.volume_db,
				AMBIENCE_NIGHT_DB if night else AMBIENCE_DAY_DB, 0.02)


func ui(id: String) -> void:
	if _ui_sounds.has(id):
		_play(_ui_sounds[id], -6.0)


func coin() -> void:
	_play(_coin, -8.0)


func siren() -> void:
	_play(_siren, -10.0)


func _play(stream: AudioStream, volume_db: float) -> void:
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _on_node_added(node: Node) -> void:
	if node is Button and not node.toggle_mode:
		node.pressed.connect(ui.bind("click"))
	elif node is Button:
		node.toggled.connect(func(_on: bool) -> void: ui("select"))


# --- Синтез ---

## «Дзынь» монеты: два звонких тона с быстрым затуханием, второй чуть позже.
func _make_coin() -> AudioStreamWAV:
	var length := 0.45
	var samples := PackedFloat32Array()
	samples.resize(int(MIX_RATE * length))
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var first := sin(TAU * 1568.0 * t) * exp(-t * 9.0)
		var second := 0.0
		if t > 0.07:
			var t2 := t - 0.07
			second = sin(TAU * 2093.0 * t2) * exp(-t2 * 7.0) + 0.4 * sin(TAU * 4186.0 * t2) * exp(-t2 * 12.0)
		samples[i] = (first * 0.5 + second * 0.5) * 0.6
	return _to_wav(samples, false)


## Короткая сирена: тон плавно гуляет вверх-вниз два раза.
func _make_siren() -> AudioStreamWAV:
	var length := 1.6
	var samples := PackedFloat32Array()
	samples.resize(int(MIX_RATE * length))
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var freq := 700.0 + 350.0 * (0.5 - 0.5 * cos(TAU * t / 0.8))
		phase += TAU * freq / MIX_RATE
		var envelope := minf(1.0, t * 10.0) * minf(1.0, (length - t) * 4.0)
		# Немного «квадратности», чтобы звучало как сирена, а не как флейта.
		var tone := sin(phase) + 0.3 * sin(phase * 3.0) / 3.0
		samples[i] = tone * envelope * 0.35
	return _to_wav(samples, false)


## Шум улицы на 12 секунд по кругу: мягкий гул и редкие проезжающие машины.
func _make_ambience() -> AudioStreamWAV:
	var length := 12.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var samples := PackedFloat32Array()
	samples.resize(int(MIX_RATE * length))
	# Гул: «коричневый» шум (сглаженный белый) — низкий и мягкий; утечка не даёт ему уползти.
	var brown := 0.0
	for i in samples.size():
		brown = brown * 0.995 + rng.randf_range(-1.0, 1.0) * 0.03
		samples[i] = brown * 0.8
	# Машины: нарастающий и затихающий шорох шин в случайные моменты.
	for car in 5:
		var start := rng.randf_range(0.0, length - 3.0)
		var duration := rng.randf_range(2.0, 3.0)
		var smooth := 0.0
		for i in int(duration * MIX_RATE):
			var t := float(i) / (duration * MIX_RATE)
			smooth = lerpf(smooth, rng.randf_range(-1.0, 1.0), 0.18)
			var index := int(start * MIX_RATE) + i
			samples[index] += smooth * sin(PI * t) * sin(PI * t) * 0.35
	# Плавный переход конца в начало, чтобы не было щелчка на стыке.
	var fade := int(0.5 * MIX_RATE)
	for i in fade:
		var k := float(i) / fade
		samples[i] = samples[i] * k + samples[samples.size() - fade + i] * (1.0 - k)
	return _to_wav(samples, true)


func _to_wav(samples: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav
