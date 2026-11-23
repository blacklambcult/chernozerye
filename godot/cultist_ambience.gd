extends Node3D
## Original procedural sound textures; no external downloads or audio assets.
var _steps: Array[AudioStreamWAV] = []
var _rustle: AudioStreamWAV
var _breath: AudioStreamWAV
var _murmur: AudioStreamWAV
var _foot: AudioStreamPlayer3D
var _cloth: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
var _distance := 0.0
var _timer := 3.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.seed = 91371
    for i in range(4):
        _steps.append(_make_sound(0, 0.29 + i * 0.018))
    _rustle = _make_sound(1, 0.38)
    _breath = _make_sound(2, 1.25)
    _murmur = _make_sound(3, 2.3)
    _foot = _speaker("Footsteps", 0.15, -13.0, 12.0)
    _cloth = _speaker("RobeRustle", 0.95, -24.0, 8.0)
    _voice = _speaker("QuietVoice", 1.58, -22.0, 10.0)

func _speaker(label: String, height: float, db: float, reach: float) -> AudioStreamPlayer3D:
    var p := AudioStreamPlayer3D.new()
    p.name = label
    p.position.y = height
    p.volume_db = db
    p.max_distance = reach
    p.unit_size = 1.4
    p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
    add_child(p)
    return p

func _make_sound(kind: int, seconds: float) -> AudioStreamWAV:
    var rate := 22050
    var count := int(seconds * rate)
    var bytes := PackedByteArray()
    bytes.resize(count * 2)
    var low := 0.0
    var phase := 0.0
    for i in range(count):
        var t := float(i) / rate
        var u := t / seconds
        var n := _rng.randf_range(-1.0, 1.0)
        low = lerpf(low, n, 0.10)
        var x := 0.0
        if kind == 0:
            x = (low * 0.65 + n * 0.13 + sin(TAU * (65.0 * t - 28.0 * t * t)) * 0.32) * exp(-t * 16.0) * minf(1.0, t * 350.0)
            x += n * 0.16 * exp(-pow((t - 0.11) / 0.045, 2.0))
        elif kind == 1:
            x = (n - low) * 0.22 * pow(sin(PI * u), 2.0) * (0.7 + 0.3 * sin(t * 48.0))
        elif kind == 2:
            x = (low * 0.50 + n * 0.08) * pow(sin(PI * u), 2.0)
        else:
            phase += TAU * (92.0 + 8.0 * sin(t * 5.3)) / rate
            var syllable := pow(0.5 + 0.5 * sin(t * 10.7 + sin(t * 4.0)), 2.0)
            x = (sin(phase) * 0.16 + sin(phase * 2.0) * 0.07 + low * 0.15) * syllable * pow(sin(PI * u), 1.4)
        bytes.encode_s16(i * 2, int(clampf(x, -1.0, 1.0) * 32760.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.stereo = false
    stream.data = bytes
    return stream

func update_motion(delta: float, travelled: float, grounded: bool) -> void:
    if _foot == null:
        return
    if grounded and travelled > 0.0001:
        _distance += travelled
        if _distance >= PI / 9.5:
            _distance = fmod(_distance, PI / 9.5)
            _foot.stream = _steps[_rng.randi_range(0, _steps.size() - 1)]
            _foot.pitch_scale = _rng.randf_range(0.92, 1.08)
            _foot.play()
            if not _cloth.playing:
                _cloth.stream = _rustle
                _cloth.pitch_scale = _rng.randf_range(0.88, 1.12)
                _cloth.play()
    _timer -= delta
    if _timer <= 0.0 and not _voice.playing:
        _voice.stream = _murmur if _rng.randf() < 0.23 else _breath
        _voice.pitch_scale = _rng.randf_range(0.92, 1.06)
        _voice.play()
        _timer = _rng.randf_range(5.0, 11.0)
