extends Node

const FADE_SECONDS := 2.0
const STREET_DB := -14.0
const CABIN_DB := -16.5

var street := AudioStreamPlayer.new()
var cabin := AudioStreamPlayer.new()
var indoors := false
var transition: Tween

func _ready() -> void:
    street.stream = preload("res://music/well_fog.ogg")
    cabin.stream = preload("res://music/dym_iz_truby.ogg")
    street.bus = &"Music"
    cabin.bus = &"Music"
    add_child(street)
    add_child(cabin)
    street.volume_linear = 0.0
    cabin.volume_linear = 0.0
    street.play()
    transition = create_tween()
    transition.tween_property(street, "volume_linear", db_to_linear(STREET_DB), FADE_SECONDS)

func set_indoors(value: bool) -> void:
    if indoors == value:
        return
    indoors = value
    var incoming := cabin if indoors else street
    var outgoing := street if indoors else cabin
    var target := db_to_linear(CABIN_DB if indoors else STREET_DB)
    transition.kill()
    if incoming.stream_paused:
        incoming.stream_paused = false
    elif not incoming.playing:
        incoming.play()
    transition = create_tween().set_parallel(true)
    transition.tween_property(incoming, "volume_linear", target, FADE_SECONDS)
    transition.tween_property(outgoing, "volume_linear", 0.0, FADE_SECONDS)
    transition.chain().tween_callback(func(): outgoing.stream_paused = true)
